require 'json'

module Crimson
  class ToolRegistry
    def initialize
      @tools = {}
    end

    def register(tool_module)
      @tools[tool_module.name.split("::").last] = tool_module
    end

    def execute(tool_name, arguments)
      tool = @tools[tool_name]
      return "Error: Unknown tool '#{tool_name}'" unless tool

      begin
        args = if arguments.is_a?(String)
                 JSON.parse(arguments, symbolize_names: true)
               else
                 arguments.transform_keys(&:to_sym)
               end
        tool.call(**args)
      rescue JSON::ParserError
        "Error: Invalid JSON arguments for #{tool_name}"
      rescue => e
        "Error executing #{tool_name}: #{e.message}"
      end
    end

    def openai_definitions
      @tools.values.map(&:definition)
    end

    def anthropic_definitions
      @tools.values.map(&:anthropic_definition)
    end

    def tool_names
      @tools.keys
    end

    def load_skills(skills_dir)
      return "" unless Dir.exist?(skills_dir)

      skill_content = []
      Dir.glob(File.join(skills_dir, "*.md")).sort.each do |file|
        content = File.read(file).strip
        next if content.empty?
        skill_content << content
      end

      skill_content.join("\n\n")
    end
  end
end
