# Sub-Tasks: Plan 02 - Authentication & Organization Model

---

## Task 2.1: Install & Configure Socialite

### Sub-task 2.1.1: Install Socialite via Composer
- Run `composer require laravel/socialite --no-interaction`
- Verify installation: `composer show laravel/socialite`
- Check `composer.json` includes `laravel/socialite`

### Sub-task 2.1.2: Add GitHub provider config to config/services.php
- Open `config/services.php`
- Add GitHub block:
  ```php
  'github' => [
      'client_id' => env('GITHUB_CLIENT_ID'),
      'client_secret' => env('GITHUB_CLIENT_SECRET'),
      'redirect' => env('GITHUB_REDIRECT_URI', '/auth/github/callback'),
  ],
  ```

### Sub-task 2.1.3: Add Google provider config to config/services.php
- Add Google block:
  ```php
  'google' => [
      'client_id' => env('GOOGLE_CLIENT_ID'),
      'client_secret' => env('GOOGLE_CLIENT_SECRET'),
      'redirect' => env('GOOGLE_REDIRECT_URI', '/auth/google/callback'),
  ],
  ```

### Sub-task 2.1.4: Update .env.example with Socialite variables
- Add:
  ```
  GITHUB_CLIENT_ID=
  GITHUB_CLIENT_SECRET=
  GITHUB_REDIRECT_URI="${APP_URL}/auth/github/callback"
  GOOGLE_CLIENT_ID=
  GOOGLE_CLIENT_SECRET=
  GOOGLE_REDIRECT_URI="${APP_URL}/auth/google/callback"
  ```

### Sub-task 2.1.5: Verify Socialite auto-discovery
- Check that `Laravel\Socialite\SocialiteServiceProvider` is auto-discovered
- Verify `Socialite` facade is accessible: `php artisan tinker` → `Socialite::driver('github')`

---

## Task 2.2: Social Accounts Migration & Model

### Sub-task 2.2.1: Create social_accounts migration
- Run `php artisan make:migration create_social_accounts_table --no-interaction`
- Define columns:
  - `$table->uuid('id')->primary()`
  - `$table->foreignId('user_id')->constrained()->cascadeOnDelete()`
  - `$table->string('provider', 32)` — github, google
  - `$table->string('provider_id')` — provider's user ID
  - `$table->text('provider_token')->nullable()` — encrypted OAuth token
  - `$table->text('provider_refresh_token')->nullable()` — encrypted refresh token
  - `$table->string('avatar_url', 512)->nullable()`
  - `$table->string('provider_email')->nullable()` — email from provider
  - `$table->timestamps()`
- Add unique index: `$table->unique(['provider', 'provider_id'])`
- Add index: `$table->index('user_id')`

### Sub-task 2.2.2: Run migration and verify
- Run `php artisan migrate --no-interaction`
- Verify table exists: `php artisan tinker` → `Schema::hasTable('social_accounts')`
- Verify columns: `Schema::getColumnListing('social_accounts')`

### Sub-task 2.2.3: Create SocialAccount model
- Run `php artisan make:model SocialAccount --no-interaction`
- Add `HasUuids` trait
- Set `$fillable`: `['user_id', 'provider', 'provider_id', 'provider_token', 'provider_refresh_token', 'avatar_url', 'provider_email']`
- Add `casts()` method:
  ```php
  protected function casts(): array
  {
      return [
          'provider_token' => 'encrypted',
          'provider_refresh_token' => 'encrypted',
      ];
  }
  ```
- Add `user()` BelongsTo relationship with return type `BelongsTo`

### Sub-task 2.2.4: Add socialAccounts relationship to User model
- Open `app/Models/User.php`
- Add method:
  ```php
  public function socialAccounts(): HasMany
  {
      return $this->hasMany(SocialAccount::class);
  }
  ```
- Import `HasMany` use statement

### Sub-task 2.2.5: Create SocialAccount factory
- Run `php artisan make:factory SocialAccountFactory --model=SocialAccount --no-interaction`
- Define:
  ```php
  'user_id' => User::factory(),
  'provider' => fake()->randomElement(['github', 'google']),
  'provider_id' => (string) fake()->unique()->randomNumber(8),
  'provider_token' => Str::random(40),
  'provider_email' => fake()->safeEmail(),
  'avatar_url' => fake()->imageUrl(200, 200),
  ```
