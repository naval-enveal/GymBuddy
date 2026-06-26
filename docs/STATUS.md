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
**M0 · Scaffold & tooling** → Lint + `flutter analyze` configured, both clean.

---

## Milestones

### M0 — Scaffold & tooling  `[ ]`
- [x] Monorepo initialized (`app/`, `server/`, `docs/`, `.claude/`)
- [x] Flutter app boots on a device/simulator
- [x] Express + Mongoose server boots with a health-check endpoint
- [x] Riverpod wired into the app
- [ ] Lint + `flutter analyze` configured, both clean
- [ ] CI runs analyze + server tests on push
- [ ] `app/` and `server/` CLAUDE.md files created

### M1 — Backend foundation + auth  [HUMAN GATE]  `[ ]`
- [ ] Mongoose models: User, Profile, Plan, Workout, WorkoutLog, Subscription
- [ ] JWT auth: register, login, refresh, logout (bcrypt)
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
- 2026-06-26 · M0 · Riverpod wired into the app: `ProviderScope` at the root in `main.dart`, first provider `appInfoProvider` in `core/app_info.dart`, `BootScreen` reads it as a `ConsumerWidget`; widget tests verify boot + provider override. `flutter analyze` clean, `flutter test` green (2/2).
- 2026-06-26 · M0 · Express + Mongoose server boots with a `GET /health` endpoint (status/uptime/timestamp/db state); src split into config/db/routes/controllers; jest+supertest tests and eslint config added, `npm run lint` + `npm test` green.
- 2026-06-26 · M0 · Flutter app scaffolded (`flutter create`, org com.gymbuddy, android+ios); GymBuddyApp boot screen replaces the demo counter; widget smoke test verifies boot; `flutter analyze` + `flutter test` green.
- 2026-06-26 · M0 · Monorepo initialized: app/, server/, docs/, .claude/ skeleton per PLAN, plus root .gitignore and README.
