"""The whole pipeline: declaration -> UFO -> TTF.

    python3 -m tools.build_font

Exists so the one non-obvious flag lives in code with its reason attached
rather than in someone's shell history.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from ronosathwasha import load
from tools.build_ufo import build
from tools.installed import FONTS, report

ROOT = Path(__file__).resolve().parent.parent


def main() -> None:
    ufo = ROOT / "sources" / "Ronosathwasha.ufo"
    build(load(), ufo)

    # --keep-overlaps because the outlines arrive already unioned: every glyph
    # is a stroked centreline, and pathops simplifies the stroke before it ever
    # reaches the UFO. ufo2ft's own overlap filter would redo that work, and
    # cannot, because a round cap is a closed loop with no on-curve point and
    # its filter refuses quadratic segments in a source.
    result = subprocess.run(
        [
            "fontmake",
            "-u", str(ufo),
            "-o", "ttf",
            "--output-dir", str(ROOT / "build"),
            "--keep-overlaps",
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode:
        sys.stderr.write(result.stderr)
        raise SystemExit(result.returncode)

    ttf = ROOT / "build" / "Ronosathwasha.ttf"
    print(f"{ttf.relative_to(Path.cwd())}: {ttf.stat().st_size:,} bytes")
    report(ttf, FONTS)


if __name__ == "__main__":
    main()