- Add state methods: `github()`, `google()`

### Sub-task 2.2.6: Test model relationships and factory
- In tinker: create user, attach social account, verify `$user->socialAccounts`
- Verify `$socialAccount->user` returns the user
- Verify factory generates valid records

---

## Task 2.3: Social Auth Controller & Routes (Extensible Pattern)

### Sub-task 2.3.1: Define supported providers in config
- Open `config/services.php`
- Add a `social_providers` array listing all supported OAuth providers:
  ```php
  'social_providers' => ['github', 'google'],
  ```
- Optionally create `app/Enums/SocialProvider.php` as a string-backed enum:
  ```php
  enum SocialProvider: string
  {
      case GitHub = 'github';
      case Google = 'google';
  }
  ```
- This single list controls which providers are valid everywhere (routes, UI buttons, etc.)
- To add a new provider (e.g. GitLab, Bitbucket): add it to this array/enum plus credentials in `.env`

### Sub-task 2.3.2: Create SocialAuthController
- Run `php artisan make:controller SocialAuthController --no-interaction`

### Sub-task 2.3.3: Implement generic redirect method
- Add `redirect(string $provider)` method:
  ```php
  public function redirect(string $provider): RedirectResponse
  {
      return Socialite::driver($provider)
          ->scopes($this->getScopes($provider))
          ->redirect();
  }
  ```
- Create private `getScopes(string $provider)` method using a match expression:
  ```php
  private function getScopes(string $provider): array
  {
      return match ($provider) {
          'github' => ['user:email'],
          'google' => ['openid', 'profile', 'email'],
          default  => [],
      };
  }
  ```

### Sub-task 2.3.4: Implement callback method - get provider user
- Add `callback(string $provider)` method
- Wrap in try-catch for `GuzzleHttp\Exception\ClientException` and Socialite errors
- Get user: `$socialUser = Socialite::driver($provider)->user()`
- Extract: `$socialUser->getId()`, `$socialUser->getEmail()`, `$socialUser->getName()`, `$socialUser->getAvatar()`

### Sub-task 2.3.5: Implement callback - find existing social account
- Query: `SocialAccount::where('provider', $provider)->where('provider_id', $socialUser->getId())->first()`
- If found: log in the associated user: `Auth::login($socialAccount->user)`
- Update token if changed: `$socialAccount->update(['provider_token' => $socialUser->token])`
- Redirect to dashboard

### Sub-task 2.3.6: Implement callback - find user by email (no social account)
- If no social account match, look up by email: `User::where('email', $socialUser->getEmail())->first()`
- If found: create `SocialAccount` linking provider to existing user
- Log in the user
- Redirect to dashboard

### Sub-task 2.3.7: Implement callback - create new user
- If no existing user or social account:
- Create new user:
  ```php
  $user = User::create([
      'name' => $socialUser->getName() ?? $socialUser->getNickname(),
      'email' => $socialUser->getEmail(),
      'password' => Hash::make(Str::random(32)), // random password, user can reset
      'email_verified_at' => $this->isEmailVerified($provider, $socialUser) ? now() : null,
  ]);
  ```
- Create personal team for user (Jetstream requirement):
  ```php
  $user->ownedTeams()->save(Team::forceCreate([
      'user_id' => $user->id,
      'name' => explode(' ', $user->name, 2)[0] . "'s Team",
      'personal_team' => true,
  ]));
  ```
- Create `SocialAccount` record
- Log in: `Auth::login($user)`

### Sub-task 2.3.8: Implement email verification logic
- Create private `isEmailVerified()` method:
  - GitHub: check `$socialUser->user['email_verified']` if available, or assume verified if email is primary
  - Google: Google always provides verified email for OAuth
  - If verified: set `email_verified_at = now()` on user creation
  - If NOT verified: leave `email_verified_at = null` → user will be redirected to verification

### Sub-task 2.3.9: Handle edge cases
- Already-linked account (different user): flash error "This {provider} account is already linked to another user"
- Provider returns no email: flash error and redirect to register with message
- OAuth error/cancelled: catch exception, flash error, redirect to login
- User is already authenticated and visits social callback: link account to current user instead of creating new

