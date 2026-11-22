#!/bin/sh
input=$(cat)

# Percentages render in their own colour so they stand out from the labels.
PCT=$(printf '\033[33m')   # yellow
RST=$(printf '\033[0m')

pct() {
  printf '%s%.0f%%%s' "$PCT" "$1" "$RST"
}

# --- Agent / model / effort --------------------------------------------------
# Prefer the active named agent (--agent / agent settings); fall back to model.
agent=$(echo "$input" | jq -r '.agent.name // empty')
model=$(echo "$input" | jq -r '.model.display_name // "Claude"')
effort=$(echo "$input" | jq -r '.effort.level // empty')
if [ -n "$agent" ]; then
  who="@${agent}"
else
  who="$model"
fi
[ -n "$effort" ] && who="${who} [${effort}]"

# --- Context window ----------------------------------------------------------
# current_usage is what the last request actually put in the window;
# total_input_tokens is a session-cumulative fallback.
used=$(echo "$input" | jq -r '.context_window.used_percentage // empty')
cur=$(echo "$input" | jq -r '.context_window.current_usage | if . then (.input_tokens // 0) + (.cache_creation_input_tokens // 0) + (.cache_read_input_tokens // 0) else empty end')
[ -z "$cur" ] && cur=$(echo "$input" | jq -r '.context_window.total_input_tokens // 0')
ctx_size=$(echo "$input" | jq -r '.context_window.context_window_size // 0')

fmt_tokens() {
  # Format a token count as e.g. 15.5k / 1.0M
  n="$1"
  if [ "$n" -ge 1000000 ] 2>/dev/null; then
    echo "$n" | awk '{printf "%.1fM", $1/1000000}'
  elif [ "$n" -ge 1000 ] 2>/dev/null; then
    echo "$n" | awk '{printf "%.1fk", $1/1000}'
  else
    echo "$n"
  fi
}

ctx_part=""
if [ "$cur" -gt 0 ] 2>/dev/null; then
  tok=$(fmt_tokens "$cur")
  if [ "$ctx_size" -gt 0 ] 2>/dev/null; then
    ctx_part="ctx:${tok}/$(fmt_tokens "$ctx_size")"
    [ -z "$used" ] && used=$(awk -v c="$cur" -v s="$ctx_size" 'BEGIN{printf "%.0f", 100*c/s}')
  else
    ctx_part="ctx:${tok}"
  fi
  [ -n "$used" ] && ctx_part="${ctx_part} $(pct "$used")"

  # Share of the auto-compact budget used. The status line input carries no
  # compact threshold, so read modelSettings.<model id>.autoCompactWindow from
  # settings.json; without one, compaction is bounded by the full window.
  model_id=$(echo "$input" | jq -r '.model.id // empty')
  cw=$(jq -r --arg m "$model_id" '.modelSettings[$m].autoCompactWindow // empty' "$HOME/.claude/settings.json" 2>/dev/null)
  [ -z "$cw" ] && cw="$ctx_size"
  if [ "$cw" -gt 0 ] 2>/dev/null; then
    cpct=$(awk -v c="$cur" -v s="$cw" 'BEGIN{printf "%.0f", 100*c/s}')
    ctx_part="${ctx_part}  cmp:$(pct "$cpct")/$(fmt_tokens "$cw")"
  fi
fi

