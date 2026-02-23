# Project Status: Pulseboard Platform

## Last Updated
2026-02-23

## Current Phase
**Phase 0: Planning Complete** - Plans and tasks defined, ready for implementation.

## Overall Progress

| Epic | Status | Progress |
|------|--------|----------|
| 01 - Platform Foundation | Not Started | 0% |
| 02 - Auth & Org Model | Not Started | 0% |
| 03 - Data Model & Project Mgmt | Not Started | 0% |
| 04 - Ingestion API & Processing | Not Started | 0% |
| 05 - Flutter SDK | Not Started | 0% |
| 06 - Analytics Dashboards | Not Started | 0% |
| 07 - Compliance & Governance | Not Started | 0% |
| 08 - Billing Placeholder | Not Started | 0% |
| 09 - Quality & CI/CD | Not Started | 0% |

## Recent Changes

### 2026-02-23
- Documentation updated: extensible SocialAuthController pattern (generic redirect/callback, config-driven providers)
- Documentation updated: Hetzner Cloud Germany + Laravel Forge hosting details added to CLAUDE.md, AGENTS.md, STATUS.md
- Project analyzed and deep-dived
- 9 detailed plans created in `Docs/Plans/`
- 9 task breakdown files created in `Docs/Tasks/`
- CLAUDE.md and AGENTS.md written with comprehensive AI instructions
- STATUS.md created for change tracking
- Existing state: Laravel 12 + Jetstream scaffold (fresh install)
- Flutter SDK directory is empty (not started)

## Decisions Log

| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-02-23 | No Laravel Passport | Use Sanctum for all API token needs; simpler, already installed |
| 2026-02-23 | EU-first privacy model | Primary market is European; GDPR-first, privacy-by-default |
| 2026-02-23 | PostgreSQL over SQLite | Production-ready, supports jsonb, GIN indexes for analytics |
| 2026-02-23 | No Spark billing | Placeholder billing only for MVP, no payment provider coupling |
| 2026-02-23 | Hetzner Cloud Germany + Laravel Forge | EU data residency for GDPR compliance; Forge for managed deployments, SSL, daemons |
| 2026-02-23 | PostgreSQL 16 + Redis 7 on Hetzner | Co-located with app servers in Germany; no cross-border data transfers |
| 2026-02-23 | Ubuntu 24.04 LTS | LTS for stability; Forge-supported |
| 2026-02-23 | Extensible SocialAuthController pattern | Generic redirect/callback with config-driven provider list instead of per-provider methods |
| 2026-02-23 | Sentry-like DSN for SDK | Single config string replaces writeKey + endpoint + environment; easier onboarding |
| 2026-02-23 | Renamed to "Pulseboard" | Full rebrand from "App Analytics"; Flutter package stays `app_analytics` |

## Blockers
- None currently

## Next Steps
1. Begin Plan 01: Platform Foundation (PostgreSQL, Redis, Horizon, Pennant, Design System)
2. Then Plan 02: Auth & Org Model (Socialite, email verification)
3. Then Plan 03: Data Model (all analytics entities)
