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
        params = {
          messages: messages.map(&:to_openai_h),
          model: @config.model
        }
        params[:tools] = tools unless tools.empty?

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
        if base_url
          opts[:base_url] = base_url.sub(/\/v1\/?$/, '')
        end

        OpenAI::Client.new(**opts)
      end

      def stream_chat(params)
        collected_content = ""
        collected_tool_calls = {}
        current_tool_calls = {}

        stream = @client.responses.stream(
          input: params[:messages],
          model: params[:model],
          tools: params[:tools]
        )

        stream.each do |event|
          case event.type
          when "response.output_text.delta"
            text = event.delta
            collected_content << text
            yield text, nil if block_given?
          when "response.function_call_arguments.delta"
            args_delta = event.delta
            call_id = event.item_id
            current_tool_calls[call_id] ||= { id: call_id, name: "", arguments: "" }
            current_tool_calls[call_id][:arguments] << args_delta
          when "response.function_call_arguments.done"
            call_id = event.item_id
            if current_tool_calls[call_id]
              yield nil, current_tool_calls[call_id] if block_given?
              collected_tool_calls[call_id] = current_tool_calls[call_id]
            end
          end
        end

        build_assistant_message(collected_content, collected_tool_calls.values)
      rescue => e
        Message::Assistant.new(content: "Error communicating with OpenAI: #{e.message}")
      end

      def non_stream_chat(params)
        response = @client.chat.completions.create(
          messages: params[:messages],
          model: params[:model],
          tools: params[:tools]
        )

        choice = response.choices.first
        return Message::Assistant.new(content: "") unless choice

        msg = choice.message
        tool_calls = parse_tool_calls(msg.tool_calls) if msg.tool_calls

        Message::Assistant.new(
          content: msg.content,
          tool_calls: tool_calls || []
        )
      rescue => e
        Message::Assistant.new(content: "Error communicating with OpenAI: #{e.message}")
      end

      def parse_tool_calls(raw_tool_calls)
        raw_tool_calls.map do |tc|
          args = begin
            JSON.parse(tc.function.arguments, symbolize_names: false)
          rescue JSON::ParserError
            {}
          end

          Message::ToolCall.new(
            id: tc.id,
            name: tc.function.name,
            arguments: args
          )
        end
      end

      def build_assistant_message(content, tool_calls)
        tc = tool_calls.map do |raw|
          args = begin
            JSON.parse(raw[:arguments], symbolize_names: false)
          rescue JSON::ParserError
            {}
          end

          Message::ToolCall.new(
            id: raw[:id],
            name: raw[:name],
            arguments: args
          )
        end

        Message::Assistant.new(
          content: content.empty? ? nil : content,
          tool_calls: tc
        )
      end
    end
  end
end
