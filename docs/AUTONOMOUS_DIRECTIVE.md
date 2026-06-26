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
   commit and push with a conventional-commit message.
6. If no unchecked tasks remain anywhere, print "BUILD_COMPLETE".
Then end your turn. Do not start a second task. Do not weaken tests to make them pass.
Do not edit secrets or force-push.
