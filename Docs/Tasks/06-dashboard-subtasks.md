# Sub-Tasks: Plan 06 - Analytics Dashboards

---

## Task 6.1: Dashboard Infrastructure & Reusable Components

### Sub-task 6.1.1: Install Chart.js
- Run `npm install chart.js --save`
- Import in `resources/js/app.js` or create `resources/js/charts.js`
- Register Chart.js globally or as Alpine.js component wrapper
- Run `npm run build` to verify

### Sub-task 6.1.2: Create DateRangePicker Livewire component
- `php artisan make:livewire DateRangePicker --no-interaction`
- Props: `$startDate`, `$endDate`
- Preset buttons: 7d, 14d, 30d, 90d, Custom
- Emit `dateRangeChanged` event to parent when selection changes
- Alpine.js for datepicker dropdown UI
- Dark mode compatible styling

### Sub-task 6.1.3: Create EnvironmentSwitcher Livewire component
- `php artisan make:livewire EnvironmentSwitcher --no-interaction`
- Props: `$projectId`, `$selectedEnvironmentId`
- Load environments for project
- Persist selection in session: `session()->put("env_{$projectId}", $envId)`
- Emit `environmentChanged` event
- Dropdown styled as badge (prod=green, staging=yellow, dev=blue)

### Sub-task 6.1.4: Create KpiCard Blade component
- `resources/views/components/kpi-card.blade.php`
- Props: `$label`, `$value`, `$previousValue` (optional), `$format` (number/percent/ms), `$icon` (optional)
- Auto-calculate trend: `($value - $previousValue) / $previousValue * 100`
- Display: large value, trend arrow (up green / down red), percentage change
- Dark mode: `dark:bg-gray-800 dark:text-white`

### Sub-task 6.1.5: Create DataTable Livewire component
- `php artisan make:livewire DataTable --no-interaction`
- Props: `$columns` (array of column configs), `$data` (paginator)
- Features: sortable headers, search input, pagination controls
- Emit `rowClicked` event for detail views
- Responsive: horizontal scroll on mobile
- Dark mode compatible

### Sub-task 6.1.6: Create TimeseriesChart Blade component
- `resources/views/components/timeseries-chart.blade.php`
- Props: `$chartId`, `$labels` (dates), `$datasets` (array with label/data/color)
- Initialize Chart.js line chart via Alpine.js `x-init`
- Responsive, dark mode (adjust grid/text colors)
- Auto-update when data changes (Alpine reactivity)

### Sub-task 6.1.7: Create BarChart Blade component
- Similar to TimeseriesChart but horizontal bar chart type
- Props: `$chartId`, `$labels`, `$data`, `$color`

### Sub-task 6.1.8: Create StackTraceViewer Blade component
- `resources/views/components/stack-trace-viewer.blade.php`
- Props: `$stacktrace` (string), `$language` (default: 'dart')
- Render in `<pre><code>` with monospace font
- Basic syntax highlighting (or use Prism.js/Highlight.js)
- Collapsible: show first 10 lines with "Show full trace" expander
- Copy-to-clipboard button

### Sub-task 6.1.9: Create EmptyState Blade component
- Already created in Task 1.6.6, verify it exists and works

### Sub-task 6.1.10: Create MetricsService
- `app/Services/MetricsService.php`
- Constructor: inject Cache
- Method: `getOverviewKpis(Environment $env, Carbon $from, Carbon $to): array`
  - Query daily_aggregates for KPIs
  - Calculate previous period for comparison
  - Return: events, active_users, sessions, crash_free_pct, p95_cold_start
- Method: `getDailyTimeseries(Environment $env, Carbon $from, Carbon $to, string $metric): array`
- Method: `getTopEvents(Environment $env, Carbon $from, Carbon $to, int $limit = 10): Collection`
- Cache: 5-minute TTL for overview KPIs, 1-minute for timeseries

### Sub-task 6.1.11: Write MetricsService unit tests
- Test KPI calculation with factory data
- Test caching works (second call faster)
- Test date range filtering

---

## Task 6.2: Overview Dashboard Page

### Sub-task 6.2.1: Create ProjectDashboard Livewire component
- `php artisan make:livewire ProjectDashboard --no-interaction`
- Props: Project model (from route)
- Listeners: `dateRangeChanged`, `environmentChanged`

### Sub-task 6.2.2: Define route
- `Route::get('/projects/{project}/dashboard', ProjectDashboard::class)->name('projects.dashboard')`
- Middleware: `auth:sanctum`, `verified`

### Sub-task 6.2.3: Implement KPI data loading
- Use MetricsService to load overview KPIs
- Calculate previous period for trend comparison
- Pass to 5 KpiCard components

