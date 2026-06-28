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
**M10 — Polish, analytics, beta** is the active milestone (`[GATE CLEARED]`) on
branch `m10-polish` (descends from `dev` with the merged M9 work stacked on top).
Task 1 (**Empty / error / loading states across features**) is **done** and
pushed: a shared `StateMessage` design-system widget now backs the empty/error
states that plans, home, and workout previously duplicated inline. **Next up:
task 2 — Accessibility pass** (semantics labels, touch-target/contrast audit, large
glanceable numerals already in the design system). After that: analytics + crash
reporting, TestFlight pipeline, Firebase App Distribution pipeline, and the Meta
glasses release-channel build target. When all six M10 tasks are checked, open PR
`Milestone M10: beta` from `m10-polish` into `dev` and stop for human review.

State-widget design notes (task 1, done): the empty/error states across features
shared one copy-pasted layout (icon + title + optional supporting line + optional
retry/CTA button). Extracted it into a single design-system widget,
`app/lib/core/design/widgets/state_message.dart` `StateMessage` (exported from the
`design.dart` barrel) — presentation only, a `Column(mainAxisSize.min)` with the
56px `onSurfaceVariant` icon, `titleMedium` title, optional `bodyMedium`-muted
message, and an optional `PrimaryButton` action (`actionLabel`/`actionIcon`/
`onAction`/`actionKey`, asserted that label+action come together). It is unwrapped
so callers place it in a `Center` for a full-screen state or drop it into a
`ListView` under a `RefreshIndicator` for a pull-to-refresh empty state. Adopted
in `_PlansEmpty`/`_PlansError` (plans), `_DashboardError` (home), and
`_NoPlan`/`_StartError` (workout) — every existing state key (`plans-empty`,
`plans-retry`, `vitals-error`, `vitals-error-retry`, `workout-empty`,
`workout-error`, `workout-error-retry`) and visible copy is preserved on the
caller's wrapper, so the feature widget tests are unchanged. Loading states were
already uniform (a keyed `Center(child: CircularProgressIndicator())`) and left
as-is; auth/onboarding carry their own inline error+`isLoading` affordances and
need no change. 4 new tests (`test/core/design/widgets_test.dart` `StateMessage`
group: icon+title with no message/action, supporting message rendered, action
button fires `onAction`, the label/action assert). `flutter analyze` clean,
`flutter test` 329/329 green (+4).

Task 5 design notes (done): "the app never holds the Claude API key" — verified
end to end and locked with a guard. The key is server-side only by construction —
`config.anthropic.apiKey` ← `ANTHROPIC_API_KEY` env, read in exactly one place
(`config/env.js`) and used in exactly one place (the `claude.client` `getClient()`
seam that lazily builds the `@anthropic-ai/sdk` client; both AI services go
through it). Nothing under `app/` references the key or the SDK: the only matches
for "Claude API key" in app sources are *prose* comments in `main.dart` /
`revenuecat_premium_service.dart` explaining the contract; the app holds only the
**public** RevenueCat key via `--dart-define=REVENUECAT_API_KEY` (not a secret).
The app reaches AI exclusively through the premium-gated backend endpoints
(`POST /plans/generate`, `POST /coaching/cues`) over the single `apiClient` seam.
The server-only-key contract is documented in `.env.example`, `server/CLAUDE.md`,
`app/CLAUDE.md`, and `config/env.js`. New regression guard
`app/test/security/no_claude_key_test.dart` walks the app's shipping surface
(`lib/`, `android/`, `ios/`, `macos`/`windows`/`linux`, `pubspec.yaml`; skips
`build/`/`.dart_tool/`/`Pods/`/`.gradle/`/`ephemeral/` and `test/` itself) and
fails if any of `ANTHROPIC_API_KEY`, an `sk-ant-` key prefix, or an Anthropic SDK
dependency (`anthropic-ai`, `package:anthropic`) appears — it forbids key
machinery, not prose, so the explanatory comments stay legal. A `files.length >
10` sanity assertion prevents a vacuous pass from an empty/wrong-cwd walk;
confirmed the guard fails on a planted token and passes once removed. No server
changes were needed (the contract was already satisfied). `flutter analyze` clean,
`flutter test` 325/325 green (+1).

Premium-gating design notes (task 4, done): premium access is enforced
server-side, never trusted from the client. New
`server/src/middleware/premium.middleware.js` `requirePremium` — mounted
**after** `requireAuth` (it reads `req.userId`), it loads the caller's
`Subscription` (the M1 source of truth, created `free` at registration) and
rejects with `402 Premium subscription required` (via `ApiError`, rendered by the
central error handler) unless `Subscription.isPremiumActive()` returns true. That
method already folds tier + status + expiry together, so a cancelled/expired row
that still says `tier: 'premium'` is gated out, and a user with **no** row
(defense in depth) is treated as free. Wired ahead of the validators on both AI
endpoints (`plan.routes.js` `/generate`, `coaching.routes.js` `/cues`) so a free
caller is rejected **before** any Claude call (and before request validation).
The client's `PremiumService`/`isPremiumProvider` (task 3) is informational UX
only and has zero authority here. The existing AI-behavior tests register a
premium caller now (a shared `grantPremium(userId)` helper flips the default
subscription via `Subscription.updateOne`) since these endpoints are premium; 6
new gating tests assert the gate directly (free→402 with the injected Claude
client proven **never invoked**, expired/cancelled premium→402, active
premium→through). `npm run lint` clean, `npm test` 136/136.

