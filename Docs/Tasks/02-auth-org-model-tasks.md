# Tasks: Plan 02 - Authentication & Organization Model

## References
- Plan: [02-auth-and-org-model.md](../Plans/02-auth-and-org-model.md)
- PRD: [PRD.md](../PRD.md) (lines 46-49, 101-124)

---

## Task 2.1: Install & Configure Socialite
**Priority:** Critical | **Estimate:** 1 hour | **Blocked by:** Plan 01

### Steps
1. Run `composer require laravel/socialite`
2. Add GitHub and Google provider credentials to `config/services.php`:
   ```php
   'github' => [
       'client_id' => config value from env,
       'client_secret' => config value from env,
       'redirect' => config value from env,
   ],
   'google' => [
       'client_id' => config value from env,
       'client_secret' => config value from env,
       'redirect' => config value from env,
   ],
   ```
3. Add env variables to `.env.example`

### Acceptance Criteria
- [ ] Socialite installed via Composer
- [ ] GitHub and Google provider configuration in `config/services.php`
- [ ] `.env.example` updated with placeholder variables

---

## Task 2.2: Social Accounts Migration & Model
**Priority:** Critical | **Estimate:** 1-2 hours | **Blocked by:** Task 2.1

### Steps
1. Create migration for `social_accounts` table:
   - `id (uuid pk)`, `user_id (fk users, cascade)`, `provider (string)`, `provider_id (string)`, `provider_token (text, encrypted)`, `provider_refresh_token (text, encrypted, nullable)`, `avatar_url (string, nullable)`, `created_at`, `updated_at`
   - Unique index: `(provider, provider_id)`
   - Index: `(user_id)`
2. Create `SocialAccount` model with:
   - `user()` BelongsTo relationship
   - Encrypted casts for `provider_token`, `provider_refresh_token`
   - `HasUuids` trait
3. Add `socialAccounts()` HasMany relationship to `User` model
4. Create factory for `SocialAccount`

### Acceptance Criteria
- [ ] Migration created and runs successfully
- [ ] Model with proper relationships and casts
- [ ] User model updated with `socialAccounts()` relationship
- [ ] Factory created

---

## Task 2.3: Social Auth Controller & Routes (Extensible Pattern)
**Priority:** Critical | **Estimate:** 3-4 hours | **Blocked by:** Task 2.2

### Steps
1. Define supported providers in config:
   - Add `'social_providers' => ['github', 'google']` to `config/services.php`
   - Alternatively, create a `SocialProvider` string-backed enum in `app/Enums/SocialProvider.php`
2. Create a single **generic `SocialAuthController`** with two methods:
   - `redirect(string $provider)` — validates provider, then calls `Socialite::driver($provider)->redirect()`
   - `callback(string $provider)` — validates provider, handles the OAuth callback
3. Provider validation: use `whereIn` route constraint against `config('services.social_providers')` or enum cases
4. Implement callback logic:
   a. Get user from Socialite provider
   b. Check if social account exists -> link to existing user
   c. If no social account: check if email matches existing user -> link
   d. If no match: create new user + personal team + social account
   e. If provider asserts verified email, mark user as verified
   f. If provider does NOT assert verified email, require verification
   g. Log user in via Auth::login()
   h. Redirect to dashboard
5. Register routes in `routes/web.php`:
   ```php
   Route::get('/auth/{provider}/redirect', [SocialAuthController::class, 'redirect'])
       ->name('auth.social.redirect')
       ->whereIn('provider', config('services.social_providers'));
   Route::get('/auth/{provider}/callback', [SocialAuthController::class, 'callback'])
       ->name('auth.social.callback')
       ->whereIn('provider', config('services.social_providers'));
   ```
6. Add CSRF/state protection (Socialite handles this)
7. Handle edge cases: user tries to link already-linked account, provider errors
8. **To add a new provider later**: add the name to `social_providers` config, add credentials in `.env` and `config/services.php` — no new controller code or routes needed

### Acceptance Criteria
- [ ] Social login redirect works for GitHub and Google
- [ ] Callback creates new user with team or links to existing user
- [ ] Controller uses generic `$provider` parameter, not provider-specific methods
- [ ] Provider validation rejects unsupported providers with 404
- [ ] Email verification enforced when provider doesn't verify email
- [ ] Session created correctly after social login
- [ ] Error handling for provider failures
- [ ] Adding a new provider requires only config + .env changes

---

## Task 2.4: Social Login UI Integration
**Priority:** High | **Estimate:** 2-3 hours | **Blocked by:** Task 2.3

### Steps
1. Update `resources/views/auth/login.blade.php`:
   - Add "Continue with GitHub" button with GitHub icon
   - Add "Continue with Google" button with Google icon
   - Add divider between social and email/password login
2. Update `resources/views/auth/register.blade.php`:
   - Same social login buttons
3. Add linked social accounts display in profile settings
4. Add "Connect/Disconnect" social account management in profile
5. Style buttons with custom design system (dark mode compatible)

### Acceptance Criteria
- [ ] Social login buttons on login page
- [ ] Social login buttons on registration page
- [ ] Profile settings show linked social accounts
- [ ] Connect/disconnect functionality works
- [ ] Dark mode compatible styling

---

## Task 2.5: Configure Sanctum API Token Abilities
**Priority:** High | **Estimate:** 2-3 hours | **Blocked by:** Plan 01

### Steps
1. Define API token abilities in `JetstreamServiceProvider`:
   ```php
   Jetstream::permissions(['projects:read', 'projects:write', 'events:read', 'crashes:read', 'traces:read', 'billing:read']);
   Jetstream::defaultApiTokenPermissions(['projects:read', 'events:read']);
   ```
2. Update Jetstream API token creation UI to show abilities
3. Create middleware or gate checks using `tokenCan()` for API routes
4. Add ability validation to API controllers

### Acceptance Criteria
- [ ] Token abilities defined and visible in API token UI
- [ ] Default abilities set for new tokens
- [ ] `tokenCan()` checks work in API controllers
- [ ] Tests verify ability-based authorization

---

## Task 2.6: Enforce Email Verification
**Priority:** High | **Estimate:** 1-2 hours | **Blocked by:** Plan 01

### Steps
1. Verify `MustVerifyEmail` interface on User model
2. Ensure `verified` middleware applied to dashboard routes in `routes/web.php`
3. Customize verification email template with Pulseboard branding
4. Handle social login users: skip verification if provider verifies email
5. Test: unverified user redirected to verification notice

### Acceptance Criteria
- [ ] Unverified users cannot access dashboard
- [ ] Verification email sends with custom branding
- [ ] Social login users with verified provider email skip verification
- [ ] Tests cover verification enforcement

---

## Task 2.7: Write Auth & Org Tests
**Priority:** High | **Estimate:** 3-4 hours | **Blocked by:** Tasks 2.1-2.6

### Steps
1. Feature test: social login redirect generates correct OAuth URL
2. Feature test: GitHub callback creates new user with team
3. Feature test: Google callback creates new user with team
4. Feature test: callback with existing email links social account
5. Feature test: callback with existing social account logs in
6. Feature test: email verification enforced for non-social users
7. Feature test: social login with verified email skips verification
8. Feature test: Sanctum token with abilities restricts API access
9. Feature test: profile shows linked social accounts
10. Run full test suite

### Acceptance Criteria
- [ ] All new tests pass
- [ ] All existing tests still pass
- [ ] Zero test failures
