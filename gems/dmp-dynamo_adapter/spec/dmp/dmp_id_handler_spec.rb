# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
RSpec.describe Dmp::DmpIdHandler do
  describe 'dmp_id_base_url' do
    it 'returns the environment variable value as is if it ends with "/"' do
      ENV['DMP_ID_BASE_URL'] = 'https://foo.org/'
      expect(described_class.send(:dmp_id_base_url)).to eql('https://foo.org/')
    end
    it 'appends a "/" to the environment variable value if does not ends with it' do
      ENV['DMP_ID_BASE_URL'] = 'https://foo.org'
      expect(described_class.send(:dmp_id_base_url)).to eql('https://foo.org/')
    end
  end

  describe 'preregister_dmp_id' do
    before(:each) do
      ENV['DMP_ID_BASE_URL'] = 'https://foo.org'
      ENV['DMP_ID_SHOULDER'] = '11.22222'

      dmp_id_prefix = "#{ENV['DMP_ID_BASE_URL']}/#{ENV['DMP_ID_SHOULDER']}"
      @expected = "#{Dmp::MetadataHandler::PK_DMP_PREFIX}#{dmp_id_prefix}"
    end

    it 'returns a new unique DMP ID' do
      allow(described_class).to receive(:find_by_pk).and_return([])
      first = described_class.send(:preregister_dmp_id)
      second = described_class.send(:preregister_dmp_id)
      expect(first.start_with?(@expected)).to eql(true)
      expect(second.start_with?(@expected)).to eql(true)
      expect(first.gsub(@expected, '')).not_to eql(second.gsub(@expected, ''))
    end
    it 'has the expected length' do
      allow(described_class).to receive(:find_by_pk).and_return([])
      expect(described_class.send(:preregister_dmp_id).length).to eql("#{@expected}.#{SecureRandom.hex(4)}".length)
    end
    it 'returns a nil if a unique id could not determined after 10 attempts' do
      allow(described_class).to receive(:find_by_pk).and_return([]).at_least(10).times
      described_class.send(:preregister_dmp_id)
    end
  end

  describe 'format_dmp_id(value:)' do
    before(:each) do
      ENV['DMP_ID_BASE_URL'] = 'https://foo.org'
      @dmp_id_prefix = "#{ENV['DMP_ID_BASE_URL']}/99.88888/"
    end

    it 'returns nil if :value does not match the DOI_REGEX' do
      expect(described_class.send(:format_dmp_id, value: '00000')).to eql(nil)
    end
    it 'ignores "doi:" in the :value' do
      expected = "#{@dmp_id_prefix}777.66/555"
      expect(described_class.send(:format_dmp_id, value: 'doi:99.88888/777.66/555')).to eql(expected)
    end
    it 'ignores preceding "/" character in the :value' do
      expected = "#{@dmp_id_prefix}777.66/555"
      expect(described_class.send(:format_dmp_id, value: '/99.88888/777.66/555')).to eql(expected)
    end
    it 'does not replace a predefined domain name with the DMP_ID_BASE_URL if the value is a URL' do
      expected = "https://bar.org/99.88888/777.66/555"
      expect(described_class.send(:format_dmp_id, value: expected)).to eql(expected)
    end
    it 'handles variations of DOI format' do
      %w[zzzzzz zzz.zzz zzz/zzz zzz-zzz zzz_zzz].each do |id|
        expected = "#{@dmp_id_prefix}/#{id}"
        expect(described_class.format_dmp_id(value: expected)).to eql(expected)
      end
    end
  end

  describe 'dmp_id_to_pk(json:)' do
    before(:each) do
      ENV['DMP_ID_BASE_URL'] = 'https://foo.org'
    end

    it 'returns nil if :json is not a Hash' do
      expect(described_class.send(:dmp_id_to_pk, json: nil)).to eql(nil)
    end
    it 'returns nil if :json has no :identifier' do
      json = JSON.parse({ type: 'doi' }.to_json)
      expect(described_class.send(:dmp_id_to_pk, json: json)).to eql(nil)
    end
    it 'correctly formats a DOI' do
      expected = "DMP#https://foo.org/99.88888/77776666.555"

      json = JSON.parse({ type: 'other', identifier: '99.88888/77776666.555' }.to_json)
      expect(described_class.send(:dmp_id_to_pk, json: json)).to eql(expected)
      json = JSON.parse({ type: 'doi', identifier: 'doi:99.88888/77776666.555' }.to_json)
      expect(described_class.send(:dmp_id_to_pk, json: json)).to eql(expected)
      json = JSON.parse({ type: 'url', identifier: expected }.to_json)
      expect(described_class.send(:dmp_id_to_pk, json: json)).to eql(expected)
    end
    it 'returns nil if the dmp_id was NOT a valid DOI' do
      json = JSON.parse({ type: 'doi', identifier: '99999' }.to_json)
      expect(described_class.send(:dmp_id_to_pk, json: json)).to eql(nil)
    end
  end

  describe 'pk_to_dmp_id(p_key:)' do
    it 'removes the PK prefix if applicable' do
      expected = { type: 'doi', identifier: 'zzzzzzzz' }
      expect(described_class.pk_to_dmp_id(p_key: 'DMP#zzzzzzzz')).to eql(expected)
      dmp_id = 'https://foo.org/99.88888/777666.555/444'
      expected = { type: 'doi', identifier: dmp_id }
      expect(described_class.pk_to_dmp_id(p_key: "DMP##{dmp_id}")).to eql(expected)
      expected = { type: 'doi', identifier: 'yyyyyy' }
      expect(described_class.pk_to_dmp_id(p_key: 'yyyyyy')).to eql(expected)
    end
  end
end
