# GymBuddy — Build Status

> **Protocol (also in CLAUDE.md):**
> 1. At session start, read this file and resume from **Next up**.
> 2. Work the first unchecked task of the active milestone, one per invocation.
> 3. Mark a task `[x]` ONLY after analyze/lint + tests pass. Never weaken a test to pass.
> 4. On completion: check the box, add a dated Changelog line, update **Next up**, commit.
> 5. If you stop mid-task, leave it unchecked and add an `IN PROGRESS: ...` note.
>
> **Gates:** If the active milestone is tagged `[HUMAN GATE]` or `[HARDWARE-REQUIRED]`
> and NOT `[GATE CLEARED]`, print `HUMAN_GATE: <milestone>` and stop. A human clears a
> gate by changing its tag to `[GATE CLEARED]` after review.

---

## Next up
**M3 · Onboarding is underway** on branch `m3-onboarding` (cut from `dev` after
M2 merged). The flow is now seven steps: `features/onboarding/onboarding_screen.dart`
(`OnboardingScreen`, a `ConsumerWidget`) renders goals, experience, days/week,
equipment, injuries, body stats, and a closing health-data permission step,
driven entirely by `onboardingControllerProvider`
(`OnboardingController`/`OnboardingState`/`OnboardingDraft` in
`onboarding_controller.dart`; the wire-mirrored answer enums in
`onboarding_options.dart`). The screen is pure presentation: a per-step
`Continue`/`Finish` gated on `controller.canAdvance`, a Back button (hidden on
step 1), a `Step X of N` progress bar, body-stats range parsing, and the final
step's `health-connect` button forwarding to
`OnboardingController.requestHealthPermission()`. That permission ask goes
through `core/health/health_permission_service.dart`
(`HealthPermissionService` interface + default `MockHealthPermissionService`,
`healthPermissionServiceProvider`) — the M5 HealthKit / Health Connect impls
override that provider; the resulting `HealthPermissionStatus` lands on the
draft (kept client-side, not part of the Profile payload).

**Next task: route to Home on completion.** Persistence is now wired:
`OnboardingController.complete()` is async — it maps the `OnboardingDraft` to
the Profile wire shape and `PUT`s it through `profileApiProvider`
(`features/onboarding/profile_api.dart`, `ProfileApi.saveOnboarding`) to the new
backend `PUT /profile`, then flips `OnboardingState.completed` only on success
(a failed save sets `OnboardingState.saveError` and leaves the user on the last
step to retry; `OnboardingState.saving` drives the Finish spinner). The
device-level `healthPermission` is intentionally NOT sent. What's left is
navigation: there is still no router — `OnboardingScreen` does not navigate when
`completed` flips, and nothing yet decides onboarding-vs-Home at launch. Wire
that with the routing task, likely via the `AuthGate` (which today only branches
signed-in/out): after auth, fetch the profile (`GET /profile`) and route to
onboarding when `profile == null` or `onboardingComplete == false`, else the
shell; have `OnboardingScreen` trigger that transition on `completed`. The
backend Profile API is in place — `server/src/{routes,controllers,services,
validators}/profile.*` (`GET`/`PUT /profile`, both `requireAuth`; the bespoke
`validateProfile` middleware mirrors the model bounds and drops unknown keys),
mounted at `/profile` in `app.js`.

Auth is now fully wired end to end: the signed-out landing
(`features/auth/signed_out_screen.dart`) routes into `features/auth/auth_screen.dart`
(a single login/signup form, mode toggled in place), whose submission logic
lives in `features/auth/auth_form_controller.dart`
(`authFormControllerProvider`, `autoDispose`) — it calls
`AuthController.signIn`/`register`, surfaces `ApiException.message`, and on
success lets the gate swap in the shell while the screen pops itself. Field
validation (email format, 8+ char password on register) is client-side; the
network layer (`token_store.dart`, `api_client.dart` with the single-flight
refresh-on-401 interceptor, `auth_api.dart`) is unchanged. The design system
lives in `core/design/` (barrel `package:gymbuddy/core/design/design.dart`).
(Note: the Flutter SDK is present at `/opt/flutter/bin` but not on `PATH` —
prepend it before running `flutter analyze`/`test`. Riverpod is 3.x: a notifier
extends `Notifier<T>` and `autoDispose` is set on the provider
(`NotifierProvider.autoDispose<C, T>`); a notifier must not touch `state` before
its `build()` runs. Dev API base URL defaults to `http://10.0.2.2:4000` — the
Android-emulator alias for the host's dev server on port 4000; override
`apiBaseUrlProvider` per environment.)

