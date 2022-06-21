 # frozen_string_literal: true

require 'dmp/dmp_id_handler'

module Dmp
  # Handles alterations to DMP metadata elements
  class MetadataHandler
    PK_DMP_PREFIX = 'DMP#'.freeze
    PK_PROVENANCE_PREFIX = 'PROVENANCE#'.freeze

    SK_PREFIX = 'VERSION#'.freeze

    LATEST_VERSION = "#{SK_PREFIX}latest".freeze
    TOMBSTONE_VERSION = "#{SK_PREFIX}tombstone".freeze

    class << self
      # determine if the objects are equal. This ignores :SK, :dmphub_modification_day
      # and :dmphub_updated_at attributes
      def eql(dmp_a:, dmp_b:)
        dmp_a = {} if dmp_a.nil?
        dmp_b = {} if dmp_b.nil?
        # They are not equal if the :PK do not match (and aren't blank)
        return false if !dmp_a['PK'].nil? && !dmp_b['PK'].nil? && dmp_a['PK'] != dmp_b['PK']

        a = deep_copy(obj: dmp_a)
        b = deep_copy(obj: dmp_b)

        # ignore some of the attributes before comparing
        %w[SK dmphub_modification_day dmphub_updated_at dmphub_created_at].each do |key|
          a.delete(key) unless a[key].nil?
          b.delete(key) unless b[key].nil?
        end
        a == b
      end

      # Append the PK prefix for the object
      def append_pk_prefix(dmp: nil, provenance: nil)
        # If all the :PK types were passed return nil because we only want one
        return nil if !dmp.nil? && !provenance.nil?

        return "#{PK_DMP_PREFIX}#{remove_pk_prefix(dmp: dmp)}" unless dmp.nil?
        return "#{PK_PROVENANCE_PREFIX}#{remove_pk_prefix(provenance: provenance)}" unless provenance.nil?

        nil
      end

      # Strip off the PK prefix
      def remove_pk_prefix(dmp: nil, provenance: nil)
        # If all the :PK types were passed return nil because we only want one
        return nil if !dmp.nil? && !provenance.nil?

        return dmp.gsub(PK_DMP_PREFIX, '') unless dmp.nil?
        return provenance.gsub(PK_PROVENANCE_PREFIX, '') unless provenance.nil?

        nil
      end

      # Add all attributes necessary for the DMPHub
      # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
      def annotate_json(provenance:, p_key:, json:)
        return nil if provenance.nil? || p_key.nil? || json.nil?

        # Fail if the :PK does not match the :dmp_id if the json has a :PK
        id = Dmp::DmpIdHandler.dmp_id_to_pk(json: json.fetch('dmp_id', {}))
        id = nil if id != p_key && !json['PK'].nil?

        annotated = deep_copy(obj: json)
        annotated['PK'] = json['PK'] || p_key
        annotated['SK'] = LATEST_VERSION

        # Ensure that the :dmp_id matches the :PK
        annotated['dmp_id'] = Dmp::DmpIdHandler.pk_to_dmp_id(p_key: annotated['PK'])

        # Update the modification timestamps
        annotated['dmphub_modification_day'] = Time.now.strftime('%Y-%M-%d')
        annotated['dmphub_updated_at'] = Time.now.iso8601
        # Only add the Creation date if it is blank
        annotated['dmphub_created_at'] = Time.now.iso8601 if json['dmphub_created_at'].nil?
        return annotated unless json['dmphub_provenance_id'].nil?

        annotated['dmphub_provenance_id'] = provenance
        return annotated if !annotated['dmphub_provenance_identifier'].nil? ||
                            json.fetch('dmp_id', {})['identifier'].nil?

        # Record the original Provenance system's identifier
        annotated['dmphub_provenance_identifier'] = json['dmp_id']
        annotated
      end
      # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

      # Process an update on the DMP metadata
      def process_update(updater:, original_version:, new_version:)
        return nil if updater.nil? || new_version.nil?
        # If there is no :original_version then assume it's a new DMP
        return new_version if original_version.nil?
        # does not allow tombstoned DMPs to be updated
        return original_version if original_version['SK'] == TOMBSTONE_VERSION
        return original_version if eql(dmp_a: original_version, dmp_b: new_version)

        owner = original_version['dmphub_provenance_id']
        args = { owner: owner, updater: updater }

        # If the system of provenance is making the change then just use the
        # new version as the base and then splice in any mods made by others
        args = args.merge({ base: new_version, mods: original_version})
        return splice_for_owner(args) if owner == updater

        # Otherwise use the original version as the base and then update the
        # metadata owned by the updater system
        args = args.merge({ base: original_version, mods: new_version})
        splice_for_others(args)
      end

      private

      # Splice changes from other systems back onto the system of provenance's changes
      def splice_for_owner(owner:, updater:, base:, mods:)
        return base if owner.nil? || updater.nil? || mods.nil?
        return mods if base.nil?

        provenance_regex = %r{"dmphub_provenance_id":"#{PK_PROVENANCE_PREFIX}[a-zA-Z\-_]+"}
        others = base.to_json.match(provenance_regex)
        # Just return it as is if there are no mods by other systems
        return mods if others.nil?

        spliced = deep_copy(obj: base)
        cloned_mods = deep_copy(obj: mods)

        # ensure that the :project and :funding are defined
        spliced['project'] = [{}] if spliced['project'].nil? || spliced['project'].empty?
        spliced['project'].first['funding'] = [] if spliced['project'].first['funding'].nil?
        # get all the new funding and retain other system's funding metadata
        mod_fundings = cloned_mods.fetch('project', [{}]).first.fetch('funding', [])
        other_fundings = spliced['project'].first['funding'].reject { |fund| fund['dmphub_provenance_id'].nil? }
        # process funding (just attach all funding not owned by the system of provenance)
        spliced['project'].first['funding'] = mod_fundings
        spliced['project'].first['funding'] << other_fundings if other_fundings.any?
        return spliced if cloned_mods['dmproadmap_related_identifiers'].nil?

        # process related_identifiers (just attach all related identifiers not owned by the system of provenance)
        spliced['dmproadmap_related_identifiers'] = [] if spliced['dmproadmap_related_identifiers'].nil?
        mod_relateds = cloned_mods.fetch('dmproadmap_related_identifiers', [])
        other_relateds = spliced['dmproadmap_related_identifiers'].reject { |id| id['dmphub_provenance_id'].nil? }
        spliced['dmproadmap_related_identifiers'] = mod_relateds
        spliced['dmproadmap_related_identifiers'] << other_relateds if other_relateds.any?
        spliced
      end

      # Splice changes from other systems back onto the system of provenance's changes
      def splice_for_others(owner:, updater:, base:, mods:)
        return base if owner.nil? || updater.nil? || base.nil? || mods.nil?

        spliced = deep_copy(obj: base)
         base_funds = spliced.fetch('project', [{}]).first.fetch('funding', [])
        base_relateds = spliced.fetch('dmproadmap_related_identifiers', [])

        mod_funds = mods.fetch('project', [{}]).first.fetch('funding', [])
        mod_relateds = mods.fetch('dmproadmap_related_identifiers', [])

        # process funding
        spliced['project'].first['funding'] = update_funding(
          updater: updater, base: base_funds, mods: mod_funds
        )
        return spliced if mod_relateds.empty?

        # process related_identifiers
        spliced['dmproadmap_related_identifiers'] = update_related_identifiers(
          updater: updater, base: base_relateds, mods: mod_relateds
        )
        spliced
      end

      # Splice funding changes
      def update_funding(updater:, base:, mods:)
        return base if updater.nil? || mods.nil? || mods.empty?

        spliced = deep_copy(obj: base)
        mods.each do |funding|
          # Ignore it if it has no status or grant id
          next if funding['funding_status'].nil? && funding['grant_id'].nil?

          # See if there is an existing funding record for the funder that's waiting on an update
          spliced = [] if spliced.nil?
          items = spliced.select do |orig|
            !orig['funder_id'].nil? &&
              orig['funder_id'] == funding['funder_id'] &&
              %w[applied planned].include?(orig['funding_status'])
          end
          # Always grab the most current
          item = items.sort { |a, b| b.fetch('dmphub_created_at', '') <=> a.fetch('dmphub_created_at', '') }.first

          # Out with the old and in with the new
          spliced.delete(item) unless item.nil?
          # retain the original name
          funding['name'] = item['name'] unless item.nil?
          item = deep_copy(obj: funding)

          item['funding_status'] == funding['funding_status'] unless funding['funding_status'].nil?
          spliced << item if funding['grant_id'].nil?
          next if funding['grant_id'].nil?

          item['grant_id'] = funding['grant_id']
          item['funding_status'] = funding['grant_id'].nil? ? 'rejected' : 'granted'

          # Add the provenance to the entry
          item['grant_id']['dmphub_provenance_id'] = updater
          item['grant_id']['dmphub_created_at'] = Time.now.iso8601
          spliced << item
        end
        spliced
      end

      # Splice related identifier changes
      def update_related_identifiers(updater:, base:, mods:)
        return base if updater.nil? || mods.nil? || mods.empty?

        # Remove the updater's existing related identifiers and replace with the new set
        spliced = base.nil? ? [] : deep_copy(obj: base)
        spliced = spliced.reject { |related| related['dmphub_provenance_id'] == updater }
        # Add the provenance to the entry
        updates = mods.nil? ? [] : deep_copy(obj: mods)
        updates = updates.map do |related|
          related['dmphub_provenance_id'] = updater
          related
        end
        spliced + updates
      end

      # Ruby's clone/dup methods do not clone/dup the children, so we need to do it here
      def deep_copy(obj:)
        case obj.class.name
        when 'Array'
          obj.map { |item| deep_copy(obj: item) }
        when 'Hash'
          hash = obj.dup
          hash.each_pair do |key, value|
            if ::String === key || ::Symbol === key
              hash[key] = deep_copy(obj: value)
            else
              hash.delete(key)
              hash[deep_copy(obj: key)] = deep_copy(obj: value)
            end
          end
          hash
        else
          obj.dup
        end
      end
    end
  end
end
