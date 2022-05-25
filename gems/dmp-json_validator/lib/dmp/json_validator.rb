# frozen_string_literal: true

require 'json'
require 'json-schema'

module Dmp
  # DMP JSON validation service using
  class JsonValidator
    # Valid Validation modes are:
    #   - :author --> system of provenance is attempting to create or update
    #   - :delete --> system of provenance is attempting to delete/tombstone
    #   - :amend  --> a non-provenance system is attempting to update
    VALIDATION_MODES = %w[author amend delete].freeze

    class << self
      def validate(mode:, json: {})
        json = prepare_json(json: json)
        return respond unless json.present? && VALIDATION_MODES.include?(mode)

        # Load the appropriate JSON schema for the mode
        schema = load_schema(mode: mode)
        return respond(message: 'Invalid mode or no JSON schema available!') unless schema.present?

        # Validate the JSON
        errors = JSON::Validator.fully_validate(schema, json)
        respond(valid: errors.empty?, message: errors)
      rescue JSON::Schema::ValidationError => e
        respond(message: "Fatal validation error: #{e.message}")
      end

      private

      # Respond in a standardized JSON format with a :valid boolean flag and
      # an array of :errors
      def respond(valid: false, errors: 'JSON was empty or an invalid mode was specified!')
        errors = [errors] unless errors.is_a?(Array)
        { valid: valid, message: errors }.to_json
      end

      # Load the JSON schema that corresponds with the mode
      def load_schema(mode:)
        filename = "#{Dir.pwd}/config/schemas/#{mode}.json"
        return nil unless mode.present? && File.exist?(filename)

        JSON.parse(File.read(filename))
      rescue JSON::ParserError
        nil
      end

      # Parse the incoming JSON if necessary
      def prepare_json(json:)
        json.is_a?(String) ? JSON.parse(json) : json
      rescue JSON::ParserError
        nil
      end
    end
  end
end
