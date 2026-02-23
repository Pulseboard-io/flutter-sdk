# Sub-Tasks: Plan 09 - Quality, Testing & CI/CD

---

## Task 9.1: Organize Test Suite Structure

### Sub-task 9.1.1: Create test directory structure
- Create directories:
  - `tests/Unit/Services/`
  - `tests/Unit/Models/`
  - `tests/Unit/Enums/`
  - `tests/Feature/Auth/`
  - `tests/Feature/Teams/`
  - `tests/Feature/Api/`
  - `tests/Feature/Livewire/`
  - `tests/Feature/Compliance/`
  - `tests/Contract/`
  - `tests/E2E/`

### Sub-task 9.1.2: Move existing auth tests to Feature/Auth/
- Move AuthenticationTest, RegistrationTest, PasswordConfirmationTest, PasswordResetTest, TwoFactorAuthenticationSettingsTest, UpdatePasswordTest, BrowserSessionsTest, DeleteAccountTest, EmailVerificationTest, ProfileInformationTest to `tests/Feature/Auth/`

### Sub-task 9.1.3: Move existing team tests to Feature/Teams/
- Move CreateTeamTest, UpdateTeamNameTest, DeleteTeamTest, InviteTeamMemberTest, UpdateTeamMemberRoleTest, RemoveTeamMemberTest, LeaveTeamTest to `tests/Feature/Teams/`

### Sub-task 9.1.4: Move API token tests to Feature/Api/
- Move CreateApiTokenTest, DeleteApiTokenTest, ApiTokenPermissionsTest to `tests/Feature/Api/`

### Sub-task 9.1.5: Update Pest.php configuration
- Open `tests/Pest.php`
- Configure test groups for new directories:
  ```php
  uses(Tests\TestCase::class, RefreshDatabase::class)->in('Feature', 'Contract', 'E2E');
  uses(Tests\TestCase::class)->in('Unit');
  ```

### Sub-task 9.1.6: Verify all tests pass in new locations
- Run `php artisan test --compact`
- Fix any namespace or path issues
- Ensure zero failures

---

## Task 9.2: Set Up CI Pipeline (GitHub Actions)

### Sub-task 9.2.1: Create workflow directory
- Create `.github/workflows/` directory

### Sub-task 9.2.2: Create ci.yml workflow file
- Define workflow:
  ```yaml
  name: CI
  on: [push, pull_request]
  jobs:
    tests:
      runs-on: ubuntu-latest
      services:
        postgres:
          image: postgres:16
          env:
            POSTGRES_DB: pulseboard_testing
            POSTGRES_USER: sail
            POSTGRES_PASSWORD: password
          ports: ['5432:5432']
          options: >-
            --health-cmd pg_isready
            --health-interval 10s
            --health-timeout 5s
            --health-retries 5
        redis:
          image: redis:7
          ports: ['6379:6379']
          options: >-
            --health-cmd "redis-cli ping"
            --health-interval 10s
            --health-timeout 5s
            --health-retries 5
  ```

### Sub-task 9.2.3: Define PHP setup steps
- Setup PHP 8.5 with extensions: pgsql, redis, mbstring, xml, curl
- Cache Composer dependencies
- Run `composer install --prefer-dist --no-progress`

### Sub-task 9.2.4: Define Node.js setup steps
- Setup Node.js (latest LTS)
- Cache npm dependencies
- Run `npm ci`
- Run `npm run build`

### Sub-task 9.2.5: Define test steps
- Copy `.env.example` to `.env`
- Set test environment variables (DB, Redis)
- Generate app key: `php artisan key:generate`
- Run migrations: `php artisan migrate --no-interaction`
- Run tests with coverage: `vendor/bin/pest --coverage --min=80`

### Sub-task 9.2.6: Define quality steps
- Run Pint check: `vendor/bin/pint --test`
- Run Composer audit: `composer audit` (optional, allow-failure for MVP)

### Sub-task 9.2.7: Define Flutter SDK test job (separate job)
- Setup Flutter SDK
- `cd "Source Code/flutter-sdk" && flutter pub get`
- `flutter analyze`
- `flutter test`

### Sub-task 9.2.8: Verify pipeline passes
- Push to remote (or run locally with `act`)
- Verify all steps pass
- Fix any issues

---

## Task 9.3: Create Contract Tests

### Sub-task 9.3.1: Create IngestPayloadV1Test
- Create `tests/Contract/IngestPayloadV1Test.php`
- Test: valid payload with all event types accepted (202)
- Test: response body matches PRD JSON structure exactly
- Test: each field in request is validated per PRD rules
- Test: error response matches PRD 422 format

### Sub-task 9.3.2: Create QueryResponseTest
- Create `tests/Contract/QueryResponseTest.php`
- Test: metrics overview response matches PRD JSON structure
  - Verify: `project_id`, `environment`, `window`, `kpis`, `timeseries` keys present
  - Verify: KPI values are correct types (int for counts, float for percentages)
- Test: event search response has correct pagination structure
- Test: crash search response groups by fingerprint correctly
- Test: trace search response includes percentile values

### Sub-task 9.3.3: Create SchemaVersionTest
- Create `tests/Contract/SchemaVersionTest.php`
- Test: schema_version 1.0 accepted
- Test: unsupported schema_version rejected with clear error
- Test: X-Schema-Version header matches payload schema_version

---

## Task 9.4: Create E2E Smoke Test

### Sub-task 9.4.1: Create OnboardingFlowTest
- Create `tests/E2E/OnboardingFlowTest.php`

### Sub-task 9.4.2: Implement registration step
- POST to register endpoint with valid user data
- Assert user created

### Sub-task 9.4.3: Implement email verification step
- Get verification URL from notification
- Visit verification URL
- Assert user email_verified_at is set

### Sub-task 9.4.4: Implement team creation step
- Already created via Jetstream (personal team)
- Verify team exists

### Sub-task 9.4.5: Implement project creation step
- POST to project creation API
- Assert project created with 3 environments (prod, staging, dev)

### Sub-task 9.4.6: Implement write key generation step
- POST to project key creation for prod environment
- Assert write key returned (plain token visible)
- Store plain token for next step

### Sub-task 9.4.7: Implement ingest batch step
- POST to `/api/v1/ingest/batch` with write key
- Use PRD example payload
- Assert 202 response with batch_id

### Sub-task 9.4.8: Implement queue processing step
- Process queue synchronously: `Queue::fake()` or run job directly
- Assert batch status = processed
- Assert events stored in database

### Sub-task 9.4.9: Implement dashboard verification step
- Load MetricsService for the environment
- Assert event count > 0
- Assert active users > 0
- (Or make web request to dashboard route, assert KPI cards render)

### Sub-task 9.4.10: Assert full flow integrity
- Entire flow from register to dashboard data takes < 30 seconds
- No errors at any step
- All assertions pass
