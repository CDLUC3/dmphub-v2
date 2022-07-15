# require 'httparty'
require 'json'
require 'dmp/authorizer'
require 'dmp/dynamo_adapter'
require 'dmp/json_validator'
require 'dmp/response_formatter'

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

MSG_DEFAULT = 'Unable to process your request.'.freeze
MSG_DISABLED = 'This operation is temporarily unavailable.'.freeze
MSG_EXISTS = 'DMP already exists.'.freeze

def lambda_handler(event:, context:)
  responder = Dmp::ResponseFormatter
  dynamo = Dmp::DynamoAdapter.new(provenance: event.caller, debug: event.debug)

  # Make sure the JSON is valid
  mode = Dmp::JsonValidator::VALIDATION_MODES.select { |item| item == 'author' }
  resp = Dmp::JsonValidator.validate(mode: mode, json: event.payload)
  return responder.format_response(status: 400, errors: resp[:errors]) unless resp[:valid]

  # Make sure the caller is authorized to do this
  action = Dmp::Authorizer::ACTION_TYPES.select { |item| item == 'create' }
  resp = Dmp::Authorizer.authorize(
    provenance: event.caller, env: event.env, action: action, dmp: event.payload
  )
  return responder.format_response(status: 400, errors: resp[:errors]) unless resp[:authorized]

  # Create the DMP
  resp = dynamo.create(json: event.payload)
  return responder.format_response(status: resp[:status], errors: resp[:error]) if resp[:status] != 201

  responder.format_response(status: 201, dmps: resp[:items])
end
