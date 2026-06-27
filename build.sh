#!/usr/bin/env bash
set -uo pipefail

REPO="${REPO:-/home/RnD/gymbuddy}"
MODEL="${MODEL:-claude-opus-4-8}"
TG_TOKEN="8812828769:AAGbJ0jWaKobMx3a81Iumo6QLeHKntEfdQc"
TG_CHAT="913615191"
HEARTBEAT_INTERVAL=300  # notify every 5 mins if a task is still running

notify() {
  curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    -d chat_id="${TG_CHAT}" \
    -d text="$1" > /dev/null
}

cd "$REPO" || { notify "❌ GymBuddy: repo not found at $REPO"; exit 1; }

git add -A && git commit -m "chore: checkpoint pre-run" --allow-empty -q
notify "🚀 GymBuddy build loop started (model: $MODEL)"

RATE_LIMIT_NOTIFIED=false   # prevents repeat rate-limit spam

while true; do
  # Read the next task name from STATUS.md for the start notification
  NEXT_TASK=$(grep -m1 "^\- \[ \]" "$REPO/docs/STATUS.md" | sed 's/- \[ \] //' || echo "unknown task")
  MILESTONE=$(grep -B5 "^\- \[ \]" "$REPO/docs/STATUS.md" | grep "^### " | tail -1 | sed 's/### //' || echo "")
  notify "⚙️ Starting: $NEXT_TASK
📍 $MILESTONE"

  # Heartbeat — ping every N seconds while claude is running
  TASK_START=$(date +%s)
  HEARTBEAT_SENT=0

  # Run claude in background, capture PID
  claude -p "$(cat docs/AUTONOMOUS_DIRECTIVE.md)" \
    --model "$MODEL" \
    --permission-mode auto \
    --output-format json > /tmp/gymbuddy_result.json 2>&1 &
  CLAUDE_PID=$!

  # Poll while claude runs — send heartbeat if taking too long
  while kill -0 $CLAUDE_PID 2>/dev/null; do
    sleep 30
    ELAPSED=$(( $(date +%s) - TASK_START ))
    MINUTES=$(( ELAPSED / 60 ))
    if (( ELAPSED > HEARTBEAT_INTERVAL && ELAPSED % HEARTBEAT_INTERVAL < 30 )); then
      notify "⏱️ Still working on: $NEXT_TASK
⌚ ${MINUTES} min elapsed..."
    fi
  done

  # Claude finished — read result
  RESULT=$(cat /tmp/gymbuddy_result.json 2>/dev/null || echo "")
  echo "$RESULT" >> docs/build.log
  RATE_LIMIT_NOTIFIED=false  # reset on each successful pass attempt

  if grep -q "BUILD_COMPLETE" <<<"$RESULT"; then
    notify "🎉 GymBuddy: BUILD COMPLETE — all milestones done!"
    echo "Build complete."; break
  fi

  if grep -q "HUMAN_GATE" <<<"$RESULT"; then
    GATE=$(grep -o "HUMAN_GATE: [^\"]*" <<<"$RESULT" | head -1)
    notify "🚧 GymBuddy: Human review needed
$GATE
👉 Merge the PR on GitHub, clear the gate in STATUS.md, then relaunch."
    echo "Stopped for human review."; break
  fi

  if grep -q "BLOCKED" <<<"$RESULT"; then
    REASON=$(grep -o "BLOCKED: [^\"]*" <<<"$RESULT" | head -1)
    notify "❌ GymBuddy: Blocked
$REASON
👉 Check docs/build.log for details."
    echo "Blocked."; break
  fi

  if grep -qiE "rate.?limit|usage limit|quota|session limit" <<<"$RESULT"; then
    if [ "$RATE_LIMIT_NOTIFIED" = false ]; then
      RESET_TIME=$(grep -o "resets [^\"]*" <<<"$RESULT" | head -1 || echo "soon")
      notify "⏳ GymBuddy: Rate limited ($RESET_TIME)
😴 Sleeping 30 mins, will auto-resume."
      RATE_LIMIT_NOTIFIED=true
    fi
    sleep 1800
    RATE_LIMIT_NOTIFIED=false
    continue
  fi

  # Task completed
  LAST_COMMIT=$(git log --oneline -1 2>/dev/null | cut -d' ' -f2-)
  ELAPSED=$(( $(date +%s) - TASK_START ))
  MINUTES=$(( ELAPSED / 60 ))
  SECONDS=$(( ELAPSED % 60 ))
  notify "✅ Task done (${MINUTES}m ${SECONDS}s)
📝 $LAST_COMMIT"

  sleep 10
done
