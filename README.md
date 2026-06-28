# GymBuddy

AI-guided fitness app. The Meta Ray-Ban Gen 2 glasses act as a "buddy" that watches
you train — counting reps, correcting form, guiding the workout, and answering
questions hands-free.

## Monorepo layout

```
gymbuddy/
├── app/      # Flutter app (iOS + Android), feature-first under lib/features/
├── server/   # Node + Express + MongoDB (Mongoose) API
├── docs/      # Product brief, architecture plan, build status
└── .claude/   # Agent harness config
```

## Getting started

- **App:** `cd app && flutter pub get && flutter run`
- **Server:** `cd server && npm install && npm run dev`

## Release pipelines

- **iOS → TestFlight:** `app/ios/fastlane` (`fastlane beta`), run from
  `.github/workflows/ios-testflight.yml` on a `v*` tag push or manual dispatch.
  Required secrets and one-time signing bootstrap are documented in
  `app/ios/fastlane/README.md`. Ordinary pushes stay on `ci.yml`.
- **Android → Firebase App Distribution:** `app/android/fastlane`
  (`fastlane beta`), run from `.github/workflows/android-firebase-distribution.yml`
  on a `v*` tag push or manual dispatch. Required secrets and one-time keystore /
  service-account bootstrap are documented in `app/android/fastlane/README.md`.
  Ordinary pushes stay on `ci.yml`.

### Meta glasses release channel

The default consumer build ships **mock-only**: it never bundles Meta's
proprietary DAT SDK and never touches the native glasses channel (the resolver
short-circuits to `MockSensorSource`). The glasses-enabled artifact is a distinct
build target, gated by a single flag:

- **Dart:** `--dart-define=GLASSES_ENABLED=true` (`kGlassesChannelEnabled` in
  `app/lib/sensors/glasses_build_config.dart` — the single source of truth).
- **Android (native):** `GLASSES_ENABLED=true` env or `-Pglasses=true`. Drop the
  vendored DAT SDK `.aar` into `app/android/app/libs/` (gitignored, never
  committed); it is linked only for this target.
- **iOS (native):** vendor the DAT SDK framework into the Xcode project, then
  build with the dart-define above.

Build it via `.github/workflows/glasses-channel-build.yml` (a `glasses-v*` tag
push or manual dispatch — kept off ordinary pushes and the plain `v*` release
pipelines). Local example:
`cd app && GLASSES_ENABLED=true flutter build apk --release --dart-define=GLASSES_ENABLED=true`.
The SDK is detected reflectively at runtime, so a glasses build with no SDK
vendored (e.g. CI) still degrades gracefully to `MockSensorSource`.

## Sources of truth

- `docs/PRODUCT_BRIEF.md` — product context
- `docs/PLAN.md` — architecture and per-milestone scope
- `docs/STATUS.md` — live task list and build status
- `CLAUDE.md` — conventions and build rules
