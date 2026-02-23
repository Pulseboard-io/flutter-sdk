# Tasks: Plan 08 - Billing Placeholder

## References
- Plan: [08-billing-placeholder.md](../Plans/08-billing-placeholder.md)

---

## Task 8.1: Create Plan Model & Seeder
**Priority:** Medium | **Estimate:** 1-2 hours | **Blocked by:** Plan 03

### Steps
1. Create `plans` migration: `id, name, slug, description, event_limit, retention_days, team_member_limit, project_limit, price_monthly, price_yearly, is_active, sort_order, created_at, updated_at`
2. Create `Plan` model
3. Create seeder with 4 tiers: Free, Trial, Pro, Enterprise
4. Create `EntitlementService` to resolve current limits from team's plan

### Acceptance Criteria
- [ ] 4 plans seeded
- [ ] EntitlementService resolves limits correctly

---

## Task 8.2: Billing UI & Upgrade CTAs
**Priority:** Medium | **Estimate:** 2-3 hours | **Blocked by:** Task 8.1

### Steps
1. Create Livewire page: `BillingSettings` in team settings
2. Display current plan with feature comparison
3. Create reusable `UpgradeCta` component
4. Show upgrade CTAs when approaching limits (80% event usage)
5. Create `CheckEntitlement` middleware for plan limit enforcement

### Acceptance Criteria
- [ ] Current plan displayed correctly
- [ ] Upgrade CTA shown at limit thresholds
- [ ] Entitlement middleware blocks over-limit actions
