# Tasks: Plan 07 - Compliance & Governance (EU-First)

## References
- Plan: [07-compliance-and-governance.md](../Plans/07-compliance-and-governance.md)
- PRD: [PRD.md](../PRD.md) (lines 416-465)

---

## Task 7.1: Create Consent Management Tables & Models
**Priority:** Critical | **Estimate:** 2-3 hours | **Blocked by:** Plan 03

### Steps
1. Add `lawful_basis` and `consent_required` columns to `environments` table (if not in initial migration)
2. Create migration for `consent_records` table:
   - `id (uuid)`, `environment_id (fk)`, `app_user_id (fk)`, `consent_type (string, enum)`, `granted (bool)`, `granted_at (timestamp)`, `revoked_at (timestamp, nullable)`, `ip_address (string, nullable, truncated)`, `created_at`
   - Index: `(environment_id, app_user_id, consent_type)`
3. Create `ConsentRecord` model with relationships and enum casts
4. Create `ConsentService` in `app/Services/Compliance/`:
   - `grantConsent(AppUser, ConsentType)` - create record
   - `revokeConsent(AppUser, ConsentType)` - update revoked_at
   - `hasConsent(AppUser, ConsentType): bool` - check active consent
   - `getConsentStatus(AppUser): array` - all consent types
5. Integrate with ingestion pipeline: reject events when consent required but not granted

### Acceptance Criteria
- [ ] Consent records stored with full audit trail
- [ ] Consent grant/revoke works correctly
- [ ] Ingestion respects consent requirements
- [ ] Tests verify consent enforcement

---

## Task 7.2: Create Audit Log System
**Priority:** Critical | **Estimate:** 2-3 hours | **Blocked by:** Plan 01

### Steps
1. Create migration for `audit_logs` table:
   - `id (uuid)`, `team_id (fk, nullable)`, `user_id (fk users, nullable)`, `action (string)`, `resource_type (string)`, `resource_id (string, nullable)`, `metadata (jsonb, default {})`, `ip_address (string, nullable, truncated)`, `created_at`
   - Index: `(team_id, created_at desc)`, `(action, created_at desc)`, `(resource_type, resource_id)`
2. Create `AuditLog` model
3. Create `Auditable` trait with `logAudit()` helper method
4. Create `AuditService` with static `log()` method
5. Define audit action constants/enum for all mandatory actions
6. Configure retention: audit logs kept for minimum 5 years
7. Apply `Auditable` trait to relevant controllers/services

### Acceptance Criteria
- [ ] Audit log captures all mandatory actions per Plan 07
- [ ] IP addresses truncated for privacy
- [ ] Metadata stored as structured JSON
- [ ] 5-year retention configured
- [ ] Trait provides easy logging API

---

## Task 7.3: Implement Data Deletion Workflow (GDPR Art. 17)
**Priority:** Critical | **Estimate:** 4-6 hours | **Blocked by:** Tasks 7.1, 7.2, Plan 03

### Steps
1. Create admin UI form: "Data Subject Erasure Request"
   - Input: user_id or anonymous_id
   - Scope selection: full erasure (default) / pseudonymization
   - Impact preview: show estimated event count, data categories
   - 30-day SLA notice
2. Create `ProcessDataDeletion` queue job:
   - Full erasure: delete from events, sessions, crash_reports, traces, app_users where linked to target user
   - Pseudonymize: replace user identifiers with irreversible hash, keep aggregate data
   - Preserve consent records for accountability (Art. 7)
   - Flag for backup exclusion
   - Generate deletion certificate (PDF or JSON proof)
   - Update request status with timestamps
   - Log all actions in audit trail
3. Create `DeletionService` orchestrating the workflow
4. API endpoint: `POST /api/v1/projects/{project}/compliance/erasure`
5. SLA tracking: 30-day countdown from request, auto-escalation

### Acceptance Criteria
- [ ] Full erasure removes all personal data
- [ ] Pseudonymization replaces identifiers irreversibly
- [ ] Consent records preserved
- [ ] Deletion certificate generated
- [ ] 30-day SLA tracked
- [ ] Audit trail complete
- [ ] Tests verify both erasure modes

---

## Task 7.4: Implement Data Export Workflow (GDPR Art. 15, 20)
**Priority:** Critical | **Estimate:** 3-4 hours | **Blocked by:** Task 7.2, Plan 03

### Steps
1. Create admin UI: "Data Subject Access Request" form
   - Input: user_id or anonymous_id
   - 30-day SLA notice
2. Create `ProcessDataExport` queue job:
   - Collect: user profile, events, sessions, crash reports, traces, consent records
   - Include metadata: data categories, processing purposes, retention info, recipients
   - Package as structured JSON (machine-readable per Art. 20)
   - Create ZIP archive
   - Store with signed temporary URL (48-hour expiry)
   - Notify admin when ready
   - Log in audit trail
