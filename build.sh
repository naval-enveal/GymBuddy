#!/usr/bin/env bash
# GymBuddy autonomous build driver.
# Re-invokes Claude Code one task at a time until done or a gate is hit.
#
# MODEL: the headless loop runs on Opus 4.8 by default for unattended consistency
# (opusplan's Opus phase only triggers in interactive Plan Mode, which a headless
# loop never enters, so it would run Sonnet here). To save quota on the routine
# milestones (M1-M6), run:  MODEL=claude-sonnet-4-6 ./build.sh
set -uo pipefail

REPO="${REPO:-$HOME/gymbuddy}"
MODEL="${MODEL:-claude-opus-4-8}"
cd "$REPO" || { echo "Repo not found at $REPO"; exit 1; }

git add -A && git commit -m "chore: checkpoint pre-run" --allow-empty -q

while true; do
  RESULT=$(claude -p "$(cat docs/AUTONOMOUS_DIRECTIVE.md)" \
            --model "$MODEL" \
            --permission-mode auto \
            --output-format json 2>&1) || true
  echo "$RESULT" >> docs/build.log

  if grep -q "BUILD_COMPLETE" <<<"$RESULT"; then
    echo "Build complete."; break
  fi
  if grep -qE "HUMAN_GATE|BLOCKED" <<<"$RESULT"; then
    echo "Stopped for human review — see docs/build.log and docs/STATUS.md."
    # optional: curl -fsS -X POST "$NOTIFY_WEBHOOK" -d "GymBuddy stopped for review"
    break
  fi
  if grep -qiE "rate.?limit|usage limit|quota" <<<"$RESULT"; then
    echo "Rate limited; sleeping 30m."; sleep 1800; continue
  fi
  sleep 10
done
