# frozen_string_literal: true

require 'json'

module Dmp
  # DMP adapter for an S3 Bucket
  class S3Adapter
    class << self
      # List the contents
      def list(criteria: {})

      end

      # Retrieve an object
      def find(dmp: {})
        return nil
      end

      # Add an object
      def create(dmp: {})

      end

      # Delete the object
      def delete(dmp: {})

      end
    end
  end
end
