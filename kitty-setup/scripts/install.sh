#!/bin/sh
# Install kitty exactly as configured in kitty-setup/files: the app, its font, the config, and
# the zsh wrapper the Claude Code key maps depend on. Idempotent; backs up anything it replaces.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
files="$here/files"
stamp=$(date +%Y%m%d-%H%M%S)

[ "$(uname)" = Darwin ] || { echo "macOS only (cmd keys, macos_* options, Homebrew casks)" >&2; exit 1; }
command -v brew >/dev/null || { echo "Homebrew missing: https://brew.sh" >&2; exit 1; }

for cask in kitty font-jetbrains-mono-nerd-font; do
  if brew list --cask "$cask" >/dev/null 2>&1; then echo "ok      $cask (installed)"
  else brew install --cask "$cask"; echo "added   $cask"; fi
done

# Copy src to dst; an existing, different dst is kept as dst.bak-<stamp>.
place() {
  src=$1 dst=$2
  mkdir -p "$(dirname "$dst")"
  if [ -e "$dst" ] && cmp -s "$src" "$dst"; then echo "ok      $dst"; return; fi
  [ -e "$dst" ] && cp -p "$dst" "$dst.bak-$stamp" && echo "backup  $dst.bak-$stamp"
  cp "$src" "$dst"; echo "wrote   $dst"
}
place "$files/kitty.conf"         "$HOME/.config/kitty/kitty.conf"
place "$files/current-theme.conf" "$HOME/.config/kitty/current-theme.conf"

zshrc="$HOME/.zshrc"
if [ -f "$zshrc" ] && grep -q 'SetUserVar=in_claude' "$zshrc"; then
  echo "ok      $zshrc (claude wrapper present)"
else
  [ -f "$zshrc" ] && cp -p "$zshrc" "$zshrc.bak-$stamp" && echo "backup  $zshrc.bak-$stamp"
  { echo; cat "$files/claude-kitty.zsh"; } >> "$zshrc"; echo "wrote   $zshrc (claude wrapper)"
fi

# Running kitty instances reload on SIGUSR1; new shells pick up the wrapper.
pkill -USR1 -x kitty 2>/dev/null && echo "reload  kitty config" || true
