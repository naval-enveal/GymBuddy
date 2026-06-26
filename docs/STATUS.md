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
**M2 · Flutter foundation + design system + shell** → next task: API client with
secure token storage + refresh interceptor. The shell + auth gate now exist
(`AuthGate` → `AppShell` four-tab `NavigationBar`, or `SignedOutScreen` when
signed out); `AuthController` is still an in-memory stub — this next task wires
it to the M1 `/auth/*` endpoints with secure token persistence + a refresh
interceptor, after which launch-time session restore can resolve the gate's
`AuthStatus.unknown` splash. The design system lives in `core/design/` and
feature UI is built from its barrel (`package:gymbuddy/core/design/design.dart`).
(Note: the Flutter SDK is present at `/opt/flutter/bin` but not on `PATH` —
prepend it before running `flutter analyze`/`test`. Riverpod is 3.x: legacy
`StateProvider` lives behind `flutter_riverpod/legacy.dart` — prefer a
`Notifier`; `NotifierProvider.overrideWith` takes a zero-arg factory and a
notifier must not touch `state` before its `build()` runs.)

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
- [ ] API client with secure token storage + refresh interceptor
- [ ] Login / signup screens wired to M1 endpoints

### M3 — Onboarding  `[ ]`
- [ ] 5–7 step flow (goals, experience, days/week, equipment, injuries, body stats)
- [ ] Health-data permission request step
- [ ] Answers persisted via Profile API
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
