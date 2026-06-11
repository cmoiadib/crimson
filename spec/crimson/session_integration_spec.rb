require "spec_helper"
require "tmpdir"

RSpec.describe "Session integration" do
  let(:tmp_dir) { Dir.mktmpdir("crimson_integration") }
  let(:cwd) { "/test/project" }
  let(:session_manager) { Crimson::SessionManager.new(sessions_dir: tmp_dir) }

  let(:mock_client) { IntMockClient.new }
  let(:registry) { Crimson::ToolRegistry.new }
  let(:system_prompt) { "You are helpful." }

  module IntEchoTool
    TOOL_NAME = "echo"
    def self.definition
      { type: "function", function: { name: TOOL_NAME, description: "Echo", parameters: { type: "object", properties: { text: { type: "string" } }, required: ["text"] } } }
    end
    def self.anthropic_definition
      { name: TOOL_NAME, description: "Echo", input_schema: { type: "object", properties: { text: { type: "string" } }, required: ["text"] } }
    end
    def self.call(text:)
      "echo: #{text}"
    end
  end

  class IntMockClient
    attr_accessor :responses

    def initialize
      @responses = []
      @call_count = 0
    end

    def chat(messages:, tools: [], &stream_callback)
      response = @responses[@call_count]
      @call_count += 1
      return [Crimson::Message::Assistant.new(content: "No more responses"), nil] if response.nil?
      [response[:message], response[:usage]]
    end
  end

  before do
    registry.register(IntEchoTool)
    config = double("config", provider: :openai, model: "gpt-4o", api_key: "test", base_url: nil, max_tokens: 4096)
    allow(Crimson).to receive(:config).and_return(config)
  end

  after { FileUtils.rm_rf(tmp_dir) }

  it "persists a multi-turn conversation with tool calls" do
    agent = Crimson::Agent.new(
      client: mock_client,
      tool_registry: registry,
      system_prompt: system_prompt
    )
    agent.start_session(cwd: cwd, session_manager: session_manager)

    tc = Crimson::Message::ToolCall.new(id: "tc-1", name: "echo", arguments: { "text" => "hello" })
    mock_client.responses = [
      { message: Crimson::Message::Assistant.new(content: nil, tool_calls: [tc]), usage: { prompt_tokens: 10, completion_tokens: 5, total_tokens: 15 } },
      { message: Crimson::Message::Assistant.new(content: "Echoed!"), usage: { prompt_tokens: 8, completion_tokens: 3, total_tokens: 11 } }
    ]

    agent.prompt("echo hello")

    session_id = agent.session_id

    new_agent = Crimson::Agent.new(
      client: mock_client,
      tool_registry: registry,
      system_prompt: system_prompt
    )
    new_agent.resume_session(session_id, cwd: cwd, session_manager: session_manager)

    expect(new_agent.history.length).to eq(4)
    expect(new_agent.history[0].content).to eq("echo hello")
    expect(new_agent.history[1]).to be_a(Crimson::Message::Assistant)
    expect(new_agent.history[2]).to be_a(Crimson::Message::ToolResult)
    expect(new_agent.history[2].content).to eq("echo: hello")
    expect(new_agent.history[3].content).to eq("Echoed!")
  end

  it "forks and continues independently" do
    agent = Crimson::Agent.new(
      client: mock_client,
      tool_registry: registry,
      system_prompt: system_prompt
    )
    agent.start_session(cwd: cwd, session_manager: session_manager)

    mock_client.responses = [
      { message: Crimson::Message::Assistant.new(content: "First"), usage: nil },
      { message: Crimson::Message::Assistant.new(content: "Second"), usage: nil }
    ]

    agent.prompt("turn one")
    agent.prompt("turn two")

    original_id = agent.session_id
    original_entries = session_manager.load(original_id, cwd: cwd)

    forked_id = session_manager.fork(original_id, cwd: cwd, from_entry_id: original_entries[1].id)

    forked_entries = session_manager.load(forked_id, cwd: cwd)
    expect(forked_entries.length).to eq(2)
    expect(forked_entries[0].content).to eq("turn one")
    expect(forked_entries[1].content).to eq("First")

    original_still_full = session_manager.load(original_id, cwd: cwd)
    expect(original_still_full.length).to eq(4)
  end
end
