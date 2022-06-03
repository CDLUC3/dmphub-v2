# frozen_string_literal: true

require 'json'

module Dmp
  # DMP adapter for an AWS DynamoDB Table
  class DynamoAdapter

    class << self
      # Search the DB using the specified criteria
      def list(criteria: {})

      end

      # Retrieve the DB entry for the specified RDA Common Standard JSON
      def find(dmp: {})
        return nil
      end

      # Add a record to the table
      def create(dmp: {})

      end

      # Update a record in the table
      def update(dmp: {})

      end

      # Delete/Tombstone a record in the table
      def delete(dmp: {})

      end
    end
  end
end
