# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
RSpec.describe Dmp::DynamoAdapter do
  before(:each) do
    @provenance = 'foo'

    @dmp = JSON.parse(File.read("#{Dir.pwd}/spec/support/json_mocks/complete.json"))['dmp']
    @dmp_id = @dmp['dmp_id']['identifier']

    ENV['AWS_REGION'] = 'us-west-2'
    ENV['AWS_DYNAMO_TABLE_NAME'] = 'foo-table'

    @mock_client = MockDynamodbClient.new
    allow(Aws::DynamoDB::Client).to receive(:new).and_return(@mock_client)

    context = Seahorse::Client::RequestContext.new
    @dynamo_error = Aws::DynamoDB::Errors::InternalServerError.new(context, 'Failed')

    @adapter = Dmp::DynamoAdapter.new(provenance: @provenance)
  end

  it 'has a version number' do
    expect(Dmp::DynamoAdapter::VERSION).not_to be nil
  end

  describe 'initialize(provenance:, debug:)' do
    it 'sets the @provenance, @client and @debug_mode variables' do
      expect(@adapter.send(:provenance)).to eql("PROVENANCE##{@provenance}")
      expect(@adapter.send(:debug_mode)).to eql(false)
      expect(@adapter.send(:client)).to eql(@mock_client)
    end
  end

  describe 'dmps_for_provenance' do
    xit 'Implement some tests!' do
      'TODO: implement this!'
    end
  end

  describe 'find_by_pk(p_key:, s_key:)' do
    xit 'Implement some tests!' do
      'TODO: implement this!'
    end
  end

  describe 'find_by_json(json:)' do
    xit 'Implement some tests!' do
      'TODO: implement this!'
    end
  end

  describe 'create(json: {})' do
    xit 'Implement some tests!' do
      'TODO: implement this!'
    end
  end

  describe 'update(p_key:, json: {})' do
    xit 'Implement some tests!' do
      'TODO: implement this!'
    end
  end

  describe 'delete(p_key:, json: {})' do
    xit 'Implement some tests!' do
      'TODO: implement this!'
    end
  end

  describe 'private methods' do
    it 'does not allow direct access to private accessors' do
      expect{ @adapter.provenance }.to raise_error(NoMethodError)
      expect{ @adapter.debug_mode }.to raise_error(NoMethodError)
      expect{ @adapter.client }.to raise_error(NoMethodError)
    end

    describe 'dmp_id_base_url' do
      it 'returns the environment variable value as is if it ends with "/"' do
        ENV['DMP_ID_BASE_URL'] = 'https://foo.org/'
        expect(@adapter.send(:dmp_id_base_url)).to eql('https://foo.org/')
      end
      it 'appends a "/" to the environment variable value if does not ends with it' do
        ENV['DMP_ID_BASE_URL'] = 'https://foo.org'
        expect(@adapter.send(:dmp_id_base_url)).to eql('https://foo.org/')
      end
    end

    describe 'preregister_dmp_id' do
      before(:each) do
        ENV['DMP_ID_BASE_URL'] = 'https://foo.org'
        ENV['DMP_ID_SHOULDER'] = '11.22222'

        @expected = "#{ENV['DMP_ID_BASE_URL']}/#{ENV['DMP_ID_SHOULDER']}"
      end

      it 'returns a new unique DMP ID' do
        allow(@adapter).to receive(:find_by_pk).and_return([])
        expect(@adapter.send(:preregister_dmp_id).start_with?(@expected)).to eql(true)
      end
      it 'has the expected length' do
        allow(@adapter).to receive(:find_by_pk).and_return([])
        expect(@adapter.send(:preregister_dmp_id).length).to eql("#{@expected}.#{SecureRandom.hex(4)}".length)
      end
      it 'does not duplicate DMP IDs' do
        allow(@adapter).to receive(:find_by_pk).and_return([@dmp], [])
        expect(@adapter).to receive(:find_by_pk).twice
        expect(@adapter.send(:preregister_dmp_id).length).to eql("#{@expected}.#{SecureRandom.hex(4)}".length)
      end
    end

    describe 'format_doi(value:)' do
      before(:each) do
        ENV['DMP_ID_BASE_URL'] = 'https://foo.org'
      end

      it 'returns nil if :value does not match the DOI_REGEX' do
        expect(@adapter.send(:format_doi, value: '00000')).to eql(nil)
      end
      it 'ignores "doi:" in the :value' do
        expected = "#{ENV['DMP_ID_BASE_URL']}/99.88888/777.66/555"
        expect(@adapter.send(:format_doi, value: 'doi:99.88888/777.66/555')).to eql(expected)
      end
      it 'ignores preceding "/" character in the :value' do
        expected = "#{ENV['DMP_ID_BASE_URL']}/99.88888/777.66/555"
        expect(@adapter.send(:format_doi, value: '/99.88888/777.66/555')).to eql(expected)
      end
      it 'replaces a predefined domain name with the DMP_ID_BASE_URL if the value is a URL' do
        expected = "https://bar.org/99.88888/777.66/555"
        expect(@adapter.send(:format_doi, value: expected)).to eql("#{ENV['DMP_ID_BASE_URL']}/99.88888/777.66/555")
      end
    end

    describe 'pk_from_dmp_id(json:)' do
      before(:each) do
        ENV['DMP_ID_BASE_URL'] = 'https://foo.org'
      end

      it 'returns nil if :json is not a Hash' do
        expect(@adapter.send(:pk_from_dmp_id, json: nil)).to eql(nil)
      end
      it 'returns nil if :json has no :identifier' do
        json = { type: 'doi' }
        expect(@adapter.send(:pk_from_dmp_id, json: json)).to eql(nil)
      end
      it 'correctly formats a DOI' do
        expected = "DMP#doi:https://foo.org/99.88888/77776666.555"

        json = { type: 'url', identifier: '99.88888/77776666.555' }
        expect(@adapter.send(:pk_from_dmp_id, json: json)).to eql(expected)
        json = { type: 'url', identifier: 'doi:99.88888/77776666.555' }
        expect(@adapter.send(:pk_from_dmp_id, json: json)).to eql(expected)
        json = { type: 'url', identifier: 'http://doi.org/99.88888/77776666.555' }
        expect(@adapter.send(:pk_from_dmp_id, json: json)).to eql(expected)
      end
      it 'correctly formats HTTP' do
        json = { type: 'url', identifier: 'http://example.org/dmps/77777' }
        expected = "DMP#uri:#{json[:identifier]}"
        expect(@adapter.send(:pk_from_dmp_id, json: json)).to eql(expected)
      end
      it 'correctly formats HTTPS' do
        json = { type: 'url', identifier: 'https://example.org/dmps/77777' }
        expected = "DMP#uri:#{json[:identifier]}"
        expect(@adapter.send(:pk_from_dmp_id, json: json)).to eql(expected)
      end
      it 'defaults to :other' do
        json = { type: 'other', identifier: '99999' }
        expected = "DMP#other:#{json[:identifier]}"
        expect(@adapter.send(:pk_from_dmp_id, json: json)).to eql(expected)
      end
    end

    describe 'annotate_json(json:, p_key:)' do
      describe 'for a new DMP' do
        before(:each) do
          @json = {
            dmp_id: { type: 'url', identifier: 'https://foo.org/dmps/999999' },
            title: 'Just testing',
            created: '2022-06-01T09:26:01Z',
            modified: '2022-06-03T08:15:24Z'
          }
          @pk = "DMP##{@dmp_id}"
          @result = @adapter.send(:annotate_json, json: @json, p_key: @pk)
        end

        it 'derives the :PK from the result of :pk_from_dmp_id' do
          expect(@result[:PK]).to eql(@pk)
        end
        it 'sets the :SK to the latest version' do
          expect(@result[:SK]).to eql('VERSION#latest')
        end
        it 'sets the :dmphub_provenance_identifier to the :dmp_id' do
          expect(@result[:dmphub_provenance_identifier]).to eql(@json[:dmp_id][:identifier])
        end
        it 'sets the :dmp_id to the value of the :PK' do
          expect(@result[:dmp_id]).to eql({ type: 'doi', identifier: @pk.gsub('DMP#', '') })
        end
        it 'sets the :dmphub_provenance_id to the current provenance' do
          expect(@result[:dmphub_provenance_id]).to eql("PROVENANCE##{@provenance}")
        end
        it 'sets the :dmphub_modification_day to the current date' do
          expect(@result[:dmphub_modification_day]).to eql(Time.now.strftime('%Y-%M-%d'))
        end
        it 'sets the :dmphub_created_at and :dmphub_updated_at to the current time' do
          expected = Time.now.iso8601
          expect(@result[:dmphub_created_at]).to be >= expected
          expect(@result[:dmphub_updated_at]).to be >= expected
        end
      end

      describe 'for an existing DMP' do
        before(:each) do
          @json = {
            PK: "DMP##{@dmp_id}",
            SK: 'VERSION#latest',
            dmp_id: { type: 'doi', identifier: @dmp_id },
            title: 'Just testing',
            created: '2022-06-01T09:26:01Z',
            modified: '2022-06-03T08:15:24Z',
            dmphub_provenance_id: "PROVENANCE##{@provenance}",
            dmphub_modification_day: '2022-05-15',
            dmphub_created_at: '2022-05-01T10:00:00Z',
            dmphub_updated_at: '2022-05-15T10:16:34Z'
          }
          @pk = "DMP##{@dmp_id}"
          @result = @adapter.send(:annotate_json, json: @json, p_key: @pk)
        end
        it 'derives the :PK from the result of :pk_from_dmp_id' do
          expect(@result[:PK]).to eql(@pk)
        end
        it 'sets the :SK to the latest version' do
          expect(@result[:SK]).to eql('VERSION#latest')
        end
        it 'does not set the :dmphub_provenance_identifier' do
          expect(@result[:dmphub_provenance_identifier]).to eql(nil)
        end
        it 'sets the :dmp_id to the value of the :PK' do
          expect(@result[:dmp_id]).to eql({ type: 'doi', identifier: @pk.gsub('DMP#', '') })
        end
        it 'does not change the :dmphub_provenance_id' do
          expect(@result[:dmphub_provenance_id]).to eql(@json[:dmphub_provenance_id])
        end
        it 'does not change the :dmphub_created_at' do
          expect(@result[:dmphub_created_at]).to eql(@json[:dmphub_created_at])
        end
        it 'sets the :dmphub_modification_day to the current date' do
          expect(@result[:dmphub_modification_day]).to eql(Time.now.strftime('%Y-%M-%d'))
        end
        it 'sets the :dmphub_created_at and :dmphub_updated_at to the current time' do
          expected = Time.now.iso8601
          expect(@result[:dmphub_updated_at]).to be >= expected
        end
      end
    end

    describe 'find_by_dmphub_provenance_identifier(json:)' do
      it 'returns an empty array if :json is nil' do
        result = @adapter.send(:find_by_dmphub_provenance_identifier, json: nil)
        expect(result).to eql([])
      end
      it 'returns an empty array if :json contains no :dmp_id' do
        dmp = { title: 'Just testing' }
        result = @adapter.send(:find_by_dmphub_provenance_identifier, json: dmp)
        expect(result).to eql([])
      end
      it 'returns an empty array if the DynamoDB query fails' do
        dmp = { title: 'Just testing', dmp_id: { type: 'doi', identifier: @dmp_id } }
        allow(@mock_client).to receive(:query).and_raise(@dynamo_error)
        result = @adapter.send(:find_by_dmphub_provenance_identifier, json: dmp)
        expect(result).to eql([])
      end
      it 'returns an empty array if the query had no matches' do
        dmp = { title: 'Just testing', dmp_id: { type: 'doi', identifier: @dmp_id } }
        allow(@mock_client).to receive(:query).and_return(nil)
        result = @adapter.send(:find_by_dmphub_provenance_identifier, json: dmp)
        expect(result).to eql([])
      end
      it 'returns an empty array if the query returned a nil result' do
        dmp = { title: 'Just testing', dmp_id: { type: 'doi', identifier: @dmp_id } }
        allow(@adapter).to receive(:find_by_pk).and_return({ status: 404, items: [] })
        result = @adapter.send(:find_by_dmphub_provenance_identifier, json: dmp)
        expect(result).to eql([])
      end
      it 'returns the expected DMP' do
        dmp = { title: 'Just testing', dmp_id: { type: 'doi', identifier: @dmp_id } }
        allow(@adapter).to receive(:find_by_pk).and_return({ status: 200, items: [@dmp] })
        result = @adapter.send(:find_by_dmphub_provenance_identifier, json: dmp)
        expect(result).to eql([@dmp])
      end
    end

    describe 'version_it(dmp:)' do
      it 'returns false if :dmp is nil' do
        expect(@adapter.send(:version_it, dmp: nil)).to eql(false)
      end
      it 'returns false if :PK is nil' do
        dmp = { SK: 'VERSION#latest' }
        expect(@adapter.send(:version_it, dmp: dmp)).to eql(false)
      end
      it 'returns false if :PK is NOT for a DMP' do
        dmp = { PK: 'PROVENANCE:foo', SK: 'PROFILE' }
        expect(@adapter.send(:version_it, dmp: dmp)).to eql(false)
      end
      it 'returns false if :SK is NOT the latest version' do
        dmp = { PK: "DMP##{@dmp_id}", SK: 'VERSION#2022-06-06T13:23:01Z' }
        expect(@adapter.send(:version_it, dmp: dmp)).to eql(false)
      end
      it 'returns false if the DynamoDB update fails' do
        dmp = { PK: "DMP##{@dmp_id}", SK: 'VERSION#latest', title: 'Just testing' }
        allow(@mock_client).to receive(:update_item).and_raise(@dynamo_error)
        expect(@adapter.send(:version_it, dmp: dmp)).to eql(false)
      end
      it 'versions the :dmp and returns true' do
        dmp = { PK: "DMP##{@dmp_id}", SK: 'VERSION#latest', dmphub_updated_at: '2022-06-06T13:30:23Z' }
        expect(@adapter.send(:version_it, dmp: dmp)).to eql(true)
        # Check to make sure the Client received the correct info
        expect(@mock_client.hash[:key][:PK]).to eql(dmp[:PK])
        expect(@mock_client.hash[:key][:SK]).to eql(dmp[:SK])
        expect(@mock_client.hash[:expression_attribute_values][:sk]).to eql("VERSION##{dmp[:dmphub_updated_at]}")
      end
    end

    describe 'prepare_json(json:)' do
      it 'returns nil if :json is not provided' do
        expect(@adapter.send(:prepare_json, json: nil)).to eql(nil)
      end
      it 'parses the JSON if it is a String' do
        expected = JSON.parse({ foo: 'bar' }.to_json)
        expect(@adapter.send(:prepare_json, json: '{"foo":"bar"}')).to eql(expected)
      end
      it 'returns nil if :json is not parseable JSON' do
        expect(@adapter.send(:prepare_json, json: '/{foo:"4%Y"$%\/')).to eql(nil)
      end
      it 'returns nil if :json is not a Hash or a String' do
        expect(@adapter.send(:prepare_json, json: 1.34)).to eql(nil)
      end
      it 'returns the :json as is if it ia a Hash' do
        expected = { foo: 'bar' }
        expect(@adapter.send(:prepare_json, json: expected)).to eql(expected)
      end
    end
  end
end
# rubocop:enable Metrics/BlockLength
