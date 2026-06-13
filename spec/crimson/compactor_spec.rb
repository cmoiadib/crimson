require "spec_helper"

RSpec.describe Crimson::Compactor do
  let(:mock_client) do
    client = double("client")
    allow(client).to receive(:chat) do |messages:, tools:|
      [Crimson::Message::Assistant.new(content: "Summary of conversation"), nil]
    end
    client
  end

  subject(:compactor) { described_class.new(client: mock_client, max_context_tokens: 100, model: "gpt-4o", provider: :openai) }

  let(:history) do
    msgs = []
    msgs << Crimson::Message::User.new("question 1")
    msgs << Crimson::Message::Assistant.new(content: "answer 1")
    msgs << Crimson::Message::User.new("question 2")
    msgs << Crimson::Message::Assistant.new(content: "answer 2")
    msgs << Crimson::Message::User.new("question 3")
    msgs << Crimson::Message::Assistant.new(content: "answer 3")
    msgs << Crimson::Message::User.new("recent question")
    msgs << Crimson::Message::Assistant.new(content: "recent answer")
    msgs
  end

  describe "#needs_compaction?" do
    it "returns true when estimated tokens exceed 80% of max" do
      compactor = described_class.new(client: mock_client, max_context_tokens: 10)
      expect(compactor.needs_compaction?(history)).to be true
    end

    it "returns false when estimated tokens are well below max" do
      compactor = described_class.new(client: mock_client, max_context_tokens: 1_000_000)
      expect(compactor.needs_compaction?(history)).to be false
    end
  end

  describe "#compact" do
    it "returns history unchanged if too short" do
      short = history[0..1]
      result = compactor.compact(short, system_prompt: "test")
      expect(result).to eq(short)
    end

    it "keeps the 4 most recent messages" do
      result = compactor.compact(history, system_prompt: "test")
      recent = result[-4..]
      expect(recent.map(&:content)).to include("question 3", "answer 3", "recent question", "recent answer")
    end

    it "prepends a summary message" do
      result = compactor.compact(history, system_prompt: "test")
      expect(result.first).to be_a(Crimson::Message::User)
      expect(result.first.content).to include("summary")
    end

    it "prepends an acknowledgment from assistant" do
      result = compactor.compact(history, system_prompt: "test")
      expect(result[1]).to be_a(Crimson::Message::Assistant)
      expect(result[1].content).to include("Understood")
    end

    it "reduces total message count" do
      result = compactor.compact(history, system_prompt: "test")
      expect(result.length).to be < history.length
    end

    it "extracts file operations from history" do
      tc = Crimson::Message::ToolCall.new(id: "tc-1", name: "read_file", arguments: { "path" => "foo.rb" })
      rich_history = [
        Crimson::Message::User.new("read foo.rb"),
        Crimson::Message::Assistant.new(content: nil, tool_calls: [tc]),
        Crimson::Message::ToolResult.new(tool_call_id: "tc-1", name: "read_file", content: "file content"),
        Crimson::Message::User.new("recent"),
        Crimson::Message::Assistant.new(content: "reply"),
        Crimson::Message::User.new("q2"),
        Crimson::Message::Assistant.new(content: "a2"),
      ]

      compactor.compact(rich_history, system_prompt: "test")
      expect(mock_client).to have_received(:chat) do |args|
        msgs = args[:messages]
        user_msg = msgs.find { |m| m.is_a?(Crimson::Message::User) }
        expect(user_msg.content).to include("foo.rb")
      end
    end
  end
end
