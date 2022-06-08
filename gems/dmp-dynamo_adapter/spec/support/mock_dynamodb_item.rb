# frozen_string_literal: true

# Mock of a DynamoDB response
class MockDynamodbItem
  attr_accessor :item

  def initialize
    @item = JSON.parse(File.read("#{Dir.pwd}/spec/support/json_mocks/complete.json"))['dmp']
  end

  def first
    @item
  end
end
