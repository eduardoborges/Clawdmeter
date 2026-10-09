#!/bin/sh
# Claude Code hook for the attention alert and the Sessions workspace (see
# README, "Attention alerts" and "Live sessions").
#   attention-hook.sh alert   Notification, PreToolUse(AskUserQuestion)
#   attention-hook.sh clear   UserPromptSubmit, PostToolUse
#   attention-hook.sh stop    Stop
#   attention-hook.sh end     SessionEnd
# Every call also records the session's last event in sessions/<session id>.
# Hook stdout can reach the model, so print nothing and always exit 0.
exec >/dev/null 2>&1
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
D="$HOME/.config/claude-usage-monitor"
mkdir -p "$D/sessions" || exit 0
in=$(cat)
s=$(printf '%s' "$in" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
case "$1" in
  alert)
    printf '%s' "$in" | jq -c '{m: (.message // .tool_input.questions[0].question // ""),
            s: .session_id}' > "$D/attention.$$" \
      && mv "$D/attention.$$" "$D/attention" ;;
  clear)
    [ -n "$s" ] && touch "$D/clear-$s" ;;
esac
[ -n "$s" ] || exit 0
if [ "$1" = end ]; then
  rm -f "$D/sessions/$s"
else
  printf '%s' "$in" | jq -c --arg e "$1" '{p: ((.cwd // "") | split("/") | last), e: $e}' \
    > "$D/sessions/.$s.$$" && mv "$D/sessions/.$s.$$" "$D/sessions/$s"
fi
exit 0
