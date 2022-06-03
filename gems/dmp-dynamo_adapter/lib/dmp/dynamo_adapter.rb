# frozen_string_literal: true

require 'json'
require 'aws-sdk-dynamodb'

module Dmp
  # DMP adapter for an AWS DynamoDB Table
  class DynamoAdapter

    MSG_DEFAULT = 'Unable to process your database request.'
    MSG_EXISTS = 'DMP already exists. Try :update instead.'
    MSG_NOT_FOUND = 'DMP does not exist.'
    MSG_UNKNOWN = 'DMP does not exist. Try :create instead.'

    class << self
      # Search the DB using the specified criteria
      def list(criteria: {})

      end

      # Retrieve the DB entry for the specified RDA Common Standard JSON
      def find(json: {})
        json = prepare_json(json: json)
        return respond if json.nil?

        client = connect
        items = []

        unless client.nil?
          response = client.get_item({
            key: json_to_key(json: json),
            table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
            consistent_read: false,
            return_consumed_capacity: 'TOTAL'
          })
          items = [response.items.first&.item]
        end

        return respond(status: 404, message: MSG_NOT_FOUND) unless items.any?

        respond(status: 200, item: items)
      rescue Aws::Errors::ServiceError => e
        respond(status: 500, error: "Unable to search for the requested item: #{e.message}")
      end

      # Add a record to the table
      def create(json: {})
        json = prepare_json(json: json)
        return respond if json.nil?

        client = connect
        items = []

        unless client.nil?
          response = client.put_item({
            item: json,
            return_consumed_capacity: 'TOTAL',
            table_name: ENV['AWS_DYNAMO_TABLE_NAME'],
          })
          items = [response.items.first&.item]
        end

        respond(status: (items.any? ? 400 : 201), item: items)
      rescue #Dynamo Duplicate Key if already exists

      rescue Aws::Errors::ServiceError => e
        respond(status: 500, error: "Unable to create the requested item: #{e.message}")
      end

      # Update a record in the table
      def update(json: {})

      end

      # Delete/Tombstone a record in the table
      def delete(json: {})

      end

      private

      # Connect to the DynamoDB Table
      def connect
        client = Aws::DynamoDB::Client.new(
          region: ENV['AWS_REGION']
        )
        { status: 200, client: client }
      rescue Aws::Errors::ServiceError => e
        { status: 500, error: "Couldn't connect to DynamoDB: #{e.code} - #{e.message}" }
      end

      # Respond in a standardized JSON format with a :valid boolean flag and
      # an array of :errors
      def respond(status: '400', error: MSG_DEFAULT, items: [])
        @errors = [error] if @error.nil?
        @errors << error
        { valid: status.to_s == '200', errors: @errors, items: items }.to_json
      end

      # Build the PK+SK key from the incoming JSON
      def json_to_key(json: {})
        # Return nil if the JSON doesn't have a PK
        return {} if json.nil? || json[:PK].nil?

        type = json[:PK].split('#').first
        # if a specific SK was specified use it, otherwise get the most relevant
        # based on the PK type
        sk = json.fetch(:SK, type == 'DMP' ? 'VERSION#latest' : 'PROFILE')

        { PK: json[:PK].to_s, SK: sk }
      end

      # Parse the incoming JSON if necessary or return as is if it's already a Hash
      def prepare_json(json:)
        return json if json.is_a?(Hash)

        json.is_a?(String) ? JSON.parse(json) : nil
      rescue JSON::ParserError => e
        record_error("Couldn't process the incoming JSON. Here's why: #{e.message}")
        nil
      end
    end
  end
end
