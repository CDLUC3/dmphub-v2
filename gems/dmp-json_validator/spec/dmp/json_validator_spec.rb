# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
RSpec.describe Dmp::JsonValidator do
  it 'has a version number' do
    expect(Dmp::JsonValidator::VERSION).not_to be nil
  end

  it 'returns the validation modes' do
    expect(Dmp::JsonValidator::VALIDATION_MODES.is_a?(Array)).to eq(true)
  end

  it 'does not allow the validation modes to be altered' do
    expect { Dmp::JsonValidator::VALIDATION_MODES << 'foo' }.to raise_error(FrozenError)
  end

  describe 'validate(mode:, json:)' do
    before(:each) do
      @expected_error = JSON.parse({
        valid: false, errors: [Dmp::JsonValidator::MSG_DEFAULT]
      }.to_json)
      @json = { 'foo': 'bar' }
      @schema = {
        "type": 'object',
        "properties": {
          "foo": {
            "$id": '#/properties/foo',
            "type": 'string'
          }
        },
        "required": [
          'foo'
        ]
      }
    end

    it 'returns the appropriate error when no :mode is specified' do
      allow(Dmp::JsonValidator).to receive(:prepare_json).and_return(@json)
      result = JSON.parse(Dmp::JsonValidator.validate(mode: nil, json: @json))
      expect(compare_hashes(hash_a: result, hash_b: @expected_error)).to eql(true)
    end
    it 'returns the appropriate error when an invalid :mode is specified' do
      allow(Dmp::JsonValidator).to receive(:prepare_json).and_return(@json)
      result = JSON.parse(Dmp::JsonValidator.validate(mode: 'foo', json: @json))
      expect(compare_hashes(hash_a: result, hash_b: @expected_error)).to eql(true)
    end
    it 'returns the appropriate error when prepare_json returns a nil' do
      allow(Dmp::JsonValidator).to receive(:prepare_json).and_return(nil)
      result = JSON.parse(Dmp::JsonValidator.validate(mode: 'author', json: @json))
      expect(compare_hashes(hash_a: result, hash_b: @expected_error)).to eql(true)
    end
    it 'returns the appropriate error when load_schema returns a nil' do
      allow(Dmp::JsonValidator).to receive(:prepare_json).and_return(@json)
      allow(Dmp::JsonValidator).to receive(:load_schema).and_return(nil)
      @expected_error['errors'] = ['No JSON schema available!']
      result = JSON.parse(Dmp::JsonValidator.validate(mode: 'author', json: @json))
      expect(compare_hashes(hash_a: result, hash_b: @expected_error)).to eql(true)
    end
    it 'returns the appropriate error if the :json is NOT valid' do
      @json = { 'bar': 'foo' }
      allow(Dmp::JsonValidator).to receive(:prepare_json).and_return(@json)
      allow(Dmp::JsonValidator).to receive(:load_schema).and_return(@schema)
      result = JSON.parse(Dmp::JsonValidator.validate(mode: 'author', json: @json))
      expect(result['valid']).to eql(false)
      expect(result['errors'].first.include?('did not contain a required property of \'foo\'')).to eql(true)
    end
    it 'returns the appropriate error if the :json is valid' do
      allow(Dmp::JsonValidator).to receive(:prepare_json).and_return(@json)
      allow(Dmp::JsonValidator).to receive(:load_schema).and_return(@schema)
      result = JSON.parse(Dmp::JsonValidator.validate(mode: 'author', json: @json))
      expected = JSON.parse({ valid: true, errors: [] }.to_json)
      expect(compare_hashes(hash_a: result, hash_b: expected)).to eql(true)
    end
  end

  describe 'private methods' do
    describe 'respond(valid:, errors:)' do
      it 'returns the expected JSON if :valid and :errors are not provided' do
        expected = {
          valid: false, errors: [Dmp::JsonValidator::MSG_DEFAULT]
        }.to_json
        expect(Dmp::JsonValidator.send(:respond)).to eql(expected)
      end
      it 'converts :errors to an Array if a string is provided' do
        expected = { valid: false, errors: ['foo'] }.to_json
        expect(Dmp::JsonValidator.send(:respond, errors: 'foo')).to eql(expected)
      end
      it 'returns { valid: false } if :valid is not true' do
        expected = {
          valid: false, errors: [Dmp::JsonValidator::MSG_DEFAULT]
        }.to_json
        expect(Dmp::JsonValidator.send(:respond, valid: 'false')).to eql(expected)
        expect(Dmp::JsonValidator.send(:respond, valid: 'foo')).to eql(expected)
        expect(Dmp::JsonValidator.send(:respond, valid: [true])).to eql(expected)
        expect(Dmp::JsonValidator.send(:respond, valid: false)).to eql(expected)
        expect(Dmp::JsonValidator.send(:respond, valid: 0)).to eql(expected)
      end
      it 'returns the expected JSON' do
        expected = { valid: false, errors: ['foo'] }.to_json
        expect(Dmp::JsonValidator.send(:respond, valid: false, errors: ['foo'])).to eql(expected)
        expected = { valid: true, errors: ['foo'] }.to_json
        expect(Dmp::JsonValidator.send(:respond, valid: true, errors: ['foo'])).to eql(expected)
        expected = { valid: true, errors: %w[foo bar] }.to_json
        expect(Dmp::JsonValidator.send(:respond, valid: true, errors: %w[foo bar])).to eql(expected)
      end
    end

    describe 'load_schema(mode:)' do
      it 'returns nil if :mode is not provided' do
        expect(Dmp::JsonValidator.send(:load_schema, mode: nil)).to eql(nil)
      end
      it 'returns nil if :mode is not a valid mode' do
        expect(Dmp::JsonValidator.send(:load_schema, mode: 'foo')).to eql(nil)
      end
      it 'returns nil if :mode has no corresponding JSON schema' do
        allow(File).to receive(:exist?).and_return(false)
        expect(Dmp::JsonValidator.send(:load_schema, mode: :author)).to eql(nil)
      end
      it 'returns nil if contents of JSON schema are not parseable' do
        allow(File).to receive(:read).and_return('/{foo:"4%Y"$%\/')
        expect(Dmp::JsonValidator.send(:load_schema, mode: :author)).to eql(nil)
      end
      it 'returns the JSON schema' do
        schema = Dmp::JsonValidator.send(:load_schema, mode: :author)
        expected = 'https://github.com/CDLUC3/dmphub-v2/gems/dmp-json_validator/config/schemas/author.json'
        expect(schema['$id']).to eql(expected)

        schema = Dmp::JsonValidator.send(:load_schema, mode: :amend)
        expected = 'https://github.com/CDLUC3/dmphub-v2/gems/dmp-json_validator/config/schemas/amend.json'
        expect(schema['$id']).to eql(expected)

        schema = Dmp::JsonValidator.send(:load_schema, mode: :delete)
        expected = 'https://github.com/CDLUC3/dmphub-v2/gems/dmp-json_validator/config/schemas/delete.json'
        expect(schema['$id']).to eql(expected)
      end
    end

    describe 'prepare_json(json:)' do
      it 'returns nil if :json is not provided' do
        expect(Dmp::JsonValidator.send(:prepare_json, json: nil)).to eql(nil)
      end
      it 'parses the JSON if it is a String' do
        expected = JSON.parse({ foo: 'bar' }.to_json)
        expect(Dmp::JsonValidator.send(:prepare_json, json: '{"foo":"bar"}')).to eql(expected)
      end
      it 'returns nil if :json is not parseable JSON' do
        expect(Dmp::JsonValidator.send(:prepare_json, json: '/{foo:"4%Y"$%\/')).to eql(nil)
      end
      it 'returns nil if :json is not a Hash or a String' do
        expect(Dmp::JsonValidator.send(:prepare_json, json: 1.34)).to eql(nil)
      end
      it 'returns the :json as is if it ia a Hash' do
        expected = { foo: 'bar' }
        expect(Dmp::JsonValidator.send(:prepare_json, json: expected)).to eql(expected)
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
