# Developer Scripts — Vietnam Smart Golf Platform

## Overview

Bootstrap, setup, and operational scripts for local development environments.

## Scripts

| Script | Purpose |
|--------|---------|
| `bootstrap.sh` | Master bootstrap: checks prerequisites, runs per-component setup |
| `bootstrapFlutter.sh` | Flutter SDK setup, `flutter pub get`, IDE config hints |
| `bootstrapApi.sh` | Backend dependency install, database migrations baseline |
| `setupLocalEnv.sh` | Generate `.env.local.example` with all required environment variables |
| `runLocalServices.sh` | Start Docker Compose services, wait for healthy, print connection info |
| `stopLocalServices.sh` | Stop Docker Compose services gracefully |

## Status

Initialized as placeholders. Scripts are implemented in Slice 2 (Developer Bootstrap).

## Prerequisites

- Flutter SDK >=3.10.0
- Docker and Docker Compose
- Git
- Node.js >=18 (for portal, Story 1.2+)
- Java 21 or Go 1.21+ (for API, Story 1.2+)

## Bootstrap Order

```bash
# 1. Clone repository
git clone <repo-url>
cd vsp

# 2. Run master bootstrap
./infra/scripts/bootstrap.sh
```

## Usage

```bash
./infra/scripts/runLocalServices.sh
./infra/scripts/bootstrap.sh
```
