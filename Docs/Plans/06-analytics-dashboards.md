# Plan 06: Analytics Dashboards

## Objective
Build the analytics dashboard UI using Livewire components with a custom design system. Deliver: overview dashboard, event explorer, sessions explorer, crash explorer, and performance explorer.

## Current State
- Only Jetstream default dashboard view exists
- No analytics visualization components
- No chart library integrated
- Custom design system foundation from Plan 01

## Target State
- Overview dashboard with KPI cards and trend charts per project/environment
- Event explorer with filtering, search, and property inspection
- Sessions explorer with timeline view and device/app context
- Crash explorer grouped by fingerprint with stack trace viewer
- Performance explorer with trace percentiles and app version breakdown
- All views support environment switching and date range selection
- Dark mode compatible
- Non-stock, custom-branded UI

## Implementation Steps

### 6.1 Dashboard Infrastructure
- Install charting library (Chart.js via CDN or Alpine.js wrapper)
- Create reusable Livewire components:
  - `DateRangePicker` - date range selection with presets (7d, 30d, 90d, custom)
  - `EnvironmentSwitcher` - dropdown to switch between environments
  - `KpiCard` - metric card with value, trend, and sparkline
  - `DataTable` - sortable, filterable table with pagination
  - `TimeseriesChart` - line/area chart for time-based metrics
  - `BarChart` - bar chart for categorical data
  - `StackTraceViewer` - formatted stack trace display with syntax highlighting

### 6.2 Overview Dashboard
- Route: `GET /projects/{project}/dashboard`
- Livewire page component: `ProjectDashboard`
- KPI cards:
  - Total events (with % change)
  - Active users (with % change)
  - Total sessions (with % change)
  - Crash-free users % (with trend)
  - p95 cold start (ms) (with trend)
- Charts:
  - Daily active users timeseries
  - Event volume timeseries
  - Top events by count (bar chart)
  - Crash-free rate trend
- Query layer:
  - `MetricsService` to query aggregated data from `daily_aggregates` and raw tables
  - Efficient queries with environment + date range scoping
  - Cache frequently accessed metrics (short TTL)

### 6.3 Event Explorer
- Route: `GET /projects/{project}/events`
- Livewire page component: `EventExplorer`
- Features:
  - Filter by event name (autocomplete from known names)
  - Filter by date range
  - Filter by user (anonymous_id or user_id)
  - Filter by session_id
  - Filter by property key/value (jsonb query)
  - Paginated event list with: name, timestamp, user, session, device
  - Event detail modal: full properties JSON, device info, session context
- Query optimization:
  - Use PostgreSQL indexes on `(environment_id, name, timestamp desc)`
  - Use GIN index for property filtering
  - Limit result sets and use cursor-based pagination for large datasets

### 6.4 Sessions Explorer
- Route: `GET /projects/{project}/sessions`
- Livewire page component: `SessionsExplorer`
- Features:
  - List sessions with: start time, duration, event count, device, user
  - Filter by date range, user, device
  - Session detail view: event timeline within session
  - Device and app context display
- Session detail:
  - Chronological list of events in the session
  - Entry/exit events highlighted
  - Duration and gap visualization

### 6.5 Crash Explorer
- Route: `GET /projects/{project}/crashes`
- Livewire page component: `CrashExplorer`
- Features:
  - Group crashes by fingerprint
  - Show: crash title (exception type + message), occurrence count, affected users, first/last seen, app version distribution
  - Filter by: date range, app version, fatal/non-fatal, device model, OS version
  - Crash detail view:
    - Full stack trace with syntax highlighting
    - Breadcrumbs timeline
    - Device and app context
    - Affected users list
    - Occurrence trend chart

### 6.6 Performance Explorer
- Route: `GET /projects/{project}/performance`
- Livewire page component: `PerformanceExplorer`
- Features:
  - List traces by name with: p50, p75, p95 durations, count
  - Filter by: date range, trace name, app version
  - Trace detail view:
    - Duration distribution histogram
    - Percentile trends over time
    - Breakdown by app version
    - Attributes table

### 6.7 Navigation & Layout
- Project-scoped sidebar navigation:
  - Dashboard (overview)
  - Events
  - Sessions
  - Crashes
  - Performance
  - Settings (project settings, environments, keys)
- Breadcrumb: Team > Project > Section
- Team switcher in top nav (Jetstream)
- Environment badge/switcher always visible

### 6.8 Query API Controllers (for Passport/Sanctum API consumers)
- `MetricsController::overview()` - overview KPIs and timeseries
- `EventsController::search()` - event explorer API
- `CrashesController::search()` - crash explorer API
- `TracesController::search()` - performance explorer API
- All endpoints protected with `auth:sanctum`
- Form Requests for query parameter validation
- Eloquent API Resources for response formatting

## Dependencies
- Plan 01 (Custom design system)
- Plan 03 (Data model)
- Plan 04 (Ingestion pipeline - data must exist to display)

## Testing Requirements
- Livewire component tests for each explorer
- Feature tests for Query API endpoints
- Unit tests for MetricsService queries
- Visual regression tests (optional, not MVP-blocking)

## Estimated Effort
6-10 person-weeks

## Files to Create
- 5+ Livewire page components
- 7+ reusable Livewire components
- 4+ API controllers
- 4+ Form Requests for query parameters
- 4+ Eloquent API Resources
- `app/Services/MetricsService.php`
- 10+ Blade views
- 15+ test files
