module Crimson
  class Config
    attr_reader :provider, :model, :api_key, :base_url, :max_tokens

    def initialize(provider: nil, model: nil, api_key: nil, base_url: nil, max_tokens: 1000)
      @provider = provider || ENV['CRIMSON_PROVIDER']
      @model = model || ENV['CRIMSON_MODEL']
      @api_key = api_key || ENV['CRIMSON_API_KEY']
      @base_url = base_url || ENV['CRIMSON_BASE_URL']
      @max_tokens = max_tokens
    end

    def self.load
      if File.exist?('.crimson')
        require 'dotenv'
        Dotenv.load('.crimson')
      end
      new
    end

    def present?(value)
      !value.nil? && !value.empty?
    end

    def valid?
      return false unless present?(@provider) && present?(@model) && present?(@api_key)

      if @provider == 'custom'
        return false unless present?(@base_url)
      end

      true
    end
  end
end
