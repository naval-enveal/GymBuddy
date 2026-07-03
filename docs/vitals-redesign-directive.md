# GymBuddy — Vitals Redesign (Whoop-style recovery model)

Goal: replace the "data dump" vitals dashboard with an interpreted, recovery-first
experience modeled on Whoop's information architecture, in GymBuddy's existing design
language (dark-first, mint #00E5A0, 8pt grid, tabular numerals). Replicate the MODEL
(raw signals -> one meaningful verdict), never Whoop's exact colors/assets/screens.

R1 scope (authoritative for R1 tasks):
- Recovery score, server-side: daily 0-100 from resting HR, HRV, sleep, prior-day load,
  each scored vs the user's rolling 14-day baseline, weighted (HRV heaviest, then RHR,
  sleep, load), combined to 0-100 with band (green 66-100 "primed", yellow 34-65
  "moderate", red 0-33 "take it easy") + one-line verdict. Cold-start (<3 days) ->
  "building your baseline", no score. Unit-test the math.
- Baseline + deltas, server-side: per-metric rolling baseline + today's delta with
  direction (RHR lower=better, HRV higher=better). One GET /vitals/today response.
- Recovery hero (app): Home top = large ring (reuse StatRing scaled up), 0-100 in
  numericLarge, band color fill, verdict beneath; count-up + spring fill. Cold-start
  state, never a fake score.
- Interpreted metric cards (app): value + unit + delta pill (mint=better, muted=neutral,
  warning=worse) + sparkline with faint baseline line; tap expands plain-language note.
- Visual depth pass (app): premium layered feel using ONLY existing tokens — elevation,
  soft shadows, faint gradient behind hero, lg/xl rhythm, section headers.
- Motion + haptics (app): ring spring, number count-up, light haptic on refresh;
  respect reduced-motion.

Guardrails: existing tokens only (mint stays sole accent); no logic in widgets (scoring/
deltas server-side); scoring unit-tested; flutter analyze + flutter test and npm lint +
test green before checking any box; never fabricate a score.
