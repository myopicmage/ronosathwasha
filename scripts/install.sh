#!/usr/bin/env bash
#
# Build both artefacts and put them where macOS looks for them.
#
#     ./scripts/install.sh
#
# Building and installing are one step on purpose. They are separable, and
# separating them is how the font sat two encodings out of date while the
# keyboard emitted the new one, which renders as fluent nonsense rather than as
# an error.
#
# Only the keyboard layout needs a logout, and only when it actually changed,
# so this says so only when it is true.

set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"

fonts="$HOME/Library/Fonts"
layouts="$HOME/Library/Keyboard Layouts"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This installs into ~/Library, so it is macOS only." >&2
  exit 1
fi

# Re-exec inside the dev shell if the toolchain is not already on PATH, which
# it will be under direnv. The guard stops this recursing if the shell somehow
# does not provide fontmake.
if ! command -v fontmake >/dev/null 2>&1; then
  if [[ -n "${RONOSATHWASHA_RESHELLED:-}" ]]; then
    echo "fontmake missing even inside the dev shell." >&2
    exit 1
  fi
  echo "Entering the dev shell..."
  RONOSATHWASHA_RESHELLED=1 exec nix develop 'path:.' --command "$0" "$@"
fi

digest() { [[ -f "$1" ]] && shasum -a 256 "$1" | cut -c1-16 || echo "absent"; }

layout_before=$(digest "$layouts/Ronosathwasha.keylayout")

echo "Building..."
python3 -m tools.build_font
python3 -m tools.build_keylayout

mkdir -p "$fonts" "$layouts"
cp build/Ronosathwasha.ttf "$fonts/"
cp layouts/Ronosathwasha.keylayout "$layouts/"

echo
echo "Installed:"
echo "  $fonts/Ronosathwasha.ttf"
echo "  $layouts/Ronosathwasha.keylayout"

echo
if [[ "$(digest "$layouts/Ronosathwasha.keylayout")" == "$layout_before" ]]; then
  echo "The font is live now. The keyboard layout is unchanged, so no logout."
else
  echo "The font is live now."
  echo "The keyboard layout CHANGED, so log out and back in for macOS to reload it."
  echo "Then enable it under System Settings > Keyboard > Input Sources > Others."
fi
