# Tasks: Plan 06 - Analytics Dashboards

## References
- Plan: [06-analytics-dashboards.md](../Plans/06-analytics-dashboards.md)
- PRD: [PRD.md](../PRD.md) (lines 70-75, 237-262)

---

## Task 6.1: Dashboard Infrastructure & Reusable Components
**Priority:** Critical | **Estimate:** 4-6 hours | **Blocked by:** Plan 01 (design system), Plan 03

### Steps
1. Add Chart.js via npm or CDN for data visualization
2. Create reusable Livewire/Blade components:
   - `DateRangePicker` - Livewire component with presets (7d, 14d, 30d, 90d, custom)
   - `EnvironmentSwitcher` - dropdown component, persists selection in session
   - `KpiCard` - stat card with value, label, trend arrow, optional sparkline
   - `DataTable` - sortable, filterable table with Livewire pagination
   - `TimeseriesChart` - Chart.js line/area chart wrapper
   - `BarChart` - Chart.js bar chart wrapper
   - `StackTraceViewer` - formatted code block with syntax highlighting
   - `EmptyState` - placeholder for pages with no data yet
3. Create `MetricsService` in `app/Services/MetricsService.php`:
   - Methods for querying aggregated data
   - Date range scoping
   - Environment filtering
   - Short-TTL caching for frequently accessed metrics

### Acceptance Criteria
- [ ] All reusable components created and tested
- [ ] Chart.js integrated and rendering
- [ ] MetricsService queries efficient with caching
- [ ] Components work in dark mode
- [ ] DateRangePicker and EnvironmentSwitcher persist selections

---

## Task 6.2: Overview Dashboard Page
**Priority:** Critical | **Estimate:** 4-6 hours | **Blocked by:** Task 6.1

### Steps
1. Create Livewire page: `ProjectDashboard`
2. Route: `GET /projects/{project}/dashboard` (web, auth, verified)
3. KPI cards row:
   - Total Events (with % change from previous period)
   - Active Users (with % change)
   - Total Sessions (with % change)
   - Crash-Free Users % (with trend indicator)
   - p95 Cold Start (ms) (with trend)
4. Charts section:
   - Daily Active Users timeseries
   - Event Volume timeseries
   - Top Events by count (horizontal bar chart)
   - Crash-Free Rate trend line
5. Wire up MetricsService queries
6. Add environment switcher to page header
7. Date range picker with default (last 7 days)

### Acceptance Criteria
- [ ] Dashboard renders with KPI cards and charts
- [ ] Data refreshes when date range or environment changes
- [ ] Empty state shown when no data exists
- [ ] Charts render correctly in both light and dark mode
- [ ] Performance: page loads in <2s with cached data

---

## Task 6.3: Event Explorer Page
**Priority:** High | **Estimate:** 4-6 hours | **Blocked by:** Task 6.1

### Steps
1. Create Livewire page: `EventExplorer`
2. Route: `GET /projects/{project}/events`
3. Filter bar:
   - Event name (autocomplete/select from known event names)
   - Date range picker
   - User filter (anonymous_id or user_id search)
   - Session filter
   - Property filter (key=value with jsonb query)
4. Results table:
   - Columns: Name, Timestamp, User, Session, Device, Properties (truncated)
   - Sortable by timestamp
   - Paginated (cursor-based for large datasets)
5. Event detail drawer/modal:
   - Full properties JSON (formatted)
   - Device info
   - Session context
   - User info
6. Efficient queries using PostgreSQL indexes and GIN for property filtering

### Acceptance Criteria
- [ ] Filters work correctly (AND logic)
- [ ] Property filtering uses GIN index
- [ ] Pagination handles large datasets
- [ ] Event detail shows full context
- [ ] Autocomplete for event names works

---

## Task 6.4: Sessions Explorer Page
**Priority:** High | **Estimate:** 3-4 hours | **Blocked by:** Task 6.1

### Steps
1. Create Livewire page: `SessionsExplorer`
2. Route: `GET /projects/{project}/sessions`
3. Session list:
   - Columns: Start Time, Duration, Event Count, Device, User, Platform
   - Filter by: date range, user, device
   - Paginated
