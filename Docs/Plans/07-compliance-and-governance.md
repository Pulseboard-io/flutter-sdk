# Plan 07: Compliance & Governance (EU-First / GDPR-First)

## Objective
Implement comprehensive EU privacy compliance: GDPR data subject rights, ePrivacy Directive considerations, data residency awareness, consent management foundations, retention enforcement, audit trails, and PII filtering. This application targets the European market as its primary audience.

## Current State
- No compliance workflows exist
- Data model placeholders for `data_export_jobs` and `data_deletion_requests` defined in Plan 03
- PII mode and retention settings defined per environment in Plan 03

## Target State
- Full GDPR Article 17 (Right to Erasure) implementation
- Full GDPR Article 20 (Right to Data Portability) implementation
- GDPR Article 15 (Right of Access) support
- GDPR Article 30 (Records of Processing Activities) foundation
- Consent tracking and lawful basis documentation per data processing activity
- Cookie/tracking consent integration points for ePrivacy compliance
- Configurable data residency settings (EU-only storage flag)
- Automated retention enforcement with GDPR-compliant data minimization
- Comprehensive audit trail for all data processing activities
- Data Processing Agreement (DPA) acknowledgment workflow
- PII filtering rules configurable per environment
- Admin UI for managing compliance requests with SLA tracking
- Data breach notification workflow foundation

## GDPR-Specific Requirements

### Lawful Basis for Processing
- Each project/environment must declare its lawful basis for analytics data processing:
  - Legitimate interest (most common for analytics)
  - Consent (when required)
- Store lawful basis declaration per environment
- SDK must support consent mode: when consent is required, SDK holds events until consent is granted

### Data Subject Rights (Articles 15-22)
| Right | Article | Implementation |
|-------|---------|---------------|
| Right of Access | Art. 15 | Data export in machine-readable format |
| Right to Rectification | Art. 16 | User property correction API |
| Right to Erasure | Art. 17 | Full deletion or pseudonymization workflow |
| Right to Restrict Processing | Art. 18 | Processing hold flag per user |
| Right to Data Portability | Art. 20 | JSON export with standard schema |
| Right to Object | Art. 21 | Opt-out mechanism, processing stop |

### Data Protection by Design (Article 25)
- IP truncation enabled by default (not optional)
- User ID hashing enabled by default
- Data minimization: only collect what's necessary
- Pseudonymization as default processing approach
- Privacy-preserving defaults for all new environments

## Implementation Steps

### 7.1 Consent & Lawful Basis Management
- Add `lawful_basis` enum to environments: `legitimate_interest`, `consent`
- Add `consent_required` boolean to environments (default: false)
- Create `consent_records` table:
  - `id (uuid)`, `environment_id`, `app_user_id`, `consent_type (enum: analytics/crash_reporting/performance)`, `granted (bool)`, `granted_at`, `revoked_at`, `ip_address (truncated)`, `created_at`
- SDK integration: consent mode holds events until consent granted
- Consent withdrawal triggers processing restriction

### 7.2 Data Deletion Workflow (Art. 17)
- Admin UI: "Delete User Data" form with GDPR-specific language
  - Input: user_id or anonymous_id
  - Scope: full erasure (default per GDPR) or pseudonymization (where legitimate interest allows aggregate retention)
  - Impact preview (event count, data categories affected)
  - 30-day SLA countdown display
- `ProcessDataDeletion` queue job:
  - Full erasure: remove all personal data across events, sessions, crash reports, traces
  - Pseudonymize: replace identifiers with irreversible tokens, keep aggregate data
  - Cascade to backups: flag for backup exclusion
  - Update `data_deletion_requests` status with timestamps
  - Generate deletion certificate (proof of deletion)
- API endpoint: `POST /api/v1/projects/{project}/compliance/erasure`
- SLA enforcement: auto-escalate if not completed within 30 days (GDPR requirement)

### 7.3 Data Access & Portability (Art. 15, 20)
- Admin UI: "Export User Data" (DSAR - Data Subject Access Request)
  - Input: user_id or anonymous_id
  - Export format: JSON (machine-readable, interoperable)
  - Includes: all personal data categories, processing purposes, retention periods, third-party recipients
- `ProcessDataExport` queue job:
  - Collect: user profile, events, sessions, crash reports, traces, consent records
  - Include metadata: data categories, processing purposes, retention info
  - Package as structured JSON archive (zip)
  - Generate signed temporary download URL (expires in 48 hours)
  - Notify admin when ready
- Response deadline tracking: 30-day GDPR deadline
- API endpoint: `POST /api/v1/projects/{project}/compliance/access-request`

### 7.4 Retention Enforcement (Data Minimization - Art. 5(1)(e))
- Scheduled command: `analytics:enforce-retention`
  - Run daily via Laravel scheduler
  - For each environment, delete raw events older than `retention_days_raw`
  - Default retention: 90 days raw, 13 months aggregated (proportionate to purpose)
  - Batch deletes to avoid lock contention
  - Log retention actions for audit (Art. 30 compliance)
