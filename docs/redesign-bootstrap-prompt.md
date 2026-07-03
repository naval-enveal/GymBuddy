You are doing a one-time SETUP task for the GymBuddy repo at /home/RnD/gymbuddy. This run you
are NOT building features — you are wiring the redesign work into the existing autonomous build
system so the normal build.sh loop can pick it up. Make the changes, commit them to dev, then stop.

Context: this repo is built by an autonomous loop (build.sh) that reads docs/STATUS.md one task at
a time, follows docs/AUTONOMOUS_DIRECTIVE.md, works each milestone on its own feature branch cut
from dev, and opens a PR into dev when a milestone's tasks are all checked. Milestones tagged
[HUMAN GATE] make the loop stop for human review. Do not break any of this.

Do these steps exactly:

1. On branch dev (git checkout dev && git pull), create the file
   docs/vitals-redesign-directive.md with this content:
   ---
   Goal: replace the current "data dump" vitals dashboard with an interpreted, recovery-first
   experience modeled on Whoop's information architecture, built in GymBuddy's existing design
   language (dark-first, mint accent #00E5A0, 8pt grid, tabular numerals). Replicate the MODEL
   (raw signals -> one meaningful verdict), never Whoop's exact colors, assets, or screens.

   Core idea: users don't understand raw HRV or resting HR. Synthesize the signals into a single
   Recovery score (0-100) with a plain-language verdict, and show each metric relative to the
   user's own rolling baseline, never as a bare number.

   R1 task detail (authoritative spec for the R1 milestone):
   - Recovery score model, server-side: daily 0-100 from resting HR, HRV, sleep, prior-day load,
     each scored vs the user's rolling 14-day baseline, weighted (HRV heaviest, then RHR, sleep,
     load), combined to 0-100 with a band (green 66-100 "primed", yellow 34-65 "moderate",
     red 0-33 "take it easy") and a one-line verdict. Cold-start (<3 days data) -> "building your
     baseline", no score. Unit-test the math with fixtures.
   - Baseline + deltas, server-side: per-metric rolling baseline + today's delta with direction
     (RHR lower=better, HRV higher=better). One GET /vitals/today response with everything the
     dashboard needs.
   - Recovery hero (app): HomeScreen top = large ring (reuse StatRing scaled up) with the 0-100
     score in numericLarge, band color as fill, verdict beneath; count-up number, spring fill.
     Cold-start shows the building-baseline state, never a fake score.
   - Interpreted metric cards (app): value + unit + delta-vs-baseline colored pill (mint=better,
     muted=neutral, warning=worse) + sparkline with a faint baseline reference line; tap expands a
     plain-language explanation.
   - Visual depth pass (app): premium layered feel using ONLY existing tokens — surface elevation,
     soft shadows, faint gradient behind the hero, generous lg/xl rhythm, section headers. No new
     palette, no hardcoded values.
   - Motion + haptics (app): ring spring on load, number count-up, light haptic on refresh; respect
     reduced-motion settings.
   Guardrails: existing tokens only (mint #00E5A0 stays the sole accent); no business logic in
   widgets (scoring/deltas server-side, app renders); scoring unit-tested; flutter analyze +
   flutter test and npm run lint + npm test green before checking any box; never fabricate a score.
   ---

2. Append these two milestones to the end of the milestones section in docs/STATUS.md (before the
   Changelog), preserving the file's existing formatting exactly:

   ### R1 — Vitals recovery redesign  [HUMAN GATE]  `[ ]`
   - [ ] Recovery score model server-side (0-100 + band + verdict, baseline-scored, cold-start)
   - [ ] Baseline + deltas server-side, single GET /vitals/today response
   - [ ] Recovery hero on Home (big ring, verdict line, count-up)
   - [ ] Interpreted metric cards (value + delta pill + sparkline w/ baseline)
   - [ ] Visual depth pass (elevation, gradient, rhythm — existing tokens only)
   - [ ] Motion + haptics (ring spring, count-up, refresh haptic, reduced-motion safe)

   ### R2 — Workout module fixes  [HUMAN GATE]  `[ ]`
   - [ ] PLACEHOLDER — do not start; specific breakages pending from human. If this is the active
         milestone and its only task is this placeholder, print "HUMAN_GATE: R2 (awaiting bug list)"
         and stop.

3. In docs/AUTONOMOUS_DIRECTIVE.md, add this line to the "single sources of truth" list near the top:
   - docs/vitals-redesign-directive.md — authoritative spec for R-milestones (redesign)
   And add this rule to the task instructions: "For R-milestones, follow
   docs/vitals-redesign-directive.md as the scope spec instead of docs/PLAN.md."

4. Commit these doc changes to dev with message "chore: wire in R1 vitals redesign + R2 workout
   placeholder milestones" and push dev.

5. Do NOT start building R1 yourself. After committing, print a summary of what you changed and stop.

After you stop, a human will launch the normal loop (nohup ./build.sh) which will reach R1, cut the
branch ux-vitals-recovery (or r1-vitals) from dev, build the six tasks, open a PR into dev, and stop
at the R1 human gate for review.
