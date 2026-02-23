# Sub-Tasks: Plan 01 - Platform Foundation

---

## Task 1.1: Switch Database to PostgreSQL

### Sub-task 1.1.1: Install PostgreSQL via Docker/Sail
- Open `docker-compose.yml` (or create via `php artisan sail:install --no-interaction`)
- Add PostgreSQL service with version 16
- Expose port 5432 to host
- Set `POSTGRES_DB=pulseboard`, `POSTGRES_USER=sail`, `POSTGRES_PASSWORD=password`
- Verify container starts with `docker compose up -d`

### Sub-task 1.1.2: Update .env for PostgreSQL
- Set `DB_CONNECTION=pgsql`
- Set `DB_HOST=127.0.0.1` (or `pgsql` if using Sail)
- Set `DB_PORT=5432`
- Set `DB_DATABASE=pulseboard`
- Set `DB_USERNAME=sail`
- Set `DB_PASSWORD=password`
- Remove or comment out `DB_DATABASE` SQLite path reference

### Sub-task 1.1.3: Update .env.example
- Replace SQLite defaults with PostgreSQL placeholder values
- Add comment explaining PostgreSQL is required
- Ensure all DB_* variables are present with safe defaults

### Sub-task 1.1.4: Verify config/database.php PostgreSQL connection
- Open `config/database.php`
- Verify `pgsql` connection block reads from env correctly
- Confirm `charset` is `utf8`, `prefix` is empty, `schema` is `public`
- Verify `search_path` is set to `public`

### Sub-task 1.1.5: Audit existing migrations for PostgreSQL compatibility
- Open each migration in `database/migrations/`
- Check `0001_01_01_000000_create_users_table.php`: verify `id()` uses bigIncrements (compatible)
- Check `create_teams_table.php`: verify foreign key to users works
- Check `create_personal_access_tokens_table.php`: verify `morphs()` column type works
- Check `create_pulse_tables.php`: verify all column types are PostgreSQL-compatible
- Check `create_features_table.php`: verify jsonb/text types work
- Flag any SQLite-specific syntax (e.g., `PRAGMA`, `autoincrement` quirks)

### Sub-task 1.1.6: Create PostgreSQL database
- Run `createdb pulseboard` or use Docker exec
- Verify database is accessible: `psql -h 127.0.0.1 -U sail -d pulseboard -c '\dt'`

### Sub-task 1.1.7: Run migrations against PostgreSQL
- Execute `php artisan migrate:fresh --no-interaction`
- Verify all 10 migrations complete without errors
- Inspect tables: `php artisan tinker` → `Schema::getTableListing()`
- Verify table structure matches expectations

### Sub-task 1.1.8: Run full test suite against PostgreSQL
- Execute `php artisan test --compact`
- Verify all 21+ Jetstream tests pass
- Fix any test failures caused by PostgreSQL differences (e.g., case sensitivity, boolean handling)
- Confirm test database is created/destroyed properly (RefreshDatabase trait)

### Sub-task 1.1.9: Update phpunit.xml for PostgreSQL test database
- Open `phpunit.xml`
- Set `<env name="DB_CONNECTION" value="pgsql"/>`
- Set `<env name="DB_DATABASE" value="pulseboard_testing"/>`
- Create the test database if needed
- Verify tests still pass with explicit test DB config

### Sub-task 1.1.10: Remove SQLite database file
- Delete `database/database.sqlite`
- Update `.gitignore` to exclude any SQLite files if not already
- Verify no code references `database.sqlite` directly

---

## Task 1.2: Configure Redis Queue Connection

### Sub-task 1.2.1: Verify Redis server availability
- Check if Redis is running locally: `redis-cli ping` (expect `PONG`)
- If not running, add Redis to Docker Compose or install locally
- If using Sail, ensure Redis service is in `docker-compose.yml`

### Sub-task 1.2.2: Verify Redis configuration in config/database.php
- Open `config/database.php`
- Locate `redis` section
- Verify `client` is set to `phpredis` or `predis` (predis is in composer.json)
- Verify default connection has correct `host`, `password`, `port` reading from env
- Verify `REDIS_HOST`, `REDIS_PASSWORD`, `REDIS_PORT` are in `.env`

### Sub-task 1.2.3: Update .env queue connection
- Set `QUEUE_CONNECTION=redis`
- Add `REDIS_HOST=127.0.0.1` (or `redis` for Sail)
- Add `REDIS_PASSWORD=null`
- Add `REDIS_PORT=6379`

