#!/bin/sh
# Claude Code hook for the attention alert and the Sessions workspace (see
# README, "Attention alerts" and "Live sessions").
#   attention-hook.sh alert   Notification, PreToolUse(AskUserQuestion)
#   attention-hook.sh clear   UserPromptSubmit, PostToolUse
#   attention-hook.sh tool    PreToolUse (every tool)
#   attention-hook.sh stop    Stop
#   attention-hook.sh end     SessionEnd
# Every call also records the session's last event in sessions/<session id>,
# with the last tool.
# Hook stdout can reach the model, so print nothing and always exit 0.
exec >/dev/null 2>&1
PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
D="$HOME/.config/claude-usage-monitor"
mkdir -p "$D/sessions" || exit 0
in=$(cat)
s=$(printf '%s' "$in" | jq -r '.session_id // empty' | tr -cd 'A-Za-z0-9_-')
case "$1" in
  alert)
    printf '%s' "$in" | jq -c --arg s "$s" '{m: (.message // .tool_input.questions[0].question // ""),
            s: $s}' > "$D/attention.$$" \
      && mv "$D/attention.$$" "$D/attention" ;;
  clear)
    [ -n "$s" ] && touch "$D/clear-$s" ;;
esac
[ -n "$s" ] || exit 0
# AskUserQuestion also runs the alert hook, which must win the session file.
[ "$1" = tool ] && [ "$(printf '%s' "$in" | jq -r '.tool_name // empty')" = AskUserQuestion ] && exit 0
# The idle prompt follows every finished reply: on the Sessions tile that is done.
e=$1
[ "$e" = alert ] && [ "$(printf '%s' "$in" | jq -r '.notification_type // empty')" = idle_prompt ] && e=stop
[ "$e" = tool ] && e=clear
f="$D/sessions/$s"
if [ "$1" = end ]; then
  rm -f "$f"
else
  old=$(jq -c 'objects' "$f" 2>/dev/null); [ -n "$old" ] || old='{}'
  printf '%s' "$in" | jq -c --arg e "$e" --argjson o "$old" '
      .hook_event_name as $h
      | {p: ((.cwd // "") | split("/") | last), e: $e,
         t: (if $h == "PreToolUse" then .tool_name elif $h == "UserPromptSubmit" then "" else ($o.t // "") end)}' \
    > "$D/sessions/.$s.$$" && mv "$D/sessions/.$s.$$" "$f"
fi
exit 0
