# frozen_string_literal: true

require 'json'
require 'uc3-ssm'
require 'aws-sdk-dynamodb'

require 'dmp/dmp_id_handler'
require 'dmp/metadata_handler'

module Dmp
  # DMP adapter for an AWS DynamoDB Table
  # rubocop:disable Metrics/ClassLength
  class DynamoAdapter
    MSG_DEFAULT = 'Unable to process your request.'
    MSG_EXISTS = 'DMP already exists. Try :update instead.'
    MSG_NOT_FOUND = 'DMP does not exist.'
    MSG_FORBIDDEN = 'You cannot update the DMP.'
    MSG_NO_DMP_ID = 'A DMP ID could not be registered at this time.'
    MSG_UNKNOWN = 'DMP does not exist. Try :create instead.'
    MSG_NO_HISTORICALS = 'You cannot modify a historical version of the DMP.'

    # Initialize an instance by setting the provenance and connecting to the DB
    def initialize(provenance:, debug: false)
      @provenance = Dmp::MetadataHandler.append_pk_prefix(provenance: provenance)
      @debug_mode = debug

      @client = Aws::DynamoDB::Client.new(
        region: ENV['AWS_REGION']
      )
    end

    # Fetch the DMPs for the provenance
    # rubocop:disable Metrics/MethodLength
    def dmps_for_provenance
      return { status: 404, error: MSG_NOT_FOUND } if @provenance.nil?

      response = @client.query(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          key_conditions: {
            PK: {
              attribute_value_list: ["PROVENANCE##{@provenance}"],
              comparison_operator: 'EQ'
            },
            SK: {
              attribute_value_list: ['DMPS'],
              comparison_operator: 'EQ'
            }
          }
        }
      )
      { status: 200, items: response.items.map(&:item).compact.uniq }
    rescue Aws::Errors::ServiceError
      { status: 500, error: MSG_DEFAULT }
    end
    # rubocop:enable Metrics/MethodLength

    # Find the DMP by its PK and SK
    def find_by_pk(p_key:, s_key: Dmp::MetadataHandler::LATEST_VERSION)
      return { status: 404, error: MSG_NOT_FOUND } if p_key.nil?

      response = @client.get_item(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          key: { PK: p_key, SK: s_key },
          consistent_read: false,
          return_consumed_capacity: @debug_mode ? 'TOTAL' : 'NONE'
        }
      )
      return { status: 404, error: MSG_NOT_FOUND } if response.items.empty?

      { status: 200, items: response.items.map(&:item).compact.uniq }
    rescue Aws::Errors::ServiceError
      { status: 500, error: MSG_DEFAULT }
    end

    # Find a DMP based on the contents of the incoming JSON
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def find_by_json(json:)
      return { status: 404, error: MSG_NOT_FOUND } if json.nil? ||
                                                      (json['PK'].nil? && json['dmp_id'].nil?)

      pk = json['PK']
      # Translate the incoming :dmp_id into a PK
      pk = pk_from_dmp_id(json: json.fetch('dmp_id', {})) if pk.nil?

      # find_by_PK
      response = find_by_pk(p_key: pk, s_key: json['SK']) unless pk.nil?
      return response if response[:status] == 500
      return response unless response[:items].nil? || response[:items].empty?

      # find_by_dmphub_provenance_id -> if no PK and no dmp_id result
      find_by_dmphub_provenance_identifier(json: json)
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # Add a record to the table
    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    def create(json: {})
      json = prepare_json(json: json)
      return { status: 400, error: MSG_DEFAULT } if json.nil? || @provenance.nil?

      # Try to find it first
      result = find_by_json(json: json)
      return { status: 500, error: MSG_DEFAULT } if result[:status] == 500
      # Abort if found
      return { status: 400, error: MSG_EXISTS } if result[:items].any?

      # allocate a DMP ID
      p_key = preregister_dmp_id
      return { status: 500, error: MSG_NO_DMP_ID } if p_key.nil?

      # Add the DMPHub specific attributes and then save
      json = Dmp::MetadataHandler.annotate_json(provenance: @provenance, json: json, p_key: p_key)
      response = @client.put_item(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          item: json,
          return_consumed_capacity: @debug_mode ? 'TOTAL' : 'NONE'
        }
      )
      { status: 201, items: response.items.map(&:item).compact.uniq }
    rescue Aws::DynamoDB::Errors::DuplicateItemException
      { status: 405, error: MSG_EXISTS }
    rescue Aws::Errors::ServiceError
      { status: 500, error: MSG_DEFAULT }
    end
    # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity

    # Update a record in the table
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def update(p_key:, json: {})
      json = prepare_json(json: json)
      return { status: 400, error: MSG_DEFAULT } if json.nil? || p_key.nil? || @provenance.nil?

      # Verify that the JSON is for the same DMP in the PK
      dmp_id = json.fetch('dmp_id', {})
      return { status: 403, error: MSG_FORBIDDEN } unless Dmp::DmpIdHandler.dmp_id_to_pk(json: dmp_id) == p_key

      # Try to find it first
      result = find_by_json(json: json)
      return { status: 500, error: MSG_DEFAULT } if result[:status] == 500

      dmp = result[:items].first&.item
      return { status: 404, error: MSG_NOT_FOUND } if dmp.nil?
      # Only allow this if the provenance is the owner of the DMP!
      return { status: 403, error: MSG_FORBIDDEN } unless dmp['dmphub_provenance_id'] == @provenance
      # Make sure they're not trying to update a historical copy of the DMP
      return { status: 405, error: MSG_NO_HISTORICALS } if dmp['SK'] != Dmp::MetadataHandler::LATEST_VERSION

      # version the old :latest
      version_result = version_it(dmp: dmp)
      return version_result if version_result[:status] != 200

      # Add the DMPHub specific attributes and then save it
      json = Dmp::MetadataHandler.annotate_json(provenance: @provenance, json: json, p_key: p_key)

