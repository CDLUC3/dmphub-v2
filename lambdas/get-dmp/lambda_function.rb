require 'json'
require 'dmp/dynamo_adapter'
require 'dmp/response_formatter'

MSG_DEFAULT = 'Unable to process your request.'.freeze
MSG_NOT_FOUND = 'DMP does not exist.'.freeze

def lambda_handler(event:, context:)
  responder = Dmp::ResponseFormatter
  dmp_id = event.fetch('dmp_id', '').strip.downcase
  return responder.format_response(status: 400, errors: [MSG_DEFAULT]) if dmp_id.nil?

  results = Dmp::DynamoAdapter.find_by_pk(pk: "DMP##{dmp_id}", sk: 'VERSION#latest')
  return responder.format_response(status: 404, errors: [MSG_NOT_FOUND]) if results.nil? || results.empty?

  responder.format_response(status: 200, dmp: results.first)
end
