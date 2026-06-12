# frozen_string_literal: true

require "tempfile"

module Crimson
  module Tools
    module Truncator
      DEFAULT_MAX_BYTES = 100_000
      DEFAULT_MAX_LINES = 2000
      DEFAULT_MAX_LINE_LENGTH = 2000

      Result = Struct.new(:text, :was_truncated, :full_output_path, :original_size, keyword_init: true)

      def self.truncate(text, max_bytes: DEFAULT_MAX_BYTES, max_lines: DEFAULT_MAX_LINES, max_line_length: DEFAULT_MAX_LINE_LENGTH)
        return Result.new(text: text, was_truncated: false, full_output_path: nil, original_size: 0) if text.nil? || text.empty?

        original_size = text.bytesize
        truncated = false
        full_output_path = nil

        lines = text.lines
        if lines.any? { |l| l.chomp.length > max_line_length }
          lines = lines.map do |line|
            if line.chomp.length > max_line_length
              line.chomp[0...max_line_length] + "... (line truncated)\n"
            else
              line
            end
          end
          truncated = true
        end

        if lines.length > max_lines
          kept = lines.first(max_lines)
          remaining = lines.length - max_lines
          kept << "\n... (#{remaining} more lines, output truncated)\n"
          lines = kept
          truncated = true
        end

        result = lines.join

        if result.bytesize > max_bytes
          byte_limit = max_bytes - 100
          result = result.byteslice(0, byte_limit) + "\n... (output truncated by size)\n"
          truncated = true
        end

        if truncated && original_size > max_bytes
          full_output_path = save_full_output(text)
        end

        Result.new(
          text: result,
          was_truncated: truncated,
          full_output_path: full_output_path,
          original_size: original_size
        )
      end

      def self.save_full_output(text)
        file = Tempfile.new(["crimson-output-", ".log"])
        file.binmode
        file.write(text)
        file.close
        file.path
      rescue => e
        nil
      end
    end
  end
end
