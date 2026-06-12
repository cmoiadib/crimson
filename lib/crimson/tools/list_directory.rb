# frozen_string_literal: true

module Crimson
  module Tools
    module ListDirectory
      TOOL_NAME = "list_directory"

      PARAMS = {
        path: { type: "string", description: "The directory path to list. Defaults to current directory." }
      }.freeze

      def self.definition
        Schema.build(name: TOOL_NAME, description: "List files and directories at the given path.", parameters: PARAMS, required: ["path"])
      end

      def self.anthropic_definition
        Schema.build_anthropic(name: TOOL_NAME, description: "List files and directories at the given path.", parameters: PARAMS, required: ["path"])
      end

      def self.call(path: ".")
        expanded = File.expand_path(path)
        return "Error: Directory not found: #{path}" unless Dir.exist?(expanded)

        entries = Dir.entries(expanded).sort - [".", ".."]

        entries.map do |entry|
          full_path = File.join(expanded, entry)
          File.directory?(full_path) ? "#{entry}/" : entry
        end.join("\n")
      rescue => e
        "Error listing directory: #{e.message}"
      end
    end
  end
end
