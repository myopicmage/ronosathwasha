"""Check every lexicon entry against the script.

The point is the feedback loop. Add a word, run pytest, and find out
immediately whether it is writable rather than discovering it when you try to
set it in the font. Nothing here validates meaning; only form.
"""

from __future__ import annotations

import tomllib
from pathlib import Path

import pytest

from ronesathwasha import Backness, ParseFailure, Script, Syllable

LEXICON = Path(__file__).resolve().parent.parent / "data" / "lexicon.toml"

# Entries known to be blocked by an inventory decision, kept visible rather
# than deleted. They are reported, not enforced.
PENDING = "respell"


@pytest.fixture(scope="session")
def lexicon() -> dict[str, dict[str, str]]:
    return tomllib.loads(LEXICON.read_text(encoding="utf-8"))


def entries(lexicon: dict[str, dict[str, str]]) -> list[tuple[str, str, str]]:
    """(section, word, gloss) for everything except the pending section."""
    return [
        (section, word, gloss)
        for section, words in lexicon.items()
        if section != PENDING
        for word, gloss in words.items()
    ]


def parse_all(script: Script, word: str) -> list[Syllable] | ParseFailure:
    """Phrases are several words; parse each and concatenate."""
    out: list[Syllable] = []
    for part in word.split():
        parsed = script.parse(part)
        if isinstance(parsed, ParseFailure):
            return parsed

        out.extend(parsed)
    return out


def test_every_entry_is_writable(
    script: Script, lexicon: dict[str, dict[str, str]]
) -> None:
    broken = []
    for section, word, gloss in entries(lexicon):
        parsed = parse_all(script, word)
        if isinstance(parsed, ParseFailure):
            broken.append(f"[{section}] {word} ({gloss}): {parsed.reason}")

    assert not broken, "\n".join(
        ["unwritable entries outside [respell]:", *broken]
    )


def test_the_pending_section_is_actually_pending(
    script: Script, lexicon: dict[str, dict[str, str]]
) -> None:
    """Anything in [respell] that now parses should be moved out of it."""
    fixed = [
        word
        for word in lexicon.get(PENDING, {})
        if not isinstance(parse_all(script, word), ParseFailure)
    ]
    assert not fixed, f"these are writable now, move them: {', '.join(fixed)}"


def test_harmony_class_is_derivable_for_every_entry(
    script: Script, lexicon: dict[str, dict[str, str]]
) -> None:
    """Front, back, neutral, or disharmonic. Computed, never stored.

    Disharmonic words are legal and expected: the lexicon predates the harmony
    decision, so most of it has not been reconciled yet. This asserts the
    classification runs, not that the language is already harmonious.
    """
    counts = {"front": 0, "back": 0, "neutral": 0, "disharmonic": 0}
    for _, word, _ in entries(lexicon):
        parsed = parse_all(script, word)
        assert not isinstance(parsed, ParseFailure)

        sides = {
            s.vowel.backness for s in parsed if s.vowel.backness is not Backness.CENTRAL
        }
        if not sides:
            counts["neutral"] += 1
        elif len(sides) > 1:
            counts["disharmonic"] += 1
        else:
            counts[sides.pop().name.lower()] += 1

    assert sum(counts.values()) == len(entries(lexicon))
    assert counts["neutral"] > 0, "a language with no all-neutral words is suspicious"
