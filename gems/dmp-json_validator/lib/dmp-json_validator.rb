# frozen_string_literal: true

require 'json'
require 'json-schema'

module Dmp
  class JsonValidator
    # Valid Validation modes are:
    #   - :author --> system of provenance is either creating or updating
    #   - :amend  --> a non-provenance system is attempting to update
    #   - :delete --> system of provenance is attempting to tombstone
    VALIDATION_MODES = %w[author amend delete]

    class << self
      def validate(mode:, json: {})
        return respond unless json.present? && VALIDATION_MODES.include?(mode)
        
        # Choose the JSON Schema based on the specified mode
        case mode
        when 'amend'
          schema = amend_schema
        when 'delete'
          schema = delete_schema
        else
          schema = author_schema
        end    
        
        errors = JSON::Validator.fully_validate(JSON.parse(schema), json)
        respond(valid: errors.empty?, message: errors)
      rescue JSON::ParserError => e
        respond(message: "Invalid JSON: #{e.message}")
      rescue JSON::Schema::ValidationError => e
        respons(message: "Fatal validation error: #{e.message}")
      end
      
      private
      
      def respond(valid: false, message: 'JSON was empty or an invalid mode was specified!')
        { valid: valid, message: message }.to_json
      end
      
      def root_schema
        {
          "$schema": "http://json-schema.org/draft-07/schema#",
          "$id": "https://github.com/CDLUC3/dmphub-v2/gems/dmp-json_validator/lib/schemas/delete.json",
          title: "DMPHub DMP deletion schema",
          description: "JSON Schema for the a DMP ID that should be deleted (tombstoned)",
          type: "object",
          properties: {
            dmp: {
              "$id": "#/properties/dmp",
              type: "object",
              title: "A minimal DMP Schema",
              properties: {}
            }
          },
          additionalProperties: false,
          required: ["dmp"]
        }
      end
      
      def delete_schema
        root_schema.fetch(:properties, {})
                   .fetch(:dmp, {})
                   .fetch(:properties, {})
                   .merge(
          {
            dmp_id: {
              "$id": "#/properties/dmp/properties/dmp_id",
              type: "object",
              title: "The DMP Identifier Schema",
              description: "Identifier for the DMP itself",
              properties: {
                identifier: {
                  "$id": "#/properties/dmp/properties/dmp_id/properties/identifier",
                  type: "string",
                  title: "The DMP Identifier Value Schema",
                  description: "Identifier for a DMP",
                  examples: ["https://doi.org/10.1371/journal.pcbi.1006750"]
                },
                type: {
                  "$id": "#/properties/dmp/properties/dmp_id/properties/type",
                  type: "string",
                  enum: [
                    "handle",
                    "doi",
                    "ark",
                    "url",
                    "other"
                  ],
                  title: "The DMP Identifier Type Schema",
                  description: "The DMP Identifier Type. Allowed values: handle, doi, ark, url, other",
                  examples: ["doi"]
                }
              },
              required: [
                "identifier",
                "type"
              ]
            },
            title: {
              "$id": "#/properties/dmp/properties/title",
              type: "string",
              title: "The DMP Title Schema",
              description: "Title of a DMP",
              examples: ["DMP for our new project"]
            },
            required: [
              "dmp_id",
              "title"
            ]
          }
        )
      end
      
      def amend_schema
        root_schema.fetch(:properties, {})
                   .fetch(:dmp, {})
                   .fetch(:properties, {})
                   .merge(
          {
          
          }
        )
      end
      
      def author_schema
        schema = root_schema
        schema.fetch(:properties, {})
              .fetch(:dmp, {})
              .fetch(:properties, {})
              .merge(
          {
      
          }
        )
      end
    end
  end
end