### Sub-task 2.3.9: Register extensible routes in routes/web.php
- Add routes that read the supported providers from config (not hardcoded):
  ```php
  Route::get('/auth/{provider}/redirect', [SocialAuthController::class, 'redirect'])
      ->name('auth.social.redirect')
      ->whereIn('provider', config('services.social_providers'));
  Route::get('/auth/{provider}/callback', [SocialAuthController::class, 'callback'])
      ->name('auth.social.callback')
      ->whereIn('provider', config('services.social_providers'));
  ```
- Ensure routes are NOT behind auth middleware (must be accessible to guests)
- When a new provider is added to `config('services.social_providers')`, these routes automatically support it

### Sub-task 2.3.11: Test social redirect in browser
- Visit `/auth/github/redirect` — verify redirects to GitHub OAuth page
- Visit `/auth/google/redirect` — verify redirects to Google OAuth page
- (Requires valid client IDs configured in `.env`)

---

## Task 2.4: Social Login UI Integration

### Sub-task 2.4.1: Add social buttons to login page
- Open `resources/views/auth/login.blade.php`
- Add divider after password form: `<div class="flex items-center my-6"><div class="flex-1 border-t"></div><span class="px-4 text-sm text-gray-500">or continue with</span><div class="flex-1 border-t"></div></div>`
- Add GitHub button: link to `route('auth.social.redirect', 'github')` with GitHub SVG icon
- Add Google button: link to `route('auth.social.redirect', 'google')` with Google SVG icon
- Style buttons: full-width, outline style, icon + text

### Sub-task 2.4.2: Add social buttons to register page
- Open `resources/views/auth/register.blade.php`
- Add same divider and buttons as login page
- Same routes, same styling

### Sub-task 2.4.3: Create GitHub SVG icon component
- Create `resources/views/components/icons/github.blade.php`
- Add GitHub logo SVG with configurable `class` prop

### Sub-task 2.4.4: Create Google SVG icon component
- Create `resources/views/components/icons/google.blade.php`
- Add Google logo SVG with configurable `class` prop

### Sub-task 2.4.5: Add linked accounts to profile settings
- Open profile settings view (Jetstream)
- Add "Connected Accounts" section
- Display list of linked social accounts with provider name, email, connected date
- Add "Disconnect" button for each linked account (if user has password set)
- Add "Connect GitHub" / "Connect Google" buttons for unlinked providers

### Sub-task 2.4.6: Implement disconnect social account
- Create method in controller or Livewire action to delete social account
- Guard: don't allow disconnect if it's the only auth method (no password set)
- Flash success/error message
- Audit log: log disconnect event

### Sub-task 2.4.7: Style for dark mode
- Verify all social buttons render correctly in dark mode
- GitHub button: use white icon on dark background in dark mode
- Google button: maintain Google brand colors per guidelines
- Divider text color: `text-gray-500 dark:text-gray-400`

---

## Task 2.5: Configure Sanctum API Token Abilities

### Sub-task 2.5.1: Define API permissions in JetstreamServiceProvider
- Open `app/Providers/JetstreamServiceProvider.php`
- Add in `boot()` or `configurePermissions()`:
  ```php
  Jetstream::permissions([
      'projects:read',
      'projects:write',
      'events:read',
      'crashes:read',
      'traces:read',
      'billing:read',
      'compliance:read',
      'compliance:write',
  ]);
  ```

### Sub-task 2.5.2: Set default permissions for new tokens
- Add:
  ```php
  Jetstream::defaultApiTokenPermissions(['projects:read', 'events:read']);
  ```

### Sub-task 2.5.3: Verify API token creation UI shows abilities
- Visit profile settings → API Tokens
- Create a new token
- Verify all defined permissions appear as checkboxes
- Verify defaults are pre-checked

