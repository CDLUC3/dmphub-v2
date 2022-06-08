# frozen_string_literal: true

require 'json'

module Dmp
  # DMP adapter for an S3 Bucket
  class ResponseFormatter
    class << self
      # List the contents
      def format(status: 200, dmps: [], errors: [], total_nbr_items: 0)
        total_nbr_items = dmps.length if total_nbr_items == 0 || total_nbr_items.nil?

        body = {
          item_count: total_nbr_items,
          items: []
        }
        body[:items] = dmps.map { |dmp| cleanse_dmp(dmp: dmp) } if dmps.is_a?(Array)
        body[:errors] = errors if errors.is_a?(Array) && errors.any?

        { statusCode: status.to_i, body: body.to_json }
      end

      private

      # Recursive method to remove any DMPHub specific fields from the JSON
      def cleanse_dmp_json(json:)
        return json unless json.is_a?(Hash) || json.is_a?(Array)

        # If it's an array clean each of the objects individually
        return json.map { |obj| cleanse_dmp_json(json: obj) } if json.is_a?(Array)

        cleansed = {}
        json.keys.each do |key|
          next if key.to_s.start_with?('dmphub') || %w[PK SK].include?(key.to_s)

          obj = json[key]
          # If this object is a Hash or Array then recursively cleanse it
          cleansed[key] = obj.is_a?(Hash) || obj.is_a?(Array) ? cleanse_dmp_json(json: obj) : obj
        end
        cleansed
      end
    end
  end
end
