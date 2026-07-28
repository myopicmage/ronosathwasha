"""Check every lexicon entry against the script.

The point is the feedback loop. Add a word, run pytest, and find out
immediately whether it is writable rather than discovering it when you try to
set it in the font. Nothing here validates meaning; only form.

Harmony is checked in `t/03-harmony.rakutest` rather than here. Writability is
a question about the script, which is this pipeline's subject; harmony is a
rule of the language, and it now lives with the grammar that has to apply it.
`make check` runs both suites, so the invariant is enforced exactly as before.
"""

from __future__ import annotations

from ronesathwasha import Lexicon, ParseFailure


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


