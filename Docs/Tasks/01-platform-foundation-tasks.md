# Tasks: Plan 01 - Platform Foundation

## References
- Plan: [01-platform-foundation.md](../Plans/01-platform-foundation.md)
- PRD: [PRD.md](../PRD.md)

---

## Task 1.1: Switch Database to PostgreSQL
**Priority:** Critical | **Estimate:** 2-3 hours | **Blocked by:** None

### Description
Switch the application's default database from SQLite to PostgreSQL.

### Steps
1. Update `.env` to set `DB_CONNECTION=pgsql` with PostgreSQL credentials
2. Update `.env.example` with PostgreSQL placeholder values
3. Ensure `config/database.php` pgsql connection is properly configured
4. Review all existing migrations for PostgreSQL compatibility (e.g., ensure `uuid` types work)
5. Create the PostgreSQL database
6. Run `php artisan migrate:fresh` against PostgreSQL
7. Run `php artisan test --compact` to verify all existing tests pass

### Acceptance Criteria
- [ ] `.env` and `.env.example` updated with PostgreSQL configuration
- [ ] All 10 existing migrations run successfully against PostgreSQL
- [ ] All 21+ existing Jetstream tests pass against PostgreSQL
- [ ] SQLite database file is no longer used in development

---

## Task 1.2: Configure Redis Queue Connection
**Priority:** Critical | **Estimate:** 1-2 hours | **Blocked by:** None

### Steps
1. Update `.env` to set `QUEUE_CONNECTION=redis`
2. Verify Redis connection settings in `config/database.php`
3. Ensure `predis/predis` is installed (already in composer.json)
4. Test queue dispatch and processing with a simple test job
5. Update `.env.example` with Redis queue defaults

### Acceptance Criteria
- [ ] `QUEUE_CONNECTION=redis` in `.env`
- [ ] Queue jobs dispatch to Redis and are processable
- [ ] Redis connection verified working

---

## Task 1.3: Configure Horizon Dashboard & Supervisors
**Priority:** High | **Estimate:** 2-3 hours | **Blocked by:** Task 1.2

### Steps
1. Update `config/horizon.php`:
   - Configure `local` environment with reasonable worker counts
   - Configure `production` environment with separate queues: `default`, `ingest`, `compliance`
   - Set memory limits and timeout values
2. Update `HorizonServiceProvider` gate to allow team owners/admins access
3. Verify Horizon dashboard loads at `/horizon`
4. Test that jobs run through Horizon workers
5. Add Horizon to `composer run dev` script for local development

### Acceptance Criteria
- [ ] Horizon dashboard accessible at `/horizon` with proper authorization
- [ ] Queue supervisors configured for `default`, `ingest`, and `compliance` queues
- [ ] Jobs processed through Horizon workers
- [ ] Horizon gate restricts access to authorized users only

---

## Task 1.4: Bootstrap Pennant Feature Flags
**Priority:** Medium | **Estimate:** 2-3 hours | **Blocked by:** Task 1.1

### Steps
1. Create feature flag classes in `app/Features/`:
   - `SdkReactNative.php` - gates React Native SDK access
   - `DashboardPerformance.php` - gates performance dashboard
   - `DashboardBeta.php` - gates beta dashboard features
   - `ExportsEnabled.php` - gates data export features
   - `RetentionAdvanced.php` - gates advanced retention settings
2. Scope features to Team model (use `$team->id` as scope)
3. Register features in `AppServiceProvider` if needed
4. Write tests verifying flag resolution per team

### Acceptance Criteria
- [ ] 5 feature flag classes created in `app/Features/`
- [ ] Flags resolve correctly for different teams
- [ ] Pest tests verify flag activation/deactivation
- [ ] Flags stored in database via Pennant's database driver

---

## Task 1.5: Custom Design System - Tailwind Configuration
**Priority:** High | **Estimate:** 3-4 hours | **Blocked by:** None

### Steps
1. Define custom color palette in `tailwind.config.js`:
   - Primary, secondary, accent colors
   - Neutral scale for backgrounds/text
   - Semantic colors: success, warning, error, info
2. Define custom typography scale
3. Configure dark mode with `class` strategy (already Tailwind default approach)
4. Add custom component classes if needed (e.g., `.btn-primary`, `.card`)
5. Run `npm run build` to verify compilation

### Acceptance Criteria
- [ ] Custom color palette defined in Tailwind config
- [ ] Dark mode strategy set to `class`
- [ ] Assets compile without errors
- [ ] Color variables documented

---

## Task 1.6: Custom Layout Components
**Priority:** High | **Estimate:** 4-6 hours | **Blocked by:** Task 1.5

### Steps
1. Override Jetstream's `AppLayout` with custom sidebar navigation layout
2. Create reusable Blade/Livewire components:
   - `x-sidebar-nav` - collapsible sidebar with nav items
   - `x-top-bar` - top bar with team switcher, user menu, environment badge
   - `x-stat-card` - KPI card component (value, label, trend indicator)
   - `x-page-header` - page title with breadcrumbs
   - `x-empty-state` - empty state placeholder for pages with no data
3. Update dashboard view to use new layout
4. Ensure all views render correctly in light and dark mode

### Acceptance Criteria
- [ ] Custom sidebar navigation layout replaces stock Jetstream layout
- [ ] 5+ reusable UI components created
- [ ] Dashboard renders with custom styling
- [ ] Both light and dark modes render correctly

---

## Task 1.7: Dark Mode Toggle with Persistence
**Priority:** Medium | **Estimate:** 2-3 hours | **Blocked by:** Task 1.5, Task 1.6

### Steps
1. Create Livewire component `DarkModeToggle`
2. Use `localStorage` for client-side persistence
3. Apply `dark` class to `<html>` element based on preference
4. Add toggle to top bar component
5. Default to system preference with manual override
6. Optional: sync preference to user profile table (server-side)

### Acceptance Criteria
- [ ] Dark mode toggle visible in top bar
- [ ] Preference persists across page loads
- [ ] Defaults to system preference if no manual override
- [ ] All custom components respect dark mode

---

## Task 1.8: Base Application Configuration
**Priority:** Medium | **Estimate:** 1 hour | **Blocked by:** None

### Steps
1. Set `APP_NAME=Pulseboard` in `.env` and `.env.example`
2. Configure timezone to `UTC` (store all times in UTC)
3. Configure locale to `en`
4. Set up logging channels in `config/logging.php`: `daily` for local, `stderr` for production
5. Configure base rate limiting in `AppServiceProvider` boot method

### Acceptance Criteria
- [ ] App name set correctly
- [ ] Timezone set to UTC
- [ ] Logging channels configured
- [ ] Base rate limiting registered

---

## Task 1.9: Write Foundation Tests
**Priority:** High | **Estimate:** 2-3 hours | **Blocked by:** Tasks 1.1-1.4

### Steps
1. Test PostgreSQL connectivity and migrations
2. Test Redis queue dispatch and processing
3. Test Horizon dashboard access authorization
4. Test Pennant flag resolution for teams
5. Test dark mode toggle persistence (Livewire test)
6. Run full test suite: `php artisan test --compact`

### Acceptance Criteria
- [ ] All new tests pass
- [ ] All existing Jetstream tests still pass
- [ ] Zero test failures in full suite
