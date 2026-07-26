"""The lexicon, parsed against the script rather than merely read.

`data/lexicon.toml` stores the two things that cannot be computed, a
romanisation and a gloss. Everything else about an entry (its syllables, its
code points, whether it is writable at all, its harmony class) falls out of
`script.toml`, so it is derived here and never stored there.

An entry that does not parse is not an error. `[respell]` holds words that are
attested in the original notes and blocked by a later inventory decision, and
they are meant to stay visible until someone respells them. So `Entry.parsed`
is the failure or the syllables, and callers decide which they want:
`writable()` for the ones that can be set, `blocked()` for the queue.
"""

from __future__ import annotations

import tomllib
from collections.abc import Iterator, Mapping
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Final

from ronesathwasha.script import Backness, ParseFailure, Script, Syllable

DATA: Final = Path(__file__).resolve().parent.parent / "data" / "lexicon.toml"

# Words known to be blocked by an inventory decision, kept rather than deleted.
PENDING: Final = "respell"


class LexiconError(Exception):
    """The file is malformed. Raised at load and nowhere else."""


class Harmony(Enum):
    """Which side of the vowel space a word sits on.

    Disharmonic is legal and currently common: most of the lexicon predates the
    harmony decision and has not been reconciled with it.
    """

    FRONT = "front"
    BACK = "back"
    NEUTRAL = "neutral"
    DISHARMONIC = "disharmonic"


@dataclass(frozen=True)
class Entry:
    """One line of the lexicon, with everything derivable already derived.

    `parsed` stays grouped by word rather than flattened, because a few entries
    are phrases and the grouping is the only record of where the spaces were.
    """

    section: str
    roman: str
    gloss: str
    parsed: tuple[tuple[Syllable, ...], ...] | ParseFailure

    @property
    def writable(self) -> bool:
        return not isinstance(self.parsed, ParseFailure)

    @property
    def words(self) -> tuple[tuple[Syllable, ...], ...]:
        """The parse, grouped by word. Only valid when `writable`."""
        assert not isinstance(self.parsed, ParseFailure), self.parsed
        return self.parsed

    @property
    def syllables(self) -> tuple[Syllable, ...]:
        """The parse, flattened. Word breaks are not syllable boundaries."""
        return tuple(s for word in self.words for s in word)

    @property
    def harmony(self) -> Harmony:
        sides = {
            s.vowel.backness
            for s in self.syllables
            if s.vowel.backness is not Backness.CENTRAL
        }
        if not sides:
            return Harmony.NEUTRAL

        if len(sides) > 1:
            return Harmony.DISHARMONIC

        return Harmony[sides.pop().name]

    def text(self, script: Script) -> str:
        """The entry as private-use text: the string the font renders.

        Word breaks survive as real U+0020 spaces. A phrase is several words and
        the script has no glyph for a space, so it comes from the fallback font,
        which is correct: a space is a space in every script.
        """
        return " ".join(
            "".join(chr(cp) for cp in script.encode(word)) for word in self.words
        )


@dataclass(frozen=True)
class Lexicon:
    entries: tuple[Entry, ...]

    def writable(self) -> tuple[Entry, ...]:
        """Everything that can be set in the font, in file order."""
        return tuple(e for e in self.entries if e.section != PENDING and e.writable)

    def blocked(self) -> tuple[Entry, ...]:
        """The respelling queue: attested, and currently unwritable."""
        return tuple(e for e in self.entries if e.section == PENDING)

    def sections(self) -> Iterator[tuple[str, tuple[Entry, ...]]]:
        """Writable entries grouped by their section, in file order."""
        for section in dict.fromkeys(e.section for e in self.writable()):
            yield section, tuple(e for e in self.writable() if e.section == section)


def parse(
    script: Script, roman: str
) -> tuple[tuple[Syllable, ...], ...] | ParseFailure:
    """Parse a whole entry, which may be several space-separated words.

    The first failure wins: an entry is writable or it is not, and reporting
    every broken word in a two-word phrase is noise.
    """
    out: list[tuple[Syllable, ...]] = []
    for word in roman.split():
        parsed = script.parse(word)
        if isinstance(parsed, ParseFailure):
            return parsed

        out.append(parsed)
    return tuple(out)


def load(script: Script, path: Path = DATA) -> Lexicon:
    try:
        raw = tomllib.loads(path.read_text(encoding="utf-8"))
    except OSError as e:
        raise LexiconError(f"cannot read {path}: {e}") from e
    except tomllib.TOMLDecodeError as e:
        raise LexiconError(f"{path} is not valid TOML: {e}") from e

    entries: list[Entry] = []
    for section, words in raw.items():
        if not isinstance(words, dict):
            raise LexiconError(f"[{section}] is not a table of word = gloss")

        for roman, gloss in _words(section, words).items():
            entries.append(Entry(section, roman, gloss, parse(script, roman)))

    if not entries:
        raise LexiconError(f"{path} has no entries")

    return Lexicon(tuple(entries))


def _words(section: str, words: Mapping[str, object]) -> dict[str, str]:
    out: dict[str, str] = {}
    for roman, gloss in words.items():
        if not isinstance(gloss, str):
            raise LexiconError(f"[{section}] {roman}: gloss must be a string")

        out[roman] = gloss
    return out
