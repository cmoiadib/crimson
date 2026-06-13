require "spec_helper"

RSpec.describe Crimson::Message do
  describe Crimson::Message::System do
    subject { described_class.new("system prompt") }

    it "has system role" do
      expect(subject.role).to eq("system")
    end

    it "converts to OpenAI format" do
      expect(subject.to_openai_h).to eq({ role: "system", content: "system prompt" })
    end

    it "converts to Anthropic format" do
      expect(subject.to_anthropic_h).to eq({ type: "text", text: "system prompt" })
    end
  end

  describe Crimson::Message::User do
    subject { described_class.new("user input") }

    it "has user role" do
      expect(subject.role).to eq("user")
    end

    it "converts to OpenAI format" do
      expect(subject.to_openai_h).to eq({ role: "user", content: "user input" })
    end

    it "converts to Anthropic format" do
      expect(subject.to_anthropic_h).to eq({ role: "user", content: "user input" })
    end
  end

  describe Crimson::Message::Assistant do
    subject { described_class.new(content: "hello", tool_calls: []) }

    it "has assistant role" do
      expect(subject.role).to eq("assistant")
    end

    it "has no tool call when empty" do
      expect(subject.tool_call?).to be false
    end

    context "with tool calls" do
      let(:tc) { Crimson::Message::ToolCall.new(id: "tc-1", name: "echo", arguments: { "x" => 1 }) }
      subject { described_class.new(content: nil, tool_calls: [tc]) }

      it "has tool call" do
        expect(subject.tool_call?).to be true
      end

      it "converts to OpenAI format with tool_calls" do
        h = subject.to_openai_h
        expect(h[:role]).to eq("assistant")
        expect(h[:tool_calls]).to be_an(Array)
        expect(h[:tool_calls].first[:id]).to eq("tc-1")
      end

      it "converts to Anthropic format with tool_use blocks" do
        h = subject.to_anthropic_h
        expect(h[:role]).to eq("assistant")
        expect(h[:content]).to be_an(Array)
        expect(h[:content].first[:type]).to eq("tool_use")
      end
    end

    context "with content only" do
      subject { described_class.new(content: "hi there") }

      it "includes content in OpenAI format" do
        expect(subject.to_openai_h[:content]).to eq("hi there")
      end

      it "includes text block in Anthropic format" do
        h = subject.to_anthropic_h
        expect(h[:content].first[:type]).to eq("text")
        expect(h[:content].first[:text]).to eq("hi there")
      end
    end
  end

  describe Crimson::Message::ToolCall do
    subject { described_class.new(id: "tc-1", name: "echo", arguments: { "text" => "hi" }) }

    it "has id, name, arguments" do
      expect(subject.id).to eq("tc-1")
      expect(subject.name).to eq("echo")
      expect(subject.arguments).to eq({ "text" => "hi" })
    end

    it "converts to OpenAI format" do
      h = subject.to_openai_h
      expect(h[:id]).to eq("tc-1")
      expect(h[:type]).to eq("function")
      expect(h[:function][:name]).to eq("echo")
      expect(JSON.parse(h[:function][:arguments])).to eq({ "text" => "hi" })
    end
  end

  describe Crimson::Message::ToolResult do
    subject { described_class.new(tool_call_id: "tc-1", name: "echo", content: "result") }

    it "has tool role" do
      expect(subject.role).to eq("tool")
    end

    it "converts to OpenAI format" do
      h = subject.to_openai_h
      expect(h[:role]).to eq("tool")
      expect(h[:tool_call_id]).to eq("tc-1")
      expect(h[:content]).to eq("result")
    end

    it "converts to Anthropic format" do
      h = subject.to_anthropic_h
      expect(h[:role]).to eq("user")
      expect(h[:content]).to be_an(Array)
      expect(h[:content].first[:type]).to eq("tool_result")
      expect(h[:content].first[:tool_use_id]).to eq("tc-1")
    end
  end
end