---

## Milestones

### M0 — Scaffold & tooling  `[x]`
- [x] Monorepo initialized (`app/`, `server/`, `docs/`, `.claude/`)
- [x] Flutter app boots on a device/simulator
- [x] Express + Mongoose server boots with a health-check endpoint
- [x] Riverpod wired into the app
- [x] Lint + `flutter analyze` configured, both clean
- [x] CI runs analyze + server tests on push
- [x] `app/` and `server/` CLAUDE.md files created

### M1 — Backend foundation + auth  [GATE CLEARED]  `[x]`
- [x] Mongoose models: User, Profile, Plan, Workout, WorkoutLog, Subscription
- [x] JWT auth: register, login, refresh, logout (bcrypt)
- [x] Auth middleware
- [x] Request validation + shared error response shape
- [x] Passing integration tests for the auth flow

### M2 — Flutter foundation + design system + shell  `[ ]`
- [x] Design system in `core/design/` (theme, tokens, reusable widgets)
- [x] App shell + bottom nav (Home, Plans, Workout, Profile) behind an auth gate
- [x] API client with secure token storage + refresh interceptor
- [x] Login / signup screens wired to M1 endpoints

### M3 — Onboarding  `[ ]`
- [x] 5–7 step flow (goals, experience, days/week, equipment, injuries, body stats)
- [x] Health-data permission request step
- [x] Answers persisted via Profile API
- [ ] Routes to Home on completion

### M4 — Workout plans (general / free)  `[ ]`
- [ ] Template library seeded in backend
- [ ] Endpoint returns templates matched to profile
- [ ] Plans list + detail UI
- [ ] Select / persist active plan

### M5 — Vitals dashboard  `[ ]`
- [ ] `health` package integrated (HealthKit + Health Connect)
- [ ] Permission handling with graceful denied state
- [ ] Reads resting HR, HRV, sleep, steps, readiness proxy
- [ ] Home renders StatRings + sparklines, with empty states

### M6 — Workout session engine + logging  `[ ]`
- [ ] `WorkoutSensorSource` interface + `MockSensorSource` defined
- [ ] Session state machine (exercise → set → rest → next)
- [ ] Focus-mode UI (RepCounter, RestTimer)
- [ ] Manual rep/weight logging fallback
- [ ] Post-workout summary syncs to WorkoutLog

### M7 — Glasses integration layer  [HARDWARE-REQUIRED]  `[ ]`
- [ ] Android (Kotlin) platform channel wrapping DAT SDK (camera/audio/mic)
- [ ] iOS (Swift) platform channel wrapping DAT SDK
- [ ] `MetaGlassesSensorSource` implements `WorkoutSensorSource`
- [ ] Capability detection + fallback to MockSensorSource
- [ ] Audio cue playback through glasses speakers
- [ ] Custom mic-based wake trigger for Q&A
- [ ] App builds + runs with no hardware present

### M8 — On-device rep counting & pose  [HARDWARE-REQUIRED]  `[ ]`
- [ ] Pose model integrated (tflite_flutter)
- [ ] Rep detection fed by active sensor source
- [ ] Basic joint-angle checks
- [ ] Initial mirror/POV-friendly exercise set
- [ ] UI marks exercises form-tracked vs rep-tracked-only

### M9 — AI layer + premium  [HUMAN GATE]  `[ ]`
- [ ] Server-side Claude API plan-generation service (profile + history + vitals)
- [ ] Coaching service: sampled pose → short prioritized spoken cues
- [ ] RevenueCat paywall + premium state
- [ ] Premium gating enforced server-side
- [ ] App never holds the Claude API key

### M10 — Polish, analytics, beta  [HUMAN GATE]  `[ ]`
- [ ] Empty / error / loading states across features
- [ ] Accessibility pass
- [ ] Analytics + crash reporting
- [ ] TestFlight pipeline
- [ ] Firebase App Distribution pipeline
- [ ] Meta glasses release-channel build target

---