Premium client design notes (task 3, done): the client's view of entitlement,
behind a mock-first seam — RevenueCat lives only in the real impl, never in
feature code (same rule as `WorkoutSensorSource`/`HealthPermissionService`).
`app/lib/features/premium/premium_service.dart`: `PremiumService` (abstract
interface, every method **contracted never to throw** — store/network failure
degrades to `free`/`empty`, a cancelled purchase returns the unchanged status),
the RevenueCat-agnostic value types `PremiumStatus` (`free`/`premium`),
`PremiumPackage`/`PremiumOffering` (value-equality projections of store
packages, so the paywall never imports `purchases_flutter`), and
`MockPremiumService` (the provider default — starts free, offers fixed packages,
`purchase` flips to premium so the unlock flow runs end to end with no store,
mirroring `MockSensorSource`). `revenuecat_premium_service.dart`:
`RevenueCatPremiumService` over `purchases_flutter` (`^10.3.0`) — maps the
`kPremiumEntitlementId` (`'premium'`) active entitlement to status, swallows
every store/platform failure (incl. the user-cancelled purchase error code), and
`configure({apiKey})` is best-effort. `premium_controller.dart`:
`PremiumController extends AsyncNotifier<PremiumState>` (`build()` reads
status+offering concurrently; `purchase`/`restore` fold the result back behind a
single-flight `purchasing` flag that's **always** cleared even if the service
throws; `refresh()` re-reads) + `isPremiumProvider` (a plain `bool`, `false`
until premium is positively confirmed — the safe default; server enforces the
real gate). `paywall_screen.dart`: renders the controller state (spinner /
retryable error / upsell with per-package buy buttons + restore / `_PremiumActive`
confirmation; empty offering → "purchases unavailable" + restore). `premium_gate.dart`:
`PremiumGate` reveals its child only when premium else a locked CTA that
`openPaywall`s (mirrors `VitalsPermissionGate`). Profile tab gained a
`_PremiumSection` (status badge + upgrade entry). **Composition root** (`main.dart`):
the RevenueCat **public** SDK key arrives via `--dart-define=REVENUECAT_API_KEY`
(not a secret, unlike the server-only Claude key); when set, `configure` runs and
`premiumServiceProvider` is overridden to the real service — otherwise the mock
default keeps dev/test working with no store. Note: Riverpod 3.x exposes the
nullable value as `AsyncValue.value` (not `valueOrNull`), and `Override` isn't a
public type so override lists are built inline. 22 tests (`test/features/premium/`:
8 service incl. value-equality + mock unlock + provider default, 6 controller incl.
single-flight + always-clear-on-throw + refresh, 3 gate, 5 paywall widget incl.
buy→confirmation + unavailable + error→retry). `flutter analyze` clean,
`flutter test` 324/324 green (the RevenueCat native purchase flow can't run
headless — the seam + mock + injected-fake gate is what's verified).

Coaching design notes (task 2, done): real-time form coaching lives server-side
behind the same `claude.client` seam as plan generation (the single key-holding
entry point; inject a fake via `setClient` in tests). `services/coaching.service.js`
`generateCues(userId, {exercise, formCues?, reps?, targetReps?, setNumber?})`
takes the on-device pose/form snapshot from the request body (pose lives
on-device, never stored), reads the caller's Profile (`experience` + `injuries`)
server-side to personalize and keep the wearer safe — **optional**, not required
(unlike plan generation, coaching still runs with no profile), builds a
system+user prompt, and calls `messages.create` with `output_config.format`
json_schema (`CUES_SCHEMA`) on `config.anthropic.model` (`claude-opus-4-8`,
`max_tokens` 400 — cues are tiny). Output runs through `sanitizeCues`: trims each
cue, drops blanks/non-strings, clamps cue length (160), preserves model order
(= priority) and caps the count at 3 — so malformed-but-parseable output can
never flood the speakers; a clean set returns `[]` (never throws). No text block
/ invalid JSON is a `502`; unconfigured AI is a `503` (via `getClient`). New
`POST /coaching/cues` (`requireAuth` → `validateCoachingCues` → controller)
returns `200 { cues: [...] }` (ordered, most important first); the app plays them
via `MetaGlassesSensorSource.playCue`. `coaching.validators.js` accepts a
required `exercise`, an optional `formCues` array (`{severity?, message, joint?}`,
severities good/minor/major mirroring the Dart `FormSeverity`, ≤20 entries), and
optional `reps`/`targetReps`/`setNumber` (per-field numeric bounds), stripping
everything else. Premium gating is **not** wired on this endpoint yet (M9 task 4).
12 new tests (`tests/coaching.test.js`: auth required, cues for a faulty set,
prompt carries exercise+faults+set-progress+profile + model/structured-output,
works with no profile, empty list for a clean set, sanitation trims/drops/caps,
no-cues-array → `[]`, 502 invalid-JSON, 503 unconfigured, 400 missing-exercise,
400 bad-severity, 400 out-of-range-reps). `npm run lint` clean, `npm test`
130/130. (The native Claude call can't run headless — the seam + injected-fake
gate is what's verified.)

AI plan-generation design notes (task 1, done): server-side only — the Claude
API key lives in env (`config.anthropic`, never the client) and all Claude
calls go through the new `claude.client.js` seam (`getClient()` lazily builds
the `@anthropic-ai/sdk` client from the key and throws `503` when unset;
`setClient()` injects a fake for tests so AI is exercised with no network).
`services/ai-plan.service.js` `generatePlan(userId, {vitals})` reads the
caller's Profile + the 10 most recent `WorkoutLog`s server-side, takes the
client-supplied `vitals` snapshot (resting HR / HRV / sleep / steps / readiness
— vitals live on-device in HealthKit/Health Connect, so they arrive in the
request body, never stored), builds a system+user prompt, and calls
`messages.create` with `output_config.format` json_schema (`PLAN_SCHEMA`) on
`claude-opus-4-8`. The model output is parsed and run through
`sanitizeGeneratedPlan` — clamps every numeric to its model bounds, drops
nameless/empty entries, filters unknown equipment, and falls back to the
profile's own goal/experience for out-of-vocabulary enums — so malformed-but-
parseable output can never throw at the Mongoose layer; a plan with no usable
workouts (or invalid JSON / no text block) is a `502`. `persistGeneratedPlan`
then mirrors `adoptTemplate`: owned Workouts + an owned, non-template,
`isActive` Plan with `sourceTemplate:null`, deactivating any prior active plan
(one active plan per user, server-enforced). New `POST /plans/generate`
(`requireAuth` → `validateGeneratePlan` → controller) returns `201 { plan }`
with workouts populated; `ai-plan.validators.js` accepts only an optional
`vitals` object (per-field numeric bounds, strips everything else).
`error.middleware` now renders `ApiError` verbatim for **all** statuses
(previously 4xx-only) so a deliberate `502`/`503` reaches the client instead of
an opaque `500` — `ApiError` messages are curated/client-safe by construction.
Premium gating is **not** wired on this endpoint yet (a later M9 task). Added
`@anthropic-ai/sdk` dependency. 11 new tests (`tests/ai-plan.test.js`: auth
required, profile-required, generate+persist owned/active, prior-active
deactivated, prompt carries profile+history+vitals + model/structured-output,
malformed-output sanitation, 502 no-workouts, 502 invalid-JSON, 503
unconfigured, 400 bad-vitals ×2). `npm run lint` clean, `npm test` 118/118.
(The native Claude call can't run headless — the seam + injected-fake gate is
what's verified.)

Task 5 design notes (done): `plan_detail_screen.dart`'s `_TrackingBadge` now
takes a `PoseTracking` and is built from `poseTrackingFor(exercise.name)` (the
catalog in `app/lib/core/pose/pose_exercise_catalog.dart` — single source of
truth), not the server `PlanExercise.formTracked` flag. A `switch` maps the three
states to (key, label, icon, color): `formTracked` → `exercise-form-tracked` /
"Form tracked" / visibility / accent; `repsOnly` → `exercise-reps-only` / "Reps
only" / numbers / muted; `none` → `exercise-not-tracked` / "Not tracked" /
visibility-off / muted (the new third state — previously the server flag only
gave two). So the badge can never promise form feedback the pose layer lacks
rules for, matching the session-mapper's catalog-driven `formTracked`.

Catalog design notes (task 4, done): "which exercises the glasses can track from
POV" is now one authoritative module, not a server flag the client trusts. Plans
seed *descriptive* names ("Back Squat", "Dumbbell Romanian Deadlift") while the
pose configs are keyed by short canonical movements ("squat", "romanian
deadlift"), so exact lookup matched no real plan exercise. New
`app/lib/core/pose/pose_exercise_matching.dart`: a pure `matchCanonicalKey(name,
keys)` — case-insensitive **substring** match, **longest-key-wins** so the
specific "romanian deadlift" beats the generic "deadlift". New
`app/lib/core/pose/pose_exercise_catalog.dart`: a `PoseTracking` enum
(`none`/`repsOnly`/`formTracked`) with an `isPoseTrackable`/`isRepTracked`/
`isFormTracked` extension, `kPoseTrackableExercises` (the union of the rep
`kExerciseAngleConfigs` + form `kExerciseFormConfigs` keysets — the curated set),
`canonicalExerciseKey(name)`, and `poseTrackingFor(name)` (form config →
`formTracked`, angle-only → `repsOnly`, else `none`). `resolveAngleConfig`/
`resolveFormRules` now route through `matchCanonicalKey` too, so rep counting,
form checks, and pose-trackability can never disagree about whether an exercise
is recognised (existing exact-name + case-insensitive resolver tests stay green —
an exact key is the longest match). `session_mapper.dart`'s `toSessionPlan()` now
sets `TrackedExercise.formTracked` from `poseTrackingFor(e.name).isFormTracked`
(the catalog), **not** the server `PlanExercise.formTracked` flag — so the engine
(and the `MetaGlassesSensorSource` form-checker wiring it gates) never promises
form feedback the pose layer has no rules for. Invariant enforced by test: every
form-config movement also has a rep angle config (form tracking implies rep
counting). 17 new tests (`pose_exercise_catalog_test.dart`: matcher substring/
longest-wins/blank, `canonicalExerciseKey` real plan names + unrecognised,
`poseTrackingFor` form/rep-only/none, capability getters, union set + form⊆angle
invariant; + 1 in `session_models_test.dart`: catalog overrides the server flag
both ways). `flutter analyze` clean, `flutter test` 301/301 green (the plans UI
still reads the server flag — task 5 switches it to the catalog).

Form-check design notes (task 3, done): pose-based form feedback mirrors the
task-2 rep-counter design — pure-Dart, synchronous, reading the *same* joint
angles. New `app/lib/core/pose/pose_form_checker.dart`: `FormRule`
(`{id, pivot, from, to, minAngle, maxAngle, severity, message, minConfidence}`,
asserts `minAngle <= maxAngle`) describes one joint-angle band — a measured angle
outside `[minAngle, maxAngle]` is a fault — and `PoseFormChecker(List<FormRule>)`
is an **edge-triggered** state machine: `processFrame(frame)` returns the cues
that *newly* fired this frame (a held fault yields one cue, not one per frame,
tracked via a `Set<String>` of active rule ids), can fire again after recovering
into the good band, leaves a rule's state untouched when its keypoints are
missing/low-confidence, and `reset()` clears state per set. The angle math that
was private to `PoseRepCounter` (`_angleDeg`) moved to a shared
`PoseFrame.angleDegrees(from, pivot, to, {minConfidence})` on
`pose_landmarks.dart` (returns null on absent/low-confidence keypoints); the rep
counter now reads it too, so rep counting and form checks gate on confidence
identically. New `app/lib/core/pose/exercise_form_configs.dart`:
`kExerciseFormConfigs` (squat/lunge forward-lean via the shoulder–hip–knee torso
angle; deadlift/romanian-deadlift back-rounding via the ear–shoulder–hip spine
line; push-up hip-sag) and `resolveFormRules(name)` (case-insensitive, empty list
for unknowns) — thresholds approximate, calibrated on-device later.
`MetaGlassesSensorSource.formCues` is now a broadcast `StreamController<FormCue>`
(mirroring task-2's `reps`): native form cues (if the SDK ever emits any) merge in
on first listen, and `startTracking` — when the exercise is `formTracked`, pose is
ready, and rules exist — wires a `PoseFormChecker` driven off the **one** pose
frame subscription (shared with the rep counter), pushing each cue into the
controller; `stopTracking` resets it, `dispose` closes the controller. Gated on
`formTracked` so non-form exercises emit nothing (the POV form-only contract).
21 new tests (15 `pose_form_checker_test.dart`: `FormRule` assert + minConfidence
default, checker good-band/fault/upper-bound/edge-trigger/recovery/low-confidence/
absent-keypoint/multi-rule/reset, `resolveFormRules` known+case-insensitive/empty/
coverage+message/unique-ids; 6 `meta_glasses_sensor_source_test.dart`: fault emits
a cue, held fault edge-triggered to one, no cue when not form-tracked, no cue for
an exercise without rules, cues stop after `stopTracking`). `flutter analyze`
clean, `flutter test` 288/288 green (native isn't compilable headless — the Dart
gate is what's verified).

Wake-trigger design notes (task 6, done): the second *input* path from the
glasses — a control signal, not a tracking one. The mic listens for a fixed wake
phrase (`kWakePhrase` = "hey buddy") and pushes a `WakeEvent` that opens a
hands-free Q&A turn (the Q&A round-trip itself is M9/AI). Because wake detection
is an asynchronous push from the DAT SDK's always-on mic — and independent of
`startTracking` (the wearer asks between sets) — it's a **third `EventChannel`**,
`gymbuddy/glasses/wake` (`{timestampMs, phrase, confidence?}`), not a
request/response on the control channel. **Dart:** `sensor_source.dart` gained a
`const kWakePhrase` (single source of truth, one place to grow into per-user
config later), a `WakeEvent` value type (`{phrase, timestamp, confidence?}`,
value-equality), and a `Stream<WakeEvent> get wakeEvents` on
`WorkoutSensorSource`, mirroring `reps`/`formCues`. `MockSensorSource` surfaces a
real broadcast `wakeEvents` plus an `emitWake({phrase, confidence})` emitter —
driveable in tests like `emitRep`/`emitFormCue`, but **independent of tracking**
(no `startTracking` needed; only `dispose` stops it), so Q&A wiring runs with no
hardware; it is deliberately **not** auto-simulated (a random wake mid-dev would
be noise). `MetaGlassesSensorSource` adds `kGlassesWakeChannel`, an injectable
`wakeChannel`, and a lazily-cached broadcast `wakeEvents` decoding
`{timestampMs, phrase, confidence?}` (phrase defaults to `kWakePhrase` if the
native side omits it, so a trigger is never dropped). The glasses source degrades
to an empty/never-firing stream when the SDK is absent (native emits nothing).
**Native:** Kotlin/Swift `DatSdkClient` gained `setWakeListener(listener?)`
(separate from the `startTracking` `TrackingListener` because wake is always-on)
and a `WakeSample`/`WakeListener` pair; `Unavailable*` never calls back (empty
stream with no hardware), `DatSdkAvailable*` stores it (TODO: arm the SDK's
wake-word engine for the fixed phrase, exposed as `WAKE_PHRASE`/`wakePhrase`).
Both `GlassesChannel`s wire the new `gymbuddy/glasses/wake` `EventChannel` and arm
the wake listener only while Flutter is listening (Android on `onListen`/
`onCancel`; iOS via new optional `onListen`/`onCancel` closures on
`QueuingStreamHandler`), posting each detection onto the main thread; both
`dispose()`s clear it; wire-contract doc updated in both headers. 7 new Dart tests
(meta: decode + phrase-default + broadcast; mock: `emitWake` independent-of-
tracking + overridden phrase/confidence + broadcast + `WakeEvent` equality);
`_FakeSensorSource` in the resolver test gained the `wakeEvents` override.
`flutter analyze` clean, `flutter test` 228/228 green (native isn't compilable
headless — the Dart gate is what's verified).

Audio-cue design notes (task 5, done): the first *output* path back to the
glasses. Rather than a sibling interface, `playCue(String message)` was added to
the existing `WorkoutSensorSource` seam (`app/lib/sensors/sensor_source.dart`) so
the session/coach layer reaches the speakers through the *one* resolved source the
rest of the hardware already goes through — no second provider or parallel
fallback machinery. Contract: best-effort, must **never** throw on a delivery
failure. `MockSensorSource.playCue` (the fallback whenever glasses are absent) is
a silent no-op — it has no speakers — guarded by the same `_ensureActive()` as the
other lifecycle calls (so it throws only after `dispose`, parity with the rest);
callers can fire cues unconditionally and they vanish harmlessly with no hardware.
`MetaGlassesSensorSource.playCue` invokes `playCue` over the control
`MethodChannel('gymbuddy/glasses')` with `{message}`, swallowing
`PlatformException`/`MissingPluginException` (no speaker route / unregistered
channel) — the cue is coaching, not control flow. Native sides mirror the new
verb: Kotlin/Swift `DatSdkClient` gained `playCue(message)` (`Unavailable*` =
silent no-op; `DatSdkAvailable*` = TODO over the SDK's audio/TTS route once
vendored), and both `GlassesChannel`s handle the `playCue` method (args
`{message}`, `bad_args` error if missing, else null) with the wire-contract doc
updated on both. 5 new Dart tests (3 `meta_glasses_sensor_source_test.dart`:
forwards `{message}`, swallows a `PlatformException`, swallows a
`MissingPluginException`; 1 `mock_sensor_source_test.dart`: silent no-op completes;
plus the after-dispose-throws assertions extended in both). `flutter analyze`
clean, `flutter test` 221/221 green (native isn't compilable headless — the Dart
gate is what's verified).

Capability-detection design notes (task 4, done): the M7 fallback lives in
`app/lib/sensors/sensor_source_resolver.dart` — a single async
`resolveWorkoutSensorSource({glassesFactory, mockFactory})` that constructs the
glasses source, `connect()`s it once, and **keeps it only when it reports
`SensorAvailability.available`**; on `unavailable` (no DAT SDK, channel
unregistered, no pair) — or any unexpected throw from the probe — it `dispose()`s
the glasses and returns a fresh `MockSensorSource`. The factories default to
`MetaGlassesSensorSource.new` / `MockSensorSource.new` and are injectable so the
resolver is unit-tested with fake sources and no platform channels.
`workoutSensorSourceProvider` stays a **synchronous** `Provider` (default still
the mock, so every existing test is untouched), and `main()` is now `async`:
`WidgetsFlutterBinding.ensureInitialized()` → `await
resolveWorkoutSensorSource()` → `workoutSensorSourceProvider.overrideWith((ref){
ref.onDispose(source.dispose); return source; })`, alongside the existing
health/vitals overrides. The session controller reads the provider unchanged
(`ref.read(workoutSensorSourceProvider)`), and because the resolved mock's
`connect()` is an always-succeeds no-op, the controller can still call `connect()`
again with no special-casing. 4 tests
(`test/sensors/sensor_source_resolver_test.dart`): keep-on-available (mock never
built), dispose+fallback-on-unavailable, fallback-when-probe-throws, and the
defaults path (no native handler → real `MissingPluginException` → real
`MockSensorSource`). `flutter analyze` clean, `flutter test` 217/217 green
(native can't be compiled headless; the Dart gate is what's verified).

MetaGlassesSensorSource design notes (task 3, done): the real glasses-backed
`WorkoutSensorSource` lives in `app/lib/sensors/meta_glasses_sensor_source.dart`
— a thin Dart binding over the platform channels the Kotlin/Swift sides expose,
owning no rep/form logic of its own. Channel-name constants
(`kGlassesMethodChannel` = `gymbuddy/glasses`, `kGlassesRepsChannel`,
`kGlassesFormCuesChannel`) are exported so the fallback layer + tests share them.
The constructor takes optional `MethodChannel`/`EventChannel`s (defaulting to the
named ones) for injection. `connect()` calls `invokeMapMethod('connect')`, stores
`capabilities` from `{repCounting, formTracking}`, and returns `available` only
when `availability == 'available'` — any `PlatformException`/
`MissingPluginException` (no SDK, unregistered channel) degrades to `unavailable`
with empty capabilities (the same graceful posture as the health layer), so the
source surfaces `unavailable` faithfully. `capabilities` is conservatively empty
until `connect()` runs. `startTracking` forwards `{name, formTracked}`;
`stopTracking`/`dispose` invoke their methods (`dispose` is idempotent and
swallows native failures). `reps`/`formCues` are lazily-cached broadcast streams
that `map` each `EventChannel.receiveBroadcastStream()` onto `RepEvent`
(`timestamp` from `timestampMs` via `fromMillisecondsSinceEpoch`) /`FormCue`
(`severity` name → `FormSeverity`, unknown → `minor` so a cue is never dropped).
Use-after-`dispose` throws `StateError` (parity with the mock). 14 tests
(`test/sensors/meta_glasses_sensor_source_test.dart`) drive both channel kinds via
`TestDefaultBinaryMessenger` (`setMockMethodCallHandler` + `setMockStreamHandler`/
`MockStreamHandler.inline`) — no hardware: connect available/unavailable/partial-
caps/throws→unavailable/empty-before-connect, lifecycle forwarding + idempotent
dispose + use-after-dispose throws, rep decode + broadcast, form severity decode +
unknown→minor + broadcast. `flutter analyze` clean, `flutter test` 213/213 green.
The native channels still can't be compiled headless — the Dart gate is verified.

iOS glasses-channel design notes (this task, done): the iOS side of the glasses
platform channel lives in `app/ios/Runner/Glasses/`, mirroring the Android wire
contract exactly. `DatSdkClient.swift` is the seam over Meta's DAT SDK — a
protocol (`connect`/`capabilities`/`startTracking`/`stopTracking`/`dispose` + a
`TrackingListener` for rep/form callbacks) with a `DatSdkClientFactory.create()`
that detects the SDK **reflectively** (`NSClassFromString("MetaWearablesDAT.
DeviceAccessToolkit")`, nil ⇒ absent) and returns `UnavailableDatSdkClient`
(connects to nothing, no capabilities, emits no events) whenever it's missing —
which is every build until the SDK framework is vendored — so the Dart layer
reads `unavailable` and falls back to `MockSensorSource`. `DatSdkAvailableClient`
is the real path, instantiated only when the SDK is present; until its
camera/audio/mic streams are confirmed live it conservatively reports
`unavailable` (integration TODOs inline; M8 feeds the pose pipeline through
`startTracking`). `GlassesChannel.swift` bridges the control `FlutterMethodChannel`
**`gymbuddy/glasses`** (`connect` → `{availability, capabilities:{repCounting,
formTracking}}`, `startTracking {name, formTracked}`, `stopTracking`, `dispose`)
and the two `FlutterEventChannel`s **`gymbuddy/glasses/reps`** (`{index,
timestampMs, confidence?}`) and **`gymbuddy/glasses/formCues`** (`{severity,
message}`) to the client, dispatching every sink emission onto the main queue
(Flutter sinks require the platform thread) via a small `QueuingStreamHandler`
that holds the active sink between `onListen`/`onCancel` (the Swift mirror of the
Android nullable `EventSink?`); `dispose()` clears the handlers + the client.
Wired in `AppDelegate.didInitializeImplicitFlutterEngine` (a per-plugin registrar
supplies the binary messenger), torn down in `applicationWillTerminate`. Both new
Swift files were registered in `Runner.xcodeproj/project.pbxproj` (file refs +
build files + a `Glasses` group + Sources phase entries) since the project isn't
file-system-synchronized. `Info.plist` gained `NSBluetoothAlwaysUsageDescription`
/ `NSCameraUsageDescription` / `NSMicrophoneUsageDescription` (the iOS analogues
of the Android `BLUETOOTH_CONNECT`/`CAMERA`/`RECORD_AUDIO` manifest perms — the
DAT SDK pairs over BLE and streams the glasses' POV camera+mic). Native Swift
can't be compiled headless (no Xcode), so the verifiable gate is the Dart side:
`flutter analyze` clean, `flutter test` 199/199 green (no Dart changed — confirms
no regression).

Android glasses-channel design notes (this task, done): the Android side of the
glasses platform channel lives in
`app/android/app/src/main/kotlin/com/gymbuddy/gymbuddy/glasses/`. The wire
contract (mirror it on iOS + in the Dart `MetaGlassesSensorSource`): a control
`MethodChannel` **`gymbuddy/glasses`** — `connect` →
`{availability: "available"|"unavailable", capabilities: {repCounting, formTracking}}`,
`startTracking` (args `{name, formTracked}`) → null, `stopTracking` → null,
`dispose` → null — plus two streaming `EventChannel`s: **`gymbuddy/glasses/reps`**
(`{index, timestampMs, confidence?}`) and **`gymbuddy/glasses/formCues`**
(`{severity, message}` over the Dart `FormSeverity` names good/minor/major).
`DatSdkClient.kt` is the seam over Meta's DAT SDK (camera/audio/mic): an interface
(`connect`/`capabilities`/`startTracking`/`stopTracking`/`dispose` + a
`TrackingListener` for rep/form callbacks) with `DatSdkClient.create(context)` —
the DAT SDK is Meta-proprietary and **not** a compile-time dependency, so the
factory detects it **reflectively** (`Class.forName("com.meta.wearables.dat.DeviceAccessToolkit")`,
swallowing every load failure as "absent") and returns `UnavailableDatSdkClient`
(connects to nothing, no capabilities, emits no events) whenever it's missing —
which is every build until the SDK is vendored — so the Dart layer reads
`unavailable` and falls back to `MockSensorSource`. `DatSdkAvailable` is the real
path, instantiated only when the SDK is present; until its camera/audio/mic
streams are confirmed live it conservatively reports `unavailable` rather than
claiming a connection it can't back (integration TODOs marked inline; M8 feeds the
pose pipeline through `startTracking`). `GlassesChannel.kt` bridges the channels
to the client and posts every event-sink emission onto the main looper (Flutter
sinks require the platform thread); `dispose()` clears handlers + the client.
Wired in `MainActivity.configureFlutterEngine` (constructed there, torn down in
`cleanUpFlutterEngine`). Manifest gained `BLUETOOTH_CONNECT` / `CAMERA` /
`RECORD_AUDIO` (the DAT SDK pairs over BLE and streams the glasses' POV
camera+mic) and a non-required `camera.any` feature. `flutter analyze` clean,
`flutter test` 199/199 green (no Dart changed — confirms no regression; the Kotlin
isn't compilable headless).

WorkoutLog-sync design notes (this task, done): the post-workout summary now
persists to the backend on completion. **Server:** new `POST /workout-logs`
(`requireAuth` → `validateWorkoutLog` → `createLog`), mounted at `/workout-logs`
in `app.js`, wired `routes/workout-log.routes.js` →
`controllers/workout-log.controller.js` → `services/workout-log.service.js`
(`createLog(userId, payload)` stamps `user: userId` so the owner is never
trusted from the body) over the existing M1 `WorkoutLog` model
(`{user, plan?, workout?, startedAt(req), completedAt?, durationSeconds?,
exercises:[{name, sets:[{reps?, weightKg?, completed}]}], notes?}`).
`validators/workout-log.validators.js` mirrors the profile-validator spirit:
`startedAt` required (ISO/epoch → Date), everything else optional, per-field
bounds + sanity caps, and it replaces `req.body` with only the declared fields
(strips a smuggled `user`). Returns `201 { log }`. 8 tests
(`tests/workout-logs.test.js`): auth required, full persist + owned-to-caller,
ignores a body `user`, minimal (startedAt-only), and four validation rejects.
**Client:** `features/workout/workout_log_api.dart` — `WorkoutLogApi.saveLog({
startedAt, completedAt, sets })` over `apiClientProvider` (mirrors
`plan_api.dart`), groups the flat `List<CompletedSet>` into per-exercise blocks
by consecutive name (preserving order), omits `weightKg` when `weight` is null
(bodyweight), and derives `durationSeconds` from the timestamps (clamped ≥ 0);
`workoutLogApiProvider`. The session controller
(`workout_session_controller.dart`) captures `_startedAt` at `start()`, clears
it at `stop()`, and fires a best-effort `_syncLog()` (`unawaited`, errors
swallowed so a failed sync never blocks the return to idle) at **both**
completion transitions (the last-set branch of `completeSet()` and the
defensive completion branch of `_advance()` — mutually exclusive, so exactly one
POST per finished workout); `_syncLog` no-ops when there's nothing recorded.
7 new tests: 3 API wire (`workout_log_api_test.dart` — grouping + weight-omit +
duration via `MockClient`, negative-duration clamp, non-2xx → `ApiException`) and
4 controller (`workout_session_controller_test.dart` — syncs sets in order on
completion + timestamp window, manual weight carried into the sync, no sync when
stopped early, a throwing sync doesn't block completion). The existing
`makeSession` helper now also overrides `workoutLogApiProvider` with a recording
fake so completing-workout tests fire no real network call. `flutter analyze`
clean, `flutter test` 199/199 green; `npm run lint` clean, `npm test` 107/107.

Manual logging design notes (prior task, done): the no-glasses logging path.
`CompletedSet` gained a nullable `double? weight` (null = unlogged/bodyweight,
part of value identity) and `WorkoutSessionState` a transient `double? weight`
for the *current* set (reset to null at the start of every set via a `copyWith`
`clearWeight` flag, mirroring `clearFormCue`). The controller
(`workout_session_controller.dart`) added two synchronous, exercising-only
affordances: `setReps(int)` — overrides the counted reps (clamped ≥ 0; unlike a
sensor rep it never trips auto-advance, so a lifter can correct a miscount or log
reps by hand) — and `setWeight(double?)` (null/negative clears). `completeSet()`
now snapshots both `state.reps` *and* `state.weight` into the `CompletedSet`.
Surfaced in `_ExercisingView`: a `_RepStepper` flanks the `RepCounter` with
`rep-decrement`/`rep-increment` `IconButton`s (decrement disabled at 0) that
dispatch `setReps(reps ± 1)`, and a `_WeightInput` (`Key('weight-input')`,
stateful only for its `TextEditingController`, keyed by exercise+set so a new set
clears it) forwards parsed input via `setWeight`. `_CompletedSetTile` shows
"{weight} kg × {reps} reps" when a weight was logged. The mapper needs no change
— `PlanExercise` carries no weight, so the session default is simply null. 11 new
tests (6 controller: setReps override/clamp/no-op, setWeight record/clear/no-op,
completeSet snapshot, per-set reset; 1 model: `CompletedSet` weight equality; 4
widget: rep stepper forwards ±, decrement disabled at 0, weight input forwards
double/null, completed tile shows the load). `flutter analyze` clean, `flutter
test` 192/192 green.

Focus-mode UI design notes (this task, done): `features/workout/workout_screen.dart`
is now a `ConsumerWidget` over `workoutSessionControllerProvider` — pure
presentation that renders `WorkoutSessionState` and forwards the controller's
manual actions (`completeSet`/`skipRest`/`stop`), no logic in the widget. A
`switch (session.status)` picks the body: `idle` → `_StartView`, `exercising` →
`_ExercisingView`, `resting` → `_RestingView`, `completed` → `_CompletedView`
(the app-bar title shows the plan name once a session is live). `_StartView`
(itself a `ConsumerWidget`, so the active-plan read only fires at rest) watches
`activePlanControllerProvider` and renders its `AsyncValue`: spinner
(`Key('workout-loading')`), retryable error (`Key('workout-error')` →
`ref.invalidate`), then either `_StartReady` (plan name + first non-empty
training day + a `workout-start-button` that maps the day via
`PlanWorkout.toSessionPlan()` and calls `start()`) or `_NoPlan`
(`Key('workout-empty')`, points at the Plans tab). `_ExercisingView` shows the
`_SessionProgress` line ("Exercise n of m"), the exercise name + "Set x of y",
the design-system `RepCounter` (reps vs `targetReps`), a severity-colored
`_FormCueBanner` (`Key('form-cue')`, good→accent / minor→warning / major→error,
`SizedBox.shrink` when null so the layout doesn't jump), a `complete-set-button`,
and a muted `stop-workout-button`. `_RestingView` draws the `RestTimer`
(`remaining` off `restRemaining`, `total` off the current exercise's
`restSeconds`) with a `skip-rest-button`. `_CompletedView` lists the
`completedSets` ("{n} sets · {reps} reps" header + a tile per set) with a
`workout-done-button` that calls `stop()` → idle (the WorkoutLog sync is the next
task). The Workout tab builds eagerly in the shell's `IndexedStack`, so the
shell test already stubs `planApiProvider`. 7 widget tests
(`test/features/workout/workout_screen_test.dart`): the idle→start path drives
the real controller over a manual `MockSensorSource` (`autoSimulate: false`) to
confirm the tab wires to the active plan and transitions to exercising; the four
presentation views are driven by a `_SeededController` (a `WorkoutSessionController`
subclass returning a fixed state with no-op, call-counting actions — no sensors
or timers) to assert rendering + action-forwarding (complete-set/skip/done), plus
the empty and error idle states. `flutter analyze` clean, `flutter test` 183/183
green. (`MockSensorSource`'s `autoSimulate: true` app default makes reps tick on
their own in dev builds, so focus mode animates with no glasses.)

Session state-machine design notes (this task, done): the engine lives in
`features/workout/`, fully decoupled from the plans feature. `session_models.dart`
holds the feature-agnostic value types — `SessionExercise`
(`{TrackedExercise exercise, int sets, int? targetReps, int restSeconds}`; a null
`targetReps` = a "to failure"/time-based set that never auto-advances),
`SessionPlan` (`{name, List<SessionExercise>}`, with a const `empty`),
`CompletedSet` (`{exerciseName, setNumber, reps}`, accumulated as the session
advances to feed the later WorkoutLog sync), `SessionStatus`
(`idle`/`exercising`/`resting`/`completed`), and the immutable
`WorkoutSessionState` (status, plan, `exerciseIndex` 0-based, `setNumber`
1-based, `reps`, `restRemaining`, `completedSets`, nullable `formCue`) with
derived getters (`currentExercise`, `targetReps`, `exerciseNumber`,
`isExercising`/`isResting`/…) and a `copyWith` whose `clearFormCue` flag nulls
the cue (plain `copyWith` can't pass null). `session_mapper.dart` is the **single
seam** to the plans models: `PlanWorkout.toSessionPlan()` reduces each
`PlanExercise` to a `TrackedExercise` (+ prescription, null-safe defaults: 1 set,
60s rest) — the controller itself never imports the plans feature.
`workout_session_controller.dart` — `WorkoutSessionController extends
Notifier<WorkoutSessionState>` (provider `workoutSessionControllerProvider`,
non-autoDispose): `start(plan)` connects `workoutSensorSourceProvider`,
subscribes to its `reps`/`formCues` broadcast streams, and tracks the first
exercise (no-op on an empty plan or an already-active session); a rep at/over
`targetReps` auto-completes the set; `completeSet()` records the set and either
enters a rest countdown (`Timer.periodic(1s)` decrementing `restRemaining`, which
auto-advances at zero — or immediately when rest ≤ 0) or finishes the workout if
it was the last set; `skipRest()` jumps past the countdown; `_advance()` moves to
the next set or exercise (resetting reps + resuming tracking) or completes;
`stop()` tears down and returns to idle. Guards: reps/cues are ignored unless
exercising, and `completeSet()` flips status synchronously before the async
`stopTracking()` so a straggler rep can't double-complete. `completeSet()` is
also the manual seam the manual-logging fallback (a later task) builds on. Runs
end to end against `MockSensorSource` with no glasses. 20 tests
(`test/features/workout/`): 6 model/mapper (`session_models_test.dart` — value
equality, derived getters, `copyWith` cue-clearing, the `toSessionPlan` edge with
default fallbacks) and 14 controller (`workout_session_controller_test.dart` —
start/empty-plan/no-restart, rep counting, auto-advance on target, null-target
manual completion, rest-phase reps ignored, skipRest, next-exercise advance,
final-set completion, zero-rest immediate advance, form-cue surface+clear on
advance, stop→idle, and a `fakeAsync` rest-countdown tick test mirroring the mock
sensor's timer pattern). `flutter analyze` clean, `flutter test` 176/176 green.

Sensor-layer design notes (this task, done): the hardware abstraction lives in
`app/lib/sensors/`. `sensor_source.dart` defines `WorkoutSensorSource` (an
`abstract interface class`) plus its value types — `SensorCapabilities`
(`repCounting`/`formTracking`, read before surfacing capability-gated UI),
`SensorAvailability` (`available`/`unavailable`, what M7's capability detection
falls back on), `TrackedExercise` (a minimal, feature-agnostic `{name,
formTracked}` descriptor so the `sensors/` layer never depends on the plans
models), `RepEvent` (`{index (1-based, resets per set), timestamp, confidence?}`)
and `FormCue` (`{severity, message}`, `FormSeverity` good/minor/major). The
interface exposes broadcast `Stream<RepEvent> reps` + `Stream<FormCue> formCues`
and lifecycle `connect() → startTracking(exercise) → stopTracking() → dispose()`.
`workoutSensorSourceProvider` defaults to `MockSensorSource` (mock-first rule —
M7 overrides it with the DAT-SDK-backed source that itself falls back to the mock
when glasses report `unavailable`). `mock_sensor_source.dart` —
`MockSensorSource` advertises full capabilities; while tracking with
`autoSimulate: true` (the app/dev default) it emits a rep every `repInterval` on
a `Timer.periodic` plus a periodic "good form" cue for form-tracked exercises, so
focus-mode UI animates with no hardware. Tests construct it with `autoSimulate:
false` + an injected `clock` and drive `emitRep`/`emitFormCue` directly for
determinism; `emitFormCue` no-ops for rep-only exercises (the source can't see
form), `emitRep` no-ops before tracking, and any use after `dispose()` throws.
20 tests (`test/sensors/mock_sensor_source_test.dart`): provider default, value
equality for all four types, the mock contract (capabilities, connect, rep
indexing + reset, form-cue gating, use-after-dispose), and two auto-simulation
tests. **Gotcha for the next timer-driven tests:** the auto-simulation tests run
under `fakeAsync` (added `fake_async` to dev_deps), NOT `testWidgets`/
`tester.pump` — awaiting a broadcast `StreamController.close()` inside the
widget-tester binding's fake-async zone never resolves and hangs the runner
(reproduced cleanly in this env); `fakeAsync` + `async.elapse`/`flushMicrotasks`
drives the periodic timer deterministically with no hang.

Dashboard design notes (this task, done): `features/home/home_screen.dart` now
renders the live vitals dashboard inside `VitalsPermissionGate` instead of a
placeholder. `_VitalsDashboard` (`ConsumerWidget`) watches
`vitalsControllerProvider` and renders its `AsyncValue` via `.when` — a spinner
(`Key('vitals-loading')`), a retryable error (`Key('vitals-error')` →
`ref.invalidate`, belt-and-braces since the reader never throws), or the loaded
`_DashboardBody`. The body is a scrollable `ListView` (`AlwaysScrollableScroll
Physics`) wrapped in a `RefreshIndicator` whose `onRefresh` calls
`VitalsController.refresh()` (pull-to-refresh). It draws a headline readiness
`StatRing` (`_ReadinessHero`, em-dash + prompt when readiness is null) plus a
`_VitalCard` per metric (resting HR / HRV / sleep / steps): a `StatRing` gauge
(progress mapped per metric — HR lower-is-better, the rest higher), the formatted
current value + unit, and a 7-day `Sparkline`. Each card shows a per-metric empty
state (`Key('vital-empty-<id>')`, "No data yet") when its `VitalsReading` field
is null — never a fabricated zero — and "Not enough history yet" when the series
has <2 points. To feed real sparklines the data layer gained a daily-history
read: `vitals_reader.dart` adds `VitalsSeries` (four `List<double>` daily series,
oldest→newest, value-equality via `listEquals`) and `VitalsReader.readSeries()`;
`HealthPackageVitalsReader.readSeries()` buckets the seam's samples by local day
over a 7-day window (latest-per-day for HR/HRV, summed for sleep/steps, each
`_guardList`ed so one failing metric degrades to an empty list), and
`MockVitalsReader` returns a plausible 7-day series (provider default for
tests/dev). `VitalsSnapshot` now carries `series` alongside `reading`; the
controller reads both concurrently in `_load`. New `Sparkline` design-system
widget (`core/design/widgets/sparkline.dart`, exported from the barrel): a
`CustomPainter` polyline normalized to its own min/max, flat for a constant
series, empty box for <2 points. 14 new tests: 4 reader-series
(`vitals_reader_test.dart`: day bucketing/latest+sum, per-metric failure→empty,
all-empty, mock series), 1 controller (series surfaced in the snapshot), 3
`Sparkline` (`core/design/widgets_test.dart`: multi-point, <2 points, constant),
6 dashboard (`test/features/home/home_screen_test.dart`: full render w/ 5 rings +
4 sparklines + computed readiness, per-metric empty state, all-empty dashes,
pull-to-refresh re-reads, loading spinner, error→retry recovers). `flutter
analyze` clean, `flutter test` 143/143 green. (On-device HealthKit/Health Connect
reads still can't run headless; the Dart analyze + test gate is what's verified.)

Data-read design notes (this task, done): the read layer lives behind the
`health` package in `core/health/vitals_reader.dart` (feature code never touches
HealthKit/Health Connect directly, same rule as the sensor + permission layers).
`vitals_reader.dart` exposes: `VitalsReading` (the four nullable scalars — resting
HR bpm, HRV ms, last-night sleep hours, today's steps — `null` = not recorded, so
the UI shows empty rather than a fake zero; `hasAny`/`empty`/value-equality);
`VitalsReader` (`Future<VitalsReading> read()`, contracted never to throw);
`HealthPackageVitalsReader` (real impl over a `VitalsReadClient` seam +
injectable `clock` for deterministic windowing) — it reads each metric
independently and `_guard`s each one, so one unsupported/failing type degrades to
`null` instead of blanking the snapshot; resting HR/HRV take the latest sample in
a 7-day window, sleep sums SLEEP_ASLEEP segment durations over the past day,
steps sum since local midnight. The `VitalsReadClient` seam returns normalized
`HealthSample`s (value/start/end off the package's `HealthDataPoint`/
`NumericHealthValue`) so reduction is unit-testable without the method channel;
`LiveVitalsReadClient` wraps `Health()` and configures lazily. `MockVitalsReader`
is the **provider default** (fixed plausible snapshot → populated dashboard in
tests + hardware-free dev); `main.dart` overrides `vitalsReaderProvider` to the
real reader, exactly like the permission-service override. The readiness proxy is
computed in the controller via the pure `computeReadiness(VitalsReading)`: a rough
0–100 blend of the recovery signals only (HRV higher-is-better 20→100ms, resting
HR lower-is-better 80→40bpm, sleep 0→8h), averaging just the present sub-scores,
`null` when none are available — steps are activity, not recovery, so excluded by
design. `vitals_controller.dart` adds `VitalsSnapshot` (`reading` + derived
`readiness`) and `VitalsController extends AsyncNotifier<VitalsSnapshot>`:
`build()` `ref.watch`es `vitalsPermissionControllerProvider.isGranted` and stays
`VitalsSnapshot.empty` (firing NO read) until granted — so the gate, not a
premature platform read, drives connecting; on grant it rebuilds, reads, and
computes readiness. `refresh()` re-reads (pull-to-refresh), a no-op while not
granted. 17 tests: 6 reader (`test/core/health/vitals_reader_test.dart` — all
metrics/latest-wins/sleep-sum/steps-sum, missing→null, all-empty, per-metric
failure isolated, zero-duration sleep, mock populated) and 11 controller
(`test/features/vitals/vitals_controller_test.dart` — 5 readiness: blend, top,
partial, clamp, null-when-no-recovery; 6 controller: empty-until-granted +
no-read, reads+readiness on grant, missing metrics preserved, refresh re-reads,
refresh no-op ungranted).

Permission-flow design notes (prior task, done): the vitals feature
(`app/lib/features/vitals/`) gates the dashboard on health access on top of the
real `healthPermissionServiceProvider`. `vitals_permission_controller.dart` adds
`VitalsPermissionController` (`Notifier<VitalsPermissionState>`) — state starts
`notRequested` (Home does NOT fire a platform dialog on load; the user opts in),
`request()` calls the service, records `granted`/`denied`/`unavailable`, sets a
transient `requesting` flag, no-ops on a double-tap, and defensively falls back
to `unavailable` if the service ever throws (its contract degrades, but the UI
must never stick on a spinner). `vitals_permission_gate.dart` (`VitalsPermissionGate`,
`ConsumerWidget`) reveals its `child` only when `granted`; otherwise it renders a
shared `_VitalsLocked` layout per non-granted outcome (un-asked → connect prompt,
declined → retry, no store → check-again), each with a connect/retry action.
Declining never blocks the app — vitals just stay locked, the same empty-state
posture as the sensor/network layers. `home_screen.dart` (now a plain
`HomeScreen`) wraps a granted-state placeholder in the gate; the live StatRings +
sparklines land in the next task. All permission I/O lives in the controller,
never the widgets. 13 tests (`test/features/vitals/`: 6 controller — initial
state, granted/denied/unavailable outcomes, in-flight flag, single-flight; 7 gate
— each locked layout, granted reveals the dashboard, tap-to-connect grant/deny).
Note: the gate-test helper builds its override list inline because Riverpod's
`Override` type isn't part of its public API and can't be named in a signature.

Integration design notes (prior task, done): the real service lives behind the
existing `HealthPermissionService` interface in `app/lib/core/health/`. New
`health_data_types.dart` exposes `vitalsHealthTypes()` — the platform-aware set
of `HealthDataType`s the dashboard reads (resting HR, HRV, sleep, steps); HRV
differs by platform (HealthKit `SDNN` vs Health Connect `RMSSD`), so resolve it
per `Platform.isAndroid`. Reuse this same list for the M5 data reads so the
permission request and the reads ask for exactly the same types.
`health_package_permission_service.dart` adds `HealthPackagePermissionService`
(real `HealthPermissionService`) over a thin injectable `HealthClient` seam
(`LiveHealthClient` wraps the package's `Health()`; the seam exists so the
service is unit-testable without the platform method channel, which is absent
under `flutter test`). `request()` → `configure()` → `isHealthConnectAvailable()`
(false ⇒ `unavailable`) → `requestAuthorization(READ)` (granted ⇒ `granted`,
else `denied`); any thrown platform error degrades to `unavailable` rather than
crashing — the same mock-first/graceful posture as the sensor layer. The mock
stays the **provider default** (tests + hardware-free dev); `main.dart`
(composition root) overrides `healthPermissionServiceProvider` to the real
service, exactly like the `sessionExpiredProvider` override. Native config:
Android manifest gained the four Health Connect READ permissions (resting HR,
HRV, sleep, steps) + `ACTIVITY_RECOGNITION` (steps), the `healthdata` package
query, and the `ACTION_SHOW_PERMISSIONS_RATIONALE` intent-filter; `MainActivity`
now extends `FlutterFragmentActivity` (Health Connect needs a FragmentActivity
host); `minSdk` bumped to `maxOf(26, flutter.minSdkVersion)` (Health Connect
floor). iOS got the two HealthKit `Info.plist` usage strings and a
`Runner.entitlements` (HealthKit) wired via `CODE_SIGN_ENTITLEMENTS` in all
three Runner build configs. Note: the iOS HealthKit capability + Health Connect
on-device behavior can't be compiled/verified in this headless env — the Dart
gate (`flutter analyze` + `flutter test`) is what's green here.

---

### M4 — Workout plans (shipped, merged to `dev` via PR #4)
Adoption design notes for whoever picks up M5/customization: the adopted plan is
a *deep copy* (its own owned Workouts), not a reference to the template's
`owner:null` workouts — so a library re-seed (which `deleteMany`s template
workouts) can't dangle a user's active plan. Each adopted Plan carries a new
`sourceTemplate` ref (the template it came from); the app matches the active
owned plan back to its library card via that field (the owned copy has a
different `_id`). Server: `adoptTemplate`/`getActivePlan` in
`services/plan.service.js`, `adoptPlan`/`getActivePlan` controllers, routes in
`plan.routes.js` (`/active` before `/:id/adopt`). Client: `PlanApi.adoptPlan` +
`fetchActivePlan`, new `activePlanControllerProvider`
(`features/plans/active_plan_controller.dart`, `AsyncNotifier<PlanTemplate?>` —
`build()` loads the active plan, `adopt()` swaps in the owned copy), and the now
`ConsumerWidget` `PlanDetailScreen` with an `_AdoptBar` bottom action.

The Plans UI (this task, done): `features/plans/` — `plan_models.dart`
(`PlanTemplate`/`PlanWorkout`/`PlanExercise`, defensive `fromJson` over the
`GET /plans/templates` wire shape, wire-enum humanizing label getters),
`plan_api.dart` (`PlanApi.fetchTemplates()` + `planApiProvider` over
`apiClientProvider`, mirroring `profile_api.dart`), `plans_controller.dart`
(`PlansController extends AsyncNotifier<List<PlanTemplate>>`, `build()` fetches,
`refresh()` for pull-to-refresh + error retry), `plans_screen.dart` (replaces the
`ComingSoon` placeholder — `AsyncValue.when` → spinner / retryable error / empty
state / ranked `ListView`; top plan badged "Best match" when `matchScore > 0`;
each card taps through to detail), and `plan_detail_screen.dart` (training days +
per-exercise rows with a form-tracked vs reps-only badge keyed on the model's
`formTracked`). No-logic-in-widgets respected: all I/O lives in the
controller/API.

The matching endpoint: `GET /plans/templates`, `requireAuth`, mounted at
`/plans` in `app.js`. `routes/plan.routes.js` → `controllers/plan.controller.js`
→ `services/plan.service.js`. `getMatchedTemplates(userId)` reads the caller's
Profile + all `isTemplate` Plans (populates `workouts`), scores each via
`scoreTemplate(plan, profile)`, and returns them best-match-first (ties break on
name) as `{ templates: [ { ...plan, matchScore } ] }`. Scoring weights: goal
match +100 (profile.goals is a list, any hit counts), equipment feasibility +40
if fully runnable else −15 per missing piece (`expandEquipment` treats
bodyweight/none as always-available and `full_gym` as a superset of all kit),
experience `max(0, 20 − gap*10)`, daysPerWeek `max(0, 15 − gap*5)`. No profile
(not yet onboarded) → full library, name order, score 0. The wire shape is the
populated Plan JSON plus a `matchScore` field — the UI can show ranking and the
training days directly. 7 tests (`tests/plans.test.js`): auth required, full
library w/ populated workouts, no-profile name-order, goal-match-first,
equipment penalty (bodyweight user vs full-gym plan), full-gym perfect match
(score 175), and that adopted user plans never leak in.

---

### M3 — Onboarding (shipped, merged to `dev`)
Routing is wired through the gate. `AuthGate`
(`features/auth/auth_gate.dart`) still branches signed-in/out, but the
authenticated branch renders `_OnboardingRouter`, which watches
`onboardingGateProvider` (`features/onboarding/onboarding_gate.dart`,
`OnboardingGateController extends AsyncNotifier<bool>`). The gate's `build()`
reads `ProfileApi.fetchOnboardingComplete()` (`GET /profile`, response
`{ profile: {...} | null }`) — a null profile or unset `onboardingComplete` both
mean "needs onboarding". `data(false)` → `OnboardingScreen`, `data(true)` →
`AppShell`, loading → splash, error → an `onboarding-gate-retry` screen that
`ref.invalidate`s the gate. On finishing, `OnboardingScreen` watches
`OnboardingState.completed` via `ref.listen` and calls
`onboardingGateProvider.notifier.markComplete()` (sets `AsyncData(true)`), so the
gate routes on to the shell without a second round-trip (the just-completed
`complete()` already persisted the flag). Note: Riverpod 3.x auto-retries errored
providers with backoff, so the gate's manual retry sits on top of that; the gate
widget tests disable auto-retry (`ProviderContainer(retry: (_, _) => null)`) to
keep the error path deterministic.

The rest of the onboarding flow: seven steps in
`features/onboarding/onboarding_screen.dart` (`OnboardingScreen`,
`ConsumerWidget`) driven by `onboardingControllerProvider`
(`OnboardingController`/`OnboardingState`/`OnboardingDraft` in
`onboarding_controller.dart`; wire-mirrored answer enums in
`onboarding_options.dart`). `OnboardingController.complete()` maps the draft to
the Profile wire shape and `PUT`s it via `profileApiProvider`
(`features/onboarding/profile_api.dart`), flipping `completed` only on success
(failure → `saveError`, stay on last step). The device-level `healthPermission`
(from `core/health/health_permission_service.dart`) is kept on the draft but not
persisted. Backend Profile API:
`server/src/{routes,controllers,services,validators}/profile.*`
(`GET`/`PUT /profile`, both `requireAuth`), mounted at `/profile` in `app.js`.

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

### M3 — Onboarding  `[x]`
- [x] 5–7 step flow (goals, experience, days/week, equipment, injuries, body stats)
- [x] Health-data permission request step
- [x] Answers persisted via Profile API
- [x] Routes to Home on completion

### M4 — Workout plans (general / free)  `[x]`
- [x] Template library seeded in backend
- [x] Endpoint returns templates matched to profile
- [x] Plans list + detail UI
- [x] Select / persist active plan

### M5 — Vitals dashboard  `[ ]`
- [x] `health` package integrated (HealthKit + Health Connect)
- [x] Permission handling with graceful denied state
- [x] Reads resting HR, HRV, sleep, steps, readiness proxy
- [x] Home renders StatRings + sparklines, with empty states

### M6 — Workout session engine + logging  `[x]`
- [x] `WorkoutSensorSource` interface + `MockSensorSource` defined
- [x] Session state machine (exercise → set → rest → next)
- [x] Focus-mode UI (RepCounter, RestTimer)
- [x] Manual rep/weight logging fallback
- [x] Post-workout summary syncs to WorkoutLog

### M7 — Glasses integration layer  [HARDWARE-REQUIRED]  [GATE CLEARED]  `[x]`
- [x] Android (Kotlin) platform channel wrapping DAT SDK (camera/audio/mic)
- [x] iOS (Swift) platform channel wrapping DAT SDK
- [x] `MetaGlassesSensorSource` implements `WorkoutSensorSource`
- [x] Capability detection + fallback to MockSensorSource
- [x] Audio cue playback through glasses speakers
- [x] Custom mic-based wake trigger for Q&A
- [x] App builds + runs with no hardware present

### M8 — On-device rep counting & pose  [HARDWARE-REQUIRED]  [GATE CLEARED]  `[ ]`
- [x] Pose model integrated (tflite_flutter)
- [x] Rep detection fed by active sensor source
- [x] Basic joint-angle checks
- [x] Initial mirror/POV-friendly exercise set
- [x] UI marks exercises form-tracked vs rep-tracked-only

### M9 — AI layer + premium  [GATE CLEARED]  `[x]`
- [x] Server-side Claude API plan-generation service (profile + history + vitals)
- [x] Coaching service: sampled pose → short prioritized spoken cues
- [x] RevenueCat paywall + premium state
- [x] Premium gating enforced server-side
- [x] App never holds the Claude API key

### M10 — Polish, analytics, beta  [GATE CLEARED]  `[ ]`
- [x] Empty / error / loading states across features
- [ ] Accessibility pass
- [ ] Analytics + crash reporting
- [ ] TestFlight pipeline
- [ ] Firebase App Distribution pipeline
- [ ] Meta glasses release-channel build target

---

## Changelog
<!-- Newest first. Format: YYYY-MM-DD · Mx · what shipped -->
- 2026-06-28 · M10 · Empty/error/loading states across features (M10 task 1).
  Extracted the icon + title + optional message + optional retry/CTA layout that
  plans, home, and workout each duplicated inline into one shared design-system
  widget `StateMessage` (`app/lib/core/design/widgets/state_message.dart`, exported
  from the `design.dart` barrel; presentation-only, placeable in a `Center` or a
  scrollable `RefreshIndicator` list). Adopted it in `_PlansEmpty`/`_PlansError`,
  `_DashboardError`, and `_NoPlan`/`_StartError`, preserving every state key and
  visible string so the feature widget tests are untouched. Loading spinners were
  already uniform and left as-is. 4 new `StateMessage` widget tests. `flutter
  analyze` clean, `flutter test` 329/329 green (+4).
- 2026-06-28 · M9 · App never holds the Claude API key (M9 task 5) — verified +
  guarded. Confirmed end to end: the key lives only server-side
  (`config.anthropic` ← `ANTHROPIC_API_KEY` env, behind the `claude.client`
  `getClient()` seam — the single key-holder for both AI endpoints), no Claude/
  Anthropic key reference or SDK dependency exists anywhere under `app/` (only
  descriptive prose comments), and the app reaches AI exclusively through the
  premium-gated backend endpoints (`POST /plans/generate`, `POST /coaching/cues`)
  over the one `apiClient` network seam — never holding the key. The server-only
  contract is documented in `.env.example`, `server/CLAUDE.md`, `app/CLAUDE.md`,
  and `config/env.js`. The app ships only the *public* RevenueCat SDK key
  (`--dart-define=REVENUECAT_API_KEY`, not a secret). New regression guard
  `app/test/security/no_claude_key_test.dart` scans the app's shipping sources
  (`lib/`/`android/`/`ios/`/`pubspec.yaml`, excluding build output + `test/`) and
  fails the build if `ANTHROPIC_API_KEY`, an `sk-ant-` key, or an Anthropic SDK
  dependency ever appears — it forbids key machinery, not prose (so the existing
  "the key stays server-side" comments stay legal), and has a file-count sanity
  check so an empty walk can't pass vacuously (verified it catches a planted
  token). `flutter analyze` clean, `flutter test` 325/325 green (+1). M9 complete
  — all five tasks checked; PR `Milestone M9: ai` (m9-ai → dev) to be opened next.
- 2026-06-28 · M9 · Premium gating enforced server-side (M9 task 4). New
  `server/src/middleware/premium.middleware.js` `requirePremium` — mounted after
  `requireAuth`, it loads the caller's `Subscription` (the server-side source of
  truth, M1) and rejects with `402 Premium subscription required` unless
  `isPremiumActive()` (tier + status + expiry together) holds; a missing row or a
  cancelled/expired premium subscription is gated out, and the client's
  `isPremiumProvider` is never trusted. Wired ahead of validation on both AI
  endpoints (`POST /plans/generate`, `POST /coaching/cues`) so a free caller is
  rejected before any Claude call. The existing AI-behavior tests now register a
  premium caller (these endpoints are premium); 6 new gating tests
  (`ai-plan.test.js` + `coaching.test.js`: free→402 with the Claude client never
  invoked, expired/cancelled premium→402, active premium→through). `npm run lint`
  clean, `npm test` 136/136.
- 2026-06-28 · M9 · RevenueCat paywall + premium state (M9 task 3, client side).
  New `app/lib/features/premium/`: a mock-first `PremiumService` seam
  (`premium_service.dart` — `PremiumStatus`/`PremiumPackage`/`PremiumOffering`
  value types + `MockPremiumService` default, every method contracted never to
  throw), `RevenueCatPremiumService` over `purchases_flutter` `^10.3.0` (maps the
  `'premium'` entitlement, swallows store/cancel failures, best-effort
  `configure`), `PremiumController` (`AsyncNotifier<PremiumState>` — concurrent
  status+offering read, single-flight `purchase`/`restore` that always clears the
  `purchasing` flag, `refresh`) + `isPremiumProvider` (`false` until premium is
  confirmed), `PaywallScreen` (spinner / retry / upsell with buy + restore /
  active confirmation / purchases-unavailable), and `PremiumGate` (reveals child
  when premium, else a locked CTA that opens the paywall — mirrors
  `VitalsPermissionGate`). Profile tab gained a premium status section. The
  composition root wires the real service only when the **public** RevenueCat SDK
  key is supplied via `--dart-define=REVENUECAT_API_KEY` (not a secret; the app
  still never holds the Claude key); otherwise the mock keeps dev/test working
  with no store. Client entitlement is informational — the server enforces the
  real gate (task 4). `flutter analyze` clean, `flutter test` 324/324 (22 new in
  `test/features/premium/`).
- 2026-06-28 · M9 · Server-side Claude API coaching service (M9 task 2). New
  `server/src/services/coaching.service.js` `generateCues` — takes the on-device
  pose/form snapshot from the body (`exercise`, `formCues`, `reps`/`targetReps`/
  `setNumber`), reads the caller's Profile (`experience`+`injuries`) server-side
  to personalize (optional — coaching runs without a profile), prompts
  `claude-opus-4-8` through the `claude.client` seam with a json_schema
  structured output (`max_tokens` 400), and runs the result through
  `sanitizeCues` (trim, drop blanks/non-strings, clamp length 160, preserve
  order = priority, cap at 3 — clean set → `[]`, never throws). No text / invalid
  JSON → 502; unconfigured AI → 503. New `POST /coaching/cues` (`requireAuth` →
  `validateCoachingCues`) → 200 `{ cues }` (the app plays them via
  `MetaGlassesSensorSource.playCue`); validator requires `exercise`, accepts an
  optional `formCues` array (good/minor/major severities, ≤20) + bounded
  rep/set fields, strips the rest. Key stays server-side/env only. Premium
  gating deferred to M9 task 4. `npm run lint` clean, `npm test` 130/130 (12 new
  in `tests/coaching.test.js`).
- 2026-06-28 · M9 · Server-side Claude API plan-generation service (M9 task 1).
  New `server/src/services/claude.client.js` (the single key-holding seam over
  `@anthropic-ai/sdk`; `getClient()` lazily builds from server-side env and
  503s when unset; `setClient()` injects a fake for tests) and
  `ai-plan.service.js` `generatePlan` — reads the caller's Profile + 10 recent
  WorkoutLogs server-side, takes the client-supplied `vitals` snapshot, prompts
  `claude-opus-4-8` with a json_schema structured output, sanitizes/clamps the
  result (502 if unusable), and persists it as the caller's active owned plan
  (deactivating any prior, `sourceTemplate:null`), mirroring `adoptTemplate`.
  New `POST /plans/generate` (`requireAuth` → `validateGeneratePlan`) → 201
  `{ plan }`; `error.middleware` now renders `ApiError` verbatim for all
  statuses so 502/503 reach the client. Key is server-side/env only (never the
  app). Premium gating deferred to a later M9 task. `@anthropic-ai/sdk` added.
  `npm run lint` clean, `npm test` 118/118 (11 new in `tests/ai-plan.test.js`).
- 2026-06-27 · M8 · UI marks exercises form-tracked vs rep-tracked-only vs
  untracked (M8 task 5, last M8 task). `plan_detail_screen.dart`'s `_TrackingBadge`
  now keys off the pose catalog's three-way `poseTrackingFor(exercise.name)`
  (`PoseTracking` form-tracked / reps-only / none) — the single source of truth —
  instead of the server's two-state `PlanExercise.formTracked` flag, so the badge
  can never promise form feedback the pose layer has no rules for. Adds a third
  "Not tracked" state (`exercise-not-tracked`, dimmed visibility-off icon) for
  exercises the pose pipeline doesn't recognise. 1 new widget test (catalog
  overrides the server flag across all three states: "Back Squat"→form,
  "Bicep Curl"→reps-only, "Plank"→not-tracked). `flutter analyze` clean,
  `flutter test` 302/302 green. All M8 tasks complete.
- 2026-06-27 · M8 · Initial mirror/POV-friendly exercise set (M8 task 4). New
  `app/lib/core/pose/pose_exercise_catalog.dart` is the single source of truth for
  pose-trackability: a `PoseTracking` enum (`none`/`repsOnly`/`formTracked`),
  `kPoseTrackableExercises` (union of the rep + form config keysets), and
  `poseTrackingFor(name)`. New `pose_exercise_matching.dart` — a pure
  `matchCanonicalKey` (case-insensitive substring, longest-key-wins) so descriptive
  plan names ("Back Squat", "Dumbbell Romanian Deadlift") resolve to the canonical
  movements; `resolveAngleConfig`/`resolveFormRules` now route through it too.
  `session_mapper.dart` sets `TrackedExercise.formTracked` from the catalog, not the
  server flag. 18 new tests. `flutter analyze` clean, `flutter test` 301/301.
- 2026-06-27 · M8 · Basic joint-angle form checks (M8 task 3). New
  `app/lib/core/pose/pose_form_checker.dart` — `FormRule` (a joint-angle band +
  severity/message) and `PoseFormChecker` (edge-triggered fault detector reading
  the same angles as `PoseRepCounter`; one cue per fault, re-fires after recovery,
  `reset()` per set). Angle math extracted to a shared
  `PoseFrame.angleDegrees(from, pivot, to, {minConfidence})`; the rep counter now
  reads it too. New `exercise_form_configs.dart` — `kExerciseFormConfigs`
  (squat/lunge forward-lean, deadlift/RDL back-rounding, push-up hip-sag) +
  `resolveFormRules`. `MetaGlassesSensorSource.formCues` is now a broadcast
  controller; `startTracking` wires a `PoseFormChecker` off the shared pose-frame
  subscription, gated on `formTracked`, pushing pose-derived cues through it.
  21 new tests. `flutter analyze` clean, `flutter test` 288/288 green.
- 2026-06-27 · M8 · Rep detection fed by active sensor source (M8 task 2).
  New `app/lib/core/pose/pose_rep_counter.dart` — `RepAngleConfig` (pivot/from/to
  keypoints + low/high angle thresholds + minConfidence) and `PoseRepCounter`
  (pure-Dart joint-angle state machine: top→below-low → bottom → above-high → top
  = one rep, emits `RepEvent`; `reset()` clears count + phase per set).
  New `app/lib/core/pose/exercise_angle_configs.dart` — `kExerciseAngleConfigs`
  (8 POV/mirror-visible exercises: squat, deadlift, bicep curl, push-up, lunge,
  shoulder press, romanian deadlift, overhead press) and `resolveAngleConfig(name)`
  (case-insensitive lookup, null for unknown exercises).
  `MetaGlassesSensorSource` rewritten: added `kGlassesRepsChannel` constant for
  the native DAT-SDK rep channel; `reps` is now a lazy
  `StreamController<RepEvent>.broadcast` that subscribes to the native channel on
  first listen and cancels on last unsubscribe (native events merged in case a
  future SDK version adds them); `startTracking` resolves the angle config for the
  exercise and, when pose is ready, wires a `PoseRepCounter` that pushes `RepEvent`s
  into the same broadcast controller — silently skipped when pose isn't loaded or
  the exercise has no config; `stopTracking` cancels the per-set pose subscription
  and resets the counter; `dispose` closes the controller and tears down the pose
  detector. 30 new tests: 14 `pose_rep_counter_test.dart` (`RepAngleConfig` assert
  + minConfidence default, `PoseRepCounter` zero-start / top-stays / one-rep cycle /
  no-rep-without-bottom / two-reps / reset / low-confidence / absent-keypoint;
  `resolveAngleConfig` case-insensitive / unknown→null / full-coverage / all-expected),
  4 new `meta_glasses_sensor_source_test.dart` (wires PoseRepCounter on known+ready,
  stops after stopTracking, skips for unknown exercise, skips when pose not ready).
  `flutter analyze` clean, `flutter test` 268/268 green.
- 2026-06-27 · M8 · Pose model integrated (tflite_flutter). New `app/lib/core/pose/`:
  `pose_landmarks.dart` — `KeypointId` enum (17 COCO keypoints), `Keypoint` value
  type (x/y/confidence in 0..1), `PoseFrame` (list of keypoints + timestamp,
  `operator[]` by id); `pose_detector.dart` — `PoseInput` typed camera-frame
  value type (rgb bytes + width/height/timestamp, asserted-length), `PoseDetector`
  interface (`isReady`, `Future<bool> init()`, `Stream<PoseFrame> frames`,
  `dispose`), `poseDetectorProvider` (defaults to `MockPoseDetector`),
  `MockPoseDetector` (broadcast `frames`, manual `emitFrame`, throws after
  dispose); `tflite_pose_detector.dart` — `TflitePoseDetector` (`frameSource`
  injectable stream, `modelAsset` injectable path, `loadInterpreter` injectable
  loader for tests, lazy `init` that catches all failures + returns `false`,
  `buildInputTensor` nearest-neighbour resize → `[1,192,192,3]` uint8
  `@visibleForTesting` static, `decodeOutput` MoveNet `[1,1,17,3]`→`PoseFrame`
  `@visibleForTesting` static). `assets/models/` directory + `.gitkeep` added;
  `tflite_flutter: ^0.11.0` in pubspec. `TflitePoseDetector` is never imported
  by any test (no FFI load under `flutter test`). 9 new Dart tests (provider
  default, Keypoint equality, PoseFrame operator[], MockPoseDetector init/isReady/
  broadcast/emitFrame/use-after-dispose/multi-subscriber). `flutter analyze` clean,
  `flutter test` 239/239 green.
- 2026-06-27 · M7 · App builds + runs with no hardware present, completing M7.
  Added `app/test/sensors/hardware_free_smoke_test.dart`: an end-to-end
  hardware-free smoke test that calls `resolveWorkoutSensorSource()` with real
  defaults (no factory injection), confirms the resolver falls back to
  `MockSensorSource` when the glasses channel is unregistered
  (`MissingPluginException`), then drives a full session lifecycle — `connect`,
  capability read, `startTracking`, `emitRep`/`emitFormCue`/`emitWake`, `playCue`
  (safe no-op without speakers), `stopTracking` — against the mock. Proves the
  resolved source is actually drivable end to end with no hardware, which is what
  "runs with no hardware" means. `flutter analyze` clean, `flutter test` 229/229
  green (native isn't compilable headless — the Dart gate is verified).
- 2026-06-27 · M7 · Custom mic-based wake trigger for Q&A — the second *input*
  path from the glasses, a control signal (not a tracking one). The always-on mic
  listens for a fixed wake phrase (`kWakePhrase` = "hey buddy") and pushes a
  `WakeEvent` that opens a hands-free Q&A turn (the Q&A round-trip itself is
  M9/AI). Because it's an async push independent of `startTracking`, it's a third
  `EventChannel` `gymbuddy/glasses/wake` (`{timestampMs, phrase, confidence?}`),
  not a request/response. Dart: `sensor_source.dart` gained `kWakePhrase`, a
  `WakeEvent` value type, and `Stream<WakeEvent> get wakeEvents` on
  `WorkoutSensorSource` (mirrors `reps`/`formCues`); `MockSensorSource` surfaces a
  broadcast `wakeEvents` + an `emitWake({phrase, confidence})` emitter that is
  independent of tracking (Q&A wiring runs with no hardware) and not
  auto-simulated; `MetaGlassesSensorSource` decodes the wake channel (phrase
  defaults to `kWakePhrase` if omitted) and degrades to an empty stream with no
  SDK. Native: Kotlin/Swift `DatSdkClient` gained `setWakeListener` +
  `WakeSample`/`WakeListener` (`Unavailable*` never fires, `DatSdkAvailable*`
  stores it as a TODO over the SDK wake-word engine, phrase exposed as
  `WAKE_PHRASE`/`wakePhrase`); both `GlassesChannel`s wire the new channel, arming
  the listener only while Flutter is listening, posting on the main thread, and
  clearing on dispose; wire-contract docs updated. 7 new Dart tests (+ resolver
  fake override). `flutter analyze` clean, `flutter test` 228/228 green (native
  isn't compilable headless — the Dart gate is verified).
- 2026-06-27 · M7 · Audio cue playback through the glasses speakers — the first
  *output* path back to the hardware. `playCue(String message)` was added to the
  `WorkoutSensorSource` seam (so the session/coach layer reaches the speakers
  through the one resolved source the rest of the hardware already goes through,
  not a sibling interface). Contract: best-effort, never throws on a delivery
  failure. `MockSensorSource.playCue` is a silent no-op (no speakers — the
  fallback whenever glasses are absent), so cues fired with no hardware degrade
  harmlessly; `MetaGlassesSensorSource.playCue` invokes `playCue` over
  `MethodChannel('gymbuddy/glasses')` with `{message}`, swallowing
  `PlatformException`/`MissingPluginException`. Native sides mirror the verb:
  Kotlin/Swift `DatSdkClient` gained `playCue(message)` (`Unavailable*` no-op,
  `DatSdkAvailable*` TODO over the SDK audio/TTS route) and both `GlassesChannel`s
  handle the `playCue` method (`{message}` → null, `bad_args` if missing), wire
  doc updated on both. 5 new Dart tests (meta: forwards/swallows-PlatformException/
  swallows-MissingPlugin; mock: silent-no-op; after-dispose-throws extended in
  both). `flutter analyze` clean, `flutter test` 221/221 green (native isn't
  compilable headless — the Dart gate is verified).
- 2026-06-27 · M7 · Capability detection + fallback to `MockSensorSource`. New
  `app/lib/sensors/sensor_source_resolver.dart` exposes
  `resolveWorkoutSensorSource({glassesFactory, mockFactory})`: it builds the
  glasses source, `connect()`s it once, and keeps it only when the handshake
  reports `SensorAvailability.available`; otherwise (`unavailable` — no DAT SDK /
  unregistered channel / no pair — or any unexpected throw from the probe) it
  `dispose()`s the glasses and returns a fresh `MockSensorSource`, so the workout
  always has a usable source. Factories default to `MetaGlassesSensorSource.new` /
  `MockSensorSource.new` and are injectable for hardware-free unit tests.
  `workoutSensorSourceProvider` stays a synchronous `Provider` (default still the
  mock, leaving every existing test untouched); `main()` is now `async` and, after
  `WidgetsFlutterBinding.ensureInitialized()` + `await
  resolveWorkoutSensorSource()`, overrides the provider at the composition root
  (`overrideWith` keeping `ref.onDispose(source.dispose)`), beside the existing
  health/vitals overrides. The session controller reads the provider unchanged,
  and the resolved mock's no-op `connect()` means it can re-`connect()` with no
  special-casing. 4 tests (`test/sensors/sensor_source_resolver_test.dart`):
  keep-on-available, dispose+fallback-on-unavailable, fallback-when-probe-throws,
  and the real-defaults path (no native handler → `MissingPluginException` → real
  `MockSensorSource`). `flutter analyze` clean, `flutter test` 217/217 green.
- 2026-06-27 · M7 · `MetaGlassesSensorSource` — the Dart binding that implements
  `WorkoutSensorSource` over the glasses platform channels. New
  `app/lib/sensors/meta_glasses_sensor_source.dart` talks to the control
  `MethodChannel('gymbuddy/glasses')` (connect/startTracking/stopTracking/dispose)
  and decodes the two `EventChannel`s (`gymbuddy/glasses/reps` →
  `Stream<RepEvent>`, timestamp from `timestampMs`; `gymbuddy/glasses/formCues` →
  `Stream<FormCue>` over `FormSeverity`, unknown severity → `minor` so a cue is
  never dropped) onto the existing `sensor_source.dart` value types. `connect()`
  maps `{availability, capabilities:{repCounting, formTracking}}` and degrades to
  `unavailable` with empty capabilities on any `PlatformException`/
  `MissingPluginException` (no SDK / unregistered channel) — the same graceful
  posture as the health layer — so the source surfaces `unavailable` faithfully
  for the M7 task-4 fallback. The rep/form streams are lazily-cached broadcast
  streams; `dispose` is idempotent; use-after-dispose throws (parity with the
  mock). Channel names are exported as constants for the fallback layer + tests.
  14 tests (`test/sensors/meta_glasses_sensor_source_test.dart`) drive both
  channel kinds through `TestDefaultBinaryMessenger`
  (`setMockMethodCallHandler` + `setMockStreamHandler`) with no hardware.
  `flutter analyze` clean, `flutter test` 213/213 green (native channels aren't
  compilable headless, so the Dart gate is what's verified).
- 2026-06-27 · M7 · iOS (Swift) platform channel wrapping the DAT SDK, mirroring
  the Android wire contract. New `app/ios/Runner/Glasses/`: `DatSdkClient.swift`
  is the native seam over Meta's DAT SDK — a protocol
  (`connect`/`capabilities`/`startTracking`/`stopTracking`/`dispose` + a
  `TrackingListener` for rep/form callbacks) whose `DatSdkClientFactory.create()`
  detects the SDK **reflectively** (`NSClassFromString`, it's Meta-proprietary and
  not a compile-time dep) and returns an `UnavailableDatSdkClient` (no connection,
  no capabilities, no events) whenever it's absent — every build until the SDK
  framework is vendored — so the Dart layer reads `unavailable` and falls back to
  `MockSensorSource`, keeping the app buildable/runnable with no hardware.
  `GlassesChannel.swift` exposes the identical contract to the Android side:
  control `FlutterMethodChannel` `gymbuddy/glasses` (`connect` → availability +
  capabilities, `startTracking {name, formTracked}`, `stopTracking`, `dispose`)
  plus event channels `gymbuddy/glasses/reps` (`{index, timestampMs, confidence?}`)
  and `gymbuddy/glasses/formCues` (`{severity, message}`), dispatching sink
  emissions onto the main queue via a small `QueuingStreamHandler` (the Swift
  mirror of the Android nullable `EventSink?`). Wired in
  `AppDelegate.didInitializeImplicitFlutterEngine` (a per-plugin registrar
  supplies the messenger), torn down in `applicationWillTerminate`. Both Swift
  files were registered in `Runner.xcodeproj/project.pbxproj` (the project isn't
  file-system-synchronized); `Info.plist` gained the Bluetooth/Camera/Microphone
  usage strings (the iOS analogues of the Android BLE/camera/mic perms for the
  BLE-paired POV camera/mic). Native Swift isn't compilable headless (no Xcode),
  so the verifiable gate is the Dart side: `flutter analyze` clean, `flutter test`
  199/199 green (no Dart changed — confirms no regression).
- 2026-06-27 · M7 · Android (Kotlin) platform channel wrapping the DAT SDK
  (camera/audio/mic), starting M7 on branch `m7-glasses`. New
  `app/android/app/src/main/kotlin/com/gymbuddy/gymbuddy/glasses/`:
  `DatSdkClient.kt` is the native seam over Meta's DAT SDK — an interface
  (`connect`/`capabilities`/`startTracking`/`stopTracking`/`dispose` + a
  `TrackingListener` for rep/form callbacks) whose `create(context)` factory
  detects the SDK **reflectively** (it's Meta-proprietary, not a compile-time dep)
  and returns an `UnavailableDatSdkClient` (no connection, no capabilities, no
  events) whenever it's absent — every build until the SDK is vendored — so the
  Dart layer reads `unavailable` and falls back to `MockSensorSource`, keeping the
  app buildable/runnable with no hardware. `GlassesChannel.kt` exposes the wire
  contract the iOS channel + Dart `MetaGlassesSensorSource` will mirror: control
  `MethodChannel` `gymbuddy/glasses` (`connect` → availability + capabilities,
  `startTracking {name, formTracked}`, `stopTracking`, `dispose`) plus event
  channels `gymbuddy/glasses/reps` (`{index, timestampMs, confidence?}`) and
  `gymbuddy/glasses/formCues` (`{severity, message}`), posting sink emissions onto
  the main looper. Wired in `MainActivity.configureFlutterEngine` (torn down in
  `cleanUpFlutterEngine`); manifest gained `BLUETOOTH_CONNECT`/`CAMERA`/
  `RECORD_AUDIO` + a non-required `camera.any` feature for the BLE-paired POV
  camera/mic. Native Kotlin isn't compilable in this headless env (no Android
  SDK), so the verifiable gate is the Dart side: `flutter analyze` clean, `flutter
  test` 199/199 green (no Dart changed — confirms no regression).
- 2026-06-27 · M6 · Post-workout summary syncs to WorkoutLog, completing M6. The
  finished session now persists to the backend on completion. Server: new
  `POST /workout-logs` (`requireAuth` → `validateWorkoutLog` → `createLog`),
  mounted at `/workout-logs` in `app.js`, wired routes →
  controller → `workout-log.service.js` (`createLog(userId, payload)` stamps the
  owning user server-side, never trusting a `user` in the body) over the existing
  M1 `WorkoutLog` model. The validator mirrors the profile-validator spirit:
  `startedAt` required (ISO/epoch → Date), all else optional with per-field bounds
  and sanity caps, and it replaces `req.body` with only the declared fields.
  Returns `201 { log }`. Client: `features/workout/workout_log_api.dart` —
  `WorkoutLogApi.saveLog({startedAt, completedAt, sets})` over `apiClientProvider`
  (mirrors `plan_api.dart`), grouping the flat `List<CompletedSet>` into
  per-exercise blocks by consecutive name (order preserved), omitting `weightKg`
  for bodyweight/unlogged sets, and deriving `durationSeconds` (clamped ≥ 0). The
  session controller captures `_startedAt` at `start()`, clears it at `stop()`,
  and fires a best-effort `_syncLog()` (`unawaited`, errors swallowed so a failed
  sync never blocks the return to idle) at both completion transitions — exactly
  one POST per finished workout. 15 new tests (8 server integration; 3 client API
  wire + 4 controller sync), and `makeSession` now stubs `workoutLogApiProvider`
  so completing-workout tests fire no real network call. `flutter analyze` clean,
  `flutter test` 199/199 green; `npm run lint` clean, `npm test` 107/107.
- 2026-06-27 · M6 · Manual rep/weight logging fallback — the no-glasses logging
  path so a lifter with no sensor (or a rep the mock miscounted) can still log a
  set. `CompletedSet` gained a nullable `double? weight` (null = unlogged /
  bodyweight, now part of value identity) and `WorkoutSessionState` a transient
  `double? weight` for the current set, reset to null at the start of every set
  via a new `copyWith` `clearWeight` flag (mirroring `clearFormCue`). The session
  controller added two synchronous, exercising-only affordances: `setReps(int)`
  overrides the counted reps (clamped ≥ 0; unlike a sensor rep it never trips
  auto-advance, so the lifter can correct a miscount or log reps by hand) and
  `setWeight(double?)` records the load (null/negative clears it). `completeSet()`
  now snapshots both `state.reps` and `state.weight` into the `CompletedSet`.
  Surfaced in `_ExercisingView` (no logic in the widget): a `_RepStepper` flanks
  the `RepCounter` with `rep-decrement`/`rep-increment` buttons (decrement
  disabled at 0) that dispatch `setReps(reps ± 1)`, and a `_WeightInput` (stateful
  only for its `TextEditingController`, keyed by exercise+set so a new set clears
  it) forwards parsed input via `setWeight`; `_CompletedSetTile` shows
  "{weight} kg × {reps} reps" when a weight was logged. The session mapper needs
  no change — `PlanExercise` carries no weight, so the default is null. 11 new
  tests (6 controller, 1 model, 4 widget). `flutter analyze` clean, `flutter test`
  192/192 green.
- 2026-06-27 · M6 · Focus-mode UI (RepCounter, RestTimer). The Workout tab
  (`features/workout/workout_screen.dart`) replaces its `ComingSoon` placeholder
  with a `ConsumerWidget` over `workoutSessionControllerProvider` — pure
  presentation that renders `WorkoutSessionState` and forwards the controller's
  manual actions (`completeSet`/`skipRest`/`stop`), no logic in the widget. A
  `switch (session.status)` drives the body: `idle` → `_StartView`, `exercising`
  → `_ExercisingView`, `resting` → `_RestingView`, `completed` →
  `_CompletedView`. `_StartView` (a nested `ConsumerWidget`, so the active-plan
  read only fires at rest) watches `activePlanControllerProvider` and renders the
  `AsyncValue` — spinner / retryable error / `_StartReady` (plan + first non-empty
  training day, a start button that maps the day via `PlanWorkout.toSessionPlan()`
  and calls `start()`) / `_NoPlan` empty state. `_ExercisingView` shows
  exercise/set progress, the design-system `RepCounter` (reps vs `targetReps`), a
  severity-colored form-cue banner (good→accent / minor→warning / major→error,
  hidden when null), and complete-set + stop actions. `_RestingView` draws the
  `RestTimer` (`remaining` off `restRemaining`, `total` off the exercise's
  `restSeconds`) with a skip action. `_CompletedView` lists the `completedSets`
  ("{n} sets · {reps} reps" + a tile per set) with a done action that returns to
  idle (the WorkoutLog sync is the next task). Against `MockSensorSource`
  (`autoSimulate: true`, the app default) reps tick on their own, so focus mode
  animates with no glasses. 7 widget tests
  (`test/features/workout/workout_screen_test.dart`): the idle→start path drives
  the real controller over a manual `MockSensorSource` to confirm the tab wires to
  the active plan and transitions to exercising; the four views are driven by a
  `_SeededController` (a `WorkoutSessionController` subclass returning a fixed
  state with no-op, call-counting actions — no sensors/timers) to assert
  rendering + action-forwarding, plus the empty and error idle states. `flutter
  analyze` clean, `flutter test` 183/183 green.
- 2026-06-27 · M6 · Session state machine (exercise → set → rest → next). New
  `features/workout/` engine, fully decoupled from the plans feature.
  `session_models.dart` defines the feature-agnostic value types —
  `SessionExercise` (`{TrackedExercise exercise, int sets, int? targetReps,
  int restSeconds}`; a null `targetReps` is a "to failure"/time-based set that
  never auto-advances), `SessionPlan`, `CompletedSet` (accumulated for the later
  WorkoutLog sync), `SessionStatus` (idle/exercising/resting/completed), and the
  immutable `WorkoutSessionState` (status, plan, 0-based `exerciseIndex`, 1-based
  `setNumber`, `reps`, `restRemaining`, `completedSets`, nullable `formCue`) with
  derived getters and a `copyWith` whose `clearFormCue` flag nulls the cue.
  `session_mapper.dart` is the single seam to the plans models —
  `PlanWorkout.toSessionPlan()` reduces each `PlanExercise` to a `TrackedExercise`
  (+ prescription, null-safe defaults: 1 set, 60s rest) so the controller never
  imports the plans feature. `workout_session_controller.dart` —
  `WorkoutSessionController extends Notifier<WorkoutSessionState>` (provider
  `workoutSessionControllerProvider`): `start(plan)` connects
  `workoutSensorSourceProvider`, subscribes to its broadcast `reps`/`formCues`,
  and tracks the first exercise (no-op on an empty/already-active session); a rep
  at/over `targetReps` auto-completes the set; `completeSet()` records it and
  either runs a rest countdown (`Timer.periodic(1s)` over `restRemaining`,
  auto-advancing at zero — or immediately when rest ≤ 0) or finishes the workout
  on the last set; `skipRest()` jumps the countdown; `_advance()` moves to the
  next set/exercise (resetting reps + resuming tracking) or completes; `stop()`
  returns to idle. Reps/cues are ignored unless exercising, and `completeSet()`
  flips status synchronously before the async `stopTracking()` so a straggler rep
  can't double-complete; it's also the manual seam the later manual-logging
  fallback builds on. Runs end to end against `MockSensorSource` with no glasses.
  20 new tests (`test/features/workout/`): 6 model/mapper + 14 controller
  (start/empty/no-restart, rep counting, auto-advance on target, null-target
  manual completion, rest-phase reps ignored, skipRest, next-exercise advance,
  final-set completion, zero-rest immediate advance, form-cue surface+clear, stop,
  and a `fakeAsync` rest-countdown tick test). `flutter analyze` clean,
  `flutter test` 176/176 green.
- 2026-06-27 · M6 · `WorkoutSensorSource` interface + `MockSensorSource` defined,
  starting M6 on branch `m6-session`. New `app/lib/sensors/sensor_source.dart`
  defines the hardware abstraction every rep/form feature depends on:
  `WorkoutSensorSource` (an `abstract interface class`) with broadcast
  `Stream<RepEvent> reps` + `Stream<FormCue> formCues` and a
  `connect() → startTracking(TrackedExercise) → stopTracking() → dispose()`
  lifecycle, plus its feature-agnostic value types — `SensorCapabilities`
  (`repCounting`/`formTracking`), `SensorAvailability` (`available`/`unavailable`,
  for M7 capability detection + mock fallback), `TrackedExercise`
  (`{name, formTracked}`, so the `sensors/` layer never depends on the plans
  models), `RepEvent` (`{index (1-based per set), timestamp, confidence?}`) and
  `FormCue` (`{severity, message}` over `FormSeverity` good/minor/major), all with
  value equality. `workoutSensorSourceProvider` defaults to `MockSensorSource`
  (mock-first rule; M7 overrides it with the DAT-SDK source that itself falls back
  to the mock when glasses report `unavailable`). New `mock_sensor_source.dart` —
  `MockSensorSource` advertises full capabilities and, while tracking with
  `autoSimulate: true` (app/dev default), emits a rep every `repInterval` on a
  `Timer.periodic` plus a periodic "good form" cue for form-tracked exercises, so
  the focus-mode UI animates with no hardware; tests drive it deterministically
  with `autoSimulate: false`, an injected `clock`, and direct
  `emitRep`/`emitFormCue` (which no-op for rep-only exercises, before tracking, or
  after `dispose()` — use-after-dispose throws). 20 new tests
  (`app/test/sensors/mock_sensor_source_test.dart`): provider default, value
  equality across all four types, the mock contract (capabilities, connect, rep
  indexing + per-set reset, form-cue gating, use-after-dispose), and two
  auto-simulation tests. The auto-simulation tests run under `fakeAsync` (added
  `fake_async` to dev_dependencies), not `testWidgets`/`tester.pump`: awaiting a
  broadcast `StreamController.close()` inside the widget-tester binding's
  fake-async zone never resolves and hangs the runner (reproduced in this env), so
  `fakeAsync` + `async.elapse`/`flushMicrotasks` drives the periodic timer
  deterministically instead. `flutter analyze` clean, `flutter test` 156/156 green.
- 2026-06-27 · M5 · Home renders the live vitals dashboard, completing M5.
  `features/home/home_screen.dart` replaces the granted-state placeholder with
  the real dashboard inside `VitalsPermissionGate`. `_VitalsDashboard`
  (`ConsumerWidget`) watches `vitalsControllerProvider` and renders its
  `AsyncValue` via `.when`: a spinner (`Key('vitals-loading')`), a retryable
  error (`Key('vitals-error')` → `ref.invalidate`; belt-and-braces, the reader
  never throws), or the loaded `_DashboardBody` — a scrollable `ListView`
  (`AlwaysScrollableScrollPhysics`) inside a `RefreshIndicator` whose `onRefresh`
  calls `VitalsController.refresh()` (pull-to-refresh). It draws a headline
  readiness `StatRing` (`_ReadinessHero`; em-dash + prompt when readiness is
  null) and a `_VitalCard` per metric (resting HR / HRV / sleep / steps): a
  `StatRing` gauge (progress mapped per metric — HR lower-is-better, the rest
  higher), the formatted value + unit, and a 7-day `Sparkline`. Each card shows a
  per-metric empty state (`Key('vital-empty-<id>')`, "No data yet") when its
  nullable `VitalsReading` field is unset — never a fabricated zero — and "Not
  enough history yet" when the series has <2 points. To feed real sparklines the
  data layer gained a daily-history read: `core/health/vitals_reader.dart` adds
  `VitalsSeries` (four `List<double>` daily series, oldest→newest, `listEquals`
  value-equality) and `VitalsReader.readSeries()`;
  `HealthPackageVitalsReader.readSeries()` buckets the `VitalsReadClient`
  samples by local day over a 7-day window (latest-per-day for HR/HRV, summed for
  sleep/steps), each `_guardList`ed so one failing metric degrades to an empty
  list; `MockVitalsReader` (provider default) returns a plausible 7-day series.
  `VitalsSnapshot` now carries `series` alongside `reading`, and the controller
  reads both concurrently in `_load`. New `Sparkline` design-system widget
  (`core/design/widgets/sparkline.dart`, exported from the barrel): a
  `CustomPainter` polyline normalized to its own min/max, flat for a constant
  series, empty for <2 points. 14 new tests: 4 reader-series, 1 controller
  (series surfaced), 3 `Sparkline`, 6 dashboard (full render with 5 rings + 4
  sparklines + computed readiness, per-metric empty state, all-empty dashes,
  pull-to-refresh re-reads, loading spinner, error→retry recovers). `flutter
  analyze` clean, `flutter test` 143/143 green. (On-device HealthKit/Health
  Connect reads can't run headless; the Dart analyze + test gate is verified.)
- 2026-06-27 · M5 · Vitals data-read layer + readiness proxy. New
  `core/health/vitals_reader.dart` reads the dashboard's metrics behind the
  `health` package (feature code never touches HealthKit/Health Connect directly,
  same rule as the sensor + permission layers). `VitalsReading` holds four
  nullable scalars — resting HR (bpm), HRV (ms), last-night sleep (hours),
  today's steps — where `null` means *not recorded*, so a metric the user hasn't
  logged shows an empty state rather than a fabricated zero. `VitalsReader`
  (`Future<VitalsReading> read()`, contracted never to throw) has a real
  `HealthPackageVitalsReader` over a `VitalsReadClient` seam (+ injectable
  `clock` for deterministic windowing): it reads each metric independently and
  guards each, so one unsupported/failing type degrades to `null` instead of
  blanking the snapshot — resting HR/HRV take the latest sample in a 7-day
  window, sleep sums SLEEP_ASLEEP segment durations over the past day, steps sum
  since local midnight. The seam returns normalized `HealthSample`s
  (value/start/end off the package's `HealthDataPoint`/`NumericHealthValue`) so
  the windowing/reduction is unit-testable without the platform method channel
  (absent under `flutter test`); `LiveVitalsReadClient` wraps `Health()` and
  configures lazily. `MockVitalsReader` stays the **provider default** (fixed
  plausible snapshot → populated dashboard in tests + hardware-free dev);
  `main.dart` overrides `vitalsReaderProvider` to the real reader, mirroring the
  permission-service override. `health_data_types.dart` now exposes the metric
  types individually (`restingHeartRateType`/`hrvType`/`sleepAsleepType`/
  `stepsType`, HRV still platform-resolved SDNN vs RMSSD) with `vitalsHealthTypes()`
  built from them, so the permission request and the reads reference the same
  types. `features/vitals/vitals_controller.dart` adds `VitalsSnapshot` (raw
  `reading` + derived `readiness`), the pure `computeReadiness(VitalsReading)`
  (a rough 0–100 blend of recovery signals only — HRV 20→100ms, resting HR
  80→40bpm, sleep 0→8h — averaging just the present sub-scores, `null` when none
  available; steps are activity not recovery, so excluded by design), and
  `VitalsController extends AsyncNotifier<VitalsSnapshot>`: `build()` watches
  `vitalsPermissionControllerProvider.isGranted` and stays `VitalsSnapshot.empty`
  firing NO read until granted (the gate, not a premature read, drives
  connecting); on grant it reads + computes readiness. `refresh()` re-reads for
  pull-to-refresh, a no-op while ungranted. All I/O stays in the
  reader/controller per no-logic-in-widgets. 17 new tests: 6 reader
  (`test/core/health/vitals_reader_test.dart`: latest-wins HR/HRV + sleep/steps
  sums, missing→null, all-empty, per-metric failure isolated, zero-duration
  sleep, mock populated) and 11 controller
  (`test/features/vitals/vitals_controller_test.dart`: 5 `computeReadiness` —
  blend, top-end, partial, clamp, null-when-no-recovery; 6 `VitalsController` —
  empty-until-granted with no read, reads+readiness on grant, missing metrics
  preserved, refresh re-reads, refresh no-op ungranted). `flutter analyze` clean,
  `flutter test` 129/129 green. (On-device HealthKit/Health Connect reads can't
  run in this headless env; the Dart analyze + test gate is what's verified.)
- 2026-06-27 · M5 · Permission handling with graceful denied state. New vitals
  feature (`app/lib/features/vitals/`) gates the Home dashboard on health-data
  access, built on the real `healthPermissionServiceProvider` (the mock stays the
  test/dev default). `vitals_permission_controller.dart` —
  `VitalsPermissionController extends Notifier<VitalsPermissionState>`: state
  starts `notRequested` (Home doesn't fire a platform dialog on load — the user
  opts in), `request()` calls the service and records
  `granted`/`denied`/`unavailable`, sets a transient `requesting` flag for the
  spinner, no-ops a double-tap so two prompts can't fire, and defensively falls
  back to `unavailable` if the service ever throws (its contract degrades platform
  errors, but the UI must never stick in a spinner). `vitals_permission_gate.dart`
  — `VitalsPermissionGate` (`ConsumerWidget`) reveals its `child` only when
  access is `granted`; every other outcome renders a shared `_VitalsLocked`
  layout (un-asked → "Connect health data" prompt, declined → "Try again", no
  store → "Check again"), each offering a connect/retry action. Declining never
  blocks the app — vitals just stay locked, the same empty-state posture the
  sensor/network layers take when a dependency is absent. `home_screen.dart` is
  now a plain `HomeScreen` wrapping a granted-state placeholder in the gate (the
  live StatRings + sparklines land in the next M5 task). All permission I/O lives
  in the controller per no-logic-in-widgets; the widgets only render state and
  forward the connect tap. 13 new tests (`test/features/vitals/`): 6 controller
  (initial state, granted/denied/unavailable outcomes, in-flight `requesting`
  flag, single-flight) and 7 gate (each locked layout, granted reveals the
  dashboard, tap-to-connect on grant/deny). The gate-test helper builds its
  override list inline — Riverpod 3.x's `Override` type isn't part of its public
  API, so it can't be named in a helper signature. `flutter analyze` clean,
  `flutter test` 113/113 green.
- 2026-06-26 · M5 · `health` package integrated (HealthKit + Health Connect),
  starting M5 on branch `m5-vitals`. Added `health: ^13.0.0` (resolves to
  13.3.1). The real platform integration lives behind the existing
  `HealthPermissionService` interface in `app/lib/core/health/` (feature code
  never touches HealthKit / Health Connect directly, same rule as the sensor
  layer). New `health_data_types.dart` defines `vitalsHealthTypes()` — the
  platform-aware set of `HealthDataType`s the M5 dashboard reads (resting HR,
  HRV, sleep, steps); HRV is `SDNN` on HealthKit vs `RMSSD` on Health Connect,
  resolved per `Platform.isAndroid`, so the permission request and the later
  reads ask for the same types. New `health_package_permission_service.dart`
  adds `HealthPackagePermissionService` over a thin injectable `HealthClient`
  seam (`LiveHealthClient` wraps the package's `Health()`); the seam keeps the
  service unit-testable without the platform method channel (absent under
  `flutter test`). `request()` configures the plugin, returns `unavailable`
  when no store is reachable (`isHealthConnectAvailable()` false), else requests
  READ authorization for the vitals types and maps the result to
  `granted` / `denied`; any thrown platform error degrades to `unavailable`
  rather than crashing the flow (mock-first / graceful-degradation posture). The
  `MockHealthPermissionService` stays the **provider default** so tests and
  hardware-free dev builds are untouched; `main.dart` (composition root)
  overrides `healthPermissionServiceProvider` to the real service, mirroring the
  existing `sessionExpiredProvider` override. Native config: Android manifest
  gained the four Health Connect READ permissions + `ACTIVITY_RECOGNITION`, the
  `com.google.android.apps.healthdata` package query and
  `ACTION_SHOW_PERMISSIONS_RATIONALE` intent-filter; `MainActivity` now extends
  `FlutterFragmentActivity` (required by the Health Connect permission flow);
  `minSdk` is `maxOf(26, flutter.minSdkVersion)` (Health Connect floor). iOS got
  the two HealthKit `Info.plist` usage strings and a `Runner.entitlements`
  (HealthKit) wired via `CODE_SIGN_ENTITLEMENTS` across all three Runner build
  configs. 5 new tests (`test/core/health/health_package_permission_service_test.dart`:
  granted, denied, unavailable-skips-prompt, requests the vitals types, and a
  throw at any stage degrades to unavailable). `flutter analyze` clean,
  `flutter test` 101/101 green. (iOS HealthKit capability + on-device Health
  Connect behavior can't be compiled in this headless env; the Dart analyze +
  test gate is what's verified here.)
- 2026-06-26 · M4 · Select / persist active plan — completes M4. Backend: two
  new endpoints on the `/plans` router, both behind `requireAuth` and reusing
  the shared `{ error: { message } }` shape. `POST /plans/:id/adopt`
  (`adoptTemplate` in `services/plan.service.js`) adopts a library template as
  the caller's active plan — it deep-copies the template's training-day Workouts
  into new `owner`-set Workouts (so a library re-seed, which `deleteMany`s
  `owner:null` template workouts, can't dangle a user's plan) and writes an
  owned, non-template Plan with `isActive: true` and a new `sourceTemplate` ref
  back to the template. It enforces **one active plan per user** server-side:
  any prior active owned plan is flipped `isActive:false` in the same operation
  (never trusted from the client). A non-template / unknown id 404s.
  `GET /plans/active` (`getActivePlan`) returns the caller's active plan
  (workouts populated) or `null`. New `sourceTemplate` field on the Plan model
  (ref `Plan`, default null). Client: `PlanApi` gains `adoptPlan(templateId)` +
  `fetchActivePlan()`; new `activePlanControllerProvider`
  (`features/plans/active_plan_controller.dart`,
  `ActivePlanController extends AsyncNotifier<PlanTemplate?>` — `build()` loads
  the active plan, `adopt()` moves through loading and swaps the resolved owned
  copy into state, capturing failure as `AsyncError`). `PlanTemplate` gains a
  `sourceTemplate` field so the UI can match the owned active plan (different
  `_id`) back to its library card. `PlanDetailScreen` is now a `ConsumerWidget`
  with an `_AdoptBar` bottom action: a "Use this plan" `PrimaryButton`
  (spinner while in flight, error → SnackBar) that becomes a "Your active plan"
  indicator once this plan is active (matched via `sourceTemplate == plan.id`).
  All I/O stays in the controller/API per no-logic-in-widgets. 9 new server
  tests (`tests/plans.adopt.test.js`: auth on both endpoints, null-when-none,
  owned/active/own-workouts copy, active read-back, second-adopt deactivates the
  first (exactly one active), per-user isolation, non-template/unknown 404,
  adopted plans never leak into the library) and 8 new client tests (4
  `active_plan_controller_test.dart`: build loads / null, adopt swaps state,
  failed adopt → error; 4 `plan_detail_screen_test.dart`: offers + adopts,
  already-active surfaced, a different active plan isn't marked, adopt failure
  shows the error and stays adoptable). The shell + plans-screen test fakes now
  implement the two new `PlanApi` methods. `npm run lint` clean, `npm test`
  99/99; `flutter analyze` clean, `flutter test` 96/96 green.
- 2026-06-26 · M4 · Plans list + detail UI — the Plans tab now renders the
  profile-ranked template library instead of a `ComingSoon` placeholder. New
  `features/plans/`: `plan_models.dart` decodes the `GET /plans/templates` wire
  shape (`PlanTemplate`/`PlanWorkout`/`PlanExercise`) with defensive `fromJson`
  (missing/wrong-typed fields fall back, never throw) and humanized label
  getters for the snake_case wire enums; `plan_api.dart`
  (`PlanApi.fetchTemplates()` + `planApiProvider` over `apiClientProvider`,
  mirroring `profile_api.dart`); `plans_controller.dart` (`PlansController
  extends AsyncNotifier<List<PlanTemplate>>` — `build()` fetches once, `refresh()`
  re-fetches for pull-to-refresh and the error-state retry). `plans_screen.dart`
  renders the resulting `AsyncValue` via `.when` — a spinner, a retryable error
  state, an empty state, or the ranked `ListView` (best-match-first from the
  server; the top plan is badged "Best match for you" only when `matchScore > 0`,
  i.e. the user has onboarded). Each card taps through to `plan_detail_screen.dart`,
  which lists the plan's training days and, per exercise, a sets×reps + rest line
  and a form-tracked vs reps-only badge keyed on the model's `formTracked` flag
  (the glasses are first-person POV, so form correction is per-exercise). All I/O
  stays in the controller/API per the no-logic-in-widgets rule; the widgets only
  render state and forward taps. 10 new tests: `plan_models_test.dart` (4 — full
  parse, enum humanizing, formTracked/prescription incl. the no-reps "3 sets"
  case, graceful defaults on a sparse payload) and `plans_screen_test.dart` (6 —
  loading spinner, ranked list with the top-match badge, no badge when unranked,
  tap-through to detail showing exercises + both tracking badges, empty state,
  and error→retry→recovered with auto-retry disabled). The shell test now stubs
  `planApiProvider` (the Plans tab builds eagerly in the `IndexedStack`).
  `flutter analyze` clean, `flutter test` 88/88 green.
- 2026-06-26 · M4 · `GET /plans/templates` returns the seeded template library
  ranked against the caller's onboarding Profile. New
  `routes/plan.routes.js` → `controllers/plan.controller.js` →
  `services/plan.service.js`, mounted at `/plans` in `app.js`, behind
  `requireAuth` and reusing the shared `{ error: { message } }` shape.
  `getMatchedTemplates(userId)` loads the Profile and all `isTemplate` Plans
  (populating `workouts`), scores each template, and returns them best-first
  (ties break on name) as `{ templates: [ { ...plan, matchScore } ] }`.
  `scoreTemplate` weights goal match +100 (profile.goals is a list — any hit
  counts), equipment feasibility +40 when fully runnable else −15 per missing
  piece (a helper `expandEquipment` treats `bodyweight`/`none` as always
  available and `full_gym` as a superset of every individual piece, so a
  fully-kitted user isn't docked against a barbell-only plan and bodyweight
  plans stay runnable for everyone), experience `max(0, 20 − gap*10)` over the
  level index, and daysPerWeek `max(0, 15 − gap*5)`. A user with no profile yet
  (hasn't onboarded) can't be ranked, so the full library comes back in name
  order with score 0. 7 new tests (`tests/plans.test.js`): auth required, full
  library with populated training-day workouts, no-profile name-order/zero
  score, goal-matched template first, equipment penalty (bodyweight-only user
  ranks the bodyweight plan above the full-gym split), a full-gym intermediate
  build-muscle user hitting the perfect 175 match, and confirmation that adopted
  (owned, non-template) plans never leak into the library. `npm run lint` clean,
  `npm test` 90/90 green.
- 2026-06-26 · M4 · Template library seeded in the backend, starting M4. New pure
  data module `server/src/seeds/templates.js` defines six general/free template
  plans deliberately spanning all five goals (`general_fitness`, `gain_strength`
  ×2, `build_muscle`, `lose_weight`, `improve_endurance`) and a range of
  experience levels, equipment (bodyweight → full gym), and 2–6 training days,
  each with embedded exercises whose `formTracked` flag is set true only for
  mirror/POV-visible movements (squats, lunges, hinges, curls) per the
  first-person-POV constraint. New `services/seed.service.js` (`seedTemplates()`)
  writes them via the real Plan/Workout models and is idempotent: it
  `deleteMany`s existing `isTemplate` plans and `owner:null` template workouts,
  then recreates from the data file, so a re-run lands an exact end state with no
  duplicates and never touches user-authored workouts (real `owner`) or adopted
  plans (`isTemplate:false`). Runnable via `npm run seed` (`src/seeds/run.js`,
  connects → seeds → disconnects). Template Plans are `isTemplate:true,
  owner:null`; training-day Workouts are `owner:null`, leaving the matching
  endpoint (next task) a clean library to rank against a Profile. 7 new tests
  (`tests/seed.test.js`): per-definition plan + workout counts, template/owner
  flags, enum validity against `models/constants.js`, full-goal coverage,
  plan→workout population with non-empty exercises, idempotency (re-seed → equal
  result, unique names), and user-owned data surviving a re-seed. `npm run lint`
  clean, `npm test` 83/83 green.
- 2026-06-26 · M3 · Onboarding routes to Home on completion, finishing M3. The
  `AuthGate`'s authenticated branch no longer renders the shell directly; it now
  renders `_OnboardingRouter` (`features/auth/auth_gate.dart`), which watches the
  new `onboardingGateProvider` (`features/onboarding/onboarding_gate.dart`,
  `OnboardingGateController extends AsyncNotifier<bool>`). The gate's `build()`
  reads `ProfileApi.fetchOnboardingComplete()` — a new `GET /profile` call
  (`features/onboarding/profile_api.dart`) that returns `false` for a null
  profile or an unset `onboardingComplete` flag (both mean onboarding is still
  needed). The router maps `data(true)` → `AppShell`, `data(false)` →
  `OnboardingScreen`, `loading` → the auth splash, and `error` → a retry screen
  (`onboarding-gate-retry`) that `ref.invalidate`s the gate rather than guessing.
  `OnboardingScreen` now `ref.listen`s `OnboardingState.completed` and, on the
  flip, calls `onboardingGateProvider.notifier.markComplete()` (→
  `AsyncData(true)`), so a finished flow routes straight to the shell with no
  extra round-trip — the controller stays decoupled from routing. Riverpod 3.x
  auto-retries errored providers, so the manual retry is additive; the gate tests
  pin the error path with `ProviderContainer(retry: (_, _) => null)`. 3 new
  widget tests (`auth_gate_test.dart`: authenticated-but-incomplete lands on the
  flow, finishing routes to the shell, a failed status check shows a retry that
  recovers); the existing shell + gate tests updated to serve / override the
  `/profile` check. `flutter analyze` clean, `flutter test` 78/78 green.
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