### Sub-task 1.2.4: Update .env.example
- Set `QUEUE_CONNECTION=redis` as default
- Include all REDIS_* variables with placeholder values

### Sub-task 1.2.5: Verify predis package is installed
- Run `composer show predis/predis` to confirm installation
- If not installed: `composer require predis/predis` (already listed in composer.json)

### Sub-task 1.2.6: Test Redis connectivity
- Run `php artisan tinker`
- Execute: `Cache::store('redis')->put('test', 'works', 60)` then `Cache::store('redis')->get('test')`
- Verify `works` is returned

### Sub-task 1.2.7: Create a simple test job to verify queue processing
- Create `app/Jobs/TestQueueJob.php` using `php artisan make:job TestQueueJob --no-interaction`
- Add simple `handle()` method that logs a message: `Log::info('Test queue job processed')`
- Dispatch from tinker: `TestQueueJob::dispatch()`
- Run worker: `php artisan queue:work redis --once`
- Check `storage/logs/laravel.log` for the logged message
- Delete the test job file after verification

### Sub-task 1.2.8: Verify queue configuration in config/queue.php
- Open `config/queue.php`
- Verify `redis` connection settings: `driver`, `connection`, `queue`, `retry_after`
- Set `retry_after` to 90 seconds (reasonable default)
- Verify `failed` job config points to `failed_jobs` table

---

## Task 1.3: Configure Horizon Dashboard & Supervisors

### Sub-task 1.3.1: Review current Horizon config
- Open `config/horizon.php`
- Note current settings for `prefix`, `path`, `use`, `middleware`
- Identify the `environments` section

### Sub-task 1.3.2: Configure local environment supervisors
- In `config/horizon.php` under `environments.local`:
  ```php
  'supervisor-default' => [
      'connection' => 'redis',
      'queue' => ['default'],
      'balance' => 'auto',
      'maxProcesses' => 3,
      'maxTime' => 3600,
      'maxJobs' => 500,
      'memory' => 128,
      'tries' => 3,
      'timeout' => 60,
  ],
  'supervisor-ingest' => [
      'connection' => 'redis',
      'queue' => ['ingest'],
      'balance' => 'auto',
      'maxProcesses' => 5,
      'maxTime' => 3600,
      'maxJobs' => 1000,
      'memory' => 256,
      'tries' => 3,
      'timeout' => 120,
  ],
  'supervisor-compliance' => [
      'connection' => 'redis',
      'queue' => ['compliance'],
      'balance' => 'auto',
      'maxProcesses' => 2,
      'maxTime' => 3600,
      'maxJobs' => 100,
      'memory' => 256,
      'tries' => 1,
      'timeout' => 300,
  ],
  ```

### Sub-task 1.3.3: Configure production environment supervisors
- In `config/horizon.php` under `environments.production`:
- Same queue structure but higher `maxProcesses`:
  - `default`: maxProcesses 5
  - `ingest`: maxProcesses 10
  - `compliance`: maxProcesses 3
- Set `balance` to `auto` for auto-scaling

### Sub-task 1.3.4: Update Horizon gate for authorization
- Open `app/Providers/HorizonServiceProvider.php`
- Update `gate()` method:
  ```php
  protected function gate(): void
  {
      Gate::define('viewHorizon', function (User $user) {
          return $user->ownsTeam($user->currentTeam)
              || $user->hasTeamRole($user->currentTeam, 'admin');
      });
  }
  ```
- Ensure gate checks team ownership or admin role

### Sub-task 1.3.5: Set Horizon prefix and path
- In `config/horizon.php`:
  - Set `'prefix' => config('app.name', 'Pulseboard') . '_horizon:'`
  - Verify `'path' => 'horizon'`
  - Set `'middleware' => ['web', 'auth']`

### Sub-task 1.3.6: Test Horizon dashboard loads
- Start Horizon: `php artisan horizon`
- Visit `http://localhost:8000/horizon` (or get URL via `get-absolute-url` tool)
- Verify dashboard loads with queue monitoring UI
- Verify unauthorized users cannot access

### Sub-task 1.3.7: Test job processing through Horizon
- With Horizon running, dispatch a test job from tinker
- Verify it appears in Horizon dashboard under "Recent Jobs"
- Verify it completes successfully

