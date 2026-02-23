# Plan 09: Quality, Testing & CI/CD

## Objective
Establish comprehensive test coverage with Pest, CI pipeline with quality gates, and release readiness criteria.

## Current State
- Pest installed and configured
- 21 feature tests (all Jetstream scaffolding)
- No CI pipeline configured
- No coverage enforcement

## Target State
- Unit coverage >= 90% for core domain services
- Integration coverage >= 80% for ingest controller + queue jobs + DB persistence
- Contract tests for API request/response compatibility
- E2E smoke tests for critical flows
- CI pipeline with: install, build, migrate, test, coverage, lint, security scan
- Release readiness definition met

## Implementation Steps

### 9.1 Test Organization
```
tests/
├── Unit/
│   ├── Services/
│   │   ├── EventNormalizerTest.php
│   │   ├── DeduplicatorTest.php
│   │   ├── SessionizerTest.php
│   │   ├── PiiFilterTest.php
│   │   ├── UserPropertyApplicatorTest.php
│   │   ├── MetricsServiceTest.php
│   │   └── EntitlementServiceTest.php
│   ├── Models/
│   │   ├── ProjectTest.php
│   │   ├── EnvironmentTest.php
│   │   └── ...
│   └── Enums/
│       └── ...
├── Feature/
│   ├── Auth/           (existing Jetstream tests)
│   ├── Teams/          (existing Jetstream tests)
│   ├── Api/
│   │   ├── IngestBatchTest.php
│   │   ├── ProjectsApiTest.php
│   │   ├── MetricsApiTest.php
│   │   ├── EventsApiTest.php
│   │   ├── CrashesApiTest.php
│   │   └── TracesApiTest.php
│   ├── Livewire/
│   │   ├── ProjectDashboardTest.php
│   │   ├── EventExplorerTest.php
│   │   └── ...
│   └── Compliance/
│       ├── DataDeletionTest.php
│       └── DataExportTest.php
├── Contract/
│   ├── IngestPayloadV1Test.php
│   └── QueryResponseTest.php
└── E2E/
    └── OnboardingFlowTest.php
```

### 9.2 CI Pipeline (GitHub Actions)
```yaml
name: CI
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    services:
      postgres: ...
      redis: ...
    steps:
      - checkout
      - setup PHP 8.5
      - composer install
      - npm ci && npm run build
      - php artisan migrate
      - vendor/bin/pest --coverage --min=80
      - vendor/bin/pint --test
      # Optional: PHPStan, security audit
```

### 9.3 Coverage Targets
- Core services (Ingestion, Compliance, Metrics): >= 90%
- Controllers + Jobs: >= 80%
- Models: >= 70% (mostly relationship coverage)
- Overall: >= 80%

### 9.4 Quality Gates
- All tests pass (zero failures)
- Coverage thresholds met
- Pint formatting clean
- No high/critical security vulnerabilities
- Horizon stable queue throughput

## Dependencies
- All other plans (tests written alongside features)

## Estimated Effort
3-5 person-weeks (ongoing alongside feature development)
