         _                 _           _          _   _
      __| |   _  _   ___  | |__  _   _| |_       | | | |
     / _` |  / \/ \ |  _ \| `_ \| | | | '_ \     | | | |
    | (_| | / /\/\ \| | ) | | | | |_| | |_) |    | | | |
     \__,_|/_/    \_| '__/|_| |_|_____|_'__/     |_| |_|
 -------------------|-|-------------------------------------
------------------------------------------------------------
AWS based lambda functions and ruby gems for DMPHub v2

## Overview

<img src="application-architecture.png?raw=true">

The DMPHub has 3 types of Lambdas:
- those invoked by the API Gateway
- those invoked by messages on the SQS Queue
- those invoked by other Lambdas

The Lambdas that are invoked by calls made to the API Gateway are:
- **TRIGGER**   --> **LAMBDA**
- GET /dmps   --> lambda-get-dmps (protected by Cognito)
- POST /dmps   --> lambda-post-dmps (protected by Cognito)
- GET /dmps/{dmp_id+}   --> lambda-get-dmp
- DELETE /dmps/{dmp_id+}   --> lambda-delete-dmp (protected by Cognito)
- PUT /dmps/{dmp_id+}   --> lambda-put-dmp (protected by Cognito)

The Lambdas that are invoked by messages placed in the SQS Queue are:
- **TRIGGER**   --> **LAMBDA**
- topic == pending-download   --> lambda-document-downloader
- topic == pending-publication   --> lambda-ezid-publisher
- topic == pending-notification   --> lambda-provenance-notifier

The Lambdas that are invoked by other Lambdas are:
- **TRIGGER**   --> **LAMBDA**
- lambda-put-dmp   --> lambda-put-dmp-fundings (if different provenance)
- lambda-put-dmp   --> lambda-put-dmp-related-identifiers (if different provenance)


### lambda-get-dmps

This lambda handles search and faceting for DMPs. It relies heavily on the Dynamo Table's global secondaey indices.

Acceptible query params:
- `page=1` the page you would like (default is 1)
- `per_page=25` the number of records to include (default is 25)
- `start_date=2022-01-01` will ensure that results only include DMPs updated after the speccified date (inclusive)
- `end_date=2022-01-31` will ensuure that results onlly include DMPs, updated before the specified date (inclusive)
- `ror=abc123def45` will return DMPs related to the specified ROR
- `orcid=0000-0000-0000-000X` will return DMPs related to the specified ORCID

Returns an abbreviated set of each DMPs metadata. This subset should be enough for a client to make a subsequent call to the specific DMP of interest. For example:
```
{
  "items": [
    {
      "dmp_id": { "type": "doi", "identifier": "https://doi.org/10.48321/D1X31R" },
      "title": "Example DMP",
      "description": "Lorem ipsum foo ...",
      "created": "2022-03-14T18:42:26Z",
      "modified": "2022-05-10T16:31:45Z",
      "contact": {
        "name": "Jane Doe",
        "mbox": "jane.doe@example.edu",
        "affiliation": {
          "name": "Example University",
          "affiliation_id": { "type": "ror", "identifier": "https://ror.org/035a68863" }
        },
        "contact_id": { "type": "orcid", "identifier": "https://orcid.org/0000-0001-9870-5882" }
      }
    }
  ]
}
```

This currently requires Cognito authentication.

### lambda-post-dmp

This lambda handles the creation of a new DMP record. It performs the following actions:
- validate the incoming JSON
- TBD

This currently requires Cognito authentication.

### lambda-delete-dmp

This lambda handles the 'deletion' of a new DMP record. It performs the following actions:
- validate the incoming JSON
- TBD

This currently requires Cognito authentication.

DMPs are never deleted, they just become tombstoned so that the DMP ID is resolvable!

### lambda-get-dmp

This lambda returns the DMP metadata as HTML, JSON, XML or BIBTEX

This endpoint is currently open to the public because it resolves the DMP ID.

### lambda-put-dmp

This lambda handles the update of a new DMP record. It performs the following actions:
- validate the incoming JSON
- TBD

When the client is also the provenance, it just updates the record. When it is not the same, it updates the record and then sends a notification to the sytem of provenance if applicable.

This currently requires Cognito authentication.
