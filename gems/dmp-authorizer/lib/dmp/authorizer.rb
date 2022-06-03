# frozen_string_literal: true

require 'json'

module Dmp
  # DMP provenance authorization service
  class Authorizer
    # Valid actions types are:
    #   - :create  --> provenance wants to create a DMP
    #   - :update  --> provenance wants to update a DMP it owns
    #   - :delete  --> provenance wants to delete a DMP it owns
    ACTION_TYPES = %w[create update delete].freeze

    MSG_DEFAULT = 'DMP was empty, provenance was nil or an invalid action was specified!'
    MSG_NO_AUTH = 'Unknown provenance.'
    MSG_EXISTS = 'DMP already exists. Try :update instead.'
    MSG_UNKNOWN = 'DMP does not exist. Try :create instead.'
    MSG_UNAUTH = 'Provenance is not authorized'
    MSG_BAD_JSON = 'Fatal validation error: %<msg>s'

    class << self
      # Determines if the caller has permission to perform the operation
      def authorize(provenance:, env: 'dev', action: 'create', dmp: {})
        dmp_json = prepare_json(json: dmp)
        provenance_json = prepare_json(json: provenance)
        return respond if dmp_json.nil? || !ACTION_TYPES.include?(action)
        return respond(errors: MSG_NO_AUTH) if provenance_json.nil?

        # Verify that provenance can perform the action
        verified = verify_action(provenance: provenance_json, env: env,
                                 action: action, dmp: dmp_json)
        respond(authorized: verified[:status] == 200, errors: verified[:error])
      end

      private

      # Respond in a standardized JSON format with a :valid boolean flag and
      # an array of :errors
      def respond(authorized: false, errors: MSG_DEFAULT)
        errors = [errors] unless errors.is_a?(Array)
        errors = errors.map { |err| err.gsub(%r{ in schema [0-9a-z\-]+}, '') }
        { authorized: %w[true 1].include?(authorized.to_s), errors: errors }.to_json
      end

      # Verify that the provenance can perform the requested action on the dmp
      # rubocop:disable Metrics/CyclomaticComplexity
      def verify_action(provenance:, action:, dmp:, env: 'dev')
        # Check if the provenance has permission to write
        return { status: 401, error: MSG_UNAUTH } unless provenance[:scopes].include?("api.#{env}.write")

        # Fail if trying to create an existing DMP
        return { status: 405, error: MSG_EXISTS } if !dmp[:PK].nil? && action == 'create'
        # Fail if trying to update or delete an unknown DMP
        return { status: 404, error: MSG_UNKNOWN } if dmp[:PK].nil? && %w[delete update].include?(action)
        # Fail if trying to delete a DMP that the provenance does not own
        return { status: 401, error: MSG_UNAUTH } if dmp[:dmphub_provenance_id] != provenance[:PK] && action == 'delete'

        { status: 200, error: '' }
      end
      # rubocop:enable Metrics/CyclomaticComplexity

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
