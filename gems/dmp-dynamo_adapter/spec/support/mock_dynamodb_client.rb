# frozen__string_literal: true

# Mock Aws::DynamoDB::Client for testing
class MockDynamodbClient

  attr_accessor :hash
  attr_accessor :state

  def initialize(state: :latest)
    @state = state
  end

  def get_item(hash)
    @hash = hash
    MockDynamodbResponse.new(state: @state)
  end

  def query(hash)
    @hash = hash
    MockDynamodbResponse.new(state: @state)
  end

  def put_item(hash)
    @hash = hash
  end

  def update_item(hash)
    @hash = hash
  end
end
