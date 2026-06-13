require "spec_helper"
require "tmpdir"
require "fileutils"

RSpec.describe Crimson::Tools::ReadFile do
  let(:tmp_dir) { Dir.mktmpdir("crimson_read_test") }
  after { FileUtils.rm_rf(tmp_dir) }

  describe ".call" do
    it "reads a file successfully" do
      path = File.join(tmp_dir, "test.txt")
      File.write(path, "hello world")
      result = described_class.call(path: path)
      expect(result).to eq("hello world")
    end

    it "returns error for missing file" do
      result = described_class.call(path: File.join(tmp_dir, "nonexistent.txt"))
      expect(result).to start_with("Error: File not found")
    end

    it "returns error for nil path" do
      result = described_class.call(path: nil)
      expect(result).to start_with("Error")
    end

    it "returns error for empty path" do
      result = described_class.call(path: "  ")
      expect(result).to start_with("Error")
    end

    it "returns error for directory" do
      result = described_class.call(path: tmp_dir)
      expect(result).to start_with("Error: Not a file")
    end

    it "supports offset parameter" do
      path = File.join(tmp_dir, "multiline.txt")
      File.write(path, "line1\nline2\nline3\n")
      result = described_class.call(path: path, offset: 2)
      expect(result).to include("lines 2")
      expect(result).to include("line2")
      expect(result).not_to include("line1")
    end

    it "supports limit parameter" do
      path = File.join(tmp_dir, "multiline.txt")
      File.write(path, "line1\nline2\nline3\nline4\nline5\n")
      result = described_class.call(path: path, offset: 1, limit: 2)
      expect(result).to include("lines 1-2")
      expect(result).to include("line1")
      expect(result).to include("line2")
      expect(result).not_to include("line3")
    end

    it "describes image files" do
      path = File.join(tmp_dir, "photo.png")
      File.write(path, "fake png data")
      result = described_class.call(path: path)
      expect(result).to include("Image file")
      expect(result).to include("not yet supported")
    end

    it "describes binary files" do
      path = File.join(tmp_dir, "archive.zip")
      File.write(path, "fake zip data")
      result = described_class.call(path: path)
      expect(result).to include("Binary file")
      expect(result).to include("Cannot display")
    end
  end
end

RSpec.describe Crimson::Tools::WriteFile do
  let(:tmp_dir) { Dir.mktmpdir("crimson_write_test") }
  after { FileUtils.rm_rf(tmp_dir) }

  describe ".call" do
    it "writes content to a new file" do
      path = File.join(tmp_dir, "new.txt")
      result = described_class.call(path: path, content: "hello")
      expect(result).to include("Successfully wrote")
      expect(File.read(path)).to eq("hello")
    end

    it "overwrites existing file" do
      path = File.join(tmp_dir, "existing.txt")
      File.write(path, "old content")
      described_class.call(path: path, content: "new content")
      expect(File.read(path)).to eq("new content")
    end

    it "creates parent directories" do
      path = File.join(tmp_dir, "sub", "dir", "file.txt")
      described_class.call(path: path, content: "nested")
      expect(File.read(path)).to eq("nested")
    end

    it "returns error for nil path" do
      result = described_class.call(path: nil, content: "x")
      expect(result).to start_with("Error")
    end
  end
end

RSpec.describe Crimson::Tools::EditFile do
  let(:tmp_dir) { Dir.mktmpdir("crimson_edit_test") }
  let(:file_path) { File.join(tmp_dir, "edit.txt") }
  after { FileUtils.rm_rf(tmp_dir) }

  describe ".call single edit" do
    it "replaces a unique string" do
      File.write(file_path, "hello world")
      result = described_class.call(path: file_path, old_string: "world", new_string: "Ruby")
      expect(result).to include("Successfully edited")
      expect(File.read(file_path)).to eq("hello Ruby")
    end

    it "returns error when old_string not found" do
      File.write(file_path, "hello world")
      result = described_class.call(path: file_path, old_string: "missing", new_string: "x")
      expect(result).to include("not found")
    end

    it "returns error when old_string is not unique" do
      File.write(file_path, "foo foo bar")
      result = described_class.call(path: file_path, old_string: "foo", new_string: "x")
      expect(result).to include("found 2 times")
    end

    it "replaces all occurrences with replace_all" do
      File.write(file_path, "foo foo bar")
      result = described_class.call(path: file_path, old_string: "foo", new_string: "x", replace_all: true)
      expect(result).to include("Successfully edited")
      expect(File.read(file_path)).to eq("x x bar")
    end

    it "returns error for missing file" do
      result = described_class.call(path: File.join(tmp_dir, "nope.txt"), old_string: "a", new_string: "b")
      expect(result).to include("File not found")
    end

    it "returns error when no old_string provided" do
      File.write(file_path, "content")
      result = described_class.call(path: file_path)
      expect(result).to include("Error")
    end
  end

  describe ".call multi-edit" do
    it "applies multiple edits in sequence" do
      File.write(file_path, "line one\nline two\nline three")
      edits = [
        { "old_string" => "one", "new_string" => "1" },
        { "old_string" => "three", "new_string" => "3" }
      ]
      result = described_class.call(path: file_path, edits: edits)
      expect(result).to include("Successfully edited")
      expect(File.read(file_path)).to eq("line 1\nline two\nline 3")
    end

    it "aborts if any edit fails" do
      File.write(file_path, "hello")
      edits = [
        { "old_string" => "hello", "new_string" => "hi" },
        { "old_string" => "missing", "new_string" => "x" }
      ]
      result = described_class.call(path: file_path, edits: edits)
      expect(result).to include("not found")
    end
  end
