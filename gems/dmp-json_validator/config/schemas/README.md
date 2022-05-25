# JSON Schemas

## amend.json
This schema is used to update a DMP when the caller is not the system of provenance. This is typically for updating funding information or related identifiers.
 
The schema is based on the [RDA Common Metadata Standard for DMPs](https://github.com/RDA-DMP-Common/RDA-DMP-Common-Standard/tree/master/examples/JSON/JSON-schema).

We deviate from that baseline schema in the following ways ...

**Required attributes:**
- `:ethical_issues_exist` : NOT required (defaults to 'unknown')
- `:language` : NOT required (defaults to 'eng')
- `dataset: [:dataset_id]` : NOT required (often not known)
- `dataset: [:personal_data]` : NOT required (defaults to 'unknown')
- `dataset: [:sensitive_data]` : NOT required (defaults to 'unknown')
- `dataset: [metadata: [:language]]` : NOT required (defaults to 'eng')
- `project: [:title]` : NOT required (defaults to title of :dmp)
- `project: [:funding]` : REQUIRED
- `project: [funding: [:funding_status]]` : REQUIRED 

**Additional attributes:**
- `:dmproadmap_related_identifiers` : An array of associated items (e.g. datasets, publications, etc.)
- `contact: [dmproadmap_affiliation: [:affiliation_id, :name]]` : The contact's instiutional affiliation with name and ROR
- `contributor: [dmproadmap_affiliation: [:affiliation_id, :name]]` : The contributor's instiutional affiliation with name and ROR
- `project: [funding: [dmproadmap_funded_affiliations: [:affiliation_id, :name]]` : The instiutions that received funding

## Example of valid JSON

The followingf is an exmaple of the bare minimum DMP:
```
{
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
```

The following is an example of a complete DMP.
```
{
  "dmp": {
    "title": "Example DMP",
    "description": "An exceptional example of complete DMP metadata",
    "language": "eng",
    "created": "2021-11-08T19:06:04Z",
    "modified": "2022-01-28T17:52:14Z",
    "ethical_issues_description": "We may need to anonymize user data",
    "ethical_issues_exist": "yes",
    "ethical_issues_report": "https://example.edu/privacy_policy",
    "dmp_id": {
      "type": "doi",
      "identifier": "https://doi.org/10.12345/ABCDEFG"
    },
    "contact": {
      "name": "Jane Doe",
      "mbox": "jane.doe@example.edu",
      "dmproadmap_affiliation": {
        "name": "Example University (example.edu)",
        "affiliation_id": { 
          "type": "ror",
          "identifier": "https://ror.org/1234567890"
        }
      },
      "contact_id": {
        "type": "orcid",
        "identifier": "https://orcid.org/0000-0000-0000-000X"
      }
    },
    "contributor": [
      {
        "name": "Jane Doe",
        "mbox": "jane.doe@example.edu",
        "role": [ 
          "http://credit.niso.org/contributor-roles/data-curation",
          "http://credit.niso.org/contributor-roles/investigation"
        ],
        "dmproadmap_affiliation": {
          "name": "Example University (example.edu)",
          "affiliation_id": {
            "type": "ror",
            "identifier": "https://ror.org/1234567890"
          }
        },
        "contributor_id": {
          "type": "orcid", 
          "identifier": "https://orcid.org/0000-0000-0000-000X"
        }
      }, {
        "name":"Jennifer Smith",
        "role": [
          "http://credit.niso.org/contributor-roles/investigation"
        ],
        "dmproadmap_affiliation": {
          "name": "University of Somewhere (somwhere.edu)",
          "affiliation_id": {
            "type": "ror",
            "identifier": "https://ror.org/0987654321"
          }
        }
      }, {
        "name": "Sarah James",
        "role": [
          "http://credit.niso.org/contributor-roles/project_administration"
        ]
      }
    ],
    "cost": [
      {
        "currency_code": "USD",
        "title": "Preservation costs",
        "description": "The estimated costs for preserving our data for 20 years",
        "value": 10000
      }
    ],
    "dataset": [
      {
        "type": "dataset",
        "title": "Odds and ends",
        "description": "Collection of odds and ends",
        "issued": "2022-03-15",
        "keyword": [
          "foo"
        ],
        "dataset_id": {
          "type": "doi",
          "identifier": "http://doi.org/10.99999/8888.7777"
        }
        "language": "eng", 
        "metadata": [
          {
            "description": "The industry standard!",
            "language": "eng",
            "metadata_standard_id": {
              "type": "url",
              "identifier": "https://example.com/metadata_standards/123"
            }
          }
        ],
        "personal_data": "no",
        "data_quality_assurance": [
          "We will ensure that the preserved copies are of high quality",
        ],
        "preservation_statement": "We are going to preserve this data for 20 years",
        "security_and_privacy": [
          {
            "title": "Data security",
            "description": "We're going to encrypt this one."
          }
        ],
        "sensitive_data": "yes",
        "technical_resource": [
          {
            "name": "Elctron microscope 1234",
            "description": "A super electron microscope"
          }
        ],
        "distribution": [
          {
            "access_url": "https://example.edu/datasets/00000",
            "download_url": "https://example.edu/datasets/00000.pdf",
            "available_until": "2052-03-15",
            "byte_size": 1234567890,
            "data_access": "shared",
            "format": "application/vnd.ms-excel",
            "host": {
              "title": "Random repo",
              "url": "A generic data repository",
              "dmproadmap_host_id": {
                "type": "url",
                "identifier": "https://hosts.example.org/765675"
              }
            },
            "license": [
              {
                "license_ref": "https://licenses.example.org/zyxw",
                "start_date": "2022-03-15"
              }
            ]
          }
        ]
      }
    ],
    "language": "eng",
    "project": [
      {
        "title": "Example research project"
        "description": "Abstract of what we're going to do."
        "start": "2015-05-12T00:00:00Z",
        "end": "2024-05-24T11:32:21-07:00",
        "funding": [
          {
            "name": "National Funding Organization",
            "funder_id": { 
              "type": "fundref",
              "identifier": "http://dx.doi.org/10.13039/100005595"
            },
            "funding_status": "granted",
            "grant_id": {
              "type": "url",
              "identifier": "https://nfo.example.org/awards/098765"
            }
            "dmproadmap_funded_affiliations": [
              {
                "name": "Example University (example.edu)",
                "affiliation_id": {
                  "type": "ror",
                  "identifier": "https://ror.org/1234567890"
                }
              }
            ]
          }
        ]
      }
    ],
    "dmproadmap_related_identifiers": [ 
      {
        "descriptor": "cites",
        "type": "doi",
        "identifier": "https://doi.org/10.21966/1.566666",
        "work_type": "dataset"
      },{
        "descriptor": "is_referenced_by",
        "type": "doi",
        "identifier": "10.1111/fog.12471",
        "work_type": "article"
      }
    ]
  }
  ```