# >>> kitty-setup: claude wrapper >>>
# Tell kitty when Claude Code is running: kitty.conf's cmd+v (image paste) and cmd+backspace
# (clear input) maps fire only while the in_claude user var is set.
claude() {
  printf '\e]1337;SetUserVar=in_claude=%s\a' "$(printf 1 | base64)"
  command claude "$@"
  local rc=$?
  printf '\e]1337;SetUserVar=in_claude\a'
  return $rc
}
# <<< kitty-setup: claude wrapper <<<
