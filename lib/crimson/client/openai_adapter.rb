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
        opts[:base_url] = base_url if base_url

        OpenAI::Client.new(**opts)
      end

      def stream_chat(params, &callback)
        collected_content = String.new
        collected_tool_calls = {}

        stream = @client.chat.completions.stream(
          messages: params[:messages],
          model: params[:model],
          tools: params[:tools] || []
        )

        stream.each do |event|
          chunk = event.chunk
          next unless chunk

          choice = chunk.choices&.first
          next unless choice

          delta = choice.delta
          next unless delta

          if delta.content
            text = delta.content
            collected_content << text
            callback.call(text, nil)
          end

          if delta.tool_calls
            delta.tool_calls.each do |tc|
              id = tc.id
              idx = tc.index

              if id
                collected_tool_calls[idx] ||= {
                  id: id,
                  name: tc.function&.name || "",
                  arguments: String.new
                }
              end

              if tc.function&.arguments
                collected_tool_calls[idx][:arguments] << tc.function.arguments
                collected_tool_calls[idx][:name] = tc.function.name if tc.function.name
              end
            end
          end
        end

        collected_tool_calls.each do |_idx, tc|
          callback.call(nil, tc)
        end

        usage = stream.get_final_completion&.usage
        usage_h = usage ? {
          prompt_tokens: usage.prompt_tokens || 0,
          completion_tokens: usage.completion_tokens || 0,
          total_tokens: usage.total_tokens || 0
        } : nil

        [build_assistant_message(collected_content, collected_tool_calls.values), usage_h]
      rescue => e
        [Message::Assistant.new(content: "Error communicating with #{provider_name}: #{e.message}"), nil]
      end

      def non_stream_chat(params)
        response = @client.chat.completions.create(
          messages: params[:messages],
          model: params[:model],
          tools: params[:tools] || []
        )

        choice = response.choices&.first
        return [Message::Assistant.new(content: ""), nil] unless choice

        msg = choice.message
        tool_calls = parse_tool_calls(msg.tool_calls) if msg.tool_calls

        usage = response.usage
        usage_h = usage ? {
          prompt_tokens: usage.prompt_tokens || 0,
          completion_tokens: usage.completion_tokens || 0,
          total_tokens: usage.total_tokens || 0
        } : nil

        [Message::Assistant.new(content: msg.content, tool_calls: tool_calls || []), usage_h]
      rescue => e
        [Message::Assistant.new(content: "Error communicating with #{provider_name}: #{e.message}"), nil]
      end

      def parse_tool_calls(raw_tool_calls)
        raw_tool_calls.map do |tc|
          args = begin
            JSON.parse(tc.function.arguments, symbolize_names: false)
          rescue JSON::ParserError
            {}
          end

          Message::ToolCall.new(id: tc.id, name: tc.function.name, arguments: args)
        end
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
