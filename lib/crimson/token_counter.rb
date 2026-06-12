# frozen_string_literal: true

module Crimson
  class TokenCounter
    def initialize(model: nil, provider: nil)
      @model = model
      @provider = provider ? provider.to_sym : nil
      @encoder = nil
      @encoder_loaded = false
    end

    def count(text)
      return 0 if text.nil? || text.empty?
      encoder = load_encoder
      return estimate(text) unless encoder
      encoder.encode(text).length
    rescue => e
      estimate(text)
    end

    def count_messages(messages)
      total = 0
      messages.each do |msg|
        total += 4
        total += count(msg.content.to_s)
        if msg.respond_to?(:tool_calls) && msg.tool_calls
          msg.tool_calls.each do |tc|
            total += count(tc.name.to_s)
            total += count(tc.arguments.to_s)
          end
        end
      end
      total
    end

    private

    def load_encoder
      return @encoder if @encoder_loaded
      @encoder_loaded = true

      require "tiktoken_ruby"

      @encoder = if openai_sdk?
        load_openai_encoder
      else
        nil
      end
    rescue LoadError
      @encoder = nil
    rescue => e
      @encoder = nil
    end

    def openai_sdk?
      return true if @provider.nil? && @model&.match?(/gpt|o1|o3|davinci|curie|babbage|ada/)
      return false unless @provider
      PROVIDERS.dig(@provider, :sdk) == :openai
    end

    def load_openai_encoder
      enc = @model ? ::Tiktoken.encoding_for_model(@model) : nil
      enc || ::Tiktoken.get_encoding("cl100k_base")
    end

    def estimate(text)
      (text.length / 4.0).ceil
    end
  end
end
