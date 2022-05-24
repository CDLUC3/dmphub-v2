# frozen_string_literal: true

require 'json'
require 'json-schema'

module Dmp
  class JsonValidator
    class << self
      VALIDATION_MODES = %w[create update delete]
      
      CREATE_SCHEMA = {
        
      }.freeze
      
      UPDATE_SCHEMA = {
        
      }.freeze
      
      DMP_ID_SCHEMA = {
        
      }.freeze
      
      def validate(mode:, json: {})
        return respond unless json.present? && VALIDATION_MODES.include?(mode)
        
        if mode == 'create'
          errors = JSON::Validator.fully_validate(CREATE_SCHEMA, json)
        elsif mode == 'delete'
          errors = JSON::Validator.fully_validate(UPDATE_SCHEMA, json)
        else
          errors = JSON::Validator.fully_validate(DELETE_SCHEMA, json)
        end
        
        respond(valid: errors.empty?, message: errors)
      rescue JSON::ParserError => e
        respond(message: "Invalid JSON: #{e.message}")  
      end
      
      private
      
      def respond(valid: false, message: 'JSON was empty or an invalid mode was specified!')
        { valid: valid, message: message }.to_json
      end
    end
  end
end
