# Sub-Tasks: Plan 08 - Billing Placeholder

---

## Task 8.1: Create Plan Model & Seeder

### Sub-task 8.1.1: Create plans migration
- Run `php artisan make:model Plan -mfs --no-interaction` (model + migration + factory + seeder)
- Columns: `uuid('id')->primary()`, `string('name')`, `string('slug')->unique()`, `text('description')->nullable()`, `integer('event_limit')` (-1 = unlimited), `integer('retention_days')`, `integer('team_member_limit')` (-1 = unlimited), `integer('project_limit')` (-1 = unlimited), `integer('price_monthly_cents')->nullable()`, `integer('price_yearly_cents')->nullable()`, `boolean('is_active')->default(true)`, `integer('sort_order')->default(0)`, `timestamps()`

### Sub-task 8.1.2: Define Plan model
- HasUuids, fillable, casts
- Method: `isUnlimited(string $resource): bool` → check if limit == -1
- Method: `formattedPrice(): string` → format cents to EUR with 2 decimals
- Scope: `scopeActive($query)` → where is_active = true

### Sub-task 8.1.3: Create PlanSeeder
- Seed 4 plans with specific limits:
  - Free: slug `free`, 10000 events, 7 days retention, 2 members, 1 project, 0 price
  - Trial: slug `trial`, 100000 events, 30 days, 5 members, 3 projects, 0 price
  - Pro: slug `pro`, 1000000 events, 90 days, 20 members, 10 projects, 4900 cents/mo, 49000 cents/yr
  - Enterprise: slug `enterprise`, -1 events, 365 days, -1 members, -1 projects, null prices (custom)
- Register seeder in DatabaseSeeder

### Sub-task 8.1.4: Create EntitlementService
- `app/Services/EntitlementService.php`
- Constructor: accepts Team
- Method: `getEventLimit(): int` → resolve from team's subscription plan
- Method: `getRetentionDays(): int`
- Method: `getTeamMemberLimit(): int`
- Method: `getProjectLimit(): int`
- Method: `canCreateProject(): bool` → current projects < limit
- Method: `canIngestEvents(): bool` → current month events < limit
- Method: `getCurrentUsage(): array` → return all current usage counts
- Method: `getUsagePercentage(string $resource): float` → current / limit * 100
- Fallback: if no subscription, use Free plan

### Sub-task 8.1.5: Write EntitlementService tests
- Test resolves correct limits per plan
- Test unlimited resources return -1
- Test no subscription defaults to Free
- Test canCreateProject checks correctly
- Test usage percentage calculation

---

## Task 8.2: Billing UI & Upgrade CTAs

### Sub-task 8.2.1: Create BillingSettings Livewire component
- `php artisan make:livewire BillingSettings --no-interaction`
- Display current plan name, description, limits
- Show usage bars for events, members, projects
- Feature comparison table (Free vs Trial vs Pro vs Enterprise)

### Sub-task 8.2.2: Create plan comparison table
- Blade partial: `resources/views/components/plan-comparison.blade.php`
- Columns: one per plan
- Rows: events, retention, members, projects, price
- Highlight current plan
- "Upgrade" button on higher plans (links to contact form or placeholder)

### Sub-task 8.2.3: Create UpgradeCta Blade component
- `resources/views/components/upgrade-cta.blade.php`
- Props: `$message`, `$planName` (target plan)
- Display: alert-style banner with upgrade message and CTA button
- Variants: `warning` (approaching limit), `danger` (at limit)

### Sub-task 8.2.4: Add upgrade CTAs to dashboard
- In ProjectDashboard: check usage percentage
- If any resource > 80%: show UpgradeCta with warning variant
- If any resource >= 100%: show UpgradeCta with danger variant

### Sub-task 8.2.5: Create CheckEntitlement middleware
- `php artisan make:middleware CheckEntitlement --no-interaction`
- Check team's entitlement before allowing actions:
  - Project creation: check project limit
  - Team member invitation: check member limit
- Return 403 with plan upgrade message if limit exceeded
- Register as middleware alias

### Sub-task 8.2.6: Add billing route
- `Route::get('/teams/{team}/billing', BillingSettings::class)->name('teams.billing')`
- Add "Billing" link to team settings navigation

### Sub-task 8.2.7: Wire subscription creation on team creation
- In CreateTeam action or observer: assign Free plan subscription to new team
- Set `current_period_start` and `current_period_end`

### Sub-task 8.2.8: Write billing tests
- Test current plan displayed correctly
- Test upgrade CTA shown at 80% threshold
- Test entitlement middleware blocks over-limit project creation
- Test new team gets Free plan subscription