### Sub-task 6.2.4: Implement chart data loading
- DAU timeseries from MetricsService
- Event volume timeseries
- Top events bar chart
- Crash-free rate trend line

### Sub-task 6.2.5: Create Blade view
- Layout with page header (breadcrumb, environment switcher, date picker)
- KPI cards row (responsive grid: 5 columns on desktop, 2 on mobile)
- Charts section: 2-column grid (timeseries left, bar chart right)
- Empty state when no data exists

### Sub-task 6.2.6: Implement data refresh
- Re-query MetricsService when date range or environment changes
- Show loading states during refresh

### Sub-task 6.2.7: Write Livewire component test
- Test dashboard renders with data
- Test empty state renders when no data
- Test date range change triggers re-render
- Test environment switch triggers re-render

---

## Task 6.3: Event Explorer Page

### Sub-task 6.3.1: Create EventExplorer Livewire component
### Sub-task 6.3.2: Implement event name autocomplete
- Query distinct event names for environment
- Debounced search as user types
### Sub-task 6.3.3: Implement filter bar (date, user, session, property)
### Sub-task 6.3.4: Implement event query with filters
- Build Eloquent query using scopes
- Property filter using PostgreSQL jsonb: `->whereJsonContains('properties->key', 'value')`
### Sub-task 6.3.5: Implement paginated results table
### Sub-task 6.3.6: Implement event detail drawer/modal
- Show full JSON properties, device info, session context
### Sub-task 6.3.7: Write component tests

---

## Task 6.4: Sessions Explorer Page

### Sub-task 6.4.1: Create SessionsExplorer Livewire component
### Sub-task 6.4.2: Implement session list with filters
### Sub-task 6.4.3: Implement session detail view
- Load events for session, display as timeline
### Sub-task 6.4.4: Implement device context sidebar
### Sub-task 6.4.5: Write component tests

---

## Task 6.5: Crash Explorer Page

### Sub-task 6.5.1: Create CrashExplorer Livewire component
### Sub-task 6.5.2: Implement fingerprint grouping query
- `SELECT fingerprint, exception_type, message, COUNT(*) as occurrences, COUNT(DISTINCT app_user_id) as affected_users, MIN(timestamp) as first_seen, MAX(timestamp) as last_seen FROM crash_reports WHERE ... GROUP BY fingerprint, exception_type, message`
### Sub-task 6.5.3: Implement crash filters (date, version, fatal, device, OS)
### Sub-task 6.5.4: Implement crash detail view
- Stack trace viewer, breadcrumbs timeline, occurrence trend chart
### Sub-task 6.5.5: Implement affected users list
### Sub-task 6.5.6: Write component tests

---

## Task 6.6: Performance Explorer Page

### Sub-task 6.6.1: Create PerformanceExplorer Livewire component
### Sub-task 6.6.2: Implement percentile calculation query
- Use PostgreSQL `percentile_cont()` within group:
  ```sql
  SELECT name, COUNT(*),
    percentile_cont(0.5) WITHIN GROUP (ORDER BY duration_ms) AS p50,
    percentile_cont(0.75) WITHIN GROUP (ORDER BY duration_ms) AS p75,
    percentile_cont(0.95) WITHIN GROUP (ORDER BY duration_ms) AS p95
  FROM traces WHERE ... GROUP BY name
  ```
### Sub-task 6.6.3: Implement trace detail view with histogram
### Sub-task 6.6.4: Implement version breakdown
### Sub-task 6.6.5: Write component tests

---

## Task 6.7: Project Navigation & Routing

### Sub-task 6.7.1: Create project sidebar nav configuration
- Define nav items array: label, icon, route name, active check
### Sub-task 6.7.2: Update sidebar component to accept project-scoped nav
### Sub-task 6.7.3: Implement breadcrumb generation
### Sub-task 6.7.4: Register all project routes
### Sub-task 6.7.5: Update team dashboard to show project list

---

## Task 6.8: Query API Controllers

### Sub-task 6.8.1: Create MetricsController with overview() method
### Sub-task 6.8.2: Create EventsController with search() method
### Sub-task 6.8.3: Create CrashesController with search() method
### Sub-task 6.8.4: Create TracesController with search() method
### Sub-task 6.8.5: Create Form Requests for each query endpoint
### Sub-task 6.8.6: Create API Resources for each response
### Sub-task 6.8.7: Register routes in routes/api.php
### Sub-task 6.8.8: Write API endpoint tests

---

## Task 6.9: Write Dashboard Tests
### Sub-task 6.9.1-6.9.6: One test per component/controller (see task steps)
