# API Fuzz Plan: <feature>

| Endpoint/Operation | Risk ID | Schema Source | Fuzz Focus | Expected Contract | Command |
|---|---|---|---|---|---|
|  |  | openapi.yaml | missing fields, wrong types, boundary values | no 5xx, schema valid | schemathesis run ... |
