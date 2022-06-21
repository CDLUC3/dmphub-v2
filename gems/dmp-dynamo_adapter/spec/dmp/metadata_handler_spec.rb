# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
RSpec.describe Dmp::MetadataHandler do
  describe 'eql(dmp_a:, dmp_b:)' do
    before(:each) do
      @a = JSON.parse(File.read("#{Dir.pwd}/spec/support/json_mocks/complete.json"))['dmp']
    end

    it 'returns false if :dmp_a is nil and :dmp_b is not nil' do
      expect(described_class.eql(dmp_a: nil, dmp_b: @a)).to eql(false)
    end
    it 'returns false if :dmp_a is not nil and :dmp_b is nil' do
      expect(described_class.eql(dmp_a: @a, dmp_b: nil)).to eql(false)
    end
    it 'returns false if :dmp_a and :dmp_b :PK do not match' do
      b = described_class.send(:deep_copy, obj: @a)
      b['PK'] = 'DMP#zzzzzzzzzzz'
      expect(described_class.eql(dmp_a: @a, dmp_b: b)).to eql(false)
    end
    it 'ignores expected fields' do
      b = described_class.send(:deep_copy, obj: @a)
      b['SK'] = 'VERSION#zzzzzzzzzzz'
      b['dmphub_created_at'] = Time.now.iso8601
      b['dmphub_updated_at'] = Time.now.iso8601
      b['dmphub_modification_day'] = Time.now.strftime('%Y-%M-%d')
      expect(described_class.eql(dmp_a: @a, dmp_b: b)).to eql(true)
    end
    it 'returns false if :dmp_a and :dmp_b do not match' do
      b = described_class.send(:deep_copy, obj: @a)
      b['title'] = 'zzzzzzzzzzz'
      expect(described_class.eql(dmp_a: @a, dmp_b: b)).to eql(false)
    end
    it 'returns true if :dmp_a and :dmp_b match' do
      b = described_class.send(:deep_copy, obj: @a)
      expect(described_class.eql(dmp_a: @a, dmp_b: b)).to eql(true)
    end
  end

  describe 'append_pk_prefix(dmp:, provenance:)' do
    it 'returns nil if no :dmp or :provenance is defined' do
      expect(described_class.append_pk_prefix).to eql(nil)
    end
    it 'returns nil if both the :dmp and :provenance are defined' do
      expect(described_class.append_pk_prefix(dmp: 'foo', provenance: 'foo')).to eql(nil)
    end
    it 'appends the :PK prefix to the :dmp' do
      expected = "#{described_class::PK_DMP_PREFIX}foo"
      expect(described_class.append_pk_prefix(dmp: 'foo')).to eql(expected)
    end
    it 'appends the :PK prefix to the :provenance' do
      expected = "#{described_class::PK_PROVENANCE_PREFIX}foo"
      expect(described_class.append_pk_prefix(provenance: 'foo')).to eql(expected)
    end
  end

  describe 'remove_pk_prefix(dmp:, provenance:)' do
    it 'returns nil if no :dmp or :provenance is defined' do
      expect(described_class.remove_pk_prefix).to eql(nil)
    end
    it 'returns nil if both the :dmp and :provenance are defined' do
      expect(described_class.remove_pk_prefix(dmp: 'foo', provenance: 'foo')).to eql(nil)
    end
    it 'removes the :PK prefix from the :dmp' do
      dmp = "#{described_class::PK_DMP_PREFIX}foo"
      expect(described_class.remove_pk_prefix(dmp: dmp)).to eql('foo')
    end
    it 'removes the :PK prefix from the :provenance' do
      prov = "#{described_class::PK_PROVENANCE_PREFIX}foo"
      expect(described_class.remove_pk_prefix(provenance: prov)).to eql('foo')
    end
  end

  describe 'annotate_json(provenance:, json:, p_key:)' do
    before(:each) do
      @prov = described_class.append_pk_prefix(provenance: 'foo')
      @pk = described_class.append_pk_prefix(dmp: '99.88888/7777.66')
    end

    describe 'for a new DMP' do
      before(:each) do
        @json = JSON.parse({
          dmp_id: { type: 'url', identifier: 'https://foo.org/dmps/999999' },
          title: 'Just testing',
          created: '2022-06-01T09:26:01Z',
          modified: '2022-06-03T08:15:24Z'
        }.to_json)
        @result = described_class.annotate_json(provenance: @prov, json: @json, p_key: @pk)
      end

      it 'derives the :PK from the result of :pk_from_dmp_id' do
        expect(@result['PK']).to eql(@pk)
      end
      it 'sets the :SK to the latest version' do
        expect(@result['SK']).to eql(described_class::LATEST_VERSION)
      end
      it 'sets the :dmphub_provenance_identifier to the :dmp_id' do
        expect(@result['dmphub_provenance_identifier']).to eql(@json['dmp_id'])
      end
      it 'sets the :dmp_id to the value of the :PK' do
        expect(@result['dmp_id']).to eql({ type: 'doi', identifier: @pk.gsub('DMP#', '') })
      end
      it 'sets the :dmphub_provenance_id to the current provenance' do
        expect(@result['dmphub_provenance_id']).to eql(@prov)
      end
      it 'sets the :dmphub_modification_day to the current date' do
        expect(@result['dmphub_modification_day']).to eql(Time.now.strftime('%Y-%M-%d'))
      end
      it 'sets the :dmphub_created_at and :dmphub_updated_at to the current time' do
        expected = Time.now.iso8601
        expect(@result['dmphub_created_at']).to be >= expected
        expect(@result['dmphub_updated_at']).to be >= expected
      end
    end

    describe 'for an existing DMP' do
      before(:each) do
        @json = JSON.parse({
          PK: @pk,
          SK: described_class::LATEST_VERSION,
          dmp_id: { type: 'doi', identifier: @dmp_id },
          title: 'Just testing',
          created: '2022-06-01T09:26:01Z',
          modified: '2022-06-03T08:15:24Z',
          dmphub_provenance_id: "PROVENANCE#bar",
          dmphub_modification_day: '2022-05-15',
          dmphub_created_at: '2022-05-01T10:00:00Z',
          dmphub_updated_at: '2022-05-15T10:16:34Z'
        }.to_json)
        @result = described_class.annotate_json(provenance: @prov, json: @json, p_key: @pk)
      end
      it 'derives the :PK from the result of :pk_from_dmp_id' do
        expect(@result['PK']).to eql(@pk)
      end
      it 'sets the :SK to the latest version' do
        expect(@result['SK']).to eql(described_class::LATEST_VERSION)
      end
      it 'does not set the :dmphub_provenance_identifier' do
        expect(@result['dmphub_provenance_identifier']).to eql(nil)
      end
      it 'sets the :dmp_id to the value of the :PK' do
        expected = { type: 'doi', identifier: @pk.gsub(described_class::PK_DMP_PREFIX, '') }
        expect(@result['dmp_id']).to eql(expected)
      end
      it 'does not change the :dmphub_provenance_id' do
        expect(@result['dmphub_provenance_id']).to eql(@json['dmphub_provenance_id'])
      end
      it 'does not change the :dmphub_created_at' do
        expect(@result['dmphub_created_at']).to eql(@json['dmphub_created_at'])
      end
      it 'sets the :dmphub_modification_day to the current date' do
        expect(@result['dmphub_modification_day']).to eql(Time.now.strftime('%Y-%M-%d'))
      end
      it 'sets the :dmphub_created_at and :dmphub_updated_at to the current time' do
        expected = Time.now.iso8601
        expect(@result['dmphub_updated_at']).to be >= expected
      end
    end
  end

  describe 'process_update(updater:, original_version:, new_version:)' do
    before(:each) do
      @base = JSON.parse(File.read("#{Dir.pwd}/spec/support/json_mocks/complete.json"))['dmp']
      @mods = described_class.send(:deep_copy, obj: @base)
      @mods['title'] = "#{@base['title']} - updated"
      @owner = @base['dmphub_provenance_id']
      @updater = 'PROVENANCE#updater'
    end

    it 'returns nil if :updater is nil' do
      result = described_class.process_update(updater: nil, original_version: @base,
                                              new_version: @mods)
      expect(result).to eql(nil)
    end
    it 'returns :original_version if the DMP has been Tombstoned' do
      @base['SK'] = described_class::TOMBSTONE_VERSION
      result = described_class.process_update(updater: @updater, original_version: @base,
                                              new_version: @mods)
      expect(result).to eql(@base)
    end
    it 'returns nil if :new_version is nil' do
      result = described_class.process_update(updater: @updater, original_version: @base,
                                              new_version: nil)
      expect(result).to eql(nil)
    end
    it 'returns the :new_version if :original_version is nil' do
      result = described_class.process_update(updater: @updater, original_version: nil,
                                              new_version: @mods)
      expect(result).to eql(@mods)
    end
    it 'returns the :new_version if it is equal to the :old_version' do
      result = described_class.process_update(updater: @updater, original_version: @base,
                                              new_version: @base)
      expect(result).to eql(@base)
    end
    it 'calls the :splice_for_owner, no :splice_for_others, if the :updater is the :owner' do

      pp @base['title']
      pp @mods['title']

      expect(described_class).to receive(:splice_for_owner).once
      expect(described_class).to receive(:splice_for_others).never
      described_class.process_update(updater: @owner, original_version: @base,
                                              new_version: @mods)
    end
    it 'calls the :splice_for_others, no :splice_for_owner, if the :updater is NOT the :owner' do
      expect(described_class).to receive(:splice_for_owner).never
      expect(described_class).to receive(:splice_for_others).once
      described_class.process_update(updater: @updater, original_version: @base,
                                              new_version: @mods)
    end
  end

  describe 'private methods' do
    describe 'splice_for_owner(owner:, updater:, base:, mods:)' do
      before(:each) do
        @base = JSON.parse(File.read("#{Dir.pwd}/spec/support/json_mocks/complete.json"))['dmp']
        @owner = @base['dmphub_provenance_id']
        @mods = JSON.parse({
          project: [
            funding: [{
              name: 'new_funder',
              funder_id: { type: 'url', identifier: 'http://new.org' },
              funding_status: 'applied'
            }]
          ],
          dmproadmap_related_identifiers: [
            { type: 'url', work_type: 'software', descriptor: 'references', identifier: 'http://github.com' }
          ]
        }.to_json)
      end

      it 'returns :base if :owner is nil' do
        expect(described_class.send(:splice_for_owner, owner: nil, updater: @updater, base: @base,
                                                        mods: @mods)).to eql(@base)
      end
      it 'returns :base if :updater is nil' do
        expect(described_class.send(:splice_for_owner, owner: @owner, updater: nil, base: @base,
                                                        mods: @mods)).to eql(@base)
      end
      it 'returns :mods if :base is nil' do
        expect(described_class.send(:splice_for_owner, owner: @owner, updater: @updater, base: nil,
                                                        mods: @mods)).to eql(nil)
      end
      it 'returns :base if :mods is nil' do
        expect(described_class.send(:splice_for_owner, owner: @owner, updater: @updater, base: @base,
                                                        mods: nil)).to eql(@base)
      end
      it 'retains other system\'s metadata' do
        # funds and related identifiers that are not owned by the system of provenance have a provenance_id
        funds = @base['project'].first['funding'].reject { |fund| fund['dmphub_provenance_id'].nil? }
        ids = @base['dmproadmap_related_identifiers'].reject { |id| id['dmphub_provenance_id'].nil? }
        result = described_class.send(:splice_for_owner, owner: @owner, updater: @updater, base: @base,
                                                         mods: @mods)
        funds.each { |fund| expect(result['project'].first['funding'].include?(fund)).to eql(true) }
        ids.each { |id| expect(result['dmproadmap_related_identifiers'].include?(id)).to eql(true) }
      end
      it 'uses the :mods if :base has no :project defined' do
        @base.delete('project')
        result = described_class.send(:splice_for_owner, owner: @owner, updater: @owner,
                                                          base: @base, mods: @mods)
        expect(result['project']).to eql(@mods['project'])
      end
      it 'uses the :mods if :base has no :funding defined' do
        @base['project'].first.delete('funding')
        result = described_class.send(:splice_for_owner, owner: @owner, updater: @owner,
                                                          base: @base, mods: @mods)
        expect(result['project'].first['funding']).to eql(@mods['project'].first['funding'])
      end
      it 'updates the :funding' do
        result = described_class.send(:splice_for_owner, owner: @owner, updater: @owner,
                                                          base: @base, mods: @mods)
        funds = @base['project'].first['funding'].reject { |fund| fund['dmphub_provenance_id'].nil? }
        expected = @mods['project'].first['funding'].length + funds.length
        expect(result['project'].first['funding'].length).to eql(expected)
        @mods['project'].first['funding'].each do |fund|
          expect(result['project'].first['funding'].include?(fund)).to eql(true)
        end
      end
      it 'does not bother updating the :dmproadmap_related_identifiers if the mods do not contain any' do
        @mods.delete('dmproadmap_related_identifiers')
        allow(described_class).to receive(:update_related_identifiers).never
        result = described_class.send(:splice_for_owner, owner: @owner, updater: @owner,
                                                          base: @base, mods: @mods)
        expect(result['dmproadmap_related_identifiers']).to eql(@base['dmproadmap_related_identifiers'])
      end
      it 'updates the :dmproadmap_related_identifiers' do
        result = described_class.send(:splice_for_owner, owner: @owner, updater: @owner,
                                                          base: @base, mods: @mods)
        ids = @base['dmproadmap_related_identifiers'].reject { |id| id['dmphub_provenance_id'].nil? }
        expected = @mods['dmproadmap_related_identifiers'].length + ids.length
        expect(result['dmproadmap_related_identifiers'].length).to eql(expected)
        @mods['dmproadmap_related_identifiers'].each { |id| expect(result['dmproadmap_related_identifiers'].include?(id)).to eql(true) }
      end
      it 'uses the :mods if :base has no :dmproadmap_related_identifiers defined' do
        @base.delete('dmproadmap_related_identifiers')
        result = described_class.send(:splice_for_owner, owner: @owner, updater: @owner,
                                                          base: @base, mods: @mods)
        expect(result['dmproadmap_related_identifiers']).to eql(@mods['dmproadmap_related_identifiers'])
      end
    end

    describe 'splice_for_others(owner:, updater:, base:, mods:)' do
      before(:each) do
        @updater = 'PROVENANCE#updater'
        @base = JSON.parse(File.read("#{Dir.pwd}/spec/support/json_mocks/complete.json"))['dmp']
        @owner = @base['dmphub_provenance_id']
        @mods = JSON.parse({
          project: [
            funding: [{
              name: 'new_funder',
              funder_id: { type: 'url', identifier: 'http://new.org' },
              funding_status: 'applied'
            }]
          ],
          dmproadmap_related_identifiers: [
            { type: 'url', work_type: 'software', descriptor: 'references', identifier: 'http://github.com' }
          ]
        }.to_json)
      end

      it 'returns :base if :owner is nil' do
        expect(described_class.send(:splice_for_others, owner: nil, updater: @updater, base: @base,
                                                        mods: @mods)).to eql(@base)
      end
      it 'returns :base if :updater is nil' do
        expect(described_class.send(:splice_for_others, owner: @owner, updater: nil, base: @base,
                                                        mods: @mods)).to eql(@base)
      end
      it 'returns :base if :base is nil' do
        expect(described_class.send(:splice_for_others, owner: @owner, updater: @updater, base: nil,
                                                        mods: @mods)).to eql(nil)
      end
      it 'returns :base if :mods is nil' do
        expect(described_class.send(:splice_for_others, owner: @owner, updater: @updater, base: @base,
                                                        mods: nil)).to eql(@base)
      end
      it 'updates the :funding' do
        result = described_class.send(:splice_for_others, owner: @owner, updater: @updater,
                                                          base: @base, mods: @mods)
        expected = @base['project'].first['funding'].length + 1
        expect(result['project'].first['funding'].length).to eql(expected)
      end
      it 'does not bother updating the :dmproadmap_related_identifiers if the mods do not contain any' do
        @mods.delete('dmproadmap_related_identifiers')
        allow(described_class).to receive(:update_related_identifiers).never
        result = described_class.send(:splice_for_others, owner: @owner, updater: @updater,
                                                          base: @base, mods: @mods)
        expected = result['dmproadmap_related_identifiers']
        expect(@base['dmproadmap_related_identifiers']).to eql(expected)
      end
      it 'updates the :dmproadmap_related_identifiers' do
        result = described_class.send(:splice_for_others, owner: @owner, updater: @updater,
                                                          base: @base, mods: @mods)
        expected = @base['dmproadmap_related_identifiers'].length + 1
        expect(result['dmproadmap_related_identifiers'].length).to eql(expected)
      end
    end

    describe 'update_funding(updater:, base:, mods:)' do
      before(:each) do
        @updater = "#{described_class::PK_PROVENANCE_PREFIX}bar"
        @funder_id = { type: 'ror', identifier: 'https://ror.org/12345' }
        @other_funder_id = { type: 'ror', identifier: 'https://ror.org/09876' }
        @updater_existing = 'http://example.org/grants/987'
        @owner_existing = 'http://owner.com/grants/123'
        @other_existing = 'http://other.org/grants/333'

        @base = JSON.parse([
          # System of provenance fundings
          { name: 'name-only', funding_status: 'applied' },
          { name: 'planned', funder_id: @funder_id, funding_status: 'planned' },
          { name: 'granted', funder_id: @funder_id, funding_status: 'granted',
            grant_id: { type: 'url', identifier: @owner_existing } },

          # Other non-system of provenance fundings
          { name: 'name-only', funding_status: 'applied', dmphub_created_at: Time.now.iso8601,
            dmphub_provenance_id: "#{described_class::PK_PROVENANCE_PREFIX}other" },
          { name: 'rejected', funder_id: @other_funder_id, funding_status: 'rejected',
            dmphub_provenance_id: "#{described_class::PK_PROVENANCE_PREFIX}other",
            dmphub_created_at: Time.now.iso8601 },
          { name: 'granted', funder_id: @funder_id, funding_status: 'granted',
            grant_id: { type: 'url', identifier: @other_existing },
            dmphub_provenance_id: "#{described_class::PK_PROVENANCE_PREFIX}other",
            dmphub_created_at: Time.now.iso8601 }
        ].to_json)
      end

      it 'returns :base if the :updater is nil' do
        result = described_class.send(:update_funding, updater: nil, base: @base, mods: @mods)
        expect(result).to eql(@base)
      end
      it 'returns :base if the :mods are empty' do
        result = described_class.send(:update_funding, updater: @updater, base: @base, mods: nil)
        expect(result).to eql(@base)
      end
      it 'returns the :mods if :base is nil' do
        mods = JSON.parse([
          { name: 'new', funder_id: { type: 'url', identifier: 'http:/keep.me' }, funding_status: 'planned' }
        ].to_json)
        result = described_class.send(:update_funding, updater: @updater, base: nil, mods: mods)
        expect(result.length).to eql(1)
        expect(result).to eql(mods)
      end
      it 'ignores entries that do not include the :funding_status or :grant_id' do
        mods = JSON.parse([
          { name: 'ignorable', funder_id: { type: 'url', identifier: 'http:/skip.me' } }
        ].to_json)
        result = described_class.send(:update_funding, updater: @updater, base: @base, mods: mods)
        expect(result.length).to eql(@base.length)
      end
      it 'does not delete other systems\' entries' do
        mods = JSON.parse([
          { name: 'new', funder_id: { type: 'url', identifier: 'http:/keep.me' }, funding_status: 'planned' }
        ].to_json)
        result = described_class.send(:update_funding, updater: @updater, base: @base, mods: mods)
        expect(result.length).to eql(@base.length + 1)
        expect(result).to eql(@base + mods)
      end
      it 'appends new entries' do
        mods = JSON.parse([
          { name: 'new', funder_id: { type: 'url', identifier: 'http:/keep.me' }, funding_status: 'planned' }
        ].to_json)
        results = described_class.send(:update_funding, updater: @updater, base: @base, mods: mods)
        result = results.select { |entry| entry['name'] == mods.first['name'] }.first
        expect(result.nil?).to eql(false)
        expect(result['funder_id']).to eql(mods.first['funder_id'])
        expect(result['funding_status']).to eql(mods.first['funding_status'])
        expect(result['grant_id'].nil?).to eql(true)
      end
      it 'includes dmphub metadata when the new entry includes a :grant_id' do
        mods = JSON.parse([
          { name: 'new', funder_id: { type: 'url', identifier: 'http:/keep.me' },
            funding_status: 'granted', grant_id: { type: 'other', identifier: '4444' } }
        ].to_json)
        results = described_class.send(:update_funding, updater: @updater, base: @base, mods: mods)
        result = results.select { |entry| entry['name'] == mods.first['name'] }.first
        expect(result.nil?).to eql(false)
        expect(result['funder_id']).to eql(mods.first['funder_id'])
        expect(result['funding_status']).to eql('granted')
        expect(result['grant_id']['type']).to eql(mods.first['grant_id']['type'])
        expect(result['grant_id']['identifier']).to eql(mods.first['grant_id']['identifier'])
        expect(result['grant_id']['dmphub_created_at'].nil?).to eql(false)
        expect(result['grant_id']['dmphub_provenance_id']).to eql(@updater)
      end
      it 'updates the latest provenance system entry with grant metadata' do
        mods = JSON.parse([
          { name: 'arbitrary', funder_id: @funder_id, funding_status: 'granted',
            grant_id: { type: 'other', identifier: '4444' } }
        ].to_json)
        results = described_class.send(:update_funding, updater: @updater, base: @base, mods: mods)
        result = results.select { |entry| entry['funder_id'] == mods.first['funder_id'] }.last
        original = @base.select { |entry| entry['funder_id'] == mods.first['funder_id'] }.first

        expect(result.nil?).to eql(false)
        expect(result['funder_id']).to eql(original['funder_id'])
        expect(result['funding_status']).to eql('granted')
        expect(result['grant_id']['type']).to eql(mods.first['grant_id']['type'])
        expect(result['grant_id']['identifier']).to eql(mods.first['grant_id']['identifier'])
        expect(result['grant_id']['dmphub_created_at'].nil?).to eql(false)
        expect(result['grant_id']['dmphub_provenance_id']).to eql(@updater)
      end
      it 'adds a new entry if the DMP already has a \'rejected\' or \'granted\' entry for the funder' do
        mods = JSON.parse([
          { name: 'arbitrary', funder_id: @other_funder_id, funding_status: 'granted',
            grant_id: { type: 'other', identifier: '4444' } }
        ].to_json)
        results = described_class.send(:update_funding, updater: @updater, base: @base, mods: mods)
        result = results.select { |entry| entry['funder_id'] == mods.first['funder_id'] }.last
        original = @base.select { |entry| entry['funder_id'] == mods.first['funder_id'] }.first
        expect(result.nil?).to eql(false)
        expect(result['funder_id']).to eql(original['funder_id'])
        expect(result['funding_status']).to eql('granted')
        expect(result['grant_id']['type']).to eql(mods.first['grant_id']['type'])
        expect(result['grant_id']['identifier']).to eql(mods.first['grant_id']['identifier'])
        expect(result['grant_id']['dmphub_created_at'].nil?).to eql(false)
        expect(result['grant_id']['dmphub_provenance_id']).to eql(@updater)
      end
    end

    describe 'update_related_identifiers(updater:, base:, mods:)' do
      before(:each) do
        @updater = "#{described_class::PK_PROVENANCE_PREFIX}bar"
        @updater_existing = 'http://33.11111/foo'
        @owner_existing = 'http://owner.com'
        @other_existing = 'http://33.22222/bar'

        @base = JSON.parse([
          { descriptor: 'cites', work_type: 'software', type: 'url',
            identifier: @owner_existing },
          { descriptor: 'cites', work_type: 'dataset', type: 'doi',
            identifier: @other_existing,
            dmphub_provenance_id: "#{described_class::PK_PROVENANCE_PREFIX}foo" },
          { descriptor: 'cites', work_type: 'dataset', type: 'doi',
            identifier: @updater_existing, dmphub_provenance_id: @updater }
        ].to_json)
        @mods = JSON.parse([
          { descriptor: 'cites', work_type: 'software', type: 'url',
            identifier: 'http://github.com/new' },
          { descriptor: 'cites', work_type: 'dataset', type: 'doi',
            identifier: 'http://33.22222/new' }
        ].to_json)
      end

      it 'returns :base if the :updater is nil' do
        result = described_class.send(:update_related_identifiers, updater: nil, base: @base,
                                                                   mods: @mods)
        expect(result).to eql(@base)
      end
      it 'returns :base if the :mods are empty' do
        result = described_class.send(:update_related_identifiers, updater: @updater,
                                                                   base: @base, mods: nil)
        expect(result).to eql(@base)
      end
      it 'returns :mods if the :base is nil' do
        result = described_class.send(:update_related_identifiers, updater: @updater,
                                                                   base: nil, mods: @mods)
        @mods.each { |mod| mod['dmphub_provenance_id'] = @updater }
        expect(result).to eql(@mods)
      end
      it 'removes existing entries for the updater' do
        result = described_class.send(:update_related_identifiers, updater: @updater,
                                                                   base: @base, mods: @mods)
        expect(result.select { |i| i['identifier'] == @updater_existing }.length).to eql(0)
      end
      it 'does NOT remove entries for other systems' do
        result = described_class.send(:update_related_identifiers, updater: @updater,
                                                                   base: @base, mods: @mods)
        expect(result.select { |i| i['identifier'] == @other_existing }.length).to eql(1)
      end
      it 'does NOT remove entries for the system of provenance' do
        result = described_class.send(:update_related_identifiers, updater: @updater,
                                                                   base: @base, mods: @mods)
        expect(result.select { |i| i['identifier'] == @owner_existing }.length).to eql(1)
      end
      it 'adds the updater\'s entries' do
        result = described_class.send(:update_related_identifiers, updater: @updater,
                                                                   base: @base, mods: @mods)
        updated = result.select { |i| i['dmphub_provenance_id'] == @updater }
        expect(updated.length).to eql(2)
      end
    end
  end

  def compare_fundings(expected:, received:)
    expected = [] unless expected.is_a?(Array)
    received = [] unless received.is_a?(Array)

    # Ignore the created_at dates
    expected.each { |funding| funding.delete('dmphub_created_at') }
    received.each { |funding| funding.delete('dmphub_created_at') }

    received.each do |item|
      original = expected.select { |f| f['name'] == item['name'] }.first
      msg = "did not expect the result to contain an entry for '#{item['name']}'"
      expect(original.nil?).to eql(false), msg
      expect(original).to eql(item)
    end
  end
end
