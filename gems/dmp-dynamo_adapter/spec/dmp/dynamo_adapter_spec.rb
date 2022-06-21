# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
RSpec.describe Dmp::DynamoAdapter do
  before(:each) do
    @provenance = 'abcdefghijk'

    @dmp = JSON.parse(File.read("#{Dir.pwd}/spec/support/json_mocks/complete.json"))['dmp']
    @dmp_id = @dmp['dmp_id']['identifier']

    ENV['AWS_REGION'] = 'us-west-2'
    ENV['AWS_DYNAMO_TABLE_NAME'] = 'foo-table'
    ENV['DMP_ID_BASE_URL'] = 'https://foo.org'
    ENV['DMP_ID_SHOULDER'] = '11.22222'

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
    it 'returns a 404 error if the :provenance was not set during initialization' do
      @adapter.send(:provenance=, nil)
      result = @adapter.dmps_for_provenance
      expect(result[:status]).to eql(404)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NOT_FOUND)
    end
    it 'returns a an empty array if the provenance has no DMPs' do
      @mock_client.state = :empty
      result = @adapter.dmps_for_provenance
      expect(result[:status]).to eql(200)
      expect(result[:items]).to eql([])
    end
    it 'returns a an array of the provenance\'s DMPs' do
      @mock_client.state = :latest
      result = @adapter.dmps_for_provenance
      expect(result[:status]).to eql(200)
      expect(result[:items].is_a?(Array)).to eql(true)
      expect(result[:items].length).to eql(1)
    end
    it 'returns a 500 error if Dynamo throws an error' do
      @mock_client.state = nil
      result = @adapter.dmps_for_provenance
      expect(result[:status]).to eql(500)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
  end

  describe 'find_by_pk(p_key:, s_key:)' do
    before(:each) do
      @pk = "DMP##{@dmp_id}"
    end

    it 'returns a 404 error if the :p_key is nil' do
      result = @adapter.find_by_pk(p_key: nil)
      expect(result[:status]).to eql(404)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NOT_FOUND)
    end
    it 'returns a 404 error if the :p_key had no match in the database' do
      @mock_client.state = :empty
      result = @adapter.find_by_pk(p_key: @pk)
      expect(result[:status]).to eql(404)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NOT_FOUND)
    end
    it 'returns the latest version of the DMP by default' do
      @mock_client.state = :latest
      result = @adapter.find_by_pk(p_key: @pk)
      expect(result[:status]).to eql(200)
      expect(result[:items].length).to eql(1)
      expect(result[:items].first).to eql(@dmp)
      expect(result[:items].first['SK']).to eql('VERSION#latest')
    end
    it 'returns a the version specified in :s_key' do
      allow(@adapter).to receive(:prepare_json).and_return(nil)
      @mock_client.state = :version
      result = @adapter.find_by_pk(p_key: @pk)
      expect(result[:status]).to eql(200)
      expect(result[:items].length).to eql(1)
      expect(result[:items].first['SK']).not_to eql('VERSION#latest')
    end
    it 'returns a 500 error if Dynamo throws an error' do
      allow(@adapter).to receive(:prepare_json).and_return(nil)
      @mock_client.state = nil
      result = @adapter.find_by_pk(p_key: @pk)
      expect(result[:status]).to eql(500)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
  end

  describe 'find_by_json(json:)' do
    before(:each) do
      @successful_response = { status: 200, items: [@dmp] }
    end

    it 'returns a 404 error if :json is nil' do
      result = @adapter.find_by_json(json: nil)
      expect(result[:status]).to eql(404)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NOT_FOUND)
    end
    it 'returns a 404 error if the :json does not contain a :PK or :dmp_id' do
      @dmp.delete('PK')
      @dmp.delete('dmp_id')
      result = @adapter.find_by_json(json: @dmp)
      expect(result[:status]).to eql(404)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NOT_FOUND)
    end
    it 'it returns the DMP by its :PK' do
      allow(@adapter).to receive(:find_by_pk).and_return(@successful_response)
      result = @adapter.find_by_json(json: @dmp)
      expect(result[:status]).to eql(200)
      expect(result[:items].length).to eql(1)
      expect(result[:items].first).to eql(@dmp)
      expect(result[:items].first['SK']).to eql('VERSION#latest')
    end
    it 'it returns the DMP by its :dmphub_provenance_identifier' do
      allow(@adapter).to receive(:find_by_pk).and_return({ status: 200, items: [] })
      allow(@adapter).to receive(:find_by_dmphub_provenance_identifier).and_return(@successful_response)
      result = @adapter.find_by_json(json: @dmp)
      expect(result[:status]).to eql(200)
      expect(result[:items].length).to eql(1)
      expect(result[:items].first).to eql(@dmp)
      expect(result[:items].first['SK']).to eql('VERSION#latest')
    end
    it 'returns a 404 error if the DMP could not be found' do
      fail_response = { status: 404, error: Dmp::DynamoAdapter::MSG_NOT_FOUND }
      allow(@adapter).to receive(:find_by_pk).and_return(fail_response)
      allow(@adapter).to receive(:find_by_dmphub_provenance_identifier).and_return(fail_response)
      result = @adapter.find_by_json(json: @dmp)
      expect(result[:status]).to eql(404)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NOT_FOUND)
    end
    it 'returns a 500 error if :find_by_pk returns a 500' do
      @mock_client.state = nil
      result = @adapter.find_by_json(json: @dmp)
      expect(result[:status]).to eql(500)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
    it 'returns a 500 error if :find_by_dmphub_provenance_identifier returns a 500' do
      fail_response = { status: 200, items: [] }
      allow(@adapter).to receive(:find_by_pk).and_return(fail_response)
      @mock_client.state = nil
      result = @adapter.find_by_json(json: @dmp)
      expect(result[:status]).to eql(500)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
    it 'returns a 500 error if Dynamo throws an error' do
      @mock_client.state = nil
      result = @adapter.find_by_json(json: @dmp)
      expect(result[:status]).to eql(500)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
  end

  describe 'create(json: {})' do
    it 'returns a 400 error if the json could not be parsed' do
      allow(@adapter).to receive(:prepare_json).and_return(nil)
      result = @adapter.create(json: nil)
      expect(result[:status]).to eql(400)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
    it 'returns a 500 error if :find_by_json returns a 500' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      allow(@adapter).to receive(:find_by_json).and_return({ status: 500 })
      result = @adapter.create(json: @dmp)
      expect(result[:status]).to eql(500)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
    it 'returns a 400 error if :find_by_json returns an existing DMP' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      allow(@adapter).to receive(:find_by_json).and_return({ status: 200, items: @mock_client.get_item(@dmp).items })
      result = @adapter.create(json: @dmp)
      expect(result[:status]).to eql(400)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_EXISTS)
    end
    it 'returns a 500 error if a DMP ID could not be registered' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      allow(@adapter).to receive(:find_by_json).and_return({ status: 200, items: [] })
      allow(@adapter).to receive(:preregister_dmp_id).and_return(nil)
      result = @adapter.create(json: @dmp)
      expect(result[:status]).to eql(500)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NO_DMP_ID)
    end
    it 'returns a the new DMP' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      pk = 'DMP#http://doi.org/55.44444/zyxwvut'
      timestamp = Time.now
      # Clear out any existing DMPHub metadata
      @dmp.delete('PK')
      @dmp.delete('SK')
      @dmp.keys.select { |key| key.start_with?('dmphub_') }.each { |key| @dmp.delete(key) }

      allow(@adapter).to receive(:find_by_json).and_return({ status: 200, items: [] })
      allow(@adapter).to receive(:preregister_dmp_id).and_return(pk)
      result = @adapter.create(json: @dmp)
      expect(result[:status]).to eql(201)
      expect(result[:items].length).to eql(1)
      expect(result[:items].first['PK']).to eql(pk)
      expect(result[:items].first['SK']).to eql('VERSION#latest')
      expect(result[:items].first['dmphub_provenance_id']).to eql("PROVENANCE##{@provenance}")
      expect(result[:items].first['dmphub_provenance_identifier']).to eql(@dmp['dmp_id'])
      expect(result[:items].first['dmphub_created_at']).to be >= timestamp.iso8601
      expect(result[:items].first['dmphub_updated_at']).to be >= timestamp.iso8601
      expect(result[:items].first['dmphub_deleted_at']).to eql(nil)
      expect(result[:items].first['dmphub_modification_day']).to be >= timestamp.strftime('%Y-%M-%d')
    end
    it 'returns a 500 error if :find_by_json returns a 500' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      allow(@adapter).to receive(:find_by_json).and_return({ status: 200, items: [] })
      allow(@adapter).to receive(:preregister_dmp_id).and_return('DMP#gggggggg')
      @mock_client.state = nil
      result = @adapter.create(json: @dmp)
      expect(result[:status]).to eql(500)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
    it 'returns a 500 error if :find_by_json returns a 500' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      allow(@adapter).to receive(:find_by_json).and_return({ status: 200, items: [] })
      allow(@adapter).to receive(:preregister_dmp_id).and_return('DMP#gggggggg')
      allow(@mock_client).to receive(:put_item).and_raise(Aws::DynamoDB::Errors::DuplicateItemException.new(nil, nil, 'foo'))
      @mock_client.state = nil
      result = @adapter.create(json: @dmp)
      expect(result[:status]).to eql(405)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_EXISTS)
    end
  end

  describe 'update(p_key:, json: {})' do
    before(:each) do
      @pk = "DMP##{@dmp_id}"
    end

    it 'returns a 400 error if the json could not be parsed' do
      allow(@adapter).to receive(:prepare_json).and_return(nil)
      result = @adapter.update(p_key: @pk, json: nil)
      expect(result[:status]).to eql(400)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
    it 'returns a 403 error if the :p_key does not match the :dmp_id' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      result = @adapter.update(p_key: 'DMP#zz', json: @dmp)
      expect(result[:status]).to eql(403)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_FORBIDDEN)
    end
    it 'returns a 404 error if the DMP could not be found' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      allow(@adapter).to receive(:find_by_json).and_return({ status: 404, items: [] })
      result = @adapter.update(p_key: @pk, json: @dmp)
      expect(result[:status]).to eql(404)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NOT_FOUND)
    end
    it 'returns a 405 error if the DMP is not the latest version' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      @mock_client.state = :version
      allow(@adapter).to receive(:find_by_json).and_return({ status: 200, items: @mock_client.get_item(@dmp).items })
      result = @adapter.update(p_key: @pk, json: @dmp)
      expect(result[:status]).to eql(405)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NO_HISTORICALS)
    end
    it 'versions the latest version of the DMP' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      @mock_client.state = :latest
      allow(@adapter).to receive(:find_by_json).and_return({ status: 200, items: @mock_client.get_item(@dmp).items })
      expect(@adapter).to receive(:version_it).and_return({ status: 200 })
      @adapter.update(p_key: @pk, json: @dmp)
    end
    it 'updates the DMP when provenance matches the provenance of the DMP' do
      dmp = JSON.parse({
        dmp_id: @dmp['dmp_id'],
        title: 'bar',
        project: [
          funding: [
            {
              name: 'Foo Funding'
            }
          ]
        ],
        dmproadmap_related_identifiers: [
          { descriptor: 'cites', work_type: 'dataset', type: 'url', identifier: 'http://example.org' }
        ]
      }.to_json)
      allow(@adapter).to receive(:prepare_json).and_return(dmp)
      @mock_client.state = :latest
      allow(@adapter).to receive(:find_by_json).and_return({ status: 200, items: @mock_client.get_item(@dmp).items })
      expect(@adapter).to receive(:version_it).and_return({ status: 200, items: @mock_client.get_item(@dmp).items })
      result = @adapter.update(p_key: @pk, json: dmp)
      expect(result[:status]).to eql(200)
      expect(result[:items].length).to eql(1)
      expect(result[:items].first['PK']).to eql(@dmp['PK'])
      expect(result[:items].first['SK']).to eql(@dmp['SK'])
      expect(result[:items].first['dmphub_provenance_id']).to eql(@dmp['dmphub_provenance_id'])
      expect(result[:items].first['dmphub_provenance_identifier']).to eql(@dmp['dmphub_provenance_identifier'])
      expect(result[:items].first['dmphub_created_at']).to eql(@dmp['dmphub_created_at'])
      expect(result[:items].first['dmphub_deleted_at']).to eql(nil)
      expect(result[:items].first['dmphub_updated_at']).to be > @dmp['dmphub_updated_at']
      expect(result[:items].first['dmphub_modification_day']).to be > @dmp['dmphub_modification_day']
      expect(result[:items].first['title']).to eql(dmp['title'])
      expect(result[:items].first['description']).to eql(nil)

      other_funding = @dmp['project'].first['funding'].reject { |funding| funding['dmphub_provenance_id'].nil? }
      other_relateds = @dmp['dmproadmap_related_identifiers'].reject { |related| related['dmphub_provenance_id'].nil? }
      expected = dmp['project'].first['funding'].first['name']
      expect(result[:items].first['project'].first['funding'].include?(expected)).to eql(true)
      expect(result[:items].first['project'].first['funding'].include?(other_funding)).to eql(true)
      expected = dmp['dmproadmap_related_identifiers']
      expect(result[:items].first['dmproadmap_related_identifiers'].include?(expected)).to eql(true)
      expect(result[:items].first['dmproadmap_related_identifiers'].include?(other_relateds)).to eql(true)
    end
    it 'only updates the funding and related identifers when the provenance does not match' do

    end
    it 'returns a 500 error if :find_by_json returns a 500' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      @mock_client.state = nil
      result = @adapter.update(p_key: @pk, json: @dmp)
      expect(result[:status]).to eql(500)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
    it 'returns a 500 error if :version_it returns a 500' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      allow(@adapter).to receive(:find_by_json).and_return({ status: 200, items: @mock_client.get_item(@dmp).items })
      @mock_client.state = nil
      result = @adapter.update(p_key: @pk, json: @dmp)
      expect(result[:status]).to eql(500)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
    it 'returns a 500 error if Dynamo throws an error' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      allow(@adapter).to receive(:find_by_json).and_return({ status: 200, items: @mock_client.get_item(@dmp).items })
      allow(@adapter).to receive(:version_it).and_return({ status: 200, items: @mock_client.get_item(@dmp).items })
      @mock_client.state = nil
      result = @adapter.update(p_key: @pk, json: @dmp)
      expect(result[:status]).to eql(500)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
  end

  describe 'delete(p_key:, json: {})' do
    before(:each) do
      @pk = "DMP##{@dmp_id}"
    end

    it 'returns a 400 error if the json could not be parsed' do
      allow(@adapter).to receive(:prepare_json).and_return(nil)
      result = @adapter.delete(p_key: @pk, json: nil)
      expect(result[:status]).to eql(400)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
    it 'returns a 403 error if the :p_key does not match the :dmp_id' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      result = @adapter.delete(p_key: 'DMP#zzzzzzz', json: @dmp)
      expect(result[:status]).to eql(403)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_FORBIDDEN)
    end
    it 'returns a 403 error if the :provenance doe not match the DMP\'s :dmphub_provenance_id' do
      allow(@adapter).to receive(:provenance).and_return('zzzzzzzz')
      result = @adapter.delete(p_key: 'DMP#zzzzzzz', json: @dmp)
      expect(result[:status]).to eql(403)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_FORBIDDEN)
    end
    it 'returns a 404 error if the DMP could not be found' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      allow(@adapter).to receive(:find_by_json).and_return({ status: 404, items: [] })
      result = @adapter.delete(p_key: @pk, json: @dmp)
      expect(result[:status]).to eql(404)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NOT_FOUND)
    end
    it 'returns a 405 error if the DMP is not the latest version' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      @mock_client.state = :version
      allow(@adapter).to receive(:find_by_json).and_return({ status: 200, items: @mock_client.get_item(@dmp).items })
      result = @adapter.delete(p_key: @pk, json: @dmp)
      expect(result[:status]).to eql(405)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NO_HISTORICALS)
    end
    it 'tombstones the DMP' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      @mock_client.state = :latest
      timestamp = Time.now.iso8601
      allow(@adapter).to receive(:find_by_json).and_return({ status: 200, items: @mock_client.get_item(@dmp).items })
      result = @adapter.delete(p_key: @pk, json: @dmp)
      expect(result[:status]).to eql(200)
      expect(result[:items].length).to eql(1)
      expect(result[:items].first['PK']).to eql(@dmp['PK'])
      expect(result[:items].first['SK']).to eql('VERSION#tombstone')
      expect(result[:items].first['dmphub_deleted_at']).to be >= timestamp
    end
    it 'returns a 500 error if :find_by_json returns a 500' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      @mock_client.state = nil
      result = @adapter.delete(p_key: @pk, json: @dmp)
      expect(result[:status]).to eql(500)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
    it 'returns a 500 error if Dynamo throws an error' do
      allow(@adapter).to receive(:prepare_json).and_return(@dmp)
      allow(@adapter).to receive(:find_by_json).and_return({ status: 200, items: @mock_client.get_item(@dmp).items })
      @mock_client.state = nil
      result = @adapter.delete(p_key: @pk, json: @dmp)
      expect(result[:status]).to eql(500)
      expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
    end
  end

  describe 'private methods' do
    it 'does not allow direct access to private accessors' do
      expect{ @adapter.provenance }.to raise_error(NoMethodError)
      expect{ @adapter.debug_mode }.to raise_error(NoMethodError)
      expect{ @adapter.client }.to raise_error(NoMethodError)
    end

    describe 'find_by_dmphub_provenance_identifier(json:)' do
      it 'returns a 400 if :json is nil' do
        result = @adapter.send(:find_by_dmphub_provenance_identifier, json: nil)
        expect(result[:status]).to eql(400)
        expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
      end
      it 'returns a 400 if :json contains no :dmp_id' do
        dmp = JSON.parse({ title: 'Just testing' }.to_json)
        result = @adapter.send(:find_by_dmphub_provenance_identifier, json: dmp)
        expect(result[:status]).to eql(400)
        expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
      end
      it 'returns a 500 if the DynamoDB query fails' do
        dmp = JSON.parse({ title: 'Just testing', dmp_id: { type: 'doi', identifier: @dmp_id } }.to_json)
        @mock_client.state = nil
        result = @adapter.send(:find_by_dmphub_provenance_identifier, json: dmp)
        expect(result[:status]).to eql(500)
        expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
      end
      it 'returns a 404 if the query had no matches' do
        dmp = JSON.parse({ title: 'Just testing', dmp_id: { type: 'doi', identifier: @dmp_id } }.to_json)
        allow(@mock_client).to receive(:query).and_return(nil)
        result = @adapter.send(:find_by_dmphub_provenance_identifier, json: dmp)
        expect(result[:status]).to eql(404)
        expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NOT_FOUND)
      end
      it 'returns a 404 if the query returned a nil result' do
        dmp = JSON.parse({ title: 'Just testing', dmp_id: { type: 'doi', identifier: @dmp_id } }.to_json)
        allow(@adapter).to receive(:find_by_pk).and_return({ status: 404, items: [] })
        @mock_client.state = :empty
        result = @adapter.send(:find_by_dmphub_provenance_identifier, json: dmp)
        expect(result[:status]).to eql(404)
        expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NOT_FOUND)
      end
      it 'returns the expected DMP' do
        dmp = JSON.parse({ title: 'Just testing', dmp_id: { type: 'doi', identifier: @dmp_id } }.to_json)
        allow(@adapter).to receive(:find_by_pk).and_return({ status: 200, items: [@dmp] })
        result = @adapter.send(:find_by_dmphub_provenance_identifier, json: dmp)
        expect(result[:status]).to eql(200)
        expect(result[:items].length).to eql(1)
        expect(result[:items].first).to eql(@dmp)
      end
    end

    describe 'version_it(dmp:)' do
      it 'returns 400 if :dmp is nil' do
        result = @adapter.send(:version_it, dmp: nil)
        expect(result[:status]).to eql(400)
        expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
      end
      it 'returns 400 if :PK is nil' do
        dmp = JSON.parse({ SK: 'VERSION#latest' }.to_json)
        result = @adapter.send(:version_it, dmp: dmp)
        expect(result[:status]).to eql(400)
        expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
      end
      it 'returns 400 if :PK is NOT for a DMP' do
        dmp = JSON.parse({ PK: 'PROVENANCE:foo', SK: 'PROFILE' }.to_json)
        result = @adapter.send(:version_it, dmp: dmp)
        expect(result[:status]).to eql(400)
        expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
      end
      it 'returns 403 if :SK is NOT the latest version' do
        dmp = JSON.parse({ PK: "DMP##{@dmp_id}", SK: 'VERSION#2022-03-01T12:32:15Z', title: 'Just testing' }.to_json)
        @mock_client.hash = dmp
        result = @adapter.send(:version_it, dmp: dmp)
        expect(result[:status]).to eql(403)
        expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_NO_HISTORICALS)
      end
      it 'returns false if the DynamoDB update fails' do
        @mock_client.state = nil
        @mock_client.hash = @dmp
        result = @adapter.send(:version_it, dmp: @dmp)
        expect(result[:status]).to eql(500)
        expect(result[:error]).to eql(Dmp::DynamoAdapter::MSG_DEFAULT)
      end
      it 'versions the :dmp and returns true' do
        @mock_client.hash = @dmp
        result = @adapter.send(:version_it, dmp: @dmp)
        expect(result[:status]).to eql(200)
        expect(result[:items].length).to eql(1)
        expect(result[:items].first['PK']).to eql(@dmp['PK'])
        expect(result[:items].first['SK']).to eql("VERSION##{@dmp['dmphub_updated_at']}")
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
