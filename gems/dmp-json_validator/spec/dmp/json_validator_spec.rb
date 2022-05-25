# frozen_string_literal: true

RSpec.describe Dmp::JsonValidator do
  it 'has a version number' do
    expect(Dmp::JsonValidator::VERSION).not_to be nil
  end

  it 'returns the validation modes' do
    expect(Dmp::JsonValidator::VALIDATION_MODES.is_a?(Array)).to eq(true)
  end
end
