# frozen_string_literal: true

# Mock of a DynamoDB response
class MockDynamodbResponse
  attr_accessor :status
  attr_accessor :items

  def initialize(status: 200)
    @items = [MockDynamodbItem.new]
    @status = status
  end
end
