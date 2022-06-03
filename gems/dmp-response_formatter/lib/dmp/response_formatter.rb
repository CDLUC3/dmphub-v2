# frozen_string_literal: true

require 'json'

module Dmp
  # DMP adapter for an S3 Bucket
  class ResponseFormatter
    class << self
      # List the contents
      def to_json(dmp: {})
        return nil
      end

      # Retrieve an object
      def to_html(dmp: {})
        return nil
      end

      # Add an object
      def to_xml(dmp: {})
        return nil
      end

      # Delete the object
      def to_bibtex(dmp: {})
        return nil
      end
    end
  end
end
