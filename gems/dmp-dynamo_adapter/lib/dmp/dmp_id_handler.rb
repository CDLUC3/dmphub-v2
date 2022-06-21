# frozen_string_literal: true

require 'securerandom'
require 'dmp/metadata_handler'

module Dmp
  # Methods that handle PK generation
  class DmpIdHandler
    DOI_REGEX = %r{[0-9]{2}\.[0-9]{5}/[a-zA-Z0-9/_.]+}.freeze

    class << self
      def dmp_id_base_url
        ENV['DMP_ID_BASE_URL'].end_with?('/') ? ENV['DMP_ID_BASE_URL'] : "#{ENV['DMP_ID_BASE_URL']}/"
      end

      # Preassign a DMP ID that will leater be sent to the DOI minting authority (EZID)
      def preregister_dmp_id
        dmp_id = ''

        counter = 0
        while dmp_id == '' && counter <= 10
          prefix = "#{ENV['DMP_ID_SHOULDER']}.#{SecureRandom.hex(4).upcase}"
          dmp_id = prefix if find_by_pk(p_key: Dmp::MetadataHandler.append_pk_prefix(dmp: dmp_id)).empty?
          counter += 1
        end
        # Something went wrong and it was unable to identify a unique id
        return nil if counter >= 10

        "#{Dmp::MetadataHandler::PK_DMP_PREFIX}#{dmp_id_base_url}#{dmp_id}"
      end

      # Format the DMP ID in the way we want it
      def format_dmp_id(value:)
        dmp_id = value.match(DOI_REGEX).to_s
        return nil if dmp_id.nil? || dmp_id == ''
        # If it's already a URL, return it as is
        return value if value.start_with?('http')

        dmp_id = dmp_id.gsub('doi:', '')
        dmp_id = dmp_id.start_with?('/') ? dmp_id[1..dmp_id.length] : dmp_id
        "#{dmp_id_base_url}#{dmp_id}"
      end

      # Append the :PK prefix to the :dmp_id
      def dmp_id_to_pk(json:)
        return nil if json.nil? || json['identifier'].nil?

        # If it's a DOI format it correctly
        dmp_id = format_dmp_id(value: json['identifier'].to_s)
        return nil if dmp_id.nil? || dmp_id == ''

        Dmp::MetadataHandler.append_pk_prefix(dmp: dmp_id)
      end

      # Derive the DMP ID by removing the :PK prefix
      def pk_to_dmp_id(p_key:)
        return nil if p_key.nil?

        { type: 'doi', identifier: Dmp::MetadataHandler.remove_pk_prefix(dmp: p_key) }
      end
    end
  end
end
