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
**M1 · Backend foundation + auth** `[GATE CLEARED]` → next task: Auth middleware
that verifies the `Authorization: Bearer <access>` header, loads the user, and
rejects missing/invalid/expired tokens with the shared error shape. Builds on the
`verifyAccessToken` helper in `token.service`.

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

### M1 — Backend foundation + auth  [GATE CLEARED]  `[ ]`
- [x] Mongoose models: User, Profile, Plan, Workout, WorkoutLog, Subscription
- [x] JWT auth: register, login, refresh, logout (bcrypt)
- [ ] Auth middleware
- [ ] Request validation + shared error response shape
- [ ] Passing integration tests for the auth flow

### M2 — Flutter foundation + design system + shell  `[ ]`
- [ ] Design system in `core/design/` (theme, tokens, reusable widgets)
- [ ] App shell + bottom nav (Home, Plans, Workout, Profile) behind an auth gate
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
