# JSON Schemas

## amend.json
This schema is used to update a DMP when the caller is not the system of provenance. This is typically for updating funding information or related identifiers.
 
The schema is based on the [RDA Common Metadata Standard for DMPs](https://github.com/RDA-DMP-Common/RDA-DMP-Common-Standard/tree/master/examples/JSON/JSON-schema).

We deviate from that baseline schema in the following ways ...

**Required attributes:**
- `:dataset` : NOT required
- `:ethical_issues_exist` : NOT required (defaults to 'unknown')
- `:language` : NOT required (defaults to 'eng')
- `dataset: [:dataset_id]` : NOT required (often not known)
- `dataset: [:personal_data]` : NOT required (defaults to 'unknown')
- `dataset: [:sensitive_data]` : NOT required (defaults to 'unknown')
- `dataset: [metadata: [:language]]` : NOT required (defaults to 'eng')
- `project: [:title]` : NOT required (defaults to title of :dmp)
- `project: [funding: [:funding_status]]` : REQUIRED 

**Additional attributes:**
- `:dmproadmap_related_identifiers` : An array of associated items (e.g. datasets, publications, etc.)
- `contact: [dmproadmap_affiliation: [:affiliation_id, :name]]` : The contact's instiutional affiliation with name and ROR
- `contributor: [dmproadmap_affiliation: [:affiliation_id, :name]]` : The contributor's instiutional affiliation with name and ROR
- `project: [funding: [dmproadmap_funded_affiliations: [:affiliation_id, :name]]` : The instiutions that received funding

## Example of valid JSON

The following is an example of a valid DMP.
```
{
  "dmp": {
    "title": "Example DMP",
    "description": "An exceptional example of complete DMP metadata",
    "language": "eng",
    "created": "2021-11-08T19:06:04Z",
    "modified": "2022-01-28T17:52:14Z",
    "ethical_issues_exist": "no",
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
      },{
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
      }
    ],
    "project": [
      {
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
    "dataset": [
      {
        "type": "dataset",
        "title": "Time Series",
        "description": "Long-term statistics related to our research",
        "issued": "2021-05-18T00:00:00Z",
        "distribution": [
          { 
            "title": "Anticipated distribution for the long-term statistics related to our research",
            "data_access": "open",
            "host": {
              "title": "Ocean Biogeographic Information System",
              "description": "OBIS strives to document the ocean's diversity, distribution and abundance of life.",
              "url": "http://iobis.org/",
              "dmproadmap_host_id": { 
                "type": "url",
                "identifier": "https://www.re3data.org/api/v1/repository/r3d100010088"
              }
            },
            "license": [
              {
                "license_ref": "https://spdx.org/licenses/CC-BY-4.0.json",
                "start_date": "2021-05-18T00:00:00Z"
              }
            ]
          }
        ],
        "metadata": [
          {
            "description": "Darwin Core - \u003cp\u003eA body of standards, including a glossary of terms ",
            "metadata_standard_id": {
              "type": "url",
              "identifier": "https://rdamsc.bath.ac.uk/api2/m9"
            }
          }
        ],
        "keyword": [ 
          "Earth and related environmental sciences"
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