3. Create `ExportService` orchestrating the workflow
4. Download endpoint with signed URL verification
5. 30-day SLA tracking

### Acceptance Criteria
- [ ] Export includes all personal data categories
- [ ] JSON format is machine-readable and structured
- [ ] Download URL expires after 48 hours
- [ ] 30-day SLA tracked
- [ ] Audit trail complete

---

## Task 7.5: Implement Retention Enforcement
**Priority:** High | **Estimate:** 2-3 hours | **Blocked by:** Plan 03, Plan 04

### Steps
1. Create Artisan command: `analytics:enforce-retention`
2. Logic:
   - For each environment, query retention settings
   - Delete raw events older than `retention_days_raw`
   - Preserve aggregates up to `retention_days_agg`
   - Crash reports: redact PII after retention, keep fingerprint + count
   - Traces: delete raw after retention, keep aggregated percentiles
   - Consent records: never delete (Art. 7 accountability)
   - Batch deletes (e.g., 1000 at a time) to prevent lock contention
3. Register in Laravel scheduler: daily at 2:00 AM UTC
4. Log all retention actions in audit trail
5. Send notification to team admin with retention summary

### Acceptance Criteria
- [ ] Old data deleted per environment retention settings
- [ ] Aggregates preserved
- [ ] Consent records preserved
- [ ] Batch deletion prevents performance issues
- [ ] Audit trail logged
- [ ] Scheduled to run daily

---

## Task 7.6: Create PII Detection & Configuration UI
**Priority:** High | **Estimate:** 2-3 hours | **Blocked by:** Plan 03

### Steps
1. Create `PiiDetector` service in `app/Services/Compliance/`:
   - Detect email patterns in property values
   - Detect phone number patterns
   - Detect common PII field names (name, address, ssn, etc.)
   - Configurable sensitivity level
2. Create Livewire component: `PiiSettings`
   - PII mode toggle (strict/permissive)
   - Allowlist editor (add/remove property keys)
   - Denylist editor (add/remove property keys)
   - IP truncation toggle (default ON)
   - User ID hashing mode selector (default SHA-256)
   - Default denylist: email, phone, name, address, ip, ssn, credit_card
3. Connect to PiiFilter service from Plan 04

### Acceptance Criteria
- [ ] PII detection catches common patterns
- [ ] Allowlist/denylist configurable via UI
- [ ] EU-strict defaults applied
- [ ] Settings persist per environment

---

## Task 7.7: Create Data Breach Notification Foundation
**Priority:** Medium | **Estimate:** 2-3 hours | **Blocked by:** Task 7.2

### Steps
1. Create migration for `data_breach_incidents` table
2. Create `DataBreachIncident` model
3. Admin UI: breach incident logging form with:
   - Description, severity, affected data categories
   - Estimated affected user count
   - 72-hour supervisory authority notification deadline tracker
   - Template for authority notification (GDPR Art. 33)
4. Audit trail logging

### Acceptance Criteria
- [ ] Breach incidents can be logged
- [ ] 72-hour deadline tracked
- [ ] Notification template available

---

## Task 7.8: Create Compliance Dashboard
**Priority:** High | **Estimate:** 3-4 hours | **Blocked by:** Tasks 7.1-7.7

### Steps
1. Create Livewire page: `ComplianceDashboard`
2. Route: `GET /projects/{project}/compliance`
3. Sections:
   - DSAR list with 30-day SLA status (green/yellow/red)
   - Deletion requests with status and certificates
   - Export requests with download links
   - Consent overview per environment
   - Retention policy overview
   - Audit log viewer with filtering
   - Data breach incidents
4. Add to project sidebar navigation

### Acceptance Criteria
- [ ] All compliance data visible in one place
- [ ] SLA indicators show status clearly
- [ ] Audit logs searchable and filterable
- [ ] Page accessible only to team owners/admins

---

## Task 7.9: Write Compliance Tests
**Priority:** Critical | **Estimate:** 3-4 hours | **Blocked by:** Tasks 7.1-7.8

### Steps
1. Feature test: DSAR creates request with 30-day deadline
2. Feature test: full erasure removes all user-linked data
3. Feature test: pseudonymization nullifies identifiers but keeps aggregates
4. Feature test: deletion certificate generated
5. Feature test: data export contains all required categories
6. Feature test: export download URL expires correctly
7. Feature test: retention enforcement deletes old data, keeps consent records
8. Feature test: consent enforcement blocks events without consent
9. Unit test: PII detection patterns
10. Unit test: IP truncation (IPv4 and IPv6)
11. Unit test: audit trail logging
12. Unit test: SLA deadline calculation

### Acceptance Criteria
- [ ] All tests pass
- [ ] GDPR workflows fully tested
- [ ] Zero test failures
