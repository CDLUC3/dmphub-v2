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
    response = MockDynamodbResponse.new(state: @state)
    response.items = [MockDynamodbItem.new(hash: @hash[:item])]
    response
  end

  def update_item(args)
    # Update the initial hash
    args[:update_expression].gsub('SET ', '').split(',').each do |expr|
      key, val = expr.split('=')
      key = args.fetch(:expression_attribute_names, {})
                .fetch(:"#{key.strip.gsub(':', '')}", key.strip)
      val = args.fetch(:expression_attribute_values, {})
                .fetch(:"#{val.strip.gsub(':', '')}", nil)

      @hash[key] = val
    end

    response = MockDynamodbResponse.new(state: @state)
    response.items = [MockDynamodbItem.new(hash: @hash)]
    response
  end
end
