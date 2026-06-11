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

        stream_callback = proc do |chunk|
          delta = chunk.dig("choices", 0, "delta")
          next unless delta

          if delta["content"]
            text = delta["content"]
            collected_content << text
            callback.call(text, nil)
          end

          if delta["tool_calls"]
            delta["tool_calls"].each do |tc|
              id = tc.dig("id")
              idx = tc["index"]

              if id
                collected_tool_calls[idx] ||= {
                  id: id,
                  name: tc.dig("function", "name") || "",
                  arguments: String.new
                }
              end

              if tc.dig("function", "arguments")
                collected_tool_calls[idx][:arguments] << tc["function"]["arguments"]
                collected_tool_calls[idx][:name] = tc.dig("function", "name") if tc.dig("function", "name")
              end
            end
          end
        end

        @client.chat.completions.create(
          messages: params[:messages],
          model: params[:model],
          tools: params[:tools],
          stream: stream_callback
        )

        collected_tool_calls.each do |_idx, tc|
          callback.call(nil, tc)
        end

        build_assistant_message(collected_content, collected_tool_calls.values)
      rescue => e
        Message::Assistant.new(content: "Error communicating with #{provider_name}: #{e.message}")
      end

      def non_stream_chat(params)
        response = @client.chat.completions.create(
          messages: params[:messages],
          model: params[:model],
          tools: params[:tools]
        )

        choice = response.choices&.first
        return Message::Assistant.new(content: "") unless choice

        msg = choice.message
        tool_calls = parse_tool_calls(msg.tool_calls) if msg.tool_calls

        Message::Assistant.new(
          content: msg.content,
          tool_calls: tool_calls || []
        )
      rescue => e
        Message::Assistant.new(content: "Error communicating with #{provider_name}: #{e.message}")
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
