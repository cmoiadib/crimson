# frozen_string_literal: true

module Crimson
  module Tools
    module ReadFile
      TOOL_NAME = "read_file"

      IMAGE_EXTENSIONS = %w[.png .jpg .jpeg .gif .webp .bmp .ico .svg .tiff .tif].freeze
      BINARY_EXTENSIONS = %w[.zip .tar .gz .bz2 .xz .7z .rar .exe .dll .so .dylib .o .a .class .jar .wasm .pdf .doc .docx .xls .xlsx .ppt .pptx .woff .woff2 .ttf .eot .otf .mp3 .mp4 .avi .mov .mkv .flac .ogg .wav].freeze

      PARAMS = {
        path: { type: "string", description: "The path to the file to read" },
        offset: { type: "integer", description: "Line number to start reading from (1-indexed). Defaults to 1." },
        limit: { type: "integer", description: "Maximum number of lines to read. Defaults to all lines." }
      }.freeze

      def self.prepare_arguments(args)
        args["offset"] = args["offset"].to_i if args["offset"]
        args["limit"] = args["limit"].to_i if args["limit"]
        args
      end

      def self.definition
        Schema.build(name: TOOL_NAME, description: "Read the contents of a file. Supports offset/limit for reading portions of large files.", parameters: PARAMS, required: ["path"])
      end

      def self.anthropic_definition
        Schema.build_anthropic(name: TOOL_NAME, description: "Read the contents of a file. Supports offset/limit for reading portions of large files.", parameters: PARAMS, required: ["path"])
      end

      def self.call(path:, offset: nil, limit: nil)
        return "Error: No path provided" if path.nil? || path.strip.empty?

        expanded = File.expand_path(path)
        return "Error: File not found: #{path}" unless File.exist?(expanded)
        return "Error: Not a file: #{path}" unless File.file?(expanded)

        ext = File.extname(expanded).downcase
        return describe_image(expanded, ext) if IMAGE_EXTENSIONS.include?(ext)
        return describe_binary(expanded, ext) if BINARY_EXTENSIONS.include?(ext)

        content = File.read(expanded)
        lines = content.lines

        if offset || limit
          start_line = [(offset || 1) - 1, 0].max
          end_line = limit ? start_line + limit : lines.length
          end_line = [end_line, lines.length].min
          total = lines.length

          selected = lines[start_line...end_line]
          numbered = selected.each_with_index.map do |line, i|
            "#{start_line + i + 1}: #{line}"
          end

          "(lines #{start_line + 1}-#{end_line} of #{total})\n#{numbered.join}"
        else
          content
        end
      rescue => e
        "Error reading file: #{e.message}"
      end

      def self.describe_image(path, ext)
        size = File.size(path)
        size_str = size > 1_048_576 ? "#{(size / 1_048_576.0).round(1)}MB" : "#{(size / 1024.0).round(1)}KB"
        "Image file: #{File.basename(path)} (#{ext}, #{size_str}). Image reading not yet supported."
      end

      def self.describe_binary(path, ext)
        size = File.size(path)
        size_str = size > 1_048_576 ? "#{(size / 1_048_576.0).round(1)}MB" : "#{(size / 1024.0).round(1)}KB"
        "Binary file: #{File.basename(path)} (#{ext}, #{size_str}). Cannot display binary content."
      end
    end
  end
end