end

RSpec.describe Crimson::Tools::RunCommand do
  describe ".call" do
    it "executes a simple command" do
      result = described_class.call(command: "echo hello")
      expect(result).to include("hello")
    end

    it "captures stderr" do
      result = described_class.call(command: "echo error 1>&2")
      expect(result).to include("error")
    end

    it "returns exit code on failure" do
      result = described_class.call(command: "exit 42")
      expect(result).to include("exit code: 42")
    end

    it "returns no output for empty output" do
      result = described_class.call(command: "true")
      expect(result).to include("(no output)")
    end

    it "returns error for nil command" do
      result = described_class.call(command: nil)
      expect(result).to start_with("Error")
    end

    it "returns error for empty command" do
      result = described_class.call(command: "")
      expect(result).to start_with("Error")
    end
  end

  describe ".strip_ansi_codes" do
    it "removes ANSI escape sequences" do
      result = described_class.strip_ansi_codes("\e[31mred text\e[0m")
      expect(result).to eq("red text")
    end

    it "leaves plain text unchanged" do
      expect(described_class.strip_ansi_codes("hello")).to eq("hello")
    end
  end
end

RSpec.describe Crimson::Tools::SearchFiles do
  describe ".call" do
    it "finds matching content" do
      result = described_class.call(pattern: "TOOL_NAME", path: File.expand_path("../../../lib", __dir__))
      expect(result).to include("read_file")
    end

    it "returns no matches for missing pattern" do
      result = described_class.call(pattern: "nonexistent_pattern_xyz_123", path: File.expand_path("../../../lib", __dir__))
      expect(result).to include("No matches")
    end

    it "returns error for nil pattern" do
      result = described_class.call(pattern: nil, path: ".")
      expect(result).to start_with("Error")
    end

    it "returns error for empty pattern" do
      result = described_class.call(pattern: "", path: ".")
      expect(result).to start_with("Error")
    end
  end
end

RSpec.describe Crimson::Tools::Glob do
  let(:tmp_dir) { Dir.mktmpdir("crimson_glob_test") }
  after { FileUtils.rm_rf(tmp_dir) }

  describe ".call" do
    it "finds files matching pattern" do
      File.write(File.join(tmp_dir, "a.rb"), "")
      File.write(File.join(tmp_dir, "b.rb"), "")
      File.write(File.join(tmp_dir, "c.txt"), "")
      result = described_class.call(pattern: "*.rb", path: tmp_dir)
      expect(result).to include("a.rb")
      expect(result).to include("b.rb")
      expect(result).not_to include("c.txt")
    end

    it "finds files in subdirectories with ** pattern" do
      FileUtils.mkdir_p(File.join(tmp_dir, "sub"))
      File.write(File.join(tmp_dir, "sub", "deep.rb"), "")
      result = described_class.call(pattern: "**/*.rb", path: tmp_dir)
      expect(result).to include("deep.rb")
    end

    it "returns message when no files found" do
      result = described_class.call(pattern: "*.xyz", path: tmp_dir)
      expect(result).to include("No files found")
    end

    it "returns error for nil pattern" do
      result = described_class.call(pattern: nil, path: tmp_dir)
      expect(result).to start_with("Error")
    end

    it "returns error for nonexistent directory" do
      result = described_class.call(pattern: "*.rb", path: File.join(tmp_dir, "nonexistent"))
      expect(result).to start_with("Error")
    end
  end
end

