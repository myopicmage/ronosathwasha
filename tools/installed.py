"""Report whether the copy macOS is using matches the one just built.

A font and a keyboard layout are the only two artefacts here that get copied
somewhere else to take effect, which makes them the only two that can go stale
without anything failing. When they disagree the symptom is not an error, it is
correct-looking output with the wrong letters in it, because the layout emits
code points the font maps to whatever used to live at those numbers.

That happened: dropping the affricates renumbered every consonant after `t`,
the font was rebuilt and never reinstalled, and typing `ro` produced `sho` for
an hour before anyone worked out why.
"""

from __future__ import annotations

import hashlib
from pathlib import Path

FONTS = Path.home() / "Library" / "Fonts"
LAYOUTS = Path.home() / "Library" / "Keyboard Layouts"


def _digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def report(built: Path, installed_dir: Path, reinstall_note: str = "") -> None:
    """Print one line about the installed copy, or nothing if there isn't one."""
    installed = installed_dir / built.name
    if not installed_dir.is_dir():
        return  # not a mac, or nothing has ever been installed

    if not installed.exists():
        print(f"  not installed. cp {built} {installed_dir}/")
        return

    if _digest(installed) == _digest(built):
        print(f"  installed copy matches ({installed_dir.name})")
        return

    print(f"  STALE: {installed} differs from what was just built")
    print(f"  cp {built} '{installed_dir}/'{reinstall_note}")