# --- Subscription rate limits (Pro/Max only; absent otherwise) ---------------
h5=$(echo "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
wk=$(echo "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
h5_reset=$(echo "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
wk_reset=$(echo "$input" | jq -r '.rate_limits.seven_day.resets_at // empty')

now=$(date +%s)

fmt_eta() {
  # Format seconds-until-reset as e.g. 45m / 2h30m / 3d4h
  reset="$1"
  [ -z "$reset" ] && return
  rem=$((reset - now))
  [ "$rem" -lt 0 ] && rem=0
  d=$((rem / 86400))
  h=$(((rem % 86400) / 3600))
  m=$(((rem % 3600) / 60))
  if [ "$d" -gt 0 ]; then
    echo "${d}d${h}h"
  elif [ "$h" -gt 0 ]; then
    echo "${h}h${m}m"
  else
    echo "${m}m"
  fi
}

h5_part=""
if [ -n "$h5" ]; then
  h5_part="5h:$(pct "$h5")"
  eta=$(fmt_eta "$h5_reset")
  [ -n "$eta" ] && h5_part="${h5_part} (${eta})"
fi

wk_part=""
if [ -n "$wk" ]; then
  wk_part="wk:$(pct "$wk")"
  eta=$(fmt_eta "$wk_reset")
  # Reset moment in local time as a two-letter day + 24h clock, e.g. "Th 14:00".
  # date -r is BSD/macOS; GNU date takes -d @<epoch>.
  when=""
  if [ -n "$wk_reset" ]; then
    when=$(LC_ALL=C date -r "$wk_reset" '+%a %H:%M' 2>/dev/null || LC_ALL=C date -d "@$wk_reset" '+%a %H:%M' 2>/dev/null)
    when=$(printf '%s' "$when" | sed 's/^\(..\)./\1/')
  fi
  [ -n "$eta" ] && wk_part="${wk_part} (${eta}${when:+, $when})"
fi

# --- Assemble ----------------------------------------------------------------
parts="$who"
[ -n "$ctx_part" ] && parts="$parts  $ctx_part"
[ -n "$h5_part" ]  && parts="$parts  $h5_part"
[ -n "$wk_part" ]  && parts="$parts  $wk_part"

# --- Remote Control marker ------------------------------------------------
# The status line input has no RC field, but each live session writes
# ~/.claude/sessions/<pid>.json with bridgeSessionId set while RC is attached.
# The fullscreen TUI hides the built-in "/rc active" pill, so draw our own.
sid=$(echo "$input" | jq -r '.session_id // empty')
rc=""
if [ -n "$sid" ]; then
  sf=$(grep -l "\"sessionId\":\"$sid\"" "$HOME"/.claude/sessions/*.json 2>/dev/null | head -1)
  if [ -n "$sf" ]; then
    rc=$(jq -r '.bridgeSessionId // empty' "$sf" 2>/dev/null)
  fi
fi
GRN=$(printf '\033[32m')   # dark (non-bright) green
tail=""
# Account: the status line input carries none, so read the logged-in OAuth
# account from ~/.claude.json (email, planDisplayName; organizationType as fallback, claude_max -> "Max").
acct=$(jq -r '.oauthAccount // empty | (.emailAddress // "") + "\t" + (.planDisplayName // (.organizationType // "" | sub("^claude_"; "") | ascii_upcase[0:1] + .[1:]))' "$HOME/.claude.json" 2>/dev/null)
uname_=$(printf '%s' "$acct" | cut -f1)
atype=$(printf '%s' "$acct" | cut -f2)
user_part="${uname_}${atype:+ (${atype})}"
[ -n "$user_part" ] && tail="${user_part}${tail:+ $tail}"
ver=$(echo "$input" | jq -r '.version // empty')
[ -n "$ver" ] && tail="${tail:+$tail }v${ver}"
[ -n "$rc" ] && tail="${tail:+$tail }${GRN}/rc${RST}"

# Right-align the tail. Claude Code passes the terminal width in $COLUMNS and
# indents the status line by 2 columns; keep a 2-column right margin too.
vislen() { printf '%s' "$1" | sed 's/\x1b\[[0-9;]*m//g' | LC_ALL=en_US.UTF-8 wc -m | tr -d ' '; }
if [ -n "$tail" ]; then
  cols=${COLUMNS:-$(tput cols 2>/dev/null)}
  pad=0
  [ "$cols" -gt 0 ] 2>/dev/null && pad=$((cols - 4 - $(vislen "$parts") - $(vislen "$tail")))
  [ "$pad" -lt 2 ] && pad=2
  parts="${parts}$(printf '%*s' "$pad" '')${tail}"
fi

printf '%s\n' "$parts"
