require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Crimson::TrustManager do
  let(:tmp_dir) { Dir.mktmpdir("crimson_trust_test") }
  let(:trust_file) { File.join(tmp_dir, "trust.json") }
  subject(:manager) { described_class.new(trust_file: trust_file) }

  after { FileUtils.rm_rf(tmp_dir) }

  describe "#trusted?" do
    it "returns false for untrusted directory" do
      expect(manager.trusted?("/some/path")).to be false
    end

    it "returns true for trusted directory" do
      dir = File.join(tmp_dir, "myproject")
      FileUtils.mkdir_p(dir)
      trust_data = { dir => true }
      File.write(trust_file, JSON.pretty_generate(trust_data))
      manager2 = described_class.new(trust_file: trust_file)
      expect(manager2.trusted?(dir)).to be true
    end

    it "inherits trust from parent directory" do
      parent = File.join(tmp_dir, "parent")
      child = File.join(parent, "child")
      FileUtils.mkdir_p(child)
      trust_data = { parent => true }
      File.write(trust_file, JSON.pretty_generate(trust_data))
      manager2 = described_class.new(trust_file: trust_file)
      expect(manager2.trusted?(child)).to be true
    end

    it "respects explicit deny over parent trust" do
      parent = File.join(tmp_dir, "parent")
      child = File.join(parent, "child")
      FileUtils.mkdir_p(child)
      trust_data = { parent => true, child => false }
      File.write(trust_file, JSON.pretty_generate(trust_data))
      manager2 = described_class.new(trust_file: trust_file)
      expect(manager2.trusted?(child)).to be false
    end
  end

  describe "#has_context_files?" do
    it "returns true when AGENTS.md exists" do
      File.write(File.join(tmp_dir, "AGENTS.md"), "rules")
      expect(manager.has_context_files?(tmp_dir)).to be true
    end

    it "returns true when CLAUDE.md exists" do
      File.write(File.join(tmp_dir, "CLAUDE.md"), "rules")
      expect(manager.has_context_files?(tmp_dir)).to be true
    end

    it "returns false when no context files exist" do
      expect(manager.has_context_files?(tmp_dir)).to be false
    end
  end

  describe "corrupt trust file" do
    it "loads empty trust data on corrupt JSON" do
      File.write(trust_file, "NOT JSON{{{")
      manager2 = described_class.new(trust_file: trust_file)
      expect(manager2.trusted?(tmp_dir)).to be false
    end
  end
end
