"""The same questions, asked of Apple's shaper instead of HarfBuzz.

Everything else in the suite is verified against HarfBuzz, which is not the
engine that runs when you type on this machine. A font can satisfy one shaper
and not the other: they differ over which features are on by default, how
unknown scripts are handled, and what happens to a mark with no base. Any
disagreement here is a real portability bug, found before it turns up as
"it looks wrong in TextEdit but fine in Chrome".

Skipped where Swift or CoreText is unavailable, which is everywhere but macOS.
"""

from __future__ import annotations

import shutil
import subprocess
import sys

import pytest

from tests.harness import Built

pytestmark = [
    pytest.mark.skipif(sys.platform != "darwin", reason="CoreText is macOS only"),
    pytest.mark.skipif(shutil.which("swift") is None, reason="needs the Swift toolchain"),
]

WORDS = [
    "ronesathwasha",  # every position: right, left, below, glide, below
    "nishimi",        # up-left and centre-ish vowels
    "tumame",         # up-right
    "twatha",         # a glide over a derived consonant
    "jechiswo",       # the consonant whose IPA symbol collides with another's name
]


@pytest.fixture(scope="session")
def compared(built: Built) -> list[tuple[str, list[tuple[int, int, int]], list[tuple[int, int, int]]]]:
    """Both engines over the same batch, so Swift compiles once for the lot."""
    texts = [built.text(w) for w in WORDS]
    harfbuzz = [built.absolute(run) for run in built.shape(texts)]
    coretext = built.coretext(texts)
    return list(zip(WORDS, harfbuzz, coretext, strict=True))


def test_the_two_shapers_agree_glyph_for_glyph(
    compared: list[tuple[str, list[tuple[int, int, int]], list[tuple[int, int, int]]]],
) -> None:
    for word, harfbuzz, coretext in compared:
        assert [g for g, _, _ in coretext] == [g for g, _, _ in harfbuzz], word


def test_the_two_shapers_agree_on_every_position(
    compared: list[tuple[str, list[tuple[int, int, int]], list[tuple[int, int, int]]]],
) -> None:
    """Marks are the whole font, so a positional disagreement is total."""
    for word, harfbuzz, coretext in compared:
        assert coretext == harfbuzz, word


def test_coretext_also_runs_the_orphan_rule(built: Built) -> None:
    """ccmp has to be on by default in both, or the safety net is HarfBuzz-only.

    Nothing in the font can force a feature to run. Each shaper decides, and
    for an unencoded script the decision comes from its default set rather than
    from anything script-specific.
    """
    vowel = built.script.vowels[0]
    text = chr(built.script.codepoint(vowel))

    coretext = built.coretext([text])[0]
    harfbuzz = built.absolute(built.shape([text])[0])

    ring = built.ttf.getGlyphID("dottedcircle")
    assert [g for g, _, _ in harfbuzz] == [ring, built.ttf.getGlyphID(vowel.glyph)]
    assert coretext == harfbuzz, "CoreText did not insert the dotted circle"


def test_coretext_uses_the_same_space(built: Built) -> None:
    text = built.text("mi", "nu")
    assert built.coretext([text])[0] == built.absolute(built.shape([text])[0])
