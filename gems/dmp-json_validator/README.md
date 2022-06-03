# dmp-json_validator

This gem is used to validate DMP metadata for the DMPHub. It supports 3 distinct 'modes':

1. `author` - this mode is used to create or update a DMP by the system of provenance
2. `amend` - this mode is used by non-provenance systems to append funding info or related identifiers to a DMP
3. `delete` - this mode is used by the provenance system to 'delete' (aka tombstone) a DMP

## Requirements

Ruby >= 2.7.6

## Installation

Add the following to your Gemfile
```
gem "dmp-json_validator"
```

Then add `require 'dmp/json_validator` to your code

## Usage

Retrieve the list of validation modes:
`puts Dmp::JsonValidator::VALIDATION_MODES`

Validate your JSON
```
json = JSON.parse(File.read("#{Dir.pwd}/spec/support/json_mocks/minimal.json"))

response = Dmp::JsonValidator.validate(mode: 'author', json: json['author'])

puts response[:valid] ? 'Success' : response[:errors].inspect
```

## JSON Schemas

All of the below schemas are derived from the [RDA Common Metadata Standard for DMPs](https://github.com/RDA-DMP-Common/RDA-DMP-Common-Standard/tree/master/examples/JSON/JSON-schema).

Note that the `"$schema": "http://json-schema.org/draft-07/schema#",` line has been removed due to an issue with the json-schema-valkidator gem.

### author.json

This schema follows the [RDA Common Standard](https://github.com/RDA-DMP-Common/RDA-DMP-Common-Standard/tree/master/examples/JSON/JSON-schema) with the following exceptions:

**Changes to Required attributes:**
- `contributor: [:contributor_id]` : NOT required
- `dataset: [:dataset_id]` : NOT required (often not known)
- `dataset: [:personal_data]` : NOT required (defaults to 'unknown')
- `dataset: [:sensitive_data]` : NOT required (defaults to 'unknown')
- `dataset: [metadata: [:language]]` : NOT required (defaults to 'eng')
- `:ethical_issues_exist` : NOT required (defaults to 'unknown')
- `:language` : NOT required (defaults to 'eng')
- `project: [:title]` : NOT required (defaults to title of :dmp)
- `project: [:funding]` : REQUIRED
- `project: [funding: [:funding_status]]` : REQUIRED

**New attributes:**
- `:dmproadmap_related_identifiers` : An array of associated items (e.g. datasets, publications, etc.)
- `contact: [dmproadmap_affiliation: [:affiliation_id, :name]]` : The contact's instiutional affiliation with name and ROR
- `contributor: [dmproadmap_affiliation: [:affiliation_id, :name]]` : The contributor's instiutional affiliation with name and ROR
- `project: [funding: [dmproadmap_funded_affiliations: [:affiliation_id, :name]]` : The instiutions that received funding

See the 'author' for an [example of the minimum metadata](https://github.com/CDLUC3/dmphub-v2/tree/main/gems/dmp-json_validator/spec/support/json_mocks/minimal.json)
See a [complete metadata example](https://github.com/CDLUC3/dmphub-v2/tree/main/gems/dmp-json_validator/spec/support/json_mocks/complete.json)

### amend.json

This schema only requires the following metadata to be present:
- :dmp_id (including :type and :identifier)
- :title
- :modified
- one or more of the following:
  - :project -> :funding (including :funder_id (with :type and :identifier) and :funding_status)
  - :dmproadmap_related_identifiers (including :type, :identifier, :work_type and :descriptor)

See the 'amend-related_identifiers' and 'amend-funding' examples [from the RSpec tests](https://github.com/CDLUC3/dmphub-v2/tree/main/gems/dmp-json_validator/spec/support/json_mocks/minimal.json)

### delete.json

This schema only requires the following metadata to be present:
- :dmp_id (including :type and :identifier)
- :title

See the 'delete' example [from the RSpec tests](https://github.com/CDLUC3/dmphub-v2/tree/main/gems/dmp-json_validator/spec/support/json_mocks/minimal.json)
