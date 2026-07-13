# GymBuddy

AI-guided fitness app. The Meta Ray-Ban Gen 2 glasses act as a "buddy" that watches
you train — counting reps, correcting form, guiding the workout, and answering
questions hands-free. Flutter front end (iOS + Android), Node/Express/MongoDB backend.
Full product context in docs/PRODUCT_BRIEF.md; architecture and per-milestone scope in
docs/PLAN.md; live task list in docs/STATUS.md.

## Structure
- `app/` — Flutter app. Feature-first under `lib/features/`.
- `server/` — Express API, Mongoose models under `src/models/`.
- Glasses/hardware lives behind `app/lib/sensors/sensor_source.dart`. Feature code
  NEVER calls the Meta DAT SDK directly — always go through that interface.

## Commands
- App: `cd app && flutter run` (device), `flutter analyze`, `flutter test`
- Server: `cd server && npm run dev`, `npm test`, `npm run lint`

## Conventions
- State management: Riverpod. No business logic in widgets.
- API: REST + JSON, JWT in the Authorization header, shared error response shape.
- Secrets via env only. The Gemini API key is server-side only — the app never holds it.
- Premium gating is enforced server-side, never trusted from the client.
- Commits: conventional commits (feat:, fix:, chore:).

## Status protocol — read this first, every session
1. On session start, read docs/STATUS.md and resume from "Next up".
2. Work only the first unchecked task of the active milestone.
3. Mark a task [x] ONLY after `flutter analyze` / `npm run lint` and the relevant tests
   pass clean. Never weaken or skip a test to make it pass.
4. On completion: check the box, add a dated Changelog line, update "Next up", and
   commit STATUS.md.
5. If you stop mid-task, leave the box unchecked and add an "IN PROGRESS: <what's left>"
   note on that task.

## Autonomous run rules
- Do exactly ONE STATUS.md task per headless invocation, then end your turn.
- Respect milestone gate tags. If the active milestone is tagged [HUMAN GATE] or
  [HARDWARE-REQUIRED] and is not [GATE CLEARED], print "HUMAN_GATE: <milestone>" and
  stop without changing anything.
- Never edit .env or secrets. Never force-push. Never run curl-pipe-to-shell.

## Guardrails
- Rep/form features must work against MockSensorSource with no hardware attached.
  Do not write feature code that assumes glasses are present.
- Green CI is necessary, not sufficient — write meaningful tests, not box-tickers.
