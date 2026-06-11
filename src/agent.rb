require 'pastel'

module Crimson
  class Agent
    MAX_ITERATIONS = 50

    attr_reader :tool_registry

    def initialize(client:, tool_registry:, system_prompt:)
      @client = client
      @tool_registry = tool_registry
      @system_prompt = system_prompt
      @history = []
      @pastel = Pastel.new
    end

    def run(user_input)
      @history << Message::User.new(user_input)

      iterations = 0

      loop do
        iterations += 1
        if iterations > MAX_ITERATIONS
          puts @pastel.yellow("\nMax iterations (#{MAX_ITERATIONS}) reached. Stopping.")
          break
        end

        messages = build_messages
        tools = provider_tool_definitions

        response = @client.chat(messages: messages, tools: tools) do |text_chunk, tool_event|
          if text_chunk
            print text_chunk
            $stdout.flush
          elsif tool_event
            print_tool_call(tool_event)
          end
        end

        @history << response

        if response.tool_call?
          puts if response.content && !response.content.empty?
          execute_tool_calls(response)
        else
          puts "\n"
          break
        end
      end
    end

    def reset
      @history.clear
    end

    private

    def build_messages
      msgs = []
      msgs << Message::System.new(@system_prompt) unless @system_prompt.empty?
      msgs.concat(@history)
      msgs
    end

    def provider_tool_definitions
      sdk = PROVIDERS[Crimson.config.provider.to_sym][:sdk]

      case sdk
      when :openai
        @tool_registry.openai_definitions
      when :anthropic
        @tool_registry.anthropic_definitions
      else
        []
      end
    end

    def execute_tool_calls(response)
      response.tool_calls.each do |tc|
        result = @tool_registry.execute(tc.name, tc.arguments)
        puts @pastel.dim("  -> #{truncate(result, 200)}")
        @history << Message::ToolResult.new(
          tool_call_id: tc.id,
          name: tc.name,
          content: result
        )
      end
    end

    def print_tool_call(tool_event)
      name = tool_event[:name]
      args = tool_event[:arguments]

      display = begin
        parsed = args.is_a?(String) ? JSON.parse(args) : args
        parsed.map { |k, v| "#{k}: #{truncate(v.to_s, 50)}" }.join(", ")
      rescue
        truncate(args.to_s, 80)
      end

      puts @pastel.cyan("  #{name}(#{display})")
    end

    def truncate(text, max_len)
      return "" if text.nil?
      cleaned = text.gsub("\n", "\\n")
      cleaned.length > max_len ? "#{cleaned[0...max_len]}..." : cleaned
    end
  end
end
