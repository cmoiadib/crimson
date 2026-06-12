# frozen_string_literal: true

module Crimson
  module Tools
    module Schema
      def self.build(name:, description:, parameters:, required:)
        {
          type: "function",
          function: {
            name: name,
            description: description,
            parameters: {
              type: "object",
              properties: parameters,
              required: required
            }
          }
        }
      end

      def self.build_anthropic(name:, description:, parameters:, required:)
        {
          name: name,
          description: description,
          input_schema: {
            type: "object",
            properties: parameters,
            required: required
          }
        }
      end

      def self.definitions_for(name:, description:, parameters:, required:)
        {
          openai: build(name: name, description: description, parameters: parameters, required: required),
          anthropic: build_anthropic(name: name, description: description, parameters: parameters, required: required)
        }
      end
    end
  end
end
