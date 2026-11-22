#!/bin/sh
# Make Claude Code run as configured in claude-cli-setup/files: the copy-code mod, status line,
# custom theme, keybindings and the settings.json keys that wire them. Idempotent; backs up
# anything it replaces. Keys of settings.json not in the fragment are left alone.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
files="$here/files"
stamp=$(date +%Y%m%d-%H%M%S)
cdir="$HOME/.claude"

command -v claude >/dev/null || { echo "claude not on PATH: install Claude Code first" >&2; exit 1; }
if ! command -v jq >/dev/null; then
  command -v brew >/dev/null || { echo "jq missing and no Homebrew to install it" >&2; exit 1; }
  brew install jq; echo "added   jq (status line + this installer need it)"
fi

place() {
  src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && cmp -s "$src" "$dst"; then echo "ok      $dst"; return; fi
  [ -e "$dst" ] && cp -p "$dst" "$dst.bak-$stamp" && echo "backup  $dst.bak-$stamp"
  cp "$src" "$dst"; echo "wrote   $dst"
}

(cd "$files/mods" && find copy-code -type f) | while read -r f; do
  place "$files/mods/$f" "$HOME/mods/$f"
done
place "$files/statusline-command.sh" "$cdir/statusline-command.sh"
place "$files/themes/mine.json"      "$cdir/themes/mine.json"
place "$files/keybindings.json"      "$cdir/keybindings.json"

# Deep-merge the fragment over settings.json; permissions.allow is unioned, not replaced.
settings="$cdir/settings.json"
[ -f "$settings" ] || echo '{}' > "$settings"
frag=$(sed "s|__HOME__|$HOME|g" "$files/settings.fragment.json")
merged=$(jq --argjson f "$frag" '
  (.permissions.allow // []) as $a
  | . * $f
  | .permissions.allow = ($a + $f.permissions.allow | unique)' "$settings")
if [ "$(jq -S . "$settings")" = "$(printf '%s' "$merged" | jq -S .)" ]; then
  echo "ok      $settings"
else
  cp -p "$settings" "$settings.bak-$stamp"; echo "backup  $settings.bak-$stamp"
  printf '%s\n' "$merged" > "$settings"; echo "wrote   $settings"
fi
echo "restart Claude Code for the mod and theme to load"
