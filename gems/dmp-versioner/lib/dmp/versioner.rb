# frozen_string_literal: true

require 'json'
require 'aws-sdk-dynamodb'

module Dmp
  # DMP provenance authorization service
  class Versioner

    MSG_DEFAULT = 'DMP was empty, provenance was nil or an invalid action was specified!'
    MSG_NO_AUTH = 'Unknown provenance.'
    MSG_EXISTS = 'DMP already exists. Try :update instead.'
    MSG_UNKNOWN = 'DMP does not exist. Try :create instead.'
    MSG_UNAUTH = 'Provenance is not authorized'
    MSG_BAD_JSON = 'Fatal validation error: %<msg>s'

    class << self
      # Determines if the caller has permission to perform the operation
      def process(dmp: {})
        return nil
      end

      private

      # Respond in a standardized JSON format with a :valid boolean flag and
      # an array of :errors
      def respond(authorized: false, errors: MSG_DEFAULT)
        errors = [errors] unless errors.is_a?(Array)
        errors = errors.map { |err| err.gsub(%r{ in schema [0-9a-z\-]+}, '') }
        { authorized: %w[true 1].include?(authorized.to_s), errors: errors }.to_json
      end

      # Parse the incoming JSON if necessary or return as is if it's already a Hash
      def prepare_json(json:)
        return json if json.is_a?(Hash)

        json.is_a?(String) ? JSON.parse(json) : nil
      rescue JSON::ParserError
        nil
      end
    end
  end
end
