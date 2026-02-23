# Plan 08: Billing Placeholder

## Objective
Implement billing placeholder model and UI surfaces without any payment provider integration. No Spark coupling.

## Current State
- No billing models or UI exist
- PRD explicitly excludes Spark integration

## Target State
- Plans table with Free/Trial/Pro/Enterprise tiers
- Per-team subscription state and entitlements
- Billing settings page with current plan display
- "Upgrade" CTA surfaces throughout the dashboard
- Entitlement checks in middleware/gates (event limits, retention limits, team member limits)
- No payment provider wiring

## Implementation Steps

### 8.1 Billing Models
- `Plan` model with seeded plans:
  - Free: 10k events/month, 7-day retention, 2 team members, 1 project
  - Trial: 100k events/month, 30-day retention, 5 team members, 3 projects (14-day trial)
  - Pro: 1M events/month, 90-day retention, 20 team members, 10 projects
  - Enterprise: unlimited events, 365-day retention, unlimited members, unlimited projects
- `BillingSubscription` model (from Plan 03 migration)
- Entitlement resolution: `EntitlementService` that resolves current limits from plan

### 8.2 Billing UI
- Team settings: "Billing" tab
  - Current plan display with feature comparison table
  - Trial countdown (if applicable)
  - "Upgrade" button (shows contact/placeholder)
- Dashboard upgrade CTAs: show when approaching limits
- "Usage" section: current event count vs plan limit

### 8.3 Entitlement Middleware
- `CheckEntitlement` middleware for enforcing plan limits
- Gates for plan-specific features (e.g., advanced retention requires Pro+)

## Dependencies
- Plan 01 (Platform Foundation)
- Plan 03 (Data Model)

## Testing Requirements
- Unit test: EntitlementService resolves correct limits per plan
- Feature test: upgrade CTA shown when limits approached
- Feature test: entitlement middleware blocks actions beyond plan limits

## Estimated Effort
1-2 person-weeks
