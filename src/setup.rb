require 'tty-prompt'
require 'tty-spinner'
require 'net/http'
require 'uri'
require 'json'
require_relative 'providers'

module Crimson
  class Setup
    def self.run
      prompt = TTY::Prompt.new
      puts "Welcome to Crimson Setup!"

      provider = select_provider(prompt)
      api_key = ask_for_api_key(prompt, provider)
      base_url = ask_for_base_url(prompt) if provider == :custom
      models = fetch_models(provider, api_key, base_url)

      if models.empty?
        puts "No models found for the provided API key."
        return
      end

      model = select_model(prompt, models)
      save_config(provider, api_key, base_url, model)

      puts "Configuration saved successfully!"
    end

    private

    def self.select_provider(prompt)
      prompt.select("Select a provider:",
        PROVIDERS.map { |key, data| { name: data[:name], value: key } }
      )
    end

    def self.ask_for_api_key(prompt, provider)
      prompt.mask("Enter your #{PROVIDERS[provider][:name]} API key:")
    end

    def self.ask_for_base_url(prompt)
      prompt.ask("Enter the base URL for the provider:")
    end

    def self.select_model(prompt, models)
      prompt.select("Select a model:", models)
    end

    def self.fetch_models(provider, api_key, base_url = nil)
      spinner = TTY::Spinner.new("[:spinner] Fetching models...", format: :dots)
      spinner.auto_spin

      url_str = base_url || PROVIDERS[provider][:base_url]
      url_str += MODELS_ENDPOINT
      uri = URI(url_str)

      headers = PROVIDERS[provider][:auth_headers].call(api_key)

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = uri.scheme == "https"
      http.open_timeout = 10
      http.read_timeout = 30

      request = Net::HTTP::Get.new(uri.request_uri, headers)

      begin
        response = http.request(request)

        unless response.is_a?(Net::HTTPSuccess)
          spinner.error("Failed!")
          return []
        end

        data = JSON.parse(response.body)
        models = data["data"].map { |model| model["id"] }

        spinner.success("Done!")
        models
      rescue => e
        spinner.error("Error: #{e.message}")
        []
      end
    end

    def self.save_config(provider, api_key, base_url, model)
      content = <<~ENV
        CRIMSON_PROVIDER=#{provider}
        CRIMSON_MODEL=#{model}
        CRIMSON_API_KEY=#{api_key}
        #{"CRIMSON_BASE_URL=#{base_url}" if base_url}
      ENV

      File.write('.crimson', content.strip)
    end
  end
end
