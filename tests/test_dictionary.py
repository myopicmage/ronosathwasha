"""The generated page, checked for the things a browser cannot tell you.

A page that renders beautifully and shows the wrong code points looks exactly
like a page that is right, because nobody reads private-use text by eye. So the
text in the page is compared against `script.encode` rather than inspected.
"""

from __future__ import annotations

import base64
import html
import re
import tomllib
from pathlib import Path

import pytest

from ronosathwasha import Lexicon, ParseFailure, Script, load_lexicon
from tools.build_dictionary import canonical, page, searchable
from tools.webfont import compile_woff2

SCRIPT_SPAN = re.compile(r'<span class="script"[^>]*>(?P<text>[^<]*)</span>')
KEY = re.compile(r'data-key="(?P<key>[^"]*)"')

# Script text now appears in two places: one span per lexicon entry, and seven
# per verb in the conjugation tables. Tests that count spans against the lexicon
# have to say which they mean, so the entry cards are matched on their own.
ENTRY_CARD = re.compile(r'<li class="entry".*?</li>', re.S)


def entry_spans(rendered: str) -> list[str]:
    return [
        html.unescape(span.group("text"))
        for card in ENTRY_CARD.finditer(rendered)
        for span in SCRIPT_SPAN.finditer(card.group(0))
    ]

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

    assert len(entry_spans(rendered)) == len(lexicon.writable())


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
    found = entry_spans(rendered)
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
    assert "runə" in searchable(dog)


def test_a_non_ascii_romanisation_is_reachable_from_a_plain_keyboard(
    lexicon: Lexicon,
) -> None:
    """`ða` is spelled with an IPA character nobody has a key for."""
    alive = next(e for e in lexicon.writable() if e.roman == "ða")
    assert canonical(alive) == "dha"
    assert "dha" in searchable(alive)

    schwa = next(e for e in lexicon.writable() if "ə" in e.roman)
    assert "ə" not in searchable(schwa).replace(schwa.roman, "")


def test_the_page_carries_the_font_it_was_built_against(
    script: Script, lexicon: Lexicon, tmp_path: Path
) -> None:
    """Inlined, and WOFF2 by its signature rather than by its declared type."""
    woff2 = compile_woff2(script, tmp_path)
    assert woff2[:4] == b"wOF2"

    built = page(script, lexicon, woff2)
    assert base64.b64encode(woff2).decode("ascii") in built
    assert "local(" not in built, "the installed font may be a different vintage"


def test_the_conjugation_tables_are_present_and_readable(script: Script) -> None:
    """The paradigms are computed in Raku and rendered here.

    Not a duplicate of the Raku tests, which check that the forms are right.
    This checks the handoff: that the file arrived, that every form in it is
    writable in the script, and that the page shows it as script rather than as
    romanisation wearing a script class.
    """
    from tools.build_dictionary import PARADIGMS

    assert PARADIGMS.exists(), "run `make build/paradigms.toml` first"

    with PARADIGMS.open("rb") as handle:
        data = tomllib.load(handle)

    assert data["verb"], "no verbs in the generated paradigms"
    assert data["cells"] == [
        "past", "present", "future", "command", "question", "might", "negative",
    ]

    for verb in data["verb"]:
        for cell in data["cells"]:
            form = verb[cell]
            parsed = script.parse(form)
            assert not isinstance(parsed, ParseFailure), f"{verb['stem']} {cell}: {parsed}"


def test_every_conjugated_form_reaches_the_page(script: Script) -> None:
    from tools.build_dictionary import PARADIGMS, page

    with PARADIGMS.open("rb") as handle:
        data = tomllib.load(handle)

    rendered = page(script, load_lexicon(script), b"")

    missing = [
        f"{verb['stem']} {cell}"
        for verb in data["verb"]
        for cell in data["cells"]
        if html.escape(verb[cell]) not in rendered
    ]
    assert not missing, f"conjugated forms absent from the page: {missing}"
