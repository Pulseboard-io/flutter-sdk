# Tasks: Plan 09 - Quality, Testing & CI/CD

## References
- Plan: [09-quality-and-cicd.md](../Plans/09-quality-and-cicd.md)

---

## Task 9.1: Organize Test Suite Structure
**Priority:** High | **Estimate:** 1-2 hours | **Blocked by:** None

### Steps
1. Restructure `tests/` directory:
   - `tests/Unit/Services/` - service unit tests
   - `tests/Unit/Models/` - model unit tests
   - `tests/Unit/Enums/` - enum tests
   - `tests/Feature/Auth/` - move existing auth tests
   - `tests/Feature/Teams/` - move existing team tests
   - `tests/Feature/Api/` - API endpoint tests
   - `tests/Feature/Livewire/` - Livewire component tests
   - `tests/Feature/Compliance/` - compliance workflow tests
   - `tests/Contract/` - API contract tests
2. Update `Pest.php` to configure new test groups

### Acceptance Criteria
- [ ] Test directory structure organized
- [ ] All existing tests still pass in new locations
- [ ] Pest configuration updated

---

## Task 9.2: Set Up CI Pipeline (GitHub Actions)
**Priority:** High | **Estimate:** 2-3 hours | **Blocked by:** None

### Steps
1. Create `.github/workflows/ci.yml`:
   - Trigger: push and pull_request
   - Services: PostgreSQL, Redis
   - Steps: checkout, setup PHP 8.5, composer install, npm ci, npm run build, migrate, test with coverage
2. Add coverage enforcement: `--min=80`
3. Add Pint formatting check: `vendor/bin/pint --test`
4. Add security audit step (optional): `composer audit`
5. Cache Composer and npm dependencies for speed

### Acceptance Criteria
- [ ] CI runs on push and PR
- [ ] PostgreSQL and Redis services configured
- [ ] Tests run with coverage reporting
- [ ] Pint formatting enforced
- [ ] Pipeline passes on current codebase

---

## Task 9.3: Create Contract Tests
**Priority:** Medium | **Estimate:** 2-3 hours | **Blocked by:** Plan 04

### Steps
1. Create `tests/Contract/IngestPayloadV1Test.php`:
   - Verify request schema matches PRD v1.0 contract
   - Test all event types validate correctly
   - Test response format matches PRD
2. Create `tests/Contract/QueryResponseTest.php`:
   - Verify metrics overview response structure
   - Verify event search response structure

### Acceptance Criteria
- [ ] Contract tests verify PRD compliance
- [ ] Both request and response formats tested
- [ ] Schema version compatibility tested

---

## Task 9.4: Create E2E Smoke Test
**Priority:** Medium | **Estimate:** 2-3 hours | **Blocked by:** Plans 01-06

### Steps
1. Create `tests/E2E/OnboardingFlowTest.php`:
   - Register user
   - Verify email
   - Create team
   - Create project (auto-creates environments)
   - Generate write key
   - POST ingest batch
   - Process queue job
   - Verify dashboard shows data

### Acceptance Criteria
- [ ] Full end-to-end flow passes
- [ ] Covers "sign up to first insight" path
- [ ] No flaky test behavior
