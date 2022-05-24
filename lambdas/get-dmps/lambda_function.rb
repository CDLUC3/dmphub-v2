# require 'httparty'
require 'json'
require 'aws-sdk-dynamodb'

def lambda_handler(event:, context:)
  # Sample pure Lambda function

  # Parameters
  # ----------
  # event: Hash, required
  #     API Gateway Lambda Proxy Input Format
  #     Event doc: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html#api-gateway-simple-proxy-for-lambda-input-format

  # context: object, required
  #     Lambda Context runtime methods and attributes
  #     Context doc: https://docs.aws.amazon.com/lambda/latest/dg/ruby-context.html

  # Returns
  # ------
  # API Gateway Lambda Proxy Output Format: dict
  #     'statusCode' and 'body' are required
  #     # api-gateway-simple-proxy-for-lambda-output-format
  #     Return doc: https://docs.aws.amazon.com/apigateway/latest/developerguide/set-up-lambda-proxy-integrations.html

  # begin
  #   response = HTTParty.get('http://checkip.amazonaws.com/')
  # rescue HTTParty::Error => error
  #   puts error.inspect
  #   raise error
  # end
  
  # TODO: Determine how best to pass region and DynamoTable name
  client = Aws::DynamoDB::Client.new(region: ENV['AWS_REGION'])
  
  results = client.query(
    table_name: ENV['DYNAMO_TABLE_NAME'],
    key_condition_expression: "PK = :dmp_id",
    expression_attribute_values: {
      ':dmp_id': "DMP##{event.fetch('dmp_id', '')}" 
    },
    projection_expression: 'PK, SK, title, contact'
  )

  {
    statusCode: 200,
    body: {
      search: "DMP##{event.fetch('dmp_id', '')}",
      items: results.items
    }.to_json
  }
end
