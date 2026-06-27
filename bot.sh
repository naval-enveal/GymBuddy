#!/usr/bin/env bash
# GymBuddy Telegram command listener
set -uo pipefail

REPO="/home/RnD/gymbuddy"
TG_TOKEN="YOUR_TOKEN_HERE"
TG_CHAT="913615191"
OFFSET_FILE="/tmp/gymbuddy_tg_offset"
OFFSET=0

notify() {
  curl -s -X POST "https://api.telegram.org/bot${TG_TOKEN}/sendMessage" \
    -d chat_id="${TG_CHAT}" \
    -d text="$1" > /dev/null
}

[ -f "$OFFSET_FILE" ] && OFFSET=$(cat "$OFFSET_FILE")

echo "GymBuddy bot listener started"

while true; do
  UPDATES=$(curl -s "https://api.telegram.org/bot${TG_TOKEN}/getUpdates?offset=$OFFSET&timeout=30")

  # Parse each update
  MESSAGES=$(echo "$UPDATES" | python3 -c "
import sys, json
data = json.load(sys.stdin)
for u in data.get('result', []):
    uid = u['update_id']
    msg = u.get('message', {}).get('text', '')
    print(f'{uid}|{msg}')
" 2>/dev/null)

  while IFS='|' read -r UPDATE_ID CMD; do
    [ -z "$UPDATE_ID" ] && continue
    OFFSET=$((UPDATE_ID + 1))
    echo "$OFFSET" > "$OFFSET_FILE"

    case "$CMD" in
      /status)
        NEXT=$(grep -A2 "## Next up" "$REPO/docs/STATUS.md" | tail -1)
        LAST=$(git -C "$REPO" log --oneline | head -5)
        PID=$(pgrep -f build.sh || echo "not running")
        notify "📊 Status
🔄 Loop PID: $PID
📍 $NEXT
📝 Recent commits:
$LAST"
        ;;
      /pause)
        kill $(pgrep -f build.sh) 2>/dev/null && \
          notify "⏸️ Loop paused. Send /resume to restart." || \
          notify "Loop wasn't running."
        ;;
      /resume)
        cd "$REPO"
        nohup ./build.sh >> docs/build.log 2>&1 &
        notify "▶️ Loop resumed (PID: $!)"
        ;;
      /log)
        LOG=$(tail -20 "$REPO/docs/build.log" 2>/dev/null || echo "No log yet")
        notify "📋 Last 20 log lines:
$LOG"
        ;;
      /model\ opus)
        export MODEL="claude-opus-4-8"
        echo "claude-opus-4-8" > /tmp/gymbuddy_model
        notify "🔄 Model switched to Opus 4.8 (takes effect on next loop restart)"
        ;;
      /model\ sonnet)
        export MODEL="claude-sonnet-4-6"
        echo "claude-sonnet-4-6" > /tmp/gymbuddy_model
        notify "🔄 Model switched to Sonnet 4.6 (takes effect on next loop restart)"
        ;;
      /skip)
        # Mark current task as blocked and let loop move on
        sed -i '0,/\- \[ \]/{s/\- \[ \]/- [x]/}' "$REPO/docs/STATUS.md"
        git -C "$REPO" add docs/STATUS.md
        git -C "$REPO" commit -m "chore: manually skipped task via Telegram"
        notify "⏭️ Task skipped. Restart loop with /resume."
        ;;
      /help)
        notify "🤖 GymBuddy Commands:
/status — current progress
/pause — stop the loop
/resume — restart the loop
/log — last 20 log lines
/model opus — switch to Opus 4.8
/model sonnet — switch to Sonnet 4.6
/skip — skip current stuck task
/help — this message"
        ;;
      *)
        [ -n "$CMD" ] && notify "❓ Unknown command: $CMD
Send /help for available commands."
        ;;
    esac
  done <<< "$MESSAGES"

  sleep 2
done
