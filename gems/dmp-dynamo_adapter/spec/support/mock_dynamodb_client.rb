# frozen__string_literal: true

# Mock Aws::DynamoDB::Client for testing
class MockDynamodbClient

  attr_accessor :hash

  def get_item(hash)
    @hash = hash
    MockDynamodbResponse.new
  end

  def query(hash)
    @hash = hash
    MockDynamodbResponse.new
  end

  def put_item(hash)
    @hash = hash
  end

  def update_item(hash)
    @hash = hash
  end
end
