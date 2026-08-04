# Test Data and Fixtures: <feature>

> **Schema Reference**: This template conforms to `schemas/test-data-fixtures.schema.json`
> Every fixture must validate against that schema.

## Fixture Registry

| Fixture ID | Description | Data Type | Environment | Idempotent | Test IDs |
|---|---|---|---|---|---|
| | | | | | |

## Fixture Details

For each fixture, document:

### FIXTURE-XXX

```yaml
fixture_id: FIXTURE-XXX
description: "<description>"
data_type: seed | mock | stub | synthetic | sampled | production_snapshot
version: "1.0.0"
environment: dev | staging | prod | all
idempotent: true | false

data:
  # Fixture data structure here

constraints:
  nullable: true | false
  unique: true | false
  min: <value>
  max: <value>
  pattern: "<regex>"

setup_commands:
  - "<command>"

teardown_commands:
  - "<command>"

depends_on:
  - FIXTURE-XXX

usage:
  - test_ids: [QA-XXX-001, QA-XXX-002]
    setup_action: before_each | before_all
    teardown_action: after_each | after_all

metadata:
  source: "<origin of data>"
  sensitivity: public | internal | confidential | restricted
  tags: [tag1, tag2]
```

## Reset Strategy

### Database Reset
```yaml
database_reset:
  method: truncate | drop_recreate | transaction_rollback
  tables_affected: []
  idempotent: true | false
```

### Mock/Stub Reset
```yaml
mock_reset:
  method: clear_cache | reimport | restart_container
  target: <mock_name>
```

### Seed Idempotency
```yaml
seed_idempotency:
  approach: upsert | delete_then_insert | truncate_then_insert
  conflict_resolution: update | skip | error
```

## Test ID Mapping

| Test ID | Fixtures Used | Setup | Teardown |
|---|---|---|---|
| | | | |

## Schema Validation

Run validation before using fixtures:

```bash
python -c "import json, jsonschema; schema = json.load(open('schemas/test-data-fixtures.schema.json')); data = json.load(open('test-data-fixtures.json')); jsonschema.validate(data, schema)"
```

## Notes

<!-- Add any special considerations for fixture setup/teardown -->