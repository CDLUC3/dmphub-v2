# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
RSpec.describe Dmp::Authorizer do
  it 'has a version number' do
    expect(Dmp::Authorizer::VERSION).not_to be nil
  end

  it 'returns the action types' do
    expect(Dmp::Authorizer::ACTION_TYPES.is_a?(Array)).to eq(true)
  end

  it 'does not allow the action types to be altered' do
    expect { Dmp::Authorizer::ACTION_TYPES << 'foo' }.to raise_error(FrozenError)
  end

  describe 'authorize(provenance:, env:, action:, dmp:)' do
    before(:each) do
      @provenance = {
        PK: 'PROVENANCE#abcdefghijk',
        scopes: ['api.test.write']
      }
      @dmp = {
        PK: 'DMP#1234567890',
        dmphub_provenance_id: @provenance[:PK],
        title: 'My test DMP'
      }
      @expected_error = JSON.parse({
        authorized: false, errors: [Dmp::Authorizer::MSG_DEFAULT]
      }.to_json)
    end

    it 'returns the appropriate error when no :provenance is specified' do
      allow(Dmp::Authorizer).to receive(:prepare_json).and_return(@dmp, nil)
      result = JSON.parse(Dmp::Authorizer.authorize(provenance: nil, action: 'create',
                                                    env: 'test', dmp: @dmp))
      @expected_error['errors'] = [Dmp::Authorizer::MSG_NO_AUTH]
      expect(compare_hashes(hash_a: result, hash_b: @expected_error)).to eql(true)
    end
    it 'returns the appropriate error when no :action is specified' do
      allow(Dmp::Authorizer).to receive(:prepare_json).and_return(@dmp, @provenance)
      result = JSON.parse(Dmp::Authorizer.authorize(provenance: @provenance, action: nil,
                                                    env: 'test', dmp: @dmp))
      expect(compare_hashes(hash_a: result, hash_b: @expected_error)).to eql(true)
    end
    it 'returns the appropriate error when an invalid :action is specified' do
      allow(Dmp::Authorizer).to receive(:prepare_json).and_return(@dmp, @provenance)
      result = JSON.parse(Dmp::Authorizer.authorize(provenance: @provenance, action: 'foo',
                                                    env: 'test', dmp: @dmp))
      expect(compare_hashes(hash_a: result, hash_b: @expected_error)).to eql(true)
    end
    it 'returns the appropriate error when prepare_json returns a nil' do
      allow(Dmp::Authorizer).to receive(:prepare_json).and_return(nil)
      result = JSON.parse(Dmp::Authorizer.authorize(provenance: @provenance, action: 'create',
                                                    env: 'test', dmp: @dmp))
      expect(compare_hashes(hash_a: result, hash_b: @expected_error)).to eql(true)
    end
    it 'returns the appropriate error if the :provenance is NOT authorized' do
      allow(Dmp::Authorizer).to receive(:prepare_json).and_return(@dmp, @provenance)
      allow(Dmp::Authorizer).to receive(:verify_action).and_return(
        { status: 401, error: Dmp::Authorizer::MSG_UNAUTH }
      )
      @expected_error['errors'] = [Dmp::Authorizer::MSG_UNAUTH]
      result = JSON.parse(Dmp::Authorizer.authorize(provenance: @provenance, action: 'create',
                                                    env: 'test', dmp: @dmp))
      expect(compare_hashes(hash_a: result, hash_b: @expected_error)).to eql(true)
    end
    it 'returns the appropriate error if the :provenance is authorized' do
      allow(Dmp::Authorizer).to receive(:prepare_json).and_return(@dmp, @provenance)
      allow(Dmp::Authorizer).to receive(:verify_action).and_return({ status: 200, error: '' })
      expected = JSON.parse({ authorized: true, errors: [''] }.to_json)
      result = JSON.parse(Dmp::Authorizer.authorize(provenance: @provenance, action: 'create',
                                                    env: 'test', dmp: @dmp))
      expect(compare_hashes(hash_a: result, hash_b: expected)).to eql(true)
    end
  end

  describe 'private methods' do
    describe 'respond(valid:, errors:)' do
      it 'returns the expected JSON if :authorized and :errors are not provided' do
        expected = {
          authorized: false, errors: [Dmp::Authorizer::MSG_DEFAULT]
        }.to_json
        expect(Dmp::Authorizer.send(:respond)).to eql(expected)
      end
      it 'converts :errors to an Array if a string is provided' do
        expected = { authorized: false, errors: ['foo'] }.to_json
        expect(Dmp::Authorizer.send(:respond, errors: 'foo')).to eql(expected)
      end
      it 'returns { authorized: false } if :authorized is not true' do
        expected = {
          authorized: false, errors: [Dmp::Authorizer::MSG_DEFAULT]
        }.to_json
        expect(Dmp::Authorizer.send(:respond, authorized: 'false')).to eql(expected)
        expect(Dmp::Authorizer.send(:respond, authorized: 'foo')).to eql(expected)
        expect(Dmp::Authorizer.send(:respond, authorized: [true])).to eql(expected)
        expect(Dmp::Authorizer.send(:respond, authorized: false)).to eql(expected)
        expect(Dmp::Authorizer.send(:respond, authorized: 0)).to eql(expected)
      end
      it 'returns the expected JSON' do
        expected = { authorized: false, errors: ['foo'] }.to_json
        expect(Dmp::Authorizer.send(:respond, authorized: false, errors: ['foo'])).to eql(expected)
        expected = { authorized: true, errors: ['foo'] }.to_json
        expect(Dmp::Authorizer.send(:respond, authorized: true, errors: ['foo'])).to eql(expected)
        expected = { authorized: true, errors: %w[foo bar] }.to_json
        expect(Dmp::Authorizer.send(:respond, authorized: true, errors: %w[foo bar])).to eql(expected)
      end
    end

    describe 'verify_action(provenance:, action:, dmp:, env:, json:)' do
      before(:each) do
        @provenance = {
          PK: 'PROVENANCE#abcdefghijk',
          scopes: ['api.test.write']
        }
        @dmp = {
          PK: 'DMP#1234567890',
          dmphub_provenance_id: @provenance[:PK],
          title: 'My test DMP'
        }
      end

      it 'returns a 401 if :provenance does not have write permission' do
        @provenance[:scopes] = ['api.test.foo']
        result = Dmp::Authorizer.send(:verify_action, provenance: @provenance, action: 'create',
                                                      env: 'test', dmp: @dmp)
        expect(result[:status]).to eql(401)
        expect(result[:error]).to eql(Dmp::Authorizer::MSG_UNAUTH)
      end
      it 'returns a 401 if :provenance does not have write permission for the :env' do
        result = Dmp::Authorizer.send(:verify_action, provenance: @provenance, action: 'create',
                                                      env: 'foo', dmp: @dmp)
        expect(result[:status]).to eql(401)
        expect(result[:error]).to eql(Dmp::Authorizer::MSG_UNAUTH)
      end
      it 'returns a 405 if the action is :create and the dmp has been persisted' do
        result = Dmp::Authorizer.send(:verify_action, provenance: @provenance, action: 'create',
                                                      env: 'test', dmp: @dmp)
        expect(result[:status]).to eql(405)
        expect(result[:error]).to eql(Dmp::Authorizer::MSG_EXISTS)
      end
      it 'returns a 404 if the action is :update and the dmp has NOT been persisted' do
        @dmp.delete(:PK)
        result = Dmp::Authorizer.send(:verify_action, provenance: @provenance, action: 'update',
                                                      env: 'test', dmp: @dmp)
        expect(result[:status]).to eql(404)
        expect(result[:error]).to eql(Dmp::Authorizer::MSG_UNKNOWN)
      end
      it 'returns a 404 if the action is :delete and the dmp has NOT been persisted' do
        @dmp.delete(:PK)
        result = Dmp::Authorizer.send(:verify_action, provenance: @provenance, action: 'delete',
                                                      env: 'test', dmp: @dmp)
        expect(result[:status]).to eql(404)
        expect(result[:error]).to eql(Dmp::Authorizer::MSG_UNKNOWN)
      end
      it 'returns a 401 if the action is :delete and the dmp is NOT owned by the provenance' do
        @dmp[:dmphub_provenance_id] = 'PROVENANCE#zyxwvutsrq'
        result = Dmp::Authorizer.send(:verify_action, provenance: @provenance, action: 'delete',
                                                      env: 'test', dmp: @dmp)
        expect(result[:status]).to eql(401)
        expect(result[:error]).to eql(Dmp::Authorizer::MSG_UNAUTH)
      end
      it 'returns a 200 if the provenance can create the dmp' do
        @dmp.delete(:PK)
        result = Dmp::Authorizer.send(:verify_action, provenance: @provenance, action: 'create',
                                                      env: 'test', dmp: @dmp)
        expect(result[:status]).to eql(200)
        expect(result[:error]).to eql('')
      end
      it 'returns a 200 if the provenance can update a dmp it owns' do
        result = Dmp::Authorizer.send(:verify_action, provenance: @provenance, action: 'update',
                                                      env: 'test', dmp: @dmp)
        expect(result[:status]).to eql(200)
        expect(result[:error]).to eql('')
      end
      it 'returns a 200 if the provenance can update a dmp it does NOT own' do
        @dmp[:dmphub_provenance_id] = 'PROVENANCE#zyxwvutsrq'
        result = Dmp::Authorizer.send(:verify_action, provenance: @provenance, action: 'update',
                                                      env: 'test', dmp: @dmp)
        expect(result[:status]).to eql(200)
        expect(result[:error]).to eql('')
      end
      it 'returns a 200 if the provenance can delete the dmp' do
        result = Dmp::Authorizer.send(:verify_action, provenance: @provenance, action: 'delete',
                                                      env: 'test', dmp: @dmp)
        expect(result[:status]).to eql(200)
        expect(result[:error]).to eql('')
      end
    end

    describe 'prepare_json(json:)' do
      it 'returns nil if :json is not provided' do
        expect(Dmp::Authorizer.send(:prepare_json, json: nil)).to eql(nil)
      end
      it 'parses the JSON if it is a String' do
        expected = JSON.parse({ foo: 'bar' }.to_json)
        expect(Dmp::Authorizer.send(:prepare_json, json: '{"foo":"bar"}')).to eql(expected)
      end
      it 'returns nil if :json is not parseable JSON' do
        expect(Dmp::Authorizer.send(:prepare_json, json: '/{foo:"4%Y"$%\/')).to eql(nil)
      end
      it 'returns nil if :json is not a Hash or a String' do
        expect(Dmp::Authorizer.send(:prepare_json, json: 1.34)).to eql(nil)
      end
      it 'returns the :json as is if it ia a Hash' do
        expected = { foo: 'bar' }
        expect(Dmp::Authorizer.send(:prepare_json, json: expected)).to eql(expected)
      end
    end
  end

  # Helper function that compares 2 hashes regardless of the order of their keys
  def compare_hashes(hash_a: {}, hash_b: {})
    a_keys = hash_a.keys.sort { |a, b| a <=> b }
    b_keys = hash_b.keys.sort { |a, b| a <=> b }
    return false unless a_keys == b_keys

    valid = true
    a_keys.each { |key| valid = false unless hash_a[key] == hash_b[key] }
    valid
  end
end
# rubocop:enable Metrics/BlockLength
