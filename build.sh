#!/usr/bin/env bash
set -uo pipefail

REPO="${REPO:-/home/RnD/gymbuddy}"
MODEL="${MODEL:-claude-opus-4-8}"
TG_TOKEN="8812828769:AAGbJ0jWaKobMx3a81Iumo6QLeHKntEfdQc"
TG_CHAT="913615191"

notify() {
  curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    -d chat_id="${TG_CHAT}" \
    -d text="$1" > /dev/null
}

cd "$REPO" || { notify "❌ GymBuddy: repo not found at $REPO"; exit 1; }

git add -A && git commit -m "chore: checkpoint pre-run" --allow-empty -q
notify "🚀 GymBuddy build loop started"

while true; do
  RESULT=$(claude -p "$(cat docs/AUTONOMOUS_DIRECTIVE.md)" \
            --model "$MODEL" \
            --permission-mode auto \
            --output-format json 2>&1) || true

  echo "$RESULT" >> docs/build.log

  if grep -q "BUILD_COMPLETE" <<<"$RESULT"; then
    notify "🎉 GymBuddy: BUILD COMPLETE — all milestones done!"
    echo "Build complete."; break
  fi

  if grep -q "HUMAN_GATE" <<<"$RESULT"; then
    GATE=$(grep -o "HUMAN_GATE: [^\"]*" <<<"$RESULT" | head -1)
    notify "🚧 GymBuddy: Human review needed — $GATE"
    echo "Stopped for human review."; break
  fi

  if grep -q "BLOCKED" <<<"$RESULT"; then
    REASON=$(grep -o "BLOCKED: [^\"]*" <<<"$RESULT" | head -1)
    notify "❌ GymBuddy: Blocked — $REASON"
    echo "Blocked."; break
  fi

  if grep -qiE "rate.?limit|usage limit|quota" <<<"$RESULT"; then
    notify "⏳ GymBuddy: Rate limited, sleeping 30 mins"
    echo "Rate limited; sleeping 30m."; sleep 1800; continue
  fi

  LAST_COMMIT=$(git log --oneline -1 2>/dev/null | cut -d' ' -f2-)
  notify "✅ GymBuddy: Task done — $LAST_COMMIT"

  sleep 10
done
