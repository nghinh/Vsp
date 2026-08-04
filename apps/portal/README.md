# Course Operations Portal — Vietnam Smart Golf Platform

## Overview

Web portal for golf course operators to manage course geometry, pin positions, green speed, course conditions, alerts, and data corrections.

## Status

Initialized. Tech stack deferred to Story 1.2.

## Tech Stack

- **Framework**: Node.js / web (specific stack TBD — Story 1.2)
- **Target**: Course admins, greenkeepers, tournament directors

## Repository Structure

```
apps/portal/
├── src/             # Portal source (deferred to later stories)
├── test/            # Portal tests (deferred)
├── package.json     # Node dependencies
└── README.md
```

## Development

Run `npm install` once `package.json` has been updated with runtime dependencies (Story 1.2+).

See `infra/scripts/bootstrapApi.sh` for backend dependency setup.

## Bootstrap

See `infra/scripts/bootstrap.sh` for full local environment bootstrap.
