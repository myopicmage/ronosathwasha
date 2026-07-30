"""The specimen sheet, checked for the things looking at it cannot tell you.

A specimen is the one page nobody proofreads, because its whole purpose is to be
looked at rather than read. A grid with a row missing, or with the consonant and
the vowel emitted the wrong way round, renders as a neat grid of plausible
letters. So the cells are compared against `script.encode` rather than inspected,
the same way the dictionary page is.
"""

from __future__ import annotations

import html
import re

import pytest

from ronesathwasha import Script
from tools.build_syllabary import (
    consonant_contrasts,
    page,
    vowel_contrasts,
)

GLYPH = re.compile(r'<span class="glyph"[^>]*>(?P<text>[^<]*)</span>')
GRID = re.compile(r'<div class="grid">(?P<body>.*?)</div>', re.S)
BASES = re.compile(r'<div class="bases">(?P<body>.*?)</div>', re.S)
SOURCE = re.compile(r"local\(\s*[^)]*\)|url\(\s*[\"']?(?P<target>[^\"')]*)")

# The private use area of the basic multilingual plane.
PUA = range(0xE000, 0xF900)


@pytest.fixture(scope="module")
def rendered(script: Script) -> str:
    """The page with an empty font in it.

    The font's own bytes are covered where they matter, in the tests for the
    other pages. What is under test here is which code points land in which
    cell, and that does not depend on the outlines.
    """
    return page(script, b"")


def codepoints(fragment: str) -> list[tuple[int, ...]]:
    """Every glyph span in a fragment, as the code points it actually carries.

    The page writes numeric character references so that the source stays
    diffable, which means the assertion has to unescape before comparing. A test
    that skipped this would pass on a page full of literal ampersands.
    """
    return [
        tuple(ord(c) for c in html.unescape(match.group("text")) if ord(c) in PUA)
        for match in GLYPH.finditer(fragment)
    ]


def test_the_grid_holds_every_syllable_in_declaration_order(
    script: Script, rendered: str
) -> None:
    """Consonant then vowel, consonants outermost, nothing dropped.

    Order is load-bearing rather than cosmetic: the row and column headings are
    emitted from the same two lists, so a grid that disagreed with
    `Script.syllables()` would be mislabelled everywhere at once and look fine.
    """
    grid = GRID.search(rendered)
    assert grid is not None, "the page has no grid"

    expected = [script.encode([syllable]) for syllable in script.syllables()]
    assert codepoints(grid.group("body")) == expected


def test_the_bare_rows_cover_the_whole_inventory(
    script: Script, rendered: str
) -> None:
    rows = [codepoints(match.group("body")) for match in BASES.finditer(rendered)]
    assert len(rows) == 2, f"expected a consonant row and a vowel row, found {len(rows)}"

    consonants, vowels = rows
    assert consonants == [(script.codepoint(c),) for c in script.consonants]
    assert vowels == [(script.codepoint(v),) for v in script.vowels]


def test_the_page_fetches_nothing(rendered: str) -> None:
    """No `local()` and no URL that leaves the file.

    The same failure `tools/build_docs.py` guards against: a page that resolves
    the font through the OS renders from whatever vintage is installed, and the
    two disagree exactly when the inventory has changed, which is when somebody
    is looking at a specimen.
    """
    targets = list(SOURCE.finditer(rendered))
    assert targets, "the page names no font source at all"

    for match in targets:
        target = match.group("target")
        assert target is not None, "local() reached the page"
        assert target.startswith("data:"), f"the page fetches {target}"


def test_every_derived_consonant_is_shown_against_its_base(script: Script) -> None:
    derived = {c for c in script.consonants if c.derivation is not None}
    shown = {pair[1] for pair in consonant_contrasts(script)}
    assert shown == derived


def test_mirror_pairs_are_reflections_and_exclude_schwa(script: Script) -> None:
    """Same height and cancelling backness, which schwa cannot satisfy.

    Schwa is mid and central, so it shares a height with both `e` and `o`. An
    ordering test on backness pairs it with each of them and calls all three
    mirrors, which produced two cards for a property neither pair has.
    """
    pairs = vowel_contrasts(script)
    assert pairs, "no mirror pairs found at all"

    for front, back in pairs:
        assert front.height == back.height
        assert front.backness.value == -back.backness.value
        assert back.backness.value > 0
        assert not front.glide and not back.glide

    named = {(front.roman, back.roman) for front, back in pairs}
    assert named == {("i", "u"), ("e", "o")}
