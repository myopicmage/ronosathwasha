"""Fail if a committed artefact has drifted from the generator that owns it.

Two files in this repo are outputs that happen to be tracked: the UFO and the
.keylayout. Both are overwritten wholesale on every build, so editing either by
hand is work that will vanish without a word, and committing either while stale
means the repo describes a font nobody can reproduce.

Neither failure announces itself. A README line saying "edit strokes.py, not the
UFO" is a rule you have to remember, which is the kind this project keeps trying
to design out. This is the same rule with teeth.

Generation is byte-stable, so the check is an exact comparison.
"""

from __future__ import annotations

from pathlib import Path

import pytest

from ronosathwasha import Script
from tools.build_keylayout import build as build_keylayout
from tools.build_ufo import build as build_ufo

ROOT = Path(__file__).resolve().parent.parent
UFO = ROOT / "sources" / "Ronosathwasha.ufo"
LAYOUT = ROOT / "layouts" / "Ronosathwasha.keylayout"


def test_the_committed_keylayout_matches_its_generator(script: Script) -> None:
    assert LAYOUT.read_text(encoding="utf-8") == build_keylayout(script), (
        "layouts/Ronosathwasha.keylayout is stale or hand-edited. "
        "Run: python3 -m tools.build_keylayout"
    )


def test_the_committed_ufo_matches_its_generator(
    script: Script, tmp_path: pytest.TempPathFactory
) -> None:
    """Compared file by file, so the failure names what actually differs."""
    fresh = Path(str(tmp_path)) / "Ronosathwasha.ufo"
    build_ufo(script, fresh)

    def contents(root: Path) -> dict[str, bytes]:
        return {
            str(p.relative_to(root)): p.read_bytes()
            for p in sorted(root.rglob("*"))
            if p.is_file()
        }

    committed, regenerated = contents(UFO), contents(fresh)

    fix = "Run: python3 -m tools.build_ufo"
    assert set(committed) == set(regenerated), (
        f"UFO has files the generator does not produce, or is missing some. {fix}"
    )

    differing = [name for name in committed if committed[name] != regenerated[name]]
    assert not differing, (
        f"stale or hand-edited in sources/Ronosathwasha.ufo: "
        f"{', '.join(sorted(differing))}. {fix}"
    )
