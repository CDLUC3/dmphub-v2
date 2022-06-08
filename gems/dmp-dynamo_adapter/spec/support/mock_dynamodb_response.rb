# frozen_string_literal: true

# Mock of a DynamoDB response
class MockDynamodbResponse
  attr_accessor :status
  attr_accessor :items

  STATES = %i[empty latest version]
  MOCK_DYNAMO_ERROR = 'Generic Dynamo Error'

  def initialize(status: 200, state: :latest)
    case state
    when :empty
      @items = []
    when :version
      version = MockDynamodbItem.new.item
      version['SK'] = 'VERSION#2022-03-18T23:32:00Z'
      @items = [MockDynamodbItem.new(hash: version)]
    when :latest
      @items = [MockDynamodbItem.new]
    else
      raise Aws::Errors::ServiceError.new(nil, nil, MOCK_DYNAMO_ERROR)
    end
    @status = status
  end
end