## Changelog
<!-- Newest first. Format: YYYY-MM-DD · Mx · what shipped -->
- 2026-06-26 · M3 · Onboarding answers persist via the Profile API. New backend
  Profile endpoints (`GET`/`PUT /profile`, both behind `requireAuth`):
  `routes/profile.routes.js` → `controllers/profile.controller.js` →
  `services/profile.service.js` (`getProfile`/`upsertProfile`, a
  `findOneAndUpdate` upsert keyed on `user` so a save is idempotent — one
  profile per user, created lazily on first save), mounted at `/profile` in
  `app.js`. The generic string/email `validate` middleware can't express a
  profile (enum arrays, nested body-stats, numeric ranges), so a dedicated
  `validators/profile.validators.js` (`validateProfile`) rejects the first
  violation with a 400 `ApiError` and rebuilds `req.body` from only the declared
  fields — dropping unknown keys so a client can't smuggle `isPremium` or the
  device-level `healthPermission` into the upsert. Every field is optional (a
  partial mid-onboarding save is valid) but any present field must be in-bounds
  (bounds mirror `profile.model.js`). Client: new
  `features/onboarding/profile_api.dart` (`ProfileApi.saveOnboarding`,
  `profileApiProvider`) maps the `OnboardingDraft` to the wire shape (each answer
  enum sent as its `wire` value, `onboardingComplete: true`; the health grant is
  excluded). `OnboardingController.complete()` is now async: it sets
  `OnboardingState.saving`, `PUT`s through the provider, and flips
  `completed` only on success — on an `ApiException`/error it records
  `OnboardingState.saveError` and stays on the last step so the user can retry.
  `OnboardingScreen` drives the Finish spinner off `saving` and shows the
  `onboarding-save-error` line. 9 new server tests (`tests/profile.test.js`:
  auth required, null-before-onboarding, full upsert + read-back, idempotent
  re-save, unknown-field stripping, invalid-goal/out-of-range-day/-bodystat
  rejection, partial save, per-user isolation) and updated client tests (3
  controller: persist-on-success, error-stays-incomplete, no-op-when-unsatisfied,
  all over a fake `ProfileApi`; 1 new widget: failed save surfaces the inline
  error; the full-walk + denial widget tests now override `profileApiProvider`).
  `npm run lint` clean, `npm test` 76/76; `flutter analyze` clean, `flutter test`
  75/75.
