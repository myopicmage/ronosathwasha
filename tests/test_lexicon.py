"""Check every lexicon entry against the script.

The point is the feedback loop. Add a word, run pytest, and find out
immediately whether it is writable rather than discovering it when you try to
set it in the font. Nothing here validates meaning; only form.
"""

from __future__ import annotations

from ronesathwasha import Harmony, Lexicon, ParseFailure


def test_every_entry_is_writable(lexicon: Lexicon) -> None:
    broken = [
        f"[{e.section}] {e.roman} ({e.gloss}): {e.parsed.reason}"
        for e in lexicon.entries
        if e.section != "respell" and isinstance(e.parsed, ParseFailure)
    ]
    assert not broken, "\n".join(["unwritable entries outside [respell]:", *broken])


def test_the_pending_section_is_actually_pending(lexicon: Lexicon) -> None:
    """Anything in [respell] that now parses should be moved out of it."""
    fixed = [e.roman for e in lexicon.blocked() if e.writable]
    assert not fixed, f"these are writable now, move them: {', '.join(fixed)}"


def test_every_canonical_entry_is_harmonic(lexicon: Lexicon) -> None:
    """The historical lexicon has now been reconciled with vowel harmony."""
    classes = [
        harmony
        for entry in lexicon.writable()
        for harmony in entry.harmonies
    ]
    assert len(classes) == sum(len(entry.words) for entry in lexicon.writable())
    assert Harmony.NEUTRAL in classes, "a language with no all-neutral words is suspicious"
    assert Harmony.DISHARMONIC not in classes


def test_phrases_preserve_word_level_harmony(lexicon: Lexicon) -> None:
    fireball = next(
        entry for entry in lexicon.writable() if entry.gloss == "I cast fireball"
    )
    assert fireball.harmonies == (Harmony.FRONT, Harmony.BACK)
