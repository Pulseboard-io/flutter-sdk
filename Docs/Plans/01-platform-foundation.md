# Plan 01: Platform Foundation

## Objective
Establish the Laravel 12 baseline with all required infrastructure: database switch to PostgreSQL, Redis queue configuration, Horizon dashboard access, Pennant feature flag bootstrapping, and custom design system foundation.

## Current State
- Fresh Laravel 12 install with Jetstream (Livewire stack), Sanctum, Horizon, Pennant, Pulse
- Database: SQLite (must migrate to PostgreSQL per PRD)
- Queue: database driver (must switch to Redis for Horizon)
- No custom models, controllers, or routes beyond Jetstream defaults
- CLAUDE.md and AGENTS.md contain Laravel Boost guidelines only

## Target State
- PostgreSQL as primary database with UUID primary keys
- Redis-backed queues operated through Horizon
- Pennant feature flags bootstrapped with initial flag definitions
- Custom design system foundation (non-stock Jetstream appearance)
- Dark mode with Tailwind class-based approach and persisted preference
- Base layout components with custom branding

## Implementation Steps

### 1.1 Switch to PostgreSQL
- Update `.env` and `config/database.php` to use PostgreSQL as default
- Update `.env.example` with PostgreSQL defaults
- Ensure all existing migrations are compatible with PostgreSQL
- Add `doctrine/dbal` if needed for column modifications
- Run migrations against PostgreSQL

### 1.2 Configure Redis Queues + Horizon
- Update `.env` to set `QUEUE_CONNECTION=redis`
- Configure Horizon environments in `config/horizon.php` (local, staging, production)
- Set up Horizon supervisor configuration with appropriate worker counts
- Configure Horizon gate in `HorizonServiceProvider` to restrict dashboard access to team admins
- Add Horizon to the deployment workflow

### 1.3 Bootstrap Pennant Feature Flags
- Create initial feature flag definitions:
  - `sdk.react_native.enabled` (team/project scoped)
  - `dashboard.performance.enabled`
  - `dashboard.beta.enabled`
  - `exports.enabled`
  - `retention.advanced.enabled`
- Create a `FeatureFlags` class or register features in `AppServiceProvider`
- Scope flags to Team model

### 1.4 Custom Design System Foundation
- Override Jetstream views with custom styling
- Create base color palette and typography in `tailwind.config.js`
- Implement dark mode toggle component (Livewire)
- Persist dark mode preference (localStorage + optional server sync)
- Create reusable Blade/Livewire components: sidebar navigation, top bar, card, stat widget
- Remove stock Jetstream look-and-feel from all visible pages

### 1.5 Base Configuration
- Set `APP_NAME` to "Pulseboard"
- Configure proper timezone, locale
- Set up logging channels (daily + stderr for production)
- Configure rate limiting defaults in `AppServiceProvider` or `bootstrap/app.php`

## Dependencies
- PostgreSQL server running locally or via Docker (Sail)
- Redis server running locally or via Docker (Sail)

## Testing Requirements
- Existing Jetstream test suite must continue to pass against PostgreSQL
- Add test for Horizon configuration
- Add test for Pennant flag resolution
- Add test for dark mode toggle persistence

## Estimated Effort
4-6 person-weeks

## Files to Create/Modify
- `config/database.php` (modify)
- `config/horizon.php` (modify)
- `.env` / `.env.example` (modify)
- `app/Providers/HorizonServiceProvider.php` (modify)
- `app/Features/` (new directory for Pennant feature classes)
- `tailwind.config.js` (modify)
- `resources/views/layouts/` (modify)
- `resources/views/components/` (new custom components)
- Multiple Blade view overrides
