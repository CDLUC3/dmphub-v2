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
      return { status: 404, error: MSG_NOT_FOUND } if response.items.empty?

      { status: 200, items: response.items.map(&:item).compact.uniq }
    rescue Aws::Errors::ServiceError
      { status: 500, error: MSG_DEFAULT }
    end

    # Find a DMP based on the contents of the incoming JSON
    # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    def find_by_json(json:)
      return { status: 404, error: MSG_NOT_FOUND } if json.nil? || (json['PK'].nil? && json['dmp_id'].nil?)

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
      dmp_id = preregister_dmp_id
      return { status: 500, error: MSG_NO_DMP_ID } if dmp_id.nil?

      # Add the DMPHub specific attributes and then save
      json = annotate_json(json: json, p_key: dmp_id)
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
      dmp_id = json.fetch('dmp_id', {})['identifier']
      return { status: 403, error: MSG_FORBIDDEN } unless "DMP##{dmp_id}" == p_key

      # Try to find it first
      result = find_by_json(json: json)
      return { status: 500, error: MSG_DEFAULT } if result[:status] == 500

      dmp = result[:items].first&.item
      return { status: 404, error: MSG_NOT_FOUND } if dmp.nil?
      # Only allow this if the provenance is the owner of the DMP!
      return { status: 403, error: MSG_FORBIDDEN } unless dmp['dmphub_provenance_id'] == @provenance
      # Make sure they're not trying to update a historical copy of the DMP
      return { status: 405, error: MSG_NO_HISTORICALS } if dmp['SK'] != 'VERSION#latest'

      # version the old :latest
      version_result = version_it(dmp: dmp)
      return version_result if version_result[:status] != 200

      # Add the DMPHub specific attributes and then save it
      json = annotate_json(json: json, p_key: p_key)

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
      dmp_id = json.fetch('dmp_id', {})['identifier']
      return { status: 403, error: MSG_FORBIDDEN } unless "DMP##{dmp_id}" == p_key

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
      return { status: 405, error: MSG_NO_HISTORICALS } if dmp['SK'] != 'VERSION#latest'

      response = @client.update_item(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          key: {
            PK: dmp['PK'],
            SK: 'VERSION#latest'
          },
          update_expression: 'SET SK = :sk, dmphub_deleted_at = :deletion_date',
          expression_attribute_values: {
            sk: "VERSION#tombstone",
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
      return nil if json.nil? || json['identifier'].nil?

      # If it's a DOI format it correctly
      doi = format_doi(value: json['identifier'].to_s)
      return "DMP##{doi}" unless doi.nil? || doi == ''

      # If it uses the HTTP/HTTPS protocols try to parse it as a URI
      uri = URI(json['identifier']) if json['identifier'].downcase.strip.start_with?('http')
      return "DMP##{uri}" unless uri.nil?

      nil
    rescue URI::BadURIError
      nil
    end

    # Add all attributes necessary for the DMPHub
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def annotate_json(json:, p_key:)
      annotated = json.clone
      # establish the initial PK and SK
      annotated['PK'] = p_key
      annotated['SK'] = 'VERSION#latest'

      # capture the original dmp_id if it does not match the PK
      id = annotated.fetch('dmp_id', {})['identifier']
      id = nil if id == p_key.gsub('DMP#', '')

      # Replace the dmp_id with the value in the PK
      annotated['dmp_id'] = { type: 'doi', identifier: p_key.gsub('DMP#', '') }

      # Update the following only if there is no value already
      annotated['dmphub_provenance_id'] = @provenance if json['dmphub_provenance_id'].nil?
      annotated['dmphub_created_at'] = Time.now.iso8601 if json['dmphub_created_at'].nil?

      # Always increment the modification dates
      annotated['dmphub_modification_day'] = Time.now.strftime('%Y-%M-%d')
      annotated['dmphub_updated_at'] = Time.now.iso8601
      return annotated unless annotated['dmphub_provenance_identifier'].nil? && !id.nil?

      annotated['dmphub_provenance_identifier'] = id.nil? ? annotated['dmp_id']['identifier'] : id
      annotated
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    # Safely merge updated content
    def splice_json(original_version:, new_version:)
      dmphub_keys = %w[PK SK] + new_version.keys.select { |key| key.start_with?('dmphub_') }
      spliced = {}

      # Build out the spliced copy
      dmphub_keys.each { |key| spliced[key] = new_version[key] }
      # Always retain the original record's :created_at date and ;provenance_identifier
      spliced['dmphub_created_at'] = original_version['dmphub_created_at']
      spliced['dmphub_provenance_identifier'] = original_version['dmphub_provenance_identifier']

      # Determine if the updater is the owner (aka system of provenance) of the DMP
      is_owner = @provenance == original_version['dmphub_provenance_id']
      # attributes that are allowed to be updated by non-owner systems
      provincials = %w[project dmproadmap_related_identifiers]

      # process the non-DMPHub specific attributes
      new_version.keys.reject { |key| dmphub_keys.include?(key) }.each do |key|
        # If the owner (aka system of provenance) is making the update, let them do so
        # unless this is an attibute that we allow non-owner systems to update
        spliced[key] = new_version[key] if is_owner && !provincials.include?(key)
        next if is_owner && !provincials.include?(key)
        # project if a complex type, so
        next if key == 'project'

        # This can only accomodate updates to entries that are arrays in the JSON
        spliced[key] = provincial_merge(
          provenance: original_version['dmphub_provenance_id'],
          original_array: original_version[key],
          new_array: new_version[key]
        )
      end
      spliced
    end

    # Safely merge and annotate the updateds
    def provincial_merge(provenance:, original_array:, new_array:)
      return original_array if provenance.nil?
      return new_array if original_array.nil?

      # separate all the entries into their systems of provenance
      owners = original_array.select { |obj| obj['dmphub_provenance_id'].nil? }
      others = original_array.reject { |obj| obj['dmphub_provenance_id'].nil? }
      # If the owner system is updating then replace all of its entries and retain others
      return (new_array + others) if provenance == @provenance

      # Otherwise only replace the provincial system's entries
      (owners + others.reject { |o| o['dmphub_provenance_id'] == @provenance } + new_array)
    end

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
            ':SK': 'VERSION#latest'
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
                                                    !dmp['PK'].start_with?('DMP#')
      return { status: 403, error: MSG_NO_HISTORICALS } if dmp['SK'] != 'VERSION#latest'

      response = @client.update_item(
        {
          table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          key: {
            PK: dmp['PK'],
            SK: 'VERSION#latest'
          },
          update_expression: 'SET SK = :sk',
          expression_attribute_values: {
            sk: "VERSION##{dmp['dmphub_updated_at'] || Time.now.iso8601}"
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