4. Session detail view:
   - Event timeline (chronological events within session)
   - Entry/exit events highlighted
   - Device and app context sidebar
   - Duration and gap visualization

### Acceptance Criteria
- [ ] Session list with filtering and pagination
- [ ] Session detail shows event timeline
- [ ] Device and app context displayed
- [ ] Duration formatted human-readable

---

## Task 6.5: Crash Explorer Page
**Priority:** High | **Estimate:** 4-6 hours | **Blocked by:** Task 6.1

### Steps
1. Create Livewire page: `CrashExplorer`
2. Route: `GET /projects/{project}/crashes`
3. Crash groups list (grouped by fingerprint):
   - Columns: Crash Title (exception type + message), Occurrences, Affected Users, First Seen, Last Seen, App Version
   - Filter by: date range, app version, fatal/non-fatal, device model, OS version
   - Sort by: occurrences, last seen, affected users
4. Crash detail view:
   - Full stack trace with `StackTraceViewer` component
   - Breadcrumbs timeline
   - Device and app context
   - Affected users count and list
   - Occurrence trend chart
   - Version distribution

### Acceptance Criteria
- [ ] Crashes grouped by fingerprint
- [ ] Stack trace rendered with formatting
- [ ] Breadcrumbs displayed as timeline
- [ ] Occurrence trend chart
- [ ] Filters work correctly

---

## Task 6.6: Performance Explorer Page
**Priority:** High | **Estimate:** 3-4 hours | **Blocked by:** Task 6.1

### Steps
1. Create Livewire page: `PerformanceExplorer`
2. Route: `GET /projects/{project}/performance`
3. Trace summary table:
   - Columns: Trace Name, Count, p50 (ms), p75 (ms), p95 (ms)
   - Filter by: date range, trace name, app version
4. Trace detail view:
   - Duration distribution histogram
   - Percentile trends over time
   - Breakdown by app version
   - Attributes table

### Acceptance Criteria
- [ ] Percentile calculations correct
- [ ] Duration distribution histogram renders
- [ ] Version breakdown chart
- [ ] Filters work correctly

---

## Task 6.7: Project Navigation & Routing
**Priority:** High | **Estimate:** 2-3 hours | **Blocked by:** Tasks 6.2-6.6

### Steps
1. Add project-scoped sidebar navigation:
   - Dashboard (overview icon)
   - Events (list icon)
   - Sessions (clock icon)
   - Crashes (bug icon)
   - Performance (speedometer icon)
   - Settings (gear icon)
2. Implement breadcrumb: Team > Project > Section
3. Highlight active section in sidebar
4. Register all routes in `routes/web.php` under auth/verified middleware group
5. Update team dashboard to show project list as landing page

### Acceptance Criteria
- [ ] Sidebar navigation shows on all project pages
- [ ] Active section highlighted
- [ ] Breadcrumbs show correct path
- [ ] All routes registered and accessible

---

## Task 6.8: Query API Controllers
**Priority:** Medium | **Estimate:** 3-4 hours | **Blocked by:** Tasks 6.1-6.6

### Steps
1. Create API controllers (Sanctum-protected):
   - `MetricsController::overview()` - overview KPIs + timeseries
   - `EventsController::search()` - event search with filters
   - `CrashesController::search()` - crash search with grouping
   - `TracesController::search()` - trace search with percentiles
2. Create Form Requests for query parameters
3. Create Eloquent API Resources for responses
4. Register routes in `routes/api.php`
5. Response format matches PRD Query API spec

### Acceptance Criteria
- [ ] All API endpoints return correct data
- [ ] Query parameters validated
- [ ] Responses match PRD format
- [ ] Authorization: team members only
- [ ] Sanctum token abilities checked

---

## Task 6.9: Write Dashboard Tests
**Priority:** High | **Estimate:** 4-6 hours | **Blocked by:** Tasks 6.2-6.8

### Steps
1. Livewire component tests for each page
2. Feature tests for query API endpoints
3. Unit tests for MetricsService
4. Test empty states render correctly
5. Test filter interactions
6. Test authorization (non-team-members blocked)

### Acceptance Criteria
- [ ] All component tests pass
- [ ] API endpoint tests pass
- [ ] Authorization tests pass
- [ ] Zero test failures
