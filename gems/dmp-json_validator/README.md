# dmp-json_validator

## Usage

Retrieve the list of validation modes:
`Dmp::JsonValidator::VALIDATION_MODES`

Validate your JSON 
```
json = {
  "dmp": {
    "title": "foo",
    "dmp_id": {
      "type": "url",
      "identifier": "https://dmptool.org/plans/1234567890"
    },
    "created": "2022-05-24T12:33:44Z",
    "modified": "2022-05-24T12:33:44Z",
    "contact": {
      "name": "jane doe",
      "mbox": "jane@example.edu",
      "contact_id": {
        "type": "orcid",
        "identifier": "https://orcid.org/0000-0000-0000-000X"
      }
    },
    "project": [
    ],
    "dataset": [
    ]
  }
}
errors = Dmp::JsonValidator.validate(mode: 'author', json: '{}')

p errors.empty? ? 'Success' : errors.inspect
```