p "BEFORE:"
pp json
p '==================================='
p ''

      json = splice_json(original_version: version_result[:items].first&.item, new_version: json)

p ''
p "AFTER:"
pp json

      response = @client.put_item(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          item: json,
          return_consumed_capacity: @debug_mode ? 'TOTAL' : 'NONE'
        }
      )

      # Update the provenance keys!
      # Update the ancillary keys for orcids, affiliations, provenance

      { status: 200, items: response.items.map(&:item).compact.uniq }
    rescue Aws::DynamoDB::Errors::DuplicateItemException
      { status: 405, error: MSG_EXISTS }
    rescue Aws::Errors::ServiceError
      { status: 500, error: MSG_DEFAULT }
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # Delete/Tombstone a record in the table
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def delete(p_key:, json: {})
      json = prepare_json(json: json)
      return { status: 400, error: MSG_DEFAULT } if json.nil? || p_key.nil? || @provenance.nil?

      # Verify that the JSON is for the same DMP in the PK
      dmp_id = json.fetch('dmp_id', {})
      return { status: 403, error: MSG_FORBIDDEN } unless Dmp::DmpIdHandler.dmp_id_to_pk(json: dmp_id) == p_key

      # Try to find it first
      result = find_by_json(json: json)
      return { status: 500, error: MSG_DEFAULT } if result[:status] == 500
      # Abort if NOT found
      return { status: 404, error: MSG_NOT_FOUND } unless result[:status] == 200 && result.fetch(:items, []).any?

      dmp = result[:items].first&.item
      return { status: 404, error: MSG_NOT_FOUND } if dmp.nil?
      # Only allow this if the provenance is the owner of the DMP!
      return { status: 403, error: MSG_FORBIDDEN } unless dmp['dmphub_provenance_id'] == @provenance
      # Make sure they're not trying to update a historical copy of the DMP
      return { status: 405, error: MSG_NO_HISTORICALS } if dmp['SK'] != Dmp::MetadataHandler::LATEST_VERSION

      response = @client.update_item(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          key: {
            PK: dmp['PK'],
            SK: Dmp::MetadataHandler::LATEST_VERSION
          },
          update_expression: 'SET SK = :sk, dmphub_deleted_at = :deletion_date',
          expression_attribute_values: {
            sk: Dmp::MetadataHandler::TOMBSTONE_VERSION,
            deletion_date: Time.now.iso8601
          },
          return_consumed_capacity: @debug_mode ? 'TOTAL' : 'NONE',
          return_values: 'ALL_NEW'
        }
      )
      { status: 200, items: response.items.map(&:item).compact.uniq }
    rescue Aws::Errors::ServiceError
      { status: 500, error: MSG_DEFAULT }
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    private

    attr_accessor :provenance
    attr_accessor :debug_mode
    attr_accessor :client

    # Attempt to find the DMP item by its 'is_metadata_for' :dmproadmap_related_identifier
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def find_by_dmphub_provenance_identifier(json:)
      return { status: 400, error: MSG_DEFAULT } if json.nil? || json.fetch('dmp_id', {})['identifier'].nil?

      response = @client.query(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          index_name: 'dmphub_provenance_identifier_gsi',
          key_conditions: {
            dmphub_provenance_identifier: {
              attribute_value_list: [json['dmp_id']['identifier']],
              comparison_operator: 'EQ'
            }
          },
          filter_expression: 'SK = :version',
          expression_attribute_values: {
            ':SK': Dmp::MetadataHandler::LATEST_VERSION
          },
          return_consumed_capacity: @debug_mode ? 'TOTAL' : 'NONE'
        }
      )
      return { status: 404, error: MSG_NOT_FOUND } if response.nil? || response.items.empty?

      # If we got a hit, fetch the DMP and return it.
      find_by_pk(p_key: response.items.first.item[:PK])
    rescue Aws::Errors::ServiceError
      { status: 500, error: MSG_DEFAULT }
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    # Convert the latest version into a historical version
    # rubocop:disable Metrics/MethodLength
    def version_it(dmp:)
      return { status: 400, error: MSG_DEFAULT } if dmp.nil? || dmp['PK'].nil? ||
                                                    !dmp['PK'].start_with?(Dmp::MetadataHandler::PK_DMP_PREFIX)
      return { status: 403, error: MSG_NO_HISTORICALS } if dmp['SK'] != Dmp::MetadataHandler::LATEST_VERSION

      response = @client.update_item(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          key: {
            PK: dmp['PK'],
            SK: Dmp::MetadataHandler::LATEST_VERSION
          },
          update_expression: 'SET SK = :sk',
          expression_attribute_values: {
            sk: "#{Dmp::MetadataHandler::SK_PREFIX}#{dmp['dmphub_updated_at'] || Time.now.iso8601}"
          },
          return_consumed_capacity: @debug_mode ? 'TOTAL' : 'NONE',
          return_values: 'NONE'
        }
      )
      return { status: 404, error: MSG_NOT_FOUND } if response.nil? || response.items.empty?

      { status: 200, items: response.items.map(&:item).compact.uniq }
    rescue Aws::Errors::ServiceError
      { status: 500, error: MSG_DEFAULT }
    end
    # rubocop:enable Metrics/MethodLength

    # Parse the incoming JSON if necessary or return as is if it's already a Hash
    def prepare_json(json:)
      return json if json.is_a?(Hash)

      json.is_a?(String) ? JSON.parse(json) : nil
    rescue JSON::ParserError
      nil
    end
  end
  # rubocop:enable Metrics/ClassLength
end
