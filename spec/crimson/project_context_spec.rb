require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Crimson::ProjectContext do
  let(:tmp_dir) { Dir.mktmpdir("crimson_project_test") }
  after { FileUtils.rm_rf(tmp_dir) }

  describe ".detect_language" do
    it "detects Ruby" do
      File.write(File.join(tmp_dir, "test.rb"), "puts 'hello'")
      expect(described_class.detect_language(tmp_dir)).to eq("Ruby")
    end

    it "detects Ruby from Gemfile" do
      File.write(File.join(tmp_dir, "Gemfile"), "source 'https://rubygems.org'")
      expect(described_class.detect_language(tmp_dir)).to eq("Ruby")
    end

    it "detects Python" do
      File.write(File.join(tmp_dir, "app.py"), "print('hello')")
      expect(described_class.detect_language(tmp_dir)).to eq("Python")
    end

    it "detects JavaScript" do
      File.write(File.join(tmp_dir, "package.json"), "{}")
      expect(described_class.detect_language(tmp_dir)).to eq("JavaScript")
    end

    it "detects TypeScript" do
      File.write(File.join(tmp_dir, "tsconfig.json"), "{}")
      expect(described_class.detect_language(tmp_dir)).to eq("TypeScript")
    end

    it "returns nil for unknown language" do
      expect(described_class.detect_language(tmp_dir)).to be_nil
    end
  end

  describe ".detect_framework" do
    it "detects Rails" do
      FileUtils.mkdir_p(File.join(tmp_dir, "bin"))
      File.write(File.join(tmp_dir, "bin", "rails"), "#!/bin/bash")
      expect(described_class.detect_framework(tmp_dir)).to eq("Rails")
    end

    it "detects Sinatra" do
      File.write(File.join(tmp_dir, "Gemfile"), "gem 'sinatra'")
      expect(described_class.detect_framework(tmp_dir)).to eq("Sinatra")
    end

    it "detects React" do
      File.write(File.join(tmp_dir, "package.json"), '{"dependencies": {"react": "^18"}}')
      expect(described_class.detect_framework(tmp_dir)).to eq("React")
    end

    it "detects Django" do
      File.write(File.join(tmp_dir, "manage.py"), "#!/usr/bin/env python")
      expect(described_class.detect_framework(tmp_dir)).to eq("Django")
    end

    it "returns nil when no framework detected" do
      expect(described_class.detect_framework(tmp_dir)).to be_nil
    end
  end

  describe ".detect_package_manager" do
    it "detects bundler" do
      File.write(File.join(tmp_dir, "Gemfile"), "")
      expect(described_class.detect_package_manager(tmp_dir)).to eq("bundler")
    end

    it "detects npm" do
      File.write(File.join(tmp_dir, "package-lock.json"), "{}")
      expect(described_class.detect_package_manager(tmp_dir)).to eq("npm")
    end

    it "detects cargo" do
      File.write(File.join(tmp_dir, "Cargo.toml"), "[package]")
      expect(described_class.detect_package_manager(tmp_dir)).to eq("cargo")
    end

    it "returns nil when none found" do
      expect(described_class.detect_package_manager(tmp_dir)).to be_nil
    end
  end

  describe ".detect_testing" do
    it "detects RSpec" do
      File.write(File.join(tmp_dir, "Gemfile"), "gem 'rspec'")
      expect(described_class.detect_testing(tmp_dir)).to eq("RSpec")
    end

    it "detects Minitest" do
      FileUtils.mkdir_p(File.join(tmp_dir, "test"))
      File.write(File.join(tmp_dir, "test", "foo_test.rb"), "require 'minitest'")
      expect(described_class.detect_testing(tmp_dir)).to eq("Minitest")
    end

    it "detects Jest" do
      File.write(File.join(tmp_dir, "package.json"), '{"devDependencies": {"jest": "^29"}}')
      expect(described_class.detect_testing(tmp_dir)).to eq("Jest")
    end

    it "returns nil when none found" do
      expect(described_class.detect_testing(tmp_dir)).to be_nil
    end
  end

  describe ".format_context_files" do
    it "returns empty string for nil" do
      expect(described_class.format_context_files(nil)).to eq("")
    end

    it "returns empty string for empty array" do
      expect(described_class.format_context_files([])).to eq("")
    end

    it "wraps content in project_context tags" do
      files = [{ path: "/test/AGENTS.md", content: "some rules" }]
      result = described_class.format_context_files(files)
      expect(result).to include("<project_context>")
      expect(result).to include("</project_context>")
      expect(result).to include("some rules")
    end
  end
end
