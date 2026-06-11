require "spec_helper"

RSpec.describe Crimson::SessionEntry do
  describe ".from_message" do
    it "converts a User message" do
      msg = Crimson::Message::User.new("hello")
      entry = described_class.from_message(msg, parent_id: "p1")

      expect(entry.role).to eq("user")
      expect(entry.content).to eq("hello")
      expect(entry.parent_id).to eq("p1")
      expect(entry.id).to match(/\A[0-9a-f-]{36}\z/)
      expect(entry.timestamp).to be_a(String)
      expect(entry.tool_calls).to eq([])
      expect(entry.tool_call_id).to be_nil
      expect(entry.tool_name).to be_nil
      expect(entry.token_usage).to eq({})
    end

    it "converts an Assistant message with tool calls" do
      tc = Crimson::Message::ToolCall.new(id: "tc-1", name: "read_file", arguments: { "path" => "foo.rb" })
      msg = Crimson::Message::Assistant.new(content: "Reading file", tool_calls: [tc])
      entry = described_class.from_message(msg, parent_id: "p2")

      expect(entry.role).to eq("assistant")
      expect(entry.content).to eq("Reading file")
      expect(entry.tool_calls.length).to eq(1)
      expect(entry.tool_calls.first).to eq({ "id" => "tc-1", "name" => "read_file", "arguments" => { "path" => "foo.rb" } })
      expect(entry.token_usage).to eq({})
    end

    it "converts a ToolResult message" do
      msg = Crimson::Message::ToolResult.new(tool_call_id: "tc-1", name: "read_file", content: "file contents")
      entry = described_class.from_message(msg, parent_id: "p3")

      expect(entry.role).to eq("tool_result")
      expect(entry.content).to eq("file contents")
      expect(entry.tool_call_id).to eq("tc-1")
      expect(entry.tool_name).to eq("read_file")
    end
  end

  describe "#to_h and .from_h" do
    it "round-trips a user entry" do
      msg = Crimson::Message::User.new("test")
      entry = described_class.from_message(msg, parent_id: nil)
      hash = entry.to_h
      restored = described_class.from_h(hash)

      expect(restored.id).to eq(entry.id)
      expect(restored.parent_id).to be_nil
      expect(restored.role).to eq("user")
      expect(restored.content).to eq("test")
      expect(restored.timestamp).to eq(entry.timestamp)
    end

    it "round-trips an assistant entry with token usage" do
      msg = Crimson::Message::Assistant.new(content: "Hi")
      entry = described_class.from_message(msg, parent_id: "abc")
      entry.token_usage = { "prompt" => 10, "completion" => 5, "total" => 15 }
      hash = entry.to_h
      restored = described_class.from_h(hash)

      expect(restored.token_usage).to eq({ "prompt" => 10, "completion" => 5, "total" => 15 })
    end

    it "round-trips a tool_result entry" do
      msg = Crimson::Message::ToolResult.new(tool_call_id: "tc-1", name: "echo", content: "result")
      entry = described_class.from_message(msg, parent_id: "xyz")
      hash = entry.to_h
      restored = described_class.from_h(hash)

      expect(restored.tool_call_id).to eq("tc-1")
      expect(restored.tool_name).to eq("echo")
      expect(restored.role).to eq("tool_result")
    end
  end

  describe "#to_message" do
    it "converts back to Message::User" do
      entry = described_class.new(role: "user", content: "hello")
      msg = entry.to_message

      expect(msg).to be_a(Crimson::Message::User)
      expect(msg.content).to eq("hello")
    end

    it "converts back to Message::Assistant with tool calls" do
      entry = described_class.new(
        role: "assistant",
        content: "done",
        tool_calls: [{ "id" => "tc-1", "name" => "echo", "arguments" => { "text" => "hi" } }]
      )
      msg = entry.to_message

      expect(msg).to be_a(Crimson::Message::Assistant)
      expect(msg.content).to eq("done")
      expect(msg.tool_calls.length).to eq(1)
      expect(msg.tool_calls.first.name).to eq("echo")
      expect(msg.tool_calls.first.arguments).to eq({ "text" => "hi" })
    end

    it "converts back to Message::ToolResult" do
      entry = described_class.new(
        role: "tool_result",
        content: "result text",
        tool_call_id: "tc-1",
        tool_name: "echo"
      )
      msg = entry.to_message

      expect(msg).to be_a(Crimson::Message::ToolResult)
      expect(msg.content).to eq("result text")
      expect(msg.tool_call_id).to eq("tc-1")
      expect(msg.name).to eq("echo")
    end

    it "returns nil for system entries" do
      entry = described_class.new(role: "system", content: "prompt")
      expect(entry.to_message).to be_nil
    end
  end
end
