require 'json'
require 'anthropic'
require_relative 'base'

module Crimson
  module Client
    class AnthropicAdapter < Base
      def initialize(config)
        super
        @client = Anthropic::Client.new(api_key: config.api_key)
      end

      def chat(messages:, tools: [], &stream_callback)
        system_msg, chat_msgs = split_messages(messages)

        params = {
          model: @config.model,
          max_tokens: @config.max_tokens
        }
        params[:system] = system_msg if system_msg
        params[:messages] = chat_msgs
        params[:tools] = tools unless tools.empty?

        if block_given?
          stream_chat(params, &stream_callback)
        else
          non_stream_chat(params)
        end
      end

      private

      def split_messages(messages)
        system_parts = []
        chat_msgs = []

        messages.each do |msg|
          case msg
          when Message::System
            system_parts << msg.to_anthropic_h
          when Message::Assistant
            chat_msgs << msg.to_anthropic_h
          when Message::ToolResult
            anthropic_h = msg.to_anthropic_h
            last_msg = chat_msgs.last
            if last_msg && last_msg[:role] == "user" && last_msg[:content].is_a?(Array)
              last_msg[:content].concat(anthropic_h[:content])
            else
              chat_msgs << anthropic_h
            end
          else
            chat_msgs << msg.to_anthropic_h
          end
        end

        system_text = system_parts.map { |s| s[:text] }.join("\n\n")
        system_text = nil if system_text.empty?

        [system_text, chat_msgs]
      end

      def stream_chat(params)
        collected_content = ""
        collected_tool_calls = {}
        current_tool_use = nil

        stream = @client.messages.stream(
          model: params[:model],
          max_tokens: params[:max_tokens],
          system: params[:system],
          messages: params[:messages],
          tools: params[:tools]
        )

        stream.each do |event|
          case event.type
          when "content_block_delta"
            if event.delta.is_a?(Hash)
              if event.delta[:type] == "text_delta"
                text = event.delta[:text]
                collected_content << text
                yield text, nil if block_given?
              elsif event.delta[:type] == "input_json_delta"
                if current_tool_use
                  current_tool_use[:arguments] << event.delta[:partial_json].to_s
                end
              end
            end
          when "content_block_start"
            if event.content_block.is_a?(Hash)
              cb = event.content_block
              if cb[:type] == "tool_use"
                current_tool_use = {
                  id: cb[:id],
                  name: cb[:name],
                  arguments: ""
                }
              end
            end
          when "content_block_stop"
            if current_tool_use
              yield nil, current_tool_use if block_given?
              collected_tool_calls[current_tool_use[:id]] = current_tool_use
              current_tool_use = nil
            end
          end
        end

        build_assistant_message(collected_content, collected_tool_calls.values)
      rescue => e
        Message::Assistant.new(content: "Error communicating with Anthropic: #{e.message}")
      end

      def non_stream_chat(params)
        response = @client.messages.create(
          model: params[:model],
          max_tokens: params[:max_tokens],
          system: params[:system],
          messages: params[:messages],
          tools: params[:tools]
        )

        content = ""
        tool_calls = []

        response.content.each do |block|
          if block[:type] == "text"
            content << block[:text]
          elsif block[:type] == "tool_use"
            tool_calls << Message::ToolCall.new(
              id: block[:id],
              name: block[:name],
              arguments: block[:input] || {}
            )
          end
        end

        Message::Assistant.new(
          content: content.empty? ? nil : content,
          tool_calls: tool_calls
        )
      rescue => e
        Message::Assistant.new(content: "Error communicating with Anthropic: #{e.message}")
      end

      def build_assistant_message(content, tool_calls)
        tc = tool_calls.map do |raw|
          args = begin
            JSON.parse(raw[:arguments], symbolize_names: false)
          rescue JSON::ParserError
            raw[:arguments] || {}
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
