# Plan 02: Authentication & Organization Model

## Objective
Implement social login (GitHub priority, Google second) via Socialite, enforce email verification, and extend the Jetstream Teams model with project onboarding UX.

## Current State
- Jetstream installed with Teams, API tokens, email verification views
- Socialite NOT installed
- Passport NOT used (Sanctum handles all API token needs)
- No social login routes or controllers
- Email verification views exist but enforcement may need explicit middleware wiring

## Target State
- Social login with GitHub and Google via Socialite
- Provider identity linking (users can connect multiple social accounts)
- Email verification enforced on all dashboard routes via `verified` middleware
- Sanctum token abilities for programmatic API access (no Passport)
- Team invitation flow polished with custom UI
- Project onboarding wizard (create first project after team creation)

## Implementation Steps

### 2.1 Install & Configure Socialite
- `composer require laravel/socialite`
- Add GitHub and Google credentials to `config/services.php`
- Add corresponding `.env` variables: `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`, `GITHUB_REDIRECT_URI`, `GOOGLE_CLIENT_ID`, `GOOGLE_CLIENT_SECRET`, `GOOGLE_REDIRECT_URI`

### 2.2 Social Auth Controller & Routes
- Create a **generic, extensible `SocialAuthController`** with two methods:
  - `redirect(string $provider)` — resolves the Socialite driver dynamically
  - `callback(string $provider)` — handles the OAuth callback for any supported provider
- Define supported providers in a config array or enum (start with GitHub, Google):
  ```php
  // config/services.php or app/Enums/SocialProvider.php
  'social_providers' => ['github', 'google'],
  ```
- Validate the `{provider}` route parameter against the config/enum (via `whereIn` constraint or middleware)
- Register two routes in `routes/web.php`:
  ```
  GET /auth/{provider}/redirect -> auth.social.redirect
  GET /auth/{provider}/callback -> auth.social.callback
  ```
  with `->whereIn('provider', config('services.social_providers'))`
- Adding a new provider requires only:
  1. Adding the provider name to the config array / enum
  2. Adding `CLIENT_ID`, `CLIENT_SECRET`, `REDIRECT_URI` credentials in `.env` and `config/services.php`
  3. No new controller methods or routes needed
- Implement callback logic:
  - Exchange code for provider identity
  - Match or create internal user
  - Link provider identity to user (new `social_accounts` table)
  - Sign user in via Fortify/Jetstream session
  - If provider doesn't assert verified email, force email verification

### 2.3 Social Accounts Migration & Model
- Create `social_accounts` migration:
  - `id`, `user_id (fk)`, `provider (string)`, `provider_id (string)`, `provider_token (encrypted)`, `provider_refresh_token (encrypted)`, `created_at`, `updated_at`
  - Unique index: `(provider, provider_id)`
- Create `SocialAccount` model with `user()` relationship
- Add `socialAccounts()` relationship to `User` model

### 2.4 Sanctum API Token Scoping (Programmatic API)
- Use Sanctum's built-in token abilities for programmatic API access (no Passport)
- Sanctum is already installed and supports token abilities/scopes
- Define token abilities for the programmatic API:
  - `projects:read`, `projects:write`
  - `events:read`
  - `crashes:read`
  - `traces:read`
  - `billing:read`
- Use `tokenCan()` checks in controllers/middleware
- Jetstream already provides the API token management UI with ability selection
- All API routes use `auth:sanctum` guard (already configured)

### 2.5 Enforce Email Verification
- Ensure `verified` middleware is applied to all dashboard and API routes
- Customize verification email template with project branding
- Handle social login accounts where provider asserts email as verified

### 2.6 Team & Onboarding Polish
- Customize team creation flow with project branding
- Add "Create First Project" step after team creation
- Custom invitation email template

## Dependencies
- Plan 01 (Platform Foundation) must be complete
- GitHub OAuth app credentials
- Google OAuth app credentials

## Testing Requirements
- Feature test: social login redirect generates correct OAuth URL
- Feature test: callback creates user and links social account
- Feature test: callback with existing user links social account
- Feature test: email verification enforcement on dashboard
- Feature test: Sanctum API token with abilities
- Feature test: team creation triggers project onboarding prompt

## Estimated Effort
3-5 person-weeks

## Files to Create/Modify
- `composer.json` (add socialite)
- `config/services.php` (modify - add GitHub, Google)
- `config/jetstream.php` (modify - add API token permissions/abilities)
- `config/services.php` (modify - add `social_providers` array)
- `app/Http/Controllers/SocialAuthController.php` (new - generic redirect/callback)
- `app/Models/SocialAccount.php` (new)
- `app/Models/User.php` (modify - add relationships)
- `database/migrations/*_create_social_accounts_table.php` (new)
- `routes/web.php` (modify)
- `routes/api.php` (modify)
- `resources/views/auth/login.blade.php` (modify - add social buttons)
- `resources/views/auth/register.blade.php` (modify)
- Tests in `tests/Feature/`
