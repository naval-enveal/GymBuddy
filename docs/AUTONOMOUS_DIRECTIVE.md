You are building the GymBuddy app autonomously. Single sources of truth:
- docs/STATUS.md  — task list, protocol, and gates
- docs/PLAN.md    — architecture and per-milestone scope
- CLAUDE.md       — conventions and rules

This run, do EXACTLY ONE task:
1. Read docs/STATUS.md. Find the first unchecked task in the active milestone.
2. If that milestone is tagged [HUMAN GATE] or [HARDWARE-REQUIRED] and is NOT marked
   [GATE CLEARED], print "HUMAN_GATE: <milestone>" and stop. Change nothing.
3. Otherwise implement that one task to completion, following docs/PLAN.md and CLAUDE.md.
4. Run `flutter analyze` / `npm run lint` and the relevant tests. If they fail, fix and
   re-run, up to 3 attempts. If still failing, add an "IN PROGRESS: <what's left>" note
   to the task, print "BLOCKED: <reason>", and stop.
5. When green: check the task's box, add a dated Changelog line, update "Next up", then
   commit and push to the current feature branch.
6. Branching rules:
   - main and dev are protected. Never push directly to either.
   - All feature branches are cut from dev:
     git checkout dev && git pull && git checkout -b m<N>-<name>
   - Branch names: m0-scaffold, m1-auth, m2-flutter-shell, m3-onboarding,
     m4-plans, m5-vitals, m6-session, m7-glasses, m8-pose, m9-ai, m10-beta
   - All work stays on the feature branch. Push to origin after every commit:
     git push -u origin <branch>
   - When a milestone is fully complete (all tasks checked), open a PR from
     the feature branch into dev titled "Milestone Mx: <name>". Then stop —
     do not merge, do not cut the next branch. A human reviews and merges.
   - After the human merges, the next run will cut a fresh branch from dev
     and continue with the next milestone.
7. If no unchecked tasks remain anywhere, print "BUILD_COMPLETE".
Then end your turn. Do not start a second task. Do not weaken tests to make them pass.
Do not edit secrets or force-push. Never commit to main or dev directly.