- Crash reports: redact PII after retention period, keep anonymized fingerprint + count
- Performance traces: delete raw after retention, keep aggregated percentiles
- Consent records: retained for accountability (Art. 7(1)) even after data deletion

### 7.5 Comprehensive Audit Trail (Art. 30 - Records of Processing)
- Create `audit_logs` table:
  - `id (uuid)`, `team_id`, `user_id (actor)`, `action (enum)`, `resource_type`, `resource_id`, `metadata (jsonb)`, `ip_address (truncated)`, `created_at`
- Mandatory audit actions:
  - `dsar_received` - Data Subject Access Request logged
  - `data_deletion_requested`, `data_deletion_completed`, `data_deletion_certificate_generated`
  - `data_export_requested`, `data_export_completed`, `data_export_downloaded`
  - `consent_granted`, `consent_revoked`
  - `retention_enforcement_run`, `retention_data_purged`
  - `processing_restriction_applied`, `processing_restriction_lifted`
  - `project_key_created`, `project_key_revoked`
  - `environment_settings_changed`, `pii_settings_changed`
  - `lawful_basis_changed`
  - `data_breach_reported` (foundation)
- `AuditLog` model and `Auditable` trait for easy logging
- Audit logs retained for minimum 5 years (regulatory recommendation)

### 7.6 PII Filtering & Privacy-by-Default Configuration
- Per-environment settings UI:
  - Privacy mode: strict (EU-recommended default) / permissive
  - **IP truncation: ON by default** (last octet zeroed for IPv4, last 80 bits for IPv6)
  - **User ID hashing: SHA-256 by default**
  - Property allowlist: keys explicitly allowed for collection
  - Property denylist: keys always dropped (e.g., `email`, `phone`, `name`, `address`)
  - Default denylist includes common PII field names
- PII filter service (integrated into ingestion pipeline):
  - Check properties against allowlist/denylist
  - Auto-detect potential PII patterns (email regex, phone regex) and flag/drop
  - Apply IP truncation
  - Hash user identifiers
  - Log dropped fields for transparency

### 7.7 Data Residency Awareness
- Per-environment `data_region` setting (EU/US/auto)
- For MVP: document that self-hosted deployments should use EU-region infrastructure
- Display data processing location in project settings
- Foundation for future multi-region deployment

### 7.8 Data Breach Notification Foundation (Art. 33, 34)
- `data_breach_incidents` table:
  - `id`, `team_id`, `reported_by`, `description`, `severity`, `affected_data_categories`, `affected_user_count_estimate`, `status`, `notified_authority_at`, `notified_users_at`, `created_at`
- Admin UI: breach incident logging form
- 72-hour notification deadline tracking (Art. 33)
- Template for supervisory authority notification

### 7.9 Compliance Dashboard & DPA
- Livewire page: Privacy & Compliance Center
  - DSAR requests list with 30-day SLA status indicators
  - Deletion requests with completion certificates
  - Export requests with download links
  - Consent overview per environment
  - Retention policy overview
  - Audit log viewer with advanced filtering
  - Data breach incidents (if any)
- DPA (Data Processing Agreement) acknowledgment:
  - Required checkbox during team/project setup
  - Store DPA version accepted and timestamp
  - Link to DPA document

## Dependencies
- Plan 03 (Data model)
- Plan 04 (Ingestion pipeline - PII filter integration)

## Testing Requirements
- Feature test: DSAR creates request with 30-day deadline
- Feature test: full erasure removes all user-linked data and generates certificate
- Feature test: pseudonymization nullifies identifiers but keeps aggregate data
- Feature test: data export generates structured JSON with all required categories
- Feature test: retention enforcement deletes old data, keeps consent records
- Feature test: consent record creation and revocation
- Feature test: processing restriction prevents new data processing for user
- Unit test: PII filter correctly applies allowlist/denylist and auto-detection
- Unit test: IP truncation works for IPv4 and IPv6
- Unit test: audit trail logs all mandatory actions
- Unit test: 30-day SLA tracking and escalation
- Integration test: end-to-end deletion workflow with certificate

## Estimated Effort
4-7 person-weeks

## Files to Create
- `app/Jobs/ProcessDataDeletion.php`
- `app/Jobs/ProcessDataExport.php`
- `app/Console/Commands/EnforceRetention.php`
- `app/Models/AuditLog.php`
- `app/Models/ConsentRecord.php`
- `app/Models/DataBreachIncident.php`
- `app/Services/Compliance/DeletionService.php`
- `app/Services/Compliance/ExportService.php`
- `app/Services/Compliance/ConsentService.php`
- `app/Services/Compliance/PiiDetector.php`
- `app/Traits/Auditable.php`
- `app/Enums/LawfulBasis.php`
- `app/Enums/ConsentType.php`
- `database/migrations/*_create_audit_logs_table.php`
- `database/migrations/*_create_consent_records_table.php`
- `database/migrations/*_create_data_breach_incidents_table.php`
- `database/migrations/*_add_lawful_basis_to_environments.php`
- Livewire components for compliance UI
- Blade views
- 15+ test files