### Sub-task 2.5.4: Create CheckTokenAbility middleware (or use existing)
- Verify Sanctum's `CheckAbilities` or `CheckForAnyAbility` middleware is available
- Register alias if needed in `bootstrap/app.php`:
  ```php
  ->withMiddleware(function (Middleware $middleware) {
      $middleware->alias([
          'abilities' => \Laravel\Sanctum\Http\Middleware\CheckAbilities::class,
          'ability' => \Laravel\Sanctum\Http\Middleware\CheckForAnyAbility::class,
      ]);
  })
  ```

### Sub-task 2.5.5: Write test for token ability enforcement
- Create a Sanctum token with only `projects:read` ability
- Test: GET `/api/v1/projects` succeeds with this token
- Test: POST `/api/v1/projects` fails with 403 (needs `projects:write`)
- Test: token with no abilities gets 403 on all endpoints

---

## Task 2.6: Enforce Email Verification

### Sub-task 2.6.1: Verify MustVerifyEmail interface
- Open `app/Models/User.php`
- Verify class implements `Illuminate\Contracts\Auth\MustVerifyEmail`
- If not, add: `class User extends Authenticatable implements MustVerifyEmail`

### Sub-task 2.6.2: Verify verified middleware on dashboard routes
- Open `routes/web.php`
- Verify dashboard route has `verified` middleware:
  ```php
  Route::middleware(['auth:sanctum', config('jetstream.auth_session'), 'verified'])->group(function () {
      Route::get('/dashboard', ...);
  });
  ```
- Ensure ALL dashboard/project routes are inside this middleware group

### Sub-task 2.6.3: Customize verification email template
- Open `resources/views/emails/` or check for Jetstream/Fortify verification email
- Create custom notification if needed: `php artisan make:notification VerifyEmailNotification --no-interaction`
- Add Pulseboard branding: logo, colors, custom text
- Update User model to use custom notification if overriding

### Sub-task 2.6.4: Handle social login verified emails
- In `SocialAuthController::callback()`, already set `email_verified_at = now()` when provider verifies email
- Verify: social login user with verified email can access dashboard immediately
- Verify: social login user without verified email sees verification notice

### Sub-task 2.6.5: Write email verification test
- Test: unverified user visiting `/dashboard` gets redirected to email verification notice
- Test: verified user can access `/dashboard`
- Test: clicking verification link verifies user
- Test: re-sending verification email works

---

## Task 2.7: Write Auth & Org Tests

### Sub-task 2.7.1: Test social redirect generates correct URL
- Mock Socialite driver
- Call `GET /auth/github/redirect`
- Assert redirect URL starts with `https://github.com/login/oauth/authorize`
- Assert state parameter is present (CSRF protection)

### Sub-task 2.7.2: Test GitHub callback creates new user
- Mock Socialite to return fake GitHub user
- Call `GET /auth/github/callback`
- Assert new user created in database
- Assert personal team created
- Assert social account created
- Assert user is authenticated
- Assert redirect to dashboard

### Sub-task 2.7.3: Test Google callback creates new user
- Same as 2.7.2 but for Google provider
- Verify Google-specific email verification behavior

### Sub-task 2.7.4: Test callback with existing email links account
- Create user with email `test@example.com`
- Mock Socialite to return same email
- Call callback
- Assert NO new user created
- Assert social account linked to existing user
- Assert user is authenticated

### Sub-task 2.7.5: Test callback with existing social account logs in
- Create user with linked GitHub social account
- Mock Socialite to return same provider_id
- Call callback
- Assert user logged in (no new user/account created)

### Sub-task 2.7.6: Test duplicate social account rejection
- Create user A with linked GitHub account
- Log in as user B
- Mock Socialite to return user A's GitHub provider_id
- Call callback
- Assert error flashed: "already linked"

### Sub-task 2.7.7: Test invalid provider returns 404
- Call `GET /auth/invalid_provider/redirect`
- Assert 404 response

### Sub-task 2.7.8: Test Sanctum token abilities
- Create user and generate token with `projects:read` only
- Make API request with token to read endpoint → assert 200
- Make API request with token to write endpoint → assert 403

### Sub-task 2.7.9: Test email verification enforcement
- Create unverified user
- Attempt to access `/dashboard` → assert redirect to verification notice
- Verify user's email → attempt again → assert 200

### Sub-task 2.7.10: Run full regression
- Run `php artisan test --compact`
- Verify zero failures across all tests