- 2026-06-26 · M3 · Health-data permission request step added as the closing
  (7th) onboarding step. New `core/health/health_permission_service.dart`
  abstracts the platform health-permission prompt behind a
  `HealthPermissionService` interface (`Future<HealthPermissionStatus> request()`,
  status one of `notRequested`/`granted`/`denied`/`unavailable`) — feature code
  never touches HealthKit / Health Connect directly, the same rule the sensor
  layer follows. The default `MockHealthPermissionService` (exposed via
  `healthPermissionServiceProvider`) grants immediately so the flow and dev
  builds work end to end with no platform store attached; M5 overrides the
  provider with the real `health`-package impls. `OnboardingController` gains
  `OnboardingStep.healthPermission`, a `HealthPermissionStatus` field on
  `OnboardingDraft` (kept on the draft for the flow but NOT mapped into the
  Profile payload — it's a device-level grant), a transient
  `OnboardingState.requestingHealth` in-flight flag, and an async
  `requestHealthPermission()` that calls the service through `ref`, records the
  outcome, and always clears the in-flight flag (even if the platform call
  throws). The step is optional — `canAdvance` is always true there, so a
  denial / unavailable platform never blocks finishing. The screen's
  `_HealthPermissionStep` renders the rationale + what's read, a `health-connect`
  `PrimaryButton` (spinner while in flight, disabled once granted), and a
  `health-status` feedback line per outcome; `Finish` still completes the flow
  whether or not the user connects. 5 new tests (3 controller: optional/starts
  unrequested, records grant + clears flag, records denial; 2 widget: the full
  seven-step walk now connects health before finishing, and a denial is shown
  yet still finishable) plus the existing six-step assertions updated to seven.
  `flutter analyze` clean, `flutter test` 72/72 green.
- 2026-06-26 · M3 · The 5–7 step onboarding flow UI shipped. New
  `features/onboarding/onboarding_screen.dart` (`OnboardingScreen`, a
  `ConsumerWidget`) renders the six steps — goals (multi-select), experience
  (single-select with descriptions), days/week (1–7 chips), equipment
  (multi-select; "None" clears the rest), injuries (optional add/remove chips),
  and body stats (optional height/weight/age/sex) — over the existing
  `onboardingControllerProvider`. Per the no-logic-in-widgets rule the screen is
  pure presentation: it reads `OnboardingState`, forwards taps to the
  controller, gates the per-step `Continue`/`Finish` button on
  `controller.canAdvance` (goals/experience/days/equipment require a selection;
  injuries and body stats never block), shows a Back button (hidden on step 1)
  and a `Step X of N` progress bar, and the body-stats step keeps local text
  controllers and does presentation-level range parsing (mirroring the server's
  Profile bounds via `OnboardingLimits`) before handing only in-range/null
  values to the controller. Finishing the last step calls
  `OnboardingController.complete()`, flipping `OnboardingState.completed` — the
  handoff point for the persistence + routing tasks that follow (the screen does
  not yet navigate on completion). Reusable `_OptionTile`/`_DayChip` built from
  the design tokens (accent-fill selected state, ≥48dp targets). 15 new tests
  (`test/features/onboarding/`): 11 controller tests (selection, toggles, the
  equipment "None" exclusivity, injury trim/dedupe/truncate, day clamping, the
  advance gate per step, complete) and 4 widget tests (gate disabled until a
  goal is picked, Back hidden on step 1, a full walk through all six steps that
  asserts `completed` + the collected draft, and out-of-range body stats dropped
  to null). `flutter analyze` clean, `flutter test` 68/68 green.
- 2026-06-26 · M2 · Login / signup screens wired to the M1 `/auth/*` endpoints,
  completing M2. New `features/auth/auth_screen.dart` is one form serving both
  modes (toggled in place via an `auth-toggle` button) so the user can switch
  between logging in and creating an account without losing context: an email
  field, a password field, and — in register mode only — an optional name field.
  Submission logic stays out of the widget per the no-logic-in-widgets rule: the
  new `features/auth/auth_form_controller.dart` (`authFormControllerProvider`, an
  `autoDispose` `Notifier<AuthFormState>`) owns the network exchange. Its
  `submit({mode, email, password, displayName})` calls
  `AuthController.signIn`/`register`, returns `true` on success (leaving
  `submitting` true so the button can't re-fire before the gate tears the screen
  down) and on an `ApiException` captures `message` into `AuthFormState.errorMessage`
  and returns `false`; a second submit while one is in flight is ignored, and
  `clearError()` wipes a stale error on mode-toggle. The screen runs client-side
  validation (email format; 8+ char password on register, matching the server's
  register rule; login only requires non-empty) before any network call, shows
  the server error inline (`auth-error`), and on success pops itself so the gate
  (now authenticated) reveals the shell. `SignedOutScreen` now routes into the
  auth screen — "Get started" → register mode, "I already have an account" →
  sign-in mode — replacing the transitional `signInForPreview`, which is deleted
  from `AuthController`. 10 new tests (`auth_form_controller_test.dart` 5:
  register/login success, error surfacing, clearError, single-flight;
  `auth_screen_test.dart` 4: empty-field block skips the network, short-password
  rejection, mode toggle shows/hides the name field, backend-error surfacing);
  `auth_gate_test.dart` rewritten to drive the real form (mocked `ApiClient`)
  through landing → form → shell → sign out. `flutter analyze` clean, `flutter
  test` 53/53 green.
- 2026-06-26 · M2 · API client + secure token storage + refresh interceptor, and
  `AuthController` wired to the M1 `/auth/*` endpoints. New `core/storage/token_store.dart`:
  `AuthTokens` (value type) behind a `TokenStore` interface with `SecureTokenStore`
  (OS keychain/keystore via `flutter_secure_storage`; reads/clears swallow
  platform/read failures so a host with no secure storage degrades to a
  signed-out session rather than crashing) and `InMemoryTokenStore` (tests),
  exposed via `tokenStoreProvider`. New `core/network/api_client.dart`: `ApiClient`
  is a thin JSON-over-HTTP client (on `package:http`) that injects
  `Authorization: Bearer <access>` on authenticated calls and runs the refresh
  interceptor — on a `401` it exchanges the refresh token at `/auth/refresh`,
  persists the rotated pair, and replays the original request exactly once;
  concurrent 401s share one in-flight refresh (so the refresh token rotates at
  most once); a failed refresh clears tokens, fires `onSessionExpired`, and
  surfaces the original 401 as an `ApiException` (whose message is lifted from
  the backend's shared `{ error: { message } }` shape). `core/` stays free of any
  upward dependency on the auth feature: the expiry hook is a no-op
  `sessionExpiredProvider` that `main.dart` (the composition root) overrides to
  call `AuthController.signOut`. New `features/auth/auth_api.dart` (`AuthApi`)
  types the `/auth/{register,login,logout}` calls into `AuthSession`
  (`AuthUser` + `AuthTokens`). `AuthController` now: `build()` returns
  `AuthStatus.unknown` and restores the session from the token store at launch
  (tokens present → authenticated, optimistic — an expired access token is
  repaired by the interceptor on the first protected call, a dead refresh token
  routes back through `signOut`; else → unauthenticated), `signIn`/`register`
  exchange credentials via `AuthApi` and persist the issued pair, `signOut`
  clears tokens then best-effort revokes server-side. The transitional
  signed-out landing keeps a credential-free `signInForPreview` until the login
  screens land next. 19 new tests (token store 4, ApiClient 7 incl. refresh /
  single-flight / failed-refresh, AuthApi 3, AuthController 5 incl.
  restore/persist/clear); existing gate + boot widget tests updated to seed an
  empty `InMemoryTokenStore` and settle past the new restore splash. Added deps
  `http` + `flutter_secure_storage`. `flutter analyze` clean, `flutter test`
  43/43 green.
- 2026-06-26 · M2 · App shell + four-tab bottom nav, behind a single auth gate.
  `AuthGate` (`features/auth/`) is the one place the app branches on auth: it
  watches `authControllerProvider` and renders the `AppShell` when
  authenticated, the `SignedOutScreen` when not, and a splash while session
  restore is pending (`AuthStatus.unknown`, reserved for the next token-storage
  task). `AuthController` is a thin in-memory `Notifier<AuthStatus>` stub
  (`signIn`/`signOut`) so the gate is real and testable now; credential exchange
  lands next. `AppShell` is a Material 3 `NavigationBar` over an `IndexedStack`
  (tab bodies kept alive across switches) with the four primary destinations —
  Home, Plans, Workout, Profile. Selected-tab index lives in Riverpod
  (`shellTabProvider`, an `autoDispose` `NotifierProvider`) rather than widget
  state, per the no-logic-in-widgets rule, so it survives rebuilds and is
  test-inspectable; `autoDispose` resets it to Home on a fresh sign-in. Home /
  Plans / Workout are on-brand `ComingSoon` placeholders (filled in M3–M6);
  Profile hosts the `signOut` action so the gate has a way back; the
  `SignedOutScreen` shows branding from `appInfoProvider` + a "Get started" CTA
  that calls `signIn`. `main.dart` boots straight into `AuthGate`. Reconciled
  the shell/auth code (committed earlier as a pre-run checkpoint) with
  Riverpod 3.x: replaced the legacy `StateProvider` with a `ShellTabController
  extends Notifier<int>`, switched the test override to a zero-arg factory, and
  fixed the authenticated-container helper to use an `AuthController` subclass
  whose `build()` returns authenticated (a notifier can't set `state` before
  `build()` runs). 5 new tests (`test/features/auth/auth_gate_test.dart` walks
  signed-out → sign in → shell → sign out; `test/features/shell/app_shell_test.dart`
  covers the four destinations + tab switching). `flutter analyze` clean,
  `flutter test` 24/24 green.
- 2026-06-26 · M2 · Design system landed in `app/lib/core/design/`, the
  foundation all feature UI builds on (imported via the barrel
  `core/design/design.dart`). Tokens centralize the visual language: `AppColors`
  (dark-first near-black surface ramp + the single energetic accent `0xFF00E5A0`
  with an `onAccent` near-black for legible text over it), `AppSpacing` (8pt
  grid + `minTouchTarget` 48), `AppRadii`, `AppDurations`, and `AppTypography`
  — whose numeric styles use `FontFeature.tabularFigures` so in-workout counters
  and timers don't jitter as digit widths change. `AppTheme.dark` overrides
  Material 3 heavily (near-black scaffold, flat un-elevated cards, pill primary
  buttons sized to the 48dp target, accent-focused inputs). Five reusable
  widgets, all purely presentational (logic stays in providers per the
  no-logic-in-widgets rule): `PrimaryButton` (full-width pill CTA with disabled +
  loading states, where loading uses an accent spinner that stays visible
  against the disabled surface), `MetricTile` (labelled dashboard metric),
  `StatRing` (CustomPainter ring sweeping from 12 o'clock, progress clamped to
  [0,1]), `RepCounter` (huge glanceable rep numeral + optional target), and
  `RestTimer` (depleting ring + m:ss readout, guards zero/negative inputs, turns
  warning-colored under 10s). `main.dart` now uses `AppTheme.dark`. 19 widget +
  theme tests (`test/core/design/`) covering callbacks, tap-gating while loading,
  value formatting, and out-of-range clamping. `flutter analyze` clean, `flutter
  test` 19/19 green. (Flutter 3.44.4 lives at `/opt/flutter/bin`, not on PATH.)
- 2026-06-26 · M1 · End-to-end auth-flow integration tests
  (`tests/auth.flow.test.js`), completing M1. Where `auth.test.js` exercises
  each endpoint in isolation and `auth.middleware.test.js` mounts `requireAuth`
  against synthetic tokens, this walks one user through the *connected*
  lifecycle against an in-memory MongoDB: register → use the issued access
  token on a real protected `/me` route → refresh (rotation) → use the rotated
  access token → logout → confirm the refresh token is revoked and reuse 401s.
  Proves tokens minted by the real `/auth/*` endpoints authenticate through the
  real middleware stack, that a refresh token is rejected as a Bearer access
  token (type mismatch), and that a missing token yields the shared
  `{ error: { message } }` 401. It also pins the designed contract that an
  access token stays valid until expiry after logout (logout revokes only the
  refresh side). 5 new tests; `npm run lint` clean, `npm test` 65/65 green.
- 2026-06-26 · M1 · Request validation + a centralized shared error shape. New
  generic `validate(schema)` middleware (`src/middleware/validate.middleware.js`)
  checks/sanitizes `req.body` at the edge and, on the first violation, forwards a
  400 `ApiError` with a clear message; on success it replaces `req.body` with
  only the declared fields (unknown keys dropped, so a client can't smuggle
  extra props into a `create`). Per-route schemas in
  `src/validators/auth.validators.js`: register enforces email format + an 8–200
  char password + ≤80 char displayName; login only requires a non-empty password
  (≤200) so a too-short attempt still gets the same non-enumerating 401, not a
  400; refresh/logout require `refreshToken`. Emails are trimmed + lowercased;
  passwords/tokens are left byte-for-byte intact. New `errorHandler`
  (`src/middleware/error.middleware.js`, mounted last in `app.js`) is now the
  single owner of the `{ error: { message } }` shape — maps `ApiError`/`AuthError`
  (any 4xx `statusCode`), dup-key 11000 → 409, Mongoose `ValidationError` → 400,
  malformed JSON → 400, and everything else → opaque logged 500. `asyncHandler`
  wraps the controllers so the ad-hoc `fail`/`handleServiceError`/`try-catch`
  guards are gone — handlers now trust validated input and let errors propagate.
  13 new Mongo-free validation tests (`tests/auth.validation.test.js`).
  `npm run lint` clean, `npm test` 60/60 green.
- 2026-06-26 · M1 · Auth middleware added (`src/middleware/auth.middleware.js`).
  `requireAuth` parses the `Authorization: Bearer <access>` header, verifies it
  via `token.service.verifyAccessToken`, loads the owning user, and attaches
  `req.user` + `req.userId` for downstream handlers. Every failure path —
  missing header, non-Bearer scheme, malformed/invalid/expired token, a refresh
  token presented as an access token (caught by the `type` check), or a valid
  token whose user no longer exists — returns `401` with the shared
  `{ error: { message } }` shape; non-JWT errors propagate to `next(err)`.
  7 new integration tests via `mongodb-memory-server` against a tiny app that
  mounts the middleware on a protected route. `npm run lint` clean,
  `npm test` 47/47 green.
- 2026-06-26 · M1 · JWT auth flow shipped: `POST /auth/{register,login,refresh,logout}`.
  `token.service` signs/verifies access (15m) + refresh (30d) JWTs under separate
  secrets with a `type` claim, so neither can be replayed as the other; refresh
  tokens carry a unique `jti`. `auth.service` hashes passwords with bcrypt
  (`BCRYPT_ROUNDS`, default 12), creates the default free `Subscription` on
  register, and uses a new `RefreshToken` model (stores only the `jti` + TTL index,
  never the token string) for server-side rotation/revocation — refresh atomically
  consumes the old `jti` and issues a fresh pair, so replaying a rotated/revoked
  token 401s; logout is idempotent. Login uses one non-enumerating 401 for both
  unknown email and bad password. Controllers map `AuthError`/dup-key/validation
  onto the shared `{ error: { message } }` shape; `passwordHash` is never returned.
  Env gains JWT/bcrypt settings with dev fallbacks + `assertProdSecrets()` boot
  guard; `.env.example` updated. 17 new tests (6 token unit + 11 full-flow
  integration via `mongodb-memory-server`). `npm run lint` clean, `npm test` 40/40 green.
- 2026-06-26 · M1 · Six Mongoose models added under `server/src/models/`: `User`
  (email + bcrypt `passwordHash`, hash `select:false` and stripped from `toJSON`),
  `Profile` (onboarding goals/experience/days/equipment/injuries/body stats, one
  per user), `Workout` (training-day definition with embedded exercises carrying a
  `formTracked` flag per the POV-glasses constraint), `Plan` (ordered Workout refs +
  profile-match attrs, `isTemplate`/`isActive`/`owner`), `WorkoutLog` (performed
  session with nested logged sets, `{user, startedAt:-1}` index), and `Subscription`
  (premium entitlement with an `isPremiumActive()` method for server-side gating).
  Shared enums centralized in `models/constants.js`; barrel export in `models/index.js`.
  23 unit tests (validation + method behavior via `validateSync()`, no live Mongo
  needed) — `npm run lint` clean, `npm test` 23/23 green.
- 2026-06-26 · M0 · Area `CLAUDE.md` files added for `app/` and `server/`, completing M0. Each complements the root file rather than duplicating it: `app/CLAUDE.md` covers the `lib/` layout, Riverpod/no-logic-in-widgets rule, package imports, strict-lint expectations, the dark-first theme tokens, and the `WorkoutSensorSource`/mock hardware rule; `server/CLAUDE.md` covers the side-effect-free `app.js` vs `server.js` split, the routes→controllers→services→models layering, env-only secrets, the shared `{ error: { message } }` shape, and server-side premium gating. Server `npm run lint` + `npm test` green (2/2); docs-only change, no Dart touched (Flutter SDK absent in this env, as in prior M0 entries).
- 2026-06-26 · M0 · CI added (`.github/workflows/ci.yml`), runs on push + pull_request. Two parallel jobs: **app** (Flutter stable via subosito/flutter-action → `flutter pub get` + `flutter analyze` + `flutter test`) and **server** (Node 18 with npm cache → `npm ci` + `npm run lint` + `npm test`). YAML validated; server lint + tests run green locally (2/2). Flutter job not runnable in this env (no SDK installed) — verified config syntax instead.
- 2026-06-26 · M0 · Lint + analyze configured and clean on both ends. Flutter `analysis_options.yaml` hardened beyond the template: strict-casts/inference/raw-types, `missing_required_param`/`dead_code` as errors, build/generated files excluded, plus curated lints (single quotes, trailing commas, const-correctness, package imports, `avoid_print`, `unawaited_futures`). Fixed the surfaced issues (`main.dart` package import, alphabetized pubspec deps). Server keeps its `eslint:recommended` config. `flutter analyze` → no issues, `flutter test` 2/2 green, `npm run lint` clean.
- 2026-06-26 · M0 · Riverpod wired into the app: `ProviderScope` at the root in `main.dart`, first provider `appInfoProvider` in `core/app_info.dart`, `BootScreen` reads it as a `ConsumerWidget`; widget tests verify boot + provider override. `flutter analyze` clean, `flutter test` green (2/2).
- 2026-06-26 · M0 · Express + Mongoose server boots with a `GET /health` endpoint (status/uptime/timestamp/db state); src split into config/db/routes/controllers; jest+supertest tests and eslint config added, `npm run lint` + `npm test` green.
- 2026-06-26 · M0 · Flutter app scaffolded (`flutter create`, org com.gymbuddy, android+ios); GymBuddyApp boot screen replaces the demo counter; widget smoke test verifies boot; `flutter analyze` + `flutter test` green.
- 2026-06-26 · M0 · Monorepo initialized: app/, server/, docs/, .claude/ skeleton per PLAN, plus root .gitignore and README.
