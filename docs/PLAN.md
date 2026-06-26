# GymBuddy — Architecture & Build Plan

The reference the autonomous agent consults for *what* and *how* to build each task. The task checklist lives in STATUS.md; this file explains the scope behind each milestone.

## Stack (locked)

| Layer | Choice |
|---|---|
| App | Flutter (iOS + Android, single codebase) |
| Glasses I/O | Meta DAT SDK via native platform channels (Kotlin + Swift), behind a `WorkoutSensorSource` interface |
| On-device ML | tflite_flutter / MediaPipe (rep counting, pose) |
| Cloud AI | Claude API (premium plan generation + form coaching), server-side only |
| Backend | Node.js + Express + MongoDB (Mongoose) |
| Auth | JWT (access + refresh), bcrypt |
| Vitals | HealthKit (iOS) + Health Connect (Android) via the `health` package |
| Payments | RevenueCat (premium tier) |

## Two constraints that shape scope

1. **Publishing is gated.** The Meta Wearables Device Access Toolkit is in developer preview; public store distribution of the glasses integration is limited to Meta partners until later in 2026. The phone app ships independently of this; glasses features are built and beta-tested now, published later.
2. **The glasses are first-person POV.** They see what the user sees, not the user's own body. Form correction is therefore a *graded* feature: ship it first for mirror-facing and POV-visible exercises, and mark each exercise in the UI as form-tracked vs rep-tracked-only. Do not assume universal form tracking.

## Hardware abstraction (critical)

All sensor input flows through `app/lib/sensors/sensor_source.dart` (`WorkoutSensorSource`). Two implementations: `MockSensorSource` (works today, no hardware) and `MetaGlassesSensorSource` (real DAT SDK). The app must build and run fully on the mock. Other wearables can implement the same interface later with no change to feature code.

## Repo structure

```
gymbuddy/
├── app/                       # Flutter
│   ├── lib/
│   │   ├── core/{design,network,storage}/
│   │   ├── features/{onboarding,plans,vitals,workout,coach}/
│   │   ├── sensors/{sensor_source,mock_sensor_source,meta_glasses_sensor_source}.dart
│   │   └── main.dart
│   ├── android/               # Kotlin platform channel + DAT SDK
│   └── ios/                   # Swift platform channel + DAT SDK
├── server/                    # Node + Express + MongoDB
│   └── src/{models,routes,controllers,services,middleware}/
└── docs/
```

## Design system (build once in app/lib/core/design/ before any feature UI)

Clean, gym-first, consistent. Dark-first (near-black surfaces); a single energetic accent on grayscale; a large glanceable numeral style for in-workout data (rep count, timer, weight); an 8pt spacing grid; ≥48dp touch targets for sweaty hands; a stripped-down focus mode during sets; vitals as rings + sparklines; subtle, purposeful motion only. Centralize tokens + reusable widgets (PrimaryButton, MetricTile, StatRing, RepCounter, RestTimer). Override Material 3 heavily rather than shipping its default look.

## Milestones

- **M0 — Scaffold & tooling.** Runnable Flutter app + Express/Mongoose server, Riverpod, lint + analyze, CI running both, CLAUDE.md files.
- **M1 — Backend foundation + auth.** Mongoose models (User, Profile, Plan, Workout, WorkoutLog, Subscription), JWT auth (register/login/refresh/logout + bcrypt), auth middleware, validation, shared error shape, tests.
- **M2 — Flutter foundation + design system + shell.** The design system above, app shell + bottom nav behind an auth gate, API client with secure token storage + refresh, login/signup.
- **M3 — Onboarding.** 5–7 step flow (goals, experience, days/week, equipment, injuries, body stats) + health-permission step, persisted to the Profile API.
- **M4 — Workout plans (general/free).** Seeded template library, profile-matched endpoint, Plans list/detail UI, select/persist active plan.
- **M5 — Vitals dashboard.** `health` package (HealthKit + Health Connect), permission handling, read resting HR / HRV / sleep / steps / readiness, render as rings + sparklines with empty states.
- **M6 — Workout session engine + logging.** `WorkoutSensorSource` interface + `MockSensorSource`, session state machine (exercise → set → rest → next), focus-mode UI, manual logging, post-workout summary synced to WorkoutLog.
- **M7 — Glasses integration (hardware-gated).** Android (Kotlin) + iOS (Swift) platform channels wrapping the DAT SDK (camera/audio/mic), `MetaGlassesSensorSource`, capability detection + fallback to mock, audio cue output, custom mic-based wake trigger for Q&A. Must compile/run with no hardware.
- **M8 — On-device rep counting & pose.** tflite_flutter pose model fed by the active sensor source, rep counting + basic joint-angle checks for an initial mirror/POV-friendly exercise set, form-tracked vs rep-tracked UI.
- **M9 — AI layer + premium.** Server-side Claude API plan generation (profile + history + vitals) and a coaching service (sampled pose → short prioritized spoken cues), RevenueCat paywall, server-enforced premium gating.
- **M10 — Polish, analytics, beta.** Empty/error/loading states, accessibility, analytics + crash reporting, TestFlight + Firebase App Distribution pipelines, Meta glasses release-channel build.