RSpec.describe Crimson::Tools::ListDirectory do
  let(:tmp_dir) { Dir.mktmpdir("crimson_list_test") }
  after { FileUtils.rm_rf(tmp_dir) }

  describe ".call" do
    it "lists files and directories" do
      File.write(File.join(tmp_dir, "file.txt"), "")
      FileUtils.mkdir_p(File.join(tmp_dir, "subdir"))
      result = described_class.call(path: tmp_dir)
      expect(result).to include("file.txt")
      expect(result).to include("subdir/")
    end

    it "does not include . and .." do
      result = described_class.call(path: tmp_dir)
      expect(result).not_to match(/^\.$/)
      expect(result).not_to match(/^\.\.$/)
    end

    it "returns error for nonexistent directory" do
      result = described_class.call(path: File.join(tmp_dir, "nonexistent"))
      expect(result).to start_with("Error")
    end
  end
end

RSpec.describe Crimson::Tools::Truncator do
  describe ".truncate" do
    it "returns text unchanged when within limits" do
      result = described_class.truncate("hello")
      expect(result.was_truncated).to be false
      expect(result.text).to eq("hello")
    end

    it "returns empty for nil text" do
      result = described_class.truncate(nil)
      expect(result.was_truncated).to be false
      expect(result.text).to eq(nil)
    end

    it "truncates by byte size" do
      big_text = "x" * 200_000
      result = described_class.truncate(big_text, max_bytes: 1000)
      expect(result.was_truncated).to be true
      expect(result.text.bytesize).to be < 200_000
    end

    it "truncates by line count" do
      big_text = (1..3000).map { |i| "line #{i}" }.join("\n")
      result = described_class.truncate(big_text, max_lines: 100)
      expect(result.was_truncated).to be true
      expect(result.text).to include("truncated")
    end

    it "truncates long lines" do
      long_line = "x" * 3000
      result = described_class.truncate(long_line, max_line_length: 100)
      expect(result.was_truncated).to be true
      expect(result.text).to include("line truncated")
    end

    it "saves full output to temp file when truncated" do
      big_text = "x" * 200_000
      result = described_class.truncate(big_text, max_bytes: 1000)
      expect(result.full_output_path).not_to be_nil
      expect(File.exist?(result.full_output_path)).to be true
    end
  end
end

RSpec.describe Crimson::Tools::Schema do
  describe ".build" do
    it "builds OpenAI function definition" do
      result = described_class.build(
        name: "test_tool",
        description: "A test tool",
        parameters: { x: { type: "string" } },
        required: ["x"]
      )
      expect(result[:type]).to eq("function")
      expect(result[:function][:name]).to eq("test_tool")
      expect(result[:function][:parameters][:required]).to eq(["x"])
    end
  end

  describe ".build_anthropic" do
    it "builds Anthropic tool definition" do
      result = described_class.build_anthropic(
        name: "test_tool",
        description: "A test tool",
        parameters: { x: { type: "string" } },
        required: ["x"]
      )
      expect(result[:name]).to eq("test_tool")
      expect(result[:input_schema][:required]).to eq(["x"])
    end
  end
end

RSpec.describe Crimson::Tools::DiffUtil do
  describe ".format_diff" do
    it "shows additions" do
      result = described_class.format_diff("old line", "old line\nnew line", "test.txt")
      expect(result).to include("+ new line")
    end

    it "shows deletions" do
      result = described_class.format_diff("removed line\nkept", "kept", "test.txt")
      expect(result).to include("- removed line")
    end

    it "shows unchanged lines" do
      result = described_class.format_diff("same", "same", "test.txt")
      expect(result).to include("same")
    end

    it "includes file path in header" do
      result = described_class.format_diff("a", "b", "my_file.rb")
      expect(result).to include("my_file.rb")
    end
  end
end

RSpec.describe Crimson::Tools::FileMutationQueue do
  subject(:queue) { described_class.new }

  describe "#with_file" do
    it "executes the block" do
      executed = false
      queue.with_file("/some/file") { executed = true }
      expect(executed).to be true
    end

    it "serializes concurrent access to same file" do
      results = []
      threads = 5.times.map do |i|
        Thread.new do
          queue.with_file("/same/file") do
            results << i
            sleep 0.01
          end
        end
      end
      threads.each(&:join)
      expect(results.length).to eq(5)
    end

    it "allows concurrent access to different files" do
      results = []
      threads = 5.times.map do |i|
        Thread.new do
          queue.with_file("/different/file#{i}") do
            results << i
          end
        end
      end
      threads.each(&:join)
      expect(results.length).to eq(5)
    end
  end
end
