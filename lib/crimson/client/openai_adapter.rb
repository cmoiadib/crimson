require 'json'
require 'openai'
require_relative 'base'

module Crimson
  module Client
    class OpenAIAdapter < Base
      def initialize(config)
        super
        @client = build_client
      end

      def chat(messages:, tools: [], &stream_callback)
        params = build_params(messages, tools)

        if block_given?
          stream_chat(params, &stream_callback)
        else
          non_stream_chat(params)
        end
      end

      private

      def build_client
        opts = { api_key: @config.api_key }

        base_url = @config.base_url || PROVIDERS[@config.provider.to_sym][:base_url]
        opts[:base_url] = base_url if base_url

        OpenAI::Client.new(**opts)
      end

      def build_params(messages, tools)
        params = {
          input: messages_to_input(messages),
          model: @config.model
        }
        params[:tools] = tools unless tools.empty?
        params
      end

      def messages_to_input(messages)
        messages.map { |msg| message_to_input_h(msg) }
      end

      def message_to_input_h(msg)
        case msg
        when Message::System
          { role: "system", content: msg.content }
        when Message::User
          { role: "user", content: msg.content }
        when Message::Assistant
          if msg.tool_call?
            msg.tool_calls.map do |tc|
              {
                type: "function_call",
                id: tc.id,
                name: tc.name,
                arguments: JSON.generate(tc.arguments)
              }
            end
          else
            { role: "assistant", content: msg.content || "" }
          end
        when Message::ToolResult
          {
            type: "function_call_output",
            call_id: msg.tool_call_id,
            output: msg.content
          }
        end
      end

      def stream_chat(params, &callback)
        collected_content = String.new
        collected_tool_calls = {}

        stream = @client.responses.stream(
          input: params[:input],
          model: params[:model],
          tools: params[:tools] || []
        )

        stream.each do |event|
          case event.type
          when "response.output_text.delta"
            text = event.delta
            collected_content << text
            callback.call(text, nil)
          when "response.function_call_arguments.delta"
            id = event.item_id
            collected_tool_calls[id] ||= { id: id, name: "", arguments: String.new }
            collected_tool_calls[id][:arguments] << event.delta
          when "response.function_call.name.done"
            id = event.item_id
            collected_tool_calls[id] ||= { id: id, name: "", arguments: String.new }
            collected_tool_calls[id][:name] = event.name
          end
        end

        collected_tool_calls.each do |_id, tc|
          callback.call(nil, tc)
        end

        [build_assistant_message(collected_content, collected_tool_calls.values), nil]
      rescue => e
        [Message::Assistant.new(content: "Error communicating with #{provider_name}: #{e.message}"), nil]
      end

      def non_stream_chat(params)
        response = @client.responses.create(
          input: params[:input],
          model: params[:model],
          tools: params[:tools] || []
        )

        content = String.new
        tool_calls = []

        Array(response.output).each do |block|
          case block.type
          when "message"
            Array(block.content).each do |c|
              content << c.text if c.respond_to?(:text)
            end
          when "function_call"
            args = begin
              JSON.parse(block.arguments, symbolize_names: false)
            rescue JSON::ParserError
              {}
            end
            tool_calls << Message::ToolCall.new(
              id: block.id || block.call_id,
              name: block.name,
              arguments: args
            )
          end
        end

        usage = response.usage
        usage_h = usage ? {
          prompt_tokens: usage.input_tokens || 0,
          completion_tokens: usage.output_tokens || 0,
          total_tokens: (usage.input_tokens || 0) + (usage.output_tokens || 0)
        } : nil

        [Message::Assistant.new(content: content.empty? ? nil : content.to_s, tool_calls: tool_calls), usage_h]
      rescue => e
        [Message::Assistant.new(content: "Error communicating with #{provider_name}: #{e.message}"), nil]
      end

      def build_assistant_message(content, tool_calls)
        tc = tool_calls.map do |raw|
          args = begin
            JSON.parse(raw[:arguments], symbolize_names: false)
          rescue JSON::ParserError
            {}
          end
          Message::ToolCall.new(id: raw[:id], name: raw[:name], arguments: args)
        end

        Message::Assistant.new(
          content: content.empty? ? nil : content.to_s,
          tool_calls: tc
        )
      end

      def provider_name
        PROVIDERS[@config.provider.to_sym][:name]
      end
    end
  end
end
