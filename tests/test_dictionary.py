"""The generated page, checked for the things a browser cannot tell you.

A page that renders beautifully and shows the wrong code points looks exactly
like a page that is right, because nobody reads private-use text by eye. So the
text in the page is compared against `script.encode` rather than inspected.
"""

from __future__ import annotations

import html
import re
from pathlib import Path

import pytest

from ronesathwasha import Lexicon, Script
from tools.build_dictionary import canonical, font, page, searchable

SCRIPT_SPAN = re.compile(r'<span class="script"[^>]*>(?P<text>[^<]*)</span>')
KEY = re.compile(r'data-key="(?P<key>[^"]*)"')

# The private use area of the basic multilingual plane.
PUA = range(0xE000, 0xF900)


@pytest.fixture(scope="session")
def rendered(script: Script, lexicon: Lexicon) -> str:
    """The page with an empty font. Nothing here depends on the font bytes."""
    return page(script, lexicon, b"")


def test_every_writable_entry_reaches_the_page(
    rendered: str, lexicon: Lexicon
) -> None:
    missing = [e.roman for e in lexicon.writable() if html.escape(e.gloss) not in rendered]
    assert not missing, f"entries absent from the page: {', '.join(missing)}"

    assert len(SCRIPT_SPAN.findall(rendered)) == len(lexicon.writable())


def test_the_blocked_entries_stay_out_of_it(rendered: str, lexicon: Lexicon) -> None:
    """[respell] is a queue, not vocabulary. It has no business in a dictionary."""
    leaked = [
        e.roman
        for e in lexicon.blocked()
        if re.search(rf'data-key="[^"]*\b{re.escape(e.roman)}\b', rendered)
    ]
    assert not leaked, f"unwritable entries on the page: {', '.join(leaked)}"


def test_rendered_text_is_the_encoding_the_font_expects(
    rendered: str, script: Script, lexicon: Lexicon
) -> None:
    """The page's own text, decoded back and compared with the model."""
    found = [html.unescape(m.group("text")) for m in SCRIPT_SPAN.finditer(rendered)]
    expected = [entry.text(script) for entry in lexicon.writable()]
    assert found == expected

    for text, entry in zip(found, lexicon.writable(), strict=True):
        words = text.split(" ")
        assert len(words) == len(entry.words), f"{entry.roman}: word breaks lost"

        for word, syllables in zip(words, entry.words, strict=True):
            assert tuple(ord(c) for c in word) == script.encode(syllables)


def test_every_character_of_script_text_is_private_use(rendered: str) -> None:
    """A stray Latin letter in a script span would render in the fallback font.

    It would also look plausible, since the romanisation is Latin, so this is
    checked rather than left to the eye.
    """
    for match in SCRIPT_SPAN.finditer(rendered):
        for char in html.unescape(match.group("text")).replace(" ", ""):
            assert ord(char) in PUA, f"U+{ord(char):04X} is not private use"


def test_search_keys_carry_no_private_use_text(rendered: str) -> None:
    """Searching the encoded form would need a keyboard the reader may not have.

    Worse, it would silently be case- and normalisation-blind: the PUA gets
    nothing from Unicode's collation or casefolding, so a substring match on it
    is the only search that could ever work.
    """
    for match in KEY.finditer(rendered):
        for char in html.unescape(match.group("key")):
            assert ord(char) not in PUA


def test_search_finds_a_word_by_gloss_and_by_romanisation(lexicon: Lexicon) -> None:
    dog = next(e for e in lexicon.writable() if e.gloss == "dog")
    assert "dog" in searchable(dog)
    assert "rune" in searchable(dog)


def test_a_non_ascii_romanisation_is_reachable_from_a_plain_keyboard(
    lexicon: Lexicon,
) -> None:
    """`ða` is spelled with an IPA character nobody has a key for."""
    alive = next(e for e in lexicon.writable() if e.roman == "ða")
    assert canonical(alive) == "dha"
    assert "dha" in searchable(alive)

    schwa = next(e for e in lexicon.writable() if "ə" in e.roman)
    assert "ə" not in searchable(schwa).replace(schwa.roman, "")


def test_the_embedded_font_is_really_woff2(script: Script, tmp_path: Path) -> None:
    """WOFF2's signature. A TTF would still render, and would be twice the size."""
    assert font(script, tmp_path)[:4] == b"wOF2"
