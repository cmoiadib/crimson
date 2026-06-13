require "spec_helper"

RSpec.describe Crimson::Formatter do
  before { described_class.reset }

  describe ".format_line" do
    it "returns empty string for nil" do
      expect(described_class.format_line(nil)).to eq("")
    end

    it "returns empty string for empty line" do
      expect(described_class.format_line("")).to eq("")
    end

    it "passes through plain text" do
      expect(described_class.format_line("hello world")).to eq("hello world")
    end

    it "styles headers in bold yellow" do
      result = described_class.format_line("# Title")
      expect(result).to include("\e[")  # has ANSI codes
    end

    it "styles h2 headers" do
      result = described_class.format_line("## Section")
      expect(result).to include("\e[")
    end

    it "styles h3 headers" do
      result = described_class.format_line("### Subsection")
      expect(result).to include("\e[")
    end

    it "styles inline code" do
      result = described_class.format_line("use `code` here")
      expect(result).to include("\e[")
    end

    it "styles bold text" do
      result = described_class.format_line("this is **bold** text")
      expect(result).to include("\e[")
    end

    it "styles italic text" do
      result = described_class.format_line("this is *italic* text")
      expect(result).to include("\e[")
    end

    it "styles unordered list bullets" do
      result = described_class.format_line("- item one")
      expect(result).to include("\e[")
    end

    it "styles ordered list numbers" do
      result = described_class.format_line("1. first item")
      expect(result).to include("\e[")
    end

    it "styles blockquotes" do
      result = described_class.format_line("> quoted text")
      expect(result).to include("\e[")
    end

    it "styles horizontal rules" do
      result = described_class.format_line("---")
      expect(result).to include("\e[")
    end

    it "styles links" do
      result = described_class.format_line("[text](http://example.com)")
      expect(result).to include("\e[")
    end
  end

  describe "code blocks" do
    it "enters code block on ```" do
      described_class.format_line("```ruby")
      expect(described_class.in_code_block?).to be true
    end

    it "exits code block on closing ```" do
      described_class.format_line("```ruby")
      described_class.format_line("some code")
      described_class.format_line("```")
      expect(described_class.in_code_block?).to be false
    end

    it "returns content as-is inside code block" do
      described_class.format_line("```")
      result = described_class.format_line("puts :hello")
      expect(result).to eq("puts :hello")
    end

    it "resets state on .reset" do
      described_class.format_line("```")
      expect(described_class.in_code_block?).to be true
      described_class.reset
      expect(described_class.in_code_block?).to be false
    end
  end
end
