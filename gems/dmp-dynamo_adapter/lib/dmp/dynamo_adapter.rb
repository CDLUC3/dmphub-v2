# frozen_string_literal: true

require 'uri'
require 'json'
require 'securerandom'
require 'uc3-ssm'
require 'aws-sdk-dynamodb'

module Dmp
  # DMP adapter for an AWS DynamoDB Table
  # rubocop:disable Metrics/ClassLength
  class DynamoAdapter
    DOI_REGEX = %r{[0-9]{2}\.[0-9]{5}/[a-zA-Z0-9/-_\.]+}.freeze

    MSG_DEFAULT = 'Unable to process your request.'
    MSG_EXISTS = 'DMP already exists. Try :update instead.'
    MSG_NOT_FOUND = 'DMP does not exist.'
    MSG_FORBIDDEN = 'You cannot update the DMP.'
    MSG_NO_DMP_ID = 'A DMP ID could not be registered at this time.'
    MSG_UNKNOWN = 'DMP does not exist. Try :create instead.'
    MSG_NO_HISTORICALS = 'You cannot modify a historical version of the DMP.'

    # Initialize an instance by setting the provenance and connecting to the DB
    def initialize(provenance:, debug: false)
      @provenance = provenance.start_with?('PROVENANCE#') ? provenance : "PROVENANCE##{provenance}"
      @debug_mode = debug

      @client = Aws::DynamoDB::Client.new(
        region: ENV['AWS_REGION']
      )
    end

    # Fetch the DMPs for the provenance
    # rubocop:disable Metrics/MethodLength
    def dmps_for_provenance
      return [] if @provenance.nil?

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
      response.items.first&.fetch(:dmps, []) || []
    end
    # rubocop:enable Metrics/MethodLength

    # Find the DMP by its PK and SK
    def find_by_pk(p_key:, s_key: 'VERSION#latest')
      return { status: 404, error: MSG_NOT_FOUND } if p_key.nil?

      response = @client.get_item(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          key: { PK: p_key, SK: s_key },
          consistent_read: false,
          return_consumed_capacity: @debug_mode ? 'TOTAL' : 'NONE'
        }
      )

      # TODO: Send the capacity stats to cloudwatch in debug mode

      { status: 200, items: response.items }
    end

    # Find a DMP based on the contents of the incoming JSON
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def find_by_json(json:)
      return { status: 404, error: MSG_NOT_FOUND } if json.nil? || (json[:PK].nil? && json[:dmp_id].nil?)

      pk = json[:PK]
      # Translate the incoming :dmp_id into a PK
      pk = pk_from_dmp_id(json: json.fetch(:dmp_id, {})) if pk.nil?

      # find_by_PK
      response = find_by_PK(p_key: p_key, s_key: json[:SK]) unless pk.nil?
      return response unless response[:items].nil? || response[:items].empty?

      # find_by_dmphub_provenance_id -> if no PK and no dmp_id result
      find_by_dmphub_provenance_identifier(json: json) if dmp.nil?
    end
    # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    # Add a record to the table
    # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
    def create(json: {})
      json = prepare_json(json: json)
      return { status: 400, error: MSG_DEFAULT } if json.nil? || @provenance.nil?

      # Try to find it first
      dmp = find_by_json(json: json).first
      # Abort if found
      return { status: 400, error: MSG_EXISTS } unless dmp.nil? || dmp.empty?

      # allocate a DMP ID
      dmp_id = preregister_dmp_id
      return { status: 500, error: MSG_NO_DMP_ID } if dmp_id.nil?

      # Add the DMPHub specific attributes and then save
      json = annotate_json(json: json, p_key: "DMP##{dmp_id}")
      response = @client.put_item(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          item: json,
          return_consumed_capacity: @debug_mode ? 'TOTAL' : 'NONE'
        }
      )
      { status: 201, items: response.items }
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
      dmp_id = json.fetch(:dmp_id, {})[:identifier]
      return { status: 403, error: MSG_FORBIDDEN } unless "DMP##{dmp_id}" == p_key

      # Try to find it first
      dmp = find_by_json(json: json)
      # Abort if NOT found
      return { status: 404, error: MSG_NOT_FOUND } if dmp&.item&.nil?
      # Make sure they're not trying to update a historical copy of the DMP
      return { status: 405, error: MSG_NO_HISTORICALS } if dmp[:SK] != 'VERSION#latest'

      # version the old :latest
      version_it(dmp: dmp)

      # Add the DMPHub specific attributes and then save it
      json = annotate_json(json: json, p_key: p_key)
      # Retain the original record's :created_at date and ;provenance_identifier
      json[:dmphub_created_at] = dmp[:dmphub_created_at]
      json[:dmphub_provenance_identifier] = dmp[:dmphub_provenance_identifier]
      response = @client.put_item(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          item: json,
          return_consumed_capacity: @debug_mode ? 'TOTAL' : 'NONE'
        }
      )
      { status: 200, items: response.items }
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
      dmp_id = json.fetch(:dmp_id, {})[:identifier]
      return { status: 403, error: MSG_FORBIDDEN } unless "DMP##{dmp_id}" == p_key

      # Try to find it first
      dmp = find_by_json(json: json)
      # Abort if NOT found
      return { status: 404, error: MSG_NOT_FOUND } if dmp&.item&.nil?
      # Make sure they're not trying to update a historical copy of the DMP
      return { status: 405, error: MSG_NO_HISTORICALS } if dmp[:SK] != 'VERSION#latest'

      # version the old :latest
      version_it(dmp: dmp)

      # Add the DMPHub specific attributes and then save it
      json = annotate_json(json: json, p_key: p_key)
      response = @client.update_item(
        {
          key: {
            PK: json[:PK],
            SK: 'VERSION#latest'
          },
          update_expression: 'SET SK = :sk, dmphub_deleted_at = :date',
          expression_attribute_values: {
            sk: 'VERSION#tombstone',
            date: Time.now.to_formatted_s(:iso8601)
          },
          return_consumed_capacity: @debug_mode ? 'TOTAL' : 'NONE',
          table_name: ENV['AWS_DYNAMO_TABLE_NAME']
        }
      )
      { status: 200, items: response.items }
    rescue Aws::DynamoDB::Errors::DuplicateItemException
      { status: 405, error: MSG_EXISTS }
    rescue Aws::Errors::ServiceError
      { status: 500, error: MSG_DEFAULT }
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

    private

    attr_accessor :provenance
    attr_accessor :debug_mode
    attr_accessor :client

    def dmp_id_base_url
      ENV['DMP_ID_BASE_URL'].end_with?('/') ? ENV['DMP_ID_BASE_URL'] : "#{ENV['DMP_ID_BASE_URL']}/"
    end

    # Preassign a DMP ID that will leater be sent to the DOI minting authority (EZID)
    def preregister_dmp_id
      dmp_id = ''

      while dmp_id == ''
        prefix = "#{ENV['DMP_ID_SHOULDER']}.#{SecureRandom.hex(4).upcase}"
        dmp_id = prefix if find_by_pk(p_key: "DMP##{dmp_id}").empty?
      end
      "#{dmp_id_base_url}#{dmp_id}"
    end

    # Format the DOI in the way we want it
    def format_doi(value:)
      doi = value.match(DOI_REGEX).to_s
      return nil if doi.nil? || doi == ''

      doi = doi.gsub('doi:', '')
      doi = doi.start_with?('/') ? doi[1..doi.length] : doi
      "#{dmp_id_base_url}#{doi}" unless doi.start_with?('http')
    end

    # Translate the :dmp_id into a PK
    def pk_from_dmp_id(json:)
      return nil if json.nil? || json[:identifier].nil?

      # If it's a DOI format it correctly
      doi = format_doi(value: json[:identifier].to_s)
      return "DMP#doi:#{doi}" unless doi.nil? || doi == ''

      # If it uses the HTTP/HTTPS protocols try to parse it as a URI
      uri = URI(json[:identifier]) if json[:identifier].downcase.strip.start_with?('http')
      uri.nil? ? "DMP#other:#{json[:identifier]}" : "DMP#uri:#{uri}"
    rescue URI::BadURIError
      # Its not a URI so it is 'other'
      "DMP#other:#{json[:identifier]}"
    end

    # Add all attributes necessary for the DMPHub
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def annotate_json(json:, p_key:)
      annotated = json.clone
      # establish the initial PK and SK
      annotated[:PK] = p_key
      annotated[:SK] = 'VERSION#latest'

      # capture the original dmp_id if it does not match the PK
      id = annotated.fetch(:dmp_id, {})[:identifier]
      id = nil if id == p_key.gsub('DMP#', '')

      # Replace the dmp_id with the value in the PK
      annotated[:dmp_id] = { type: 'doi', identifier: p_key.gsub('DMP#', '') }

      # Update the following only if there is no value already
      annotated[:dmphub_provenance_id] = @provenance if json[:dmphub_provenance_id].nil?
      annotated[:dmphub_created_at] = Time.now.iso8601 if json[:dmphub_created_at].nil?

      # Always increment the modification dates
      annotated[:dmphub_modification_day] = Time.now.strftime('%Y-%M-%d')
      annotated[:dmphub_updated_at] = Time.now.iso8601
      return annotated unless annotated[:dmphub_provenance_identifier].nil? && !id.nil?

      annotated[:dmphub_provenance_identifier] = id.nil? ? annotated[:dmp_id][:identifier] : id
      annotated
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    # Attempt to find the DMP item by its 'is_metadata_for' :dmproadmap_related_identifier
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def find_by_dmphub_provenance_identifier(json:)
      return [] if json.nil? || json.fetch(:dmp_id, {})[:identifier].nil?

      response = @client.query(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          index_name: 'dmphub_provenance_identifier_gsi',
          key_conditions: {
            dmphub_provenance_identifier: {
              attribute_value_list: [json[:dmp_id][:identifier]],
              comparison_operator: 'EQ'
            }
          },
          filter_expression: 'SK = :version',
          expression_attribute_values: {
            ':SK': 'VERSION#latest'
          },
          return_consumed_capacity: @debug_mode ? 'TOTAL' : 'NONE'
        }
      )
      return [] if response.nil? || response.items.empty?

      # If we got a hit, fetch the DMP and return it.
      response = find_by_pk(p_key: response.items.first.item[:PK])
      response[:status] == 200 ? response[:items] : []
    rescue Aws::Errors::ServiceError
      []
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    # Convert the latest version into a historical version
    # rubocop:disable Metrics/MethodLength
    def version_it(dmp:)
      return false if dmp.nil? || dmp[:PK].nil? || !dmp[:PK].start_with?('DMP#') ||
                      dmp[:SK] != 'VERSION#latest'

      @client.update_item(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          key: {
            PK: dmp[:PK],
            SK: 'VERSION#latest'
          },
          update_expression: 'SET SK = :sk',
          expression_attribute_values: {
            sk: "VERSION##{dmp[:dmphub_updated_at] || Time.now.iso8601}"
          },
          return_consumed_capacity: @debug_mode ? 'TOTAL' : 'NONE',
          return_values: 'NONE'
        }
      )
      true
    rescue Aws::Errors::ServiceError
      false
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
