require "spec_helper"
require "tmpdir"

RSpec.describe Crimson::Config do
  let(:tmp_dir) { Dir.mktmpdir("crimson_config_test") }
  let(:config_file) { File.join(tmp_dir, "config.json") }

  before do
    stub_const("Crimson::CONFIG_FILE", config_file)
    stub_const("Crimson::CONFIG_DIR", tmp_dir)
  end

  after { FileUtils.rm_rf(tmp_dir) }

  describe "#initialize" do
    it "sets default max_tokens" do
      config = described_class.new
      expect(config.max_tokens).to eq(8192)
    end

    it "accepts custom max_tokens" do
      config = described_class.new(max_tokens: 4096)
      expect(config.max_tokens).to eq(4096)
    end

    it "accepts provider and model" do
      config = described_class.new(provider: "openai", model: "gpt-4o", api_key: "key")
      expect(config.provider).to eq("openai")
      expect(config.model).to eq("gpt-4o")
      expect(config.api_key).to eq("key")
    end

    it "validates thinking_level" do
      config = described_class.new(thinking_level: "high")
      expect(config.thinking_level).to eq("high")
    end

    it "rejects invalid thinking_level" do
      config = described_class.new(thinking_level: "ultra")
      expect(config.thinking_level).to be_nil
    end

    it "accepts nil thinking_level" do
      config = described_class.new(thinking_level: nil)
      expect(config.thinking_level).to be_nil
    end
  end

  describe "#valid?" do
    it "returns false without provider" do
      config = described_class.new(model: "gpt-4o", api_key: "key")
      expect(config).not_to be_valid
    end

    it "returns false without model" do
      config = described_class.new(provider: "openai", api_key: "key")
      expect(config).not_to be_valid
    end

    it "returns false without api_key" do
      config = described_class.new(provider: "openai", model: "gpt-4o")
      expect(config).not_to be_valid
    end

    it "returns false for custom provider without base_url" do
      config = described_class.new(provider: "custom", model: "m", api_key: "k")
      expect(config).not_to be_valid
    end

    it "returns true for valid config" do
      config = described_class.new(provider: "openai", model: "gpt-4o", api_key: "key")
      expect(config).to be_valid
    end

    it "returns true for custom provider with base_url" do
      config = described_class.new(provider: "custom", model: "m", api_key: "k", base_url: "http://localhost")
      expect(config).to be_valid
    end
  end

  describe "#save and .load" do
    it "saves config to file" do
      config = described_class.new(provider: "openai", model: "gpt-4o", api_key: "secret")
      config.save

      expect(File.exist?(config_file)).to be true
      data = JSON.parse(File.read(config_file))
      expect(data["provider"]).to eq("openai")
      expect(data["api_key"]).to eq("secret")
    end

    it "loads config from file" do
      config = described_class.new(provider: "anthropic", model: "claude-3", api_key: "key123")
      config.save

      loaded = described_class.load
      expect(loaded.provider).to eq("anthropic")
      expect(loaded.model).to eq("claude-3")
      expect(loaded.api_key).to eq("key123")
    end

    it "returns default config when file missing" do
      loaded = described_class.load
      expect(loaded.provider).to be_nil
    end

    it "raises on corrupt JSON" do
      File.write(config_file, "NOT JSON{{{")
      expect { described_class.load }.to raise_error(Crimson::Error)
    end
  end

  describe "#thinking_level=" do
    it "sets valid thinking level" do
      config = described_class.new
      config.thinking_level = "medium"
      expect(config.thinking_level).to eq("medium")
    end

    it "rejects invalid thinking level" do
      config = described_class.new
      config.thinking_level = "invalid"
      expect(config.thinking_level).to be_nil
    end
  end
end
