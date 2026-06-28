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

## Sources of truth

- `docs/PRODUCT_BRIEF.md` — product context
- `docs/PLAN.md` — architecture and per-milestone scope
- `docs/STATUS.md` — live task list and build status
- `CLAUDE.md` — conventions and build rules
