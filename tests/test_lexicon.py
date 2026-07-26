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


def test_harmony_class_is_derivable_for_every_entry(lexicon: Lexicon) -> None:
    """Front, back, neutral, or disharmonic. Computed, never stored.

    Disharmonic words are legal and expected: the lexicon predates the harmony
    decision, so most of it has not been reconciled yet. This asserts the
    classification runs, not that the language is already harmonious.
    """
    classes = [e.harmony for e in lexicon.writable()]
    assert len(classes) == len(lexicon.writable())
    assert Harmony.NEUTRAL in classes, "a language with no all-neutral words is suspicious"
