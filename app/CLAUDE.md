# GymBuddy — Flutter app

Flutter front end (iOS + Android, single codebase). Boots to `BootScreen` today;
the design system, shell, and feature screens land in M2+. See `../docs/PLAN.md`
for per-milestone scope and `../docs/STATUS.md` for the live task list. Root
conventions in `../CLAUDE.md` apply here too.

## Commands (run from `app/`)
- `flutter run` — launch on a connected device/simulator
- `flutter analyze` — must be clean before a task is marked done
- `flutter test` — widget/unit tests under `test/`
- `flutter pub get` — after editing `pubspec.yaml`

## Layout (`lib/`)
- `main.dart` — entry point. `ProviderScope` wraps the root `GymBuddyApp`.
- `core/` — cross-feature building blocks:
  - `design/` — theme, tokens, reusable widgets (PrimaryButton, MetricTile,
    StatRing, RepCounter, RestTimer). Build this in M2 before any feature UI.
  - `network/` — API client, secure token storage, refresh interceptor (M2).
  - `storage/` — local persistence.
- `features/{onboarding,plans,vitals,workout,coach}/` — feature-first. Keep each
  feature self-contained; share only via `core/`.
- `sensors/` — hardware abstraction. `sensor_source.dart` defines
  `WorkoutSensorSource`; implementations are `MockSensorSource` (works with no
  hardware) and `MetaGlassesSensorSource` (DAT SDK, M7).

## Conventions
- **State: Riverpod.** Providers own logic; widgets only read/watch and render.
  No business logic, no I/O, no direct service calls inside widget `build`.
- **Imports:** use `package:gymbuddy/...` for cross-directory imports, not
  relative paths (enforced by `analysis_options.yaml`).
- **Lint is strict.** Single quotes, trailing commas, const-correctness,
  `avoid_print`, `unawaited_futures`; strict casts/inference/raw-types.
  `missing_required_param` and `dead_code` are errors. Don't relax these to pass.
- **Theme:** dark-first, single energetic accent (seed `0xFF00E5A0`) on
  grayscale, 8pt spacing grid, ≥48dp touch targets, large glanceable numerals for
  in-workout data. Override Material 3 heavily rather than shipping its defaults.

## Hardware rule (critical)
Feature code NEVER touches the Meta DAT SDK directly — always go through
`WorkoutSensorSource`. Every rep/form feature must build and run fully against
`MockSensorSource` with no glasses attached. Never write code that assumes
hardware is present.

## Secrets
The app never holds the Gemini API key or any server secret. AI calls go through
the backend. Premium state is informational only — gating is enforced server-side.
