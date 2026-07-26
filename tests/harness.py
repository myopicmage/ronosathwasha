"""Shared machinery for the tests that go through a real shaping engine."""

from __future__ import annotations

import re
import subprocess
from dataclasses import dataclass
from pathlib import Path

from fontTools.pens.boundsPen import BoundsPen
from fontTools.ttLib import TTFont

from ronesathwasha import ParseFailure, Script

SHAPED = re.compile(
    r"(?P<glyph>[^=|\[\]]+)=(?P<cluster>\d+)"
    r"(?:@(?P<dx>-?\d+),(?P<dy>-?\d+))?"
    r"\+(?P<advance>-?\d+)"
)


@dataclass(frozen=True)
class Placed:
    glyph: str
    cluster: int
    dx: int
    dy: int
    advance: int


@dataclass(frozen=True)
class Built:
    path: Path
    ttf: TTFont
    script: Script

    def bounds(self, glyph: str) -> tuple[float, float, float, float] | None:
        """The glyph's ink box, or None if it draws nothing (a space)."""
        pen = BoundsPen(self.ttf.getGlyphSet())
        self.ttf.getGlyphSet()[glyph].draw(pen)
        box: tuple[float, float, float, float] | None = pen.bounds
        return box

    def text(self, *words: str) -> str:
        """Romanisation to encoded text, joined by real spaces."""
        out = []
        for word in words:
            parsed = self.script.parse(word)
            assert not isinstance(parsed, ParseFailure), parsed
            out.append("".join(chr(c) for c in self.script.encode(parsed)))
        return " ".join(out)

    def _listing(self, texts: list[str], name: str) -> Path:
        listing = self.path.parent / name
        listing.write_text("\n".join(texts) + "\n", encoding="utf-8")
        return listing

    def shape(self, texts: list[str]) -> list[list[Placed]]:
        """One hb-shape run for the whole batch: 156 subprocesses is silly."""
        listing = self._listing(texts, "input.txt")
        out = subprocess.run(
            ["hb-shape", str(self.path), "--text-file", str(listing)],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.splitlines()

        assert len(out) == len(texts), f"{len(out)} results for {len(texts)} inputs"
        return [
            [
                Placed(
                    m.group("glyph"),
                    int(m.group("cluster")),
                    int(m.group("dx") or 0),
                    int(m.group("dy") or 0),
                    int(m.group("advance")),
                )
                for m in SHAPED.finditer(line)
            ]
            for line in out
        ]

    def absolute(self, run: list[Placed]) -> list[tuple[int, int, int]]:
        """HarfBuzz's advances and offsets, flattened to where things land.

        HarfBuzz describes a mark as "advance past the base, then come back";
        CoreText just says where the glyph ended up. Same geometry, different
        vocabulary, so one has to be translated into the other to compare them.
        """
        out: list[tuple[int, int, int]] = []
        pen = 0
        for placed in run:
            out.append((self.ttf.getGlyphID(placed.glyph), pen + placed.dx, placed.dy))
            pen += placed.advance
        return out

    def coretext(self, texts: list[str]) -> list[list[tuple[int, int, int]]]:
        """The same batch through Apple's shaper, already in absolute terms."""
        listing = self._listing(texts, "coretext.txt")
        script = Path(__file__).resolve().parent.parent / "tools" / "coretext_shape.swift"
        out = subprocess.run(
            ["swift", str(script), str(self.path), str(listing)],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.splitlines()

        assert len(out) == len(texts), f"{len(out)} results for {len(texts)} inputs"
        return [
            [
                (int(gid), int(x), int(y))
                for gid, x, y in (item.split(":") for item in line.split("|") if item)
            ]
            for line in out
        ]
