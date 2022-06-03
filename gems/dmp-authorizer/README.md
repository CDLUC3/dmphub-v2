# dmp-authorizer

This gem is used to determine if the provenance has permission to perform the action on the DMP.

1. `provenance` - the API client or user
2. `action` - :create, :update, :delete
3. `json` - the DMP json

## Requirements

Ruby >= 2.7.6

## Installation

Add the following to your Gemfile
```
gem "dmp-authorizer"
```

Then add `require 'dmp/authorizer` to your code

## Usage

Retrieve the list of available action:
`puts Dmp::Authorizer::ACTIONS_TYPES`

Check the authorization
```
json = JSON.parse(File.read("#{Dir.pwd}/spec/support/json_mocks/minimal.json"))

response = Dmp::Authorizer.verify(provenance: 'api_client_name', action: :create, json: json)

puts response[:valid] ? 'Success' : response[:errors].inspect
```