### Sub-task 1.3.8: Add Horizon to dev script
- Open `composer.json`
- Add `"horizon"` command to `scripts.dev` or create new script:
  ```json
  "horizon:dev": "php artisan horizon"
  ```
- Or update existing `dev` script to include Horizon alongside Vite

---

## Task 1.4: Bootstrap Pennant Feature Flags

### Sub-task 1.4.1: Create SdkReactNative feature flag
- Create `app/Features/SdkReactNative.php`:
  ```php
  class SdkReactNative
  {
      public function resolve(Team $team): bool
      {
          return false; // Disabled by default until React Native is ready
      }
  }
  ```
- Use `php artisan make:class Features/SdkReactNative --no-interaction` if artisan supports it

### Sub-task 1.4.2: Create DashboardPerformance feature flag
- Create `app/Features/DashboardPerformance.php`
- Default resolve: `false` (gated behind Pro+ plan or explicit activation)
- Scope to Team model

### Sub-task 1.4.3: Create DashboardBeta feature flag
- Create `app/Features/DashboardBeta.php`
- Default resolve: `false`
- Used for beta testing new dashboard features

### Sub-task 1.4.4: Create ExportsEnabled feature flag
- Create `app/Features/ExportsEnabled.php`
- Default resolve: `false` (gated behind plan entitlement)

### Sub-task 1.4.5: Create RetentionAdvanced feature flag
- Create `app/Features/RetentionAdvanced.php`
- Default resolve: `false` (requires Pro+ plan)

### Sub-task 1.4.6: Verify Pennant database driver configuration
- Open `config/pennant.php`
- Verify `'default' => 'database'`
- Verify `'stores.database.table' => 'features'`
- Confirm `features` table migration exists and has been run

### Sub-task 1.4.7: Register feature flags for Team scope
- Open `app/Providers/AppServiceProvider.php`
- Add in `boot()`:
  ```php
  Feature::discover();
  ```
  or explicitly register features if needed
- Verify Pennant auto-discovers classes in `app/Features/`

### Sub-task 1.4.8: Write Pest test for feature flag resolution
- Create `tests/Feature/FeatureFlagTest.php`
- Test: `SdkReactNative` resolves to `false` for a new team
- Test: activating `SdkReactNative` for a team changes resolution
- Test: `DashboardBeta` can be activated per team
- Test: feature flags persist in database
- Test: deactivating a flag works

### Sub-task 1.4.9: Test flag resolution via tinker
- Run `php artisan tinker`
- Create a team, check flag: `Feature::for($team)->active(SdkReactNative::class)`
- Activate: `Feature::for($team)->activate(SdkReactNative::class)`
- Verify active after activation

---

## Task 1.5: Custom Design System - Tailwind Configuration

### Sub-task 1.5.1: Define primary color palette
- Open `tailwind.config.js`
- Add under `theme.extend.colors`:
  ```js
  primary: {
    50: '#f0f5ff', 100: '#e0ebff', ..., 600: '#2563eb', 700: '#1d4ed8', ..., 950: '#172554'
  }
  ```
- Choose an analytics-friendly blue palette (trustworthy, professional)

### Sub-task 1.5.2: Define secondary and accent colors
- Add secondary color (slate/gray-based for neutral surfaces)
- Add accent color (teal or emerald for success/positive metrics)
- Add danger color (red for crashes, errors)
- Add warning color (amber for rate limit warnings)

### Sub-task 1.5.3: Define neutral color scale
- Add `neutral` or `surface` colors for backgrounds, borders, text
- Ensure contrast ratios meet WCAG AA standards
- Light mode: light backgrounds, dark text
- Dark mode: dark backgrounds, light text

### Sub-task 1.5.4: Define semantic color aliases
- Add `success`, `warning`, `error`, `info` aliases:
  ```js
  success: colors.emerald,
  warning: colors.amber,
  error: colors.red,
  info: colors.blue,
  ```

### Sub-task 1.5.5: Configure typography scale
- Set `fontFamily.sans` to a modern sans-serif stack (Inter, system-ui)
- Set `fontFamily.mono` to a code-friendly font (JetBrains Mono, monospace)
- Define heading sizes if extending beyond Tailwind defaults

### Sub-task 1.5.6: Configure dark mode strategy
- Set `darkMode: 'class'` in `tailwind.config.js`
- Verify Tailwind compiles `dark:` variants correctly
- Test: adding `class="dark"` to `<html>` element changes styles

