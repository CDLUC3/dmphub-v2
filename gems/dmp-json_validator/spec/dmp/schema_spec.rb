# frozen_string_literal: true

# rubocop:disable Metrics/BlockLength
RSpec.describe Dmp::JsonValidator do
  # The following tests are used to validate the JSON schema documents to ensure
  # that a minimal metadata record and a complete metadata record are valid
  describe 'config/schemas/minimal.json' do
    before(:each) do
      @json = JSON.parse(File.read("#{Dir.pwd}/spec/support/json_mocks/minimal.json"))
    end

    it 'minimal author metadata is valid' do
      json = @json['author']
      response = JSON.parse(Dmp::JsonValidator.validate(mode: 'author', json: json))
      expect(response['valid']).to eql(true), response['errors'].inspect
    end
    it 'minimal amend - related_identifiers metadata is valid' do
      json = @json['amend-related_identifiers']
      response = JSON.parse(Dmp::JsonValidator.validate(mode: 'amend', json: json))
      expect(response['valid']).to eql(true), response['errors'].inspect
    end
    it 'minimal amend - funding metadata is valid' do
      json = @json['amend-funding']
      response = JSON.parse(Dmp::JsonValidator.validate(mode: 'amend', json: json))
      expect(response['valid']).to eql(true), response['errors'].inspect
    end
    it 'minimal delete metadata is valid' do
      json = @json['delete']
      response = JSON.parse(Dmp::JsonValidator.validate(mode: 'delete', json: json))
      expect(response['valid']).to eql(true), response['errors'].inspect
    end
  end

  describe 'config/schemas/complete.json' do
    before(:each) do
      @json = JSON.parse(File.read("#{Dir.pwd}/spec/support/json_mocks/complete.json"))
    end

    # The complete JSON should pass for all modes
    Dmp::JsonValidator::VALIDATION_MODES.each do |mode|
      it "is valid for mode #{mode}" do
        response = JSON.parse(Dmp::JsonValidator.validate(mode: mode, json: @json))
        expect(response['valid']).to eql(true), response['errors'].inspect
      end
    end
  end
end
