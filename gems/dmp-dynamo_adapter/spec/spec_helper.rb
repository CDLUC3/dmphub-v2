# frozen_string_literal: true

require 'bundler/setup'
require 'dmp/dmp_id_handler'
require 'dmp/dynamo_adapter'
require 'dmp/metadata_handler'

require_relative '../spec/support/mock_dynamodb_client.rb'
require_relative '../spec/support/mock_dynamodb_response.rb'
require_relative '../spec/support/mock_dynamodb_item.rb'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