### Sub-task 1.5.7: Add custom component utilities (optional)
- Consider adding `@layer components` in `resources/css/app.css`:
  ```css
  @layer components {
    .btn-primary { @apply bg-primary-600 text-white rounded-lg px-4 py-2 hover:bg-primary-700 transition; }
    .card { @apply bg-white dark:bg-gray-800 rounded-xl shadow-sm border border-gray-200 dark:border-gray-700 p-6; }
  }
  ```

### Sub-task 1.5.8: Build and verify assets
- Run `npm run build`
- Verify no compilation errors
- Check `public/build/` for generated CSS
- Verify dark mode classes are included in output

---

## Task 1.6: Custom Layout Components

### Sub-task 1.6.1: Create AppLayout override
- Open `resources/views/layouts/app.blade.php` (Jetstream's layout)
- Replace stock layout with custom sidebar + top bar structure
- Structure: `<div class="flex h-screen">` with sidebar and main content area
- Add `@livewireStyles` in head, `@livewireScripts` before `</body>`
- Include `@stack('scripts')` for page-specific JS

### Sub-task 1.6.2: Create x-sidebar-nav Blade component
- Create `resources/views/components/sidebar-nav.blade.php`
- Props: `$items` (array of nav items), `$active` (current section)
- Structure: fixed-width sidebar with logo, nav links, team switcher at bottom
- Support icons (SVG or Heroicons) for each nav item
- Collapsible on mobile (Alpine.js toggle)
- Dark mode: `dark:bg-gray-900 dark:text-gray-100`

### Sub-task 1.6.3: Create x-top-bar Blade component
- Create `resources/views/components/top-bar.blade.php`
- Include: page title (from `$slot`), environment badge, user dropdown, dark mode toggle
- User dropdown: profile link, API tokens, team settings, logout
- Responsive: hamburger menu on mobile to toggle sidebar

### Sub-task 1.6.4: Create x-stat-card Blade component
- Create `resources/views/components/stat-card.blade.php`
- Props: `$label`, `$value`, `$trend` (positive/negative/neutral), `$trendValue`, `$icon` (optional)
- Display: large value, small label below, trend arrow with percentage
- Colors: green trend for positive, red for negative, gray for neutral
- Dark mode compatible

### Sub-task 1.6.5: Create x-page-header Blade component
- Create `resources/views/components/page-header.blade.php`
- Props: `$title`, `$breadcrumbs` (array), `$actions` (slot for buttons)
- Display: breadcrumb trail, page title, action buttons aligned right
- Breadcrumbs: clickable links with `>` separators

### Sub-task 1.6.6: Create x-empty-state Blade component
- Create `resources/views/components/empty-state.blade.php`
- Props: `$icon`, `$title`, `$description`, `$actionLabel`, `$actionUrl`
- Display: centered icon, title, description text, optional CTA button
- Used when pages have no data (e.g., no events yet, no projects)

### Sub-task 1.6.7: Update dashboard view
- Open `resources/views/dashboard.blade.php`
- Replace Jetstream default content with custom layout using new components
- Show a welcome message with "Create your first project" CTA if no projects exist
- Use `x-page-header` with breadcrumbs

### Sub-task 1.6.8: Verify light and dark mode rendering
- Load dashboard in browser
- Toggle dark mode manually (add/remove `dark` class on `<html>`)
- Verify all components render correctly in both modes
- Check contrast ratios for text readability

---

## Task 1.7: Dark Mode Toggle with Persistence

### Sub-task 1.7.1: Create DarkModeToggle Livewire component class
- Run `php artisan make:livewire DarkModeToggle --no-interaction`
- No server-side state needed (client-side only via Alpine.js)
- Component renders a button with sun/moon icon

### Sub-task 1.7.2: Implement Alpine.js toggle logic in Blade view
- In the component's Blade view:
  ```html
  <div x-data="{ dark: localStorage.getItem('darkMode') === 'true' || (!localStorage.getItem('darkMode') && window.matchMedia('(prefers-color-scheme: dark)').matches) }"
       x-init="$watch('dark', val => { localStorage.setItem('darkMode', val); document.documentElement.classList.toggle('dark', val) }); document.documentElement.classList.toggle('dark', dark)">
      <button @click="dark = !dark" class="...">
          <template x-if="dark"><!-- sun icon --></template>
          <template x-if="!dark"><!-- moon icon --></template>
      </button>
  </div>
  ```

### Sub-task 1.7.3: Add toggle to top-bar component
- Include `<livewire:dark-mode-toggle />` in `x-top-bar` component
- Position next to user dropdown

### Sub-task 1.7.4: Handle system preference detection
- Default to `window.matchMedia('(prefers-color-scheme: dark)').matches` when no manual override
- Listen for system preference changes: `window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', ...)`
- Only override system preference when user explicitly clicks toggle

### Sub-task 1.7.5: Prevent flash of wrong theme on page load
- Add inline script in `<head>` of layout (before body renders):
  ```html
  <script>
  if (localStorage.getItem('darkMode') === 'true' || (!localStorage.getItem('darkMode') && window.matchMedia('(prefers-color-scheme: dark)').matches)) {
      document.documentElement.classList.add('dark');
  }
  </script>
  ```
- This prevents flash of unstyled content (FOUC)

### Sub-task 1.7.6: Write Livewire component test
- Test component renders toggle button
- Test clicking toggle changes icon (sun ↔ moon)
- Note: localStorage persistence is client-side only, test visually or with browser test

---

## Task 1.8: Base Application Configuration

### Sub-task 1.8.1: Set APP_NAME
- Open `.env`, set `APP_NAME="Pulseboard"`
- Open `.env.example`, set `APP_NAME="Pulseboard"`

### Sub-task 1.8.2: Configure timezone
- Open `.env`, verify `APP_TIMEZONE=UTC`
- Open `config/app.php`, verify `'timezone' => env('APP_TIMEZONE', 'UTC')`

### Sub-task 1.8.3: Configure locale
- Verify `APP_LOCALE=en` in `.env`
- Verify `APP_FALLBACK_LOCALE=en` in `.env`

### Sub-task 1.8.4: Configure logging channels
- Open `config/logging.php`
- Set `'default' => env('LOG_CHANNEL', 'daily')` for file-based logging
- Verify `daily` channel config: 14 days retention, `LOG_LEVEL=debug`
- Add `stderr` channel for production: `'driver' => 'monolog', 'handler' => StreamHandler::class, 'with' => ['stream' => 'php://stderr']`
- Add `stack` channel that combines `daily` and `stderr` for production

### Sub-task 1.8.5: Configure base rate limiting
- Open `app/Providers/AppServiceProvider.php`
- Add in `boot()`:
  ```php
  RateLimiter::for('api', function (Request $request) {
      return Limit::perMinute(60)->by($request->user()?->id ?: $request->ip());
  });
  ```
- This is the base rate limiter; ingest-specific limiter is in Task 4.3

### Sub-task 1.8.6: Verify .env.example is complete
- Review all env variables used in config files
- Ensure every variable has a placeholder in `.env.example`
- Add comments grouping variables by concern (App, DB, Redis, Mail, etc.)

---

## Task 1.9: Write Foundation Tests

### Sub-task 1.9.1: Test database connectivity
- Create `tests/Feature/DatabaseConnectionTest.php`
- Test: can connect to PostgreSQL (`DB::connection()->getPdo()`)
- Test: can run a simple query (`DB::select('SELECT 1')`)

### Sub-task 1.9.2: Test migrations run completely
- Test: `migrate:fresh` runs without errors (covered by RefreshDatabase trait)
- Test: all expected tables exist after migration
- Verify table list includes: users, teams, team_user, team_invitations, personal_access_tokens, sessions, cache, jobs, failed_jobs, pulse_*, features

### Sub-task 1.9.3: Test Redis queue dispatch and processing
- Create test that dispatches a job to Redis queue
- Process the job with `Queue::fake()` or sync driver
- Verify job was dispatched to correct queue
- Clean up test job

### Sub-task 1.9.4: Test Horizon dashboard authorization
- Test: unauthenticated user gets redirected from `/horizon`
- Test: authenticated non-admin user gets 403 from `/horizon`
- Test: team owner can access `/horizon` (if in local environment)
- Note: Horizon gate may need environment-specific logic

### Sub-task 1.9.5: Test Pennant flag resolution
- Test: feature flag resolves to default value for new team
- Test: activating feature flag changes resolution for that team
- Test: deactivating feature flag reverts to default
- Test: feature flag for one team doesn't affect another team
- Test: feature flag persists in database across requests

### Sub-task 1.9.6: Run full regression test suite
- Execute `php artisan test --compact`
- Verify all existing Jetstream tests pass (21+ tests)
- Verify all new foundation tests pass
- Document any test failures and their resolution
- Ensure zero test failures before marking task complete
