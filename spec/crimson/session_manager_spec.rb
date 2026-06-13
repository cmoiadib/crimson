require "spec_helper"
require "tmpdir"

RSpec.describe Crimson::SessionManager do
  let(:tmp_dir) { Dir.mktmpdir("crimson_test") }
  let(:cwd) { "/fake/project/path" }
  let(:manager) { described_class.new(sessions_dir: tmp_dir) }

  after { FileUtils.rm_rf(tmp_dir) }

  describe "#create" do
    it "creates a new session and returns its ID" do
      id = manager.create(cwd: cwd)

      expect(id).to match(/\A[0-9a-f-]{36}\z/)
      expect(File.exist?(manager.session_file(id, cwd: cwd))).to be true
    end
  end

  describe "#append and #load" do
    it "appends entries and loads them back in order" do
      id = manager.create(cwd: cwd)

      entry1 = Crimson::SessionEntry.from_message(
        Crimson::Message::User.new("hello"), parent_id: nil
      )
      manager.append(id, cwd: cwd, entry: entry1)

      entry2 = Crimson::SessionEntry.from_message(
        Crimson::Message::Assistant.new(content: "Hi!"), parent_id: entry1.id
      )
      manager.append(id, cwd: cwd, entry: entry2)

      loaded = manager.load(id, cwd: cwd)
      expect(loaded.length).to eq(2)
      expect(loaded[0].content).to eq("hello")
      expect(loaded[0].role).to eq("user")
      expect(loaded[1].content).to eq("Hi!")
      expect(loaded[1].parent_id).to eq(entry1.id)
    end

    it "handles tool results" do
      id = manager.create(cwd: cwd)

      user_entry = Crimson::SessionEntry.from_message(
        Crimson::Message::User.new("read foo"), parent_id: nil
      )
      manager.append(id, cwd: cwd, entry: user_entry)

      tc = Crimson::Message::ToolCall.new(id: "tc-1", name: "read_file", arguments: { "path" => "foo" })
      asst_entry = Crimson::SessionEntry.from_message(
        Crimson::Message::Assistant.new(content: nil, tool_calls: [tc]), parent_id: user_entry.id
      )
      manager.append(id, cwd: cwd, entry: asst_entry)

      tool_entry = Crimson::SessionEntry.from_message(
        Crimson::Message::ToolResult.new(tool_call_id: "tc-1", name: "read_file", content: "file data"),
        parent_id: asst_entry.id
      )
      manager.append(id, cwd: cwd, entry: tool_entry)

      loaded = manager.load(id, cwd: cwd)
      expect(loaded.length).to eq(3)
      expect(loaded[2].role).to eq("tool_result")
      expect(loaded[2].tool_call_id).to eq("tc-1")
    end
  end

  describe "#list" do
    it "returns sessions sorted by last timestamp (newest first)" do
      id1 = manager.create(cwd: cwd)
      entry1 = Crimson::SessionEntry.from_message(
        Crimson::Message::User.new("first"), parent_id: nil
      )
      manager.append(id1, cwd: cwd, entry: entry1)

      id2 = manager.create(cwd: cwd)
      entry2 = Crimson::SessionEntry.from_message(
        Crimson::Message::User.new("second"), parent_id: nil
      )
      manager.append(id2, cwd: cwd, entry: entry2)

      sessions = manager.list(cwd: cwd)
      expect(sessions.length).to eq(2)
      expect(sessions[0].id).to eq(id2)
      expect(sessions[1].id).to eq(id1)
      expect(sessions[0].preview).to eq("second")
    end

    it "returns empty array when no sessions exist" do
      expect(manager.list(cwd: cwd)).to eq([])
    end
  end

  describe "#latest" do
    it "returns the most recent session" do
      id1 = manager.create(cwd: cwd)
      manager.append(id1, cwd: cwd, entry: Crimson::SessionEntry.from_message(
        Crimson::Message::User.new("old"), parent_id: nil
      ))

      id2 = manager.create(cwd: cwd)
      manager.append(id2, cwd: cwd, entry: Crimson::SessionEntry.from_message(
        Crimson::Message::User.new("new"), parent_id: nil
      ))

      latest = manager.latest(cwd: cwd)
      expect(latest.id).to eq(id2)
    end

    it "returns nil when no sessions exist" do
      expect(manager.latest(cwd: cwd)).to be_nil
    end
  end

  describe "#fork" do
    it "creates a new session with entries up to the fork point" do
      id = manager.create(cwd: cwd)

      e1 = Crimson::SessionEntry.from_message(Crimson::Message::User.new("q1"), parent_id: nil)
      manager.append(id, cwd: cwd, entry: e1)

      e2 = Crimson::SessionEntry.from_message(Crimson::Message::Assistant.new(content: "a1"), parent_id: e1.id)
      manager.append(id, cwd: cwd, entry: e2)

      e3 = Crimson::SessionEntry.from_message(Crimson::Message::User.new("q2"), parent_id: e2.id)
      manager.append(id, cwd: cwd, entry: e3)

      new_id = manager.fork(id, cwd: cwd, from_entry_id: e2.id)
      forked = manager.load(new_id, cwd: cwd)

      expect(forked.length).to eq(2)
      expect(forked[0].content).to eq("q1")
      expect(forked[1].content).to eq("a1")
    end

    it "raises when entry not found" do
      id = manager.create(cwd: cwd)
      expect { manager.fork(id, cwd: cwd, from_entry_id: "nonexistent") }.to raise_error(RuntimeError)
    end
  end

  describe "#delete" do
    it "removes the session file" do
      id = manager.create(cwd: cwd)
      expect(File.exist?(manager.session_file(id, cwd: cwd))).to be true

      manager.delete(id, cwd: cwd)
      expect(File.exist?(manager.session_file(id, cwd: cwd))).to be false
    end
  end

  describe "#dir_hash" do
    it "returns a consistent hash for the same path" do
      h1 = manager.dir_hash(cwd: "/same/path")
      h2 = manager.dir_hash(cwd: "/same/path")
      expect(h1).to eq(h2)
    end

    it "returns different hashes for different paths" do
      h1 = manager.dir_hash(cwd: "/path/one")
      h2 = manager.dir_hash(cwd: "/path/two")
      expect(h1).not_to eq(h2)
    end
  end

  describe "crash safety" do
    it "handles corrupt JSONL lines gracefully" do
      id = manager.create(cwd: cwd)
      file = manager.session_file(id, cwd: cwd)

      e1 = Crimson::SessionEntry.from_message(Crimson::Message::User.new("good"), parent_id: nil)
      File.open(file, "a") { |f| f.puts(e1.to_json) }
      File.open(file, "a") { |f| f.puts("NOT VALID JSON{{{") }
      File.open(file, "a") { |f| f.puts(e1.to_json) }

      loaded = manager.load(id, cwd: cwd)
      expect(loaded.length).to eq(2)
    end
  end
end
