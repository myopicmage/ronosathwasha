"""The script, loaded once into a shape that cannot express a broken one.

Everything downstream imports from here rather than reading the TOML itself, so
the checks below run exactly once, at load, and a malformed declaration fails
with a sentence about what is wrong instead of surfacing three stages later as
a confusing fontmake error.

Two things are computed rather than read, because a second copy is a second
thing that can disagree:

  - The six glide vowels, from the six plain ones plus a fixed offset.
  - Every chevron's bearing, from the vowel's height and backness.
"""

from __future__ import annotations

import tomllib
from collections.abc import Iterator, Mapping, Sequence
from dataclasses import dataclass
from enum import Enum
from pathlib import Path
from typing import Any, Final

DATA: Final = Path(__file__).resolve().parent.parent / "data" / "script.toml"

# The Basic Multilingual Plane's private use area.
PUA_FIRST: Final = 0xE000
PUA_LAST: Final = 0xF8FF


class ScriptError(Exception):
    """The declaration is malformed. Raised at load and nowhere else."""


class Height(Enum):
    """Vowel height, valued as its vertical position in the trapezoid."""

    CLOSE = 1
    MID = 0
    OPEN = -1


class Backness(Enum):
    """Vowel backness, valued as its horizontal position in the trapezoid."""

    FRONT = -1
    CENTRAL = 0
    BACK = 1


class Direction(Enum):
    """A chevron bearing, as (x, y), x positive rightward and y positive up.

    The nine members are the nine cells of the vowel trapezoid. Six are
    occupied. The three that are not are precisely the three bearings no
    chevron points, which is not a coincidence: it is the same fact written
    twice, once as phonology and once as geometry.
    """

    UP_LEFT = (-1, 1)
    UP = (0, 1)
    UP_RIGHT = (1, 1)
    LEFT = (-1, 0)
    CENTRE = (0, 0)
    RIGHT = (1, 0)
    DOWN_LEFT = (-1, -1)
    DOWN = (0, -1)
    DOWN_RIGHT = (1, -1)

    @property
    def opposite(self) -> Direction:
        """The tail end of the chevron, where the glide tick goes.

        CENTRE is its own opposite, which is exactly why the schwa's tick has
        to be placed by convention rather than derived: a ring has no point for
        the tick to be opposite to.
        """
        x, y = self.value
        return Direction((-x, -y))


@dataclass(frozen=True)
class Mark:
    """A stroke added to a base glyph to derive another."""

    key: str
    glyph: str
    feature: str
    description: str


@dataclass(frozen=True)
class Derivation:
    """This consonant is another consonant plus one mark."""

    base: str
    mark: str


@dataclass(frozen=True)
class Consonant:
    offset: int
    glyph: str
    roman: str
    ipa: str
    place: str
    manner: str
    voiced: bool
    derivation: Derivation | None


@dataclass(frozen=True)
class Vowel:
    offset: int
    glyph: str
    roman: str
    ipa: str
    height: Height
    backness: Backness
    glide: bool

    @property
    def direction(self) -> Direction:
        """Where the chevron points. The trapezoid cell, read as a bearing."""
        return Direction((self.backness.value, self.height.value))

    @property
    def tick(self) -> Direction | None:
        """Where the glide tick sits, or None on a plain vowel.

        Always antipodal to the chevron's point. CENTRE means the host has no
        point, so the drawing places the tick by convention (below the ring).
        """
        return self.direction.opposite if self.glide else None


@dataclass(frozen=True)
class Syllable:
    """The only well-formed unit in this language: exactly one C plus one V."""

    consonant: Consonant
    vowel: Vowel

    @property
    def roman(self) -> str:
        return self.consonant.roman + self.vowel.roman


@dataclass(frozen=True)
class ParseFailure:
    """Romanised text that is not writable in this script, and where it broke."""

    word: str
    position: int
    reason: str

    def __str__(self) -> str:
        return f"{self.word!r} at {self.position}: {self.reason}"


@dataclass(frozen=True)
class Script:
    name: str
    consonants: tuple[Consonant, ...]
    vowels: tuple[Vowel, ...]
    marks: Mapping[str, Mark]
    consonant_base: int
    vowel_base: int
    glide_offset: int

    @property
    def family(self) -> str:
        """The autonym as an artefact name: font family, keyboard layout, title.

        Derived rather than declared, because a second copy of the name is a
        second thing to forget. The name has been repaired once already, when
        harmony made `rone-` into `rono-`, and the font family, the layout, the
        Python package and the docs all kept the old spelling for a while after
        `data/script.toml` had the new one. Anything that reads this cannot fall
        behind that file again.
        """
        return self.name.capitalize()

    def codepoint(self, letter: Consonant | Vowel) -> int:
        if isinstance(letter, Consonant):
            return self.consonant_base + letter.offset

        return self.vowel_base + letter.offset + (self.glide_offset if letter.glide else 0)

    def syllables(self) -> Iterator[Syllable]:
        """All C x V, consonants outermost, so the order matches the specimen."""
        for c in self.consonants:
            for v in self.vowels:
                yield Syllable(c, v)

    def encode(self, syllables: Sequence[Syllable]) -> tuple[int, ...]:
        return tuple(
            cp
            for s in syllables
            for cp in (self.codepoint(s.consonant), self.codepoint(s.vowel))
        )

    def parse(self, word: str) -> tuple[Syllable, ...] | ParseFailure:
        """Romanisation to syllables, longest match first.

        Longest-first matters twice over: `sh` has to beat `s`, and `wa` has to
        beat `a`, or the glide silently disappears. Both the roman and the IPA
        spelling of a consonant are accepted, since the original notes write
        the dental fricatives as θ and ð.
        """
        # IPA symbols are accepted as alternative spellings, because the
        # original notes write the dental fricatives as ð and θ. Only the
        # non-ASCII ones: romanisations are built from ASCII letters, so an
        # ASCII IPA symbol is a collision waiting to happen. /y/ carries the
        # symbol "j", and accepting it silently reinterprets every word spelled
        # with a j rather than reporting it as unwritable.
        spellings: dict[str, Consonant] = {
            c.ipa: c for c in self.consonants if not c.ipa.isascii()
        }
        spellings.update({c.roman: c for c in self.consonants})
        cons = sorted(spellings.items(), key=lambda kv: len(kv[0]), reverse=True)
        vows = sorted(
            {v.roman: v for v in self.vowels}.items(),
            key=lambda kv: len(kv[0]),
            reverse=True,
        )

        out: list[Syllable] = []
        i = 0
        while i < len(word):
            hit_c = next(((r, c) for r, c in cons if word.startswith(r, i)), None)
            if hit_c is None:
                return ParseFailure(word, i, f"no consonant at {word[i:i + 3]!r}")

            spelling, c = hit_c
            i += len(spelling)

            hit_v = next(((r, v) for r, v in vows if word.startswith(r, i)), None)
            if hit_v is None:
                return ParseFailure(
                    word, i, f"{c.roman!r} is not followed by a vowel at {word[i:i + 3]!r}"
                )

            spelling, v = hit_v
            i += len(spelling)
            out.append(Syllable(c, v))

        return tuple(out)


def _table(raw: Mapping[str, Any], key: str) -> list[Mapping[str, Any]]:
    rows = raw.get(key)
    if not isinstance(rows, list) or not rows:
        raise ScriptError(f"no [[{key}]] entries")

    return rows


def _enum[E: Enum](cls: type[E], value: object, where: str) -> E:
    try:
        return cls(value) if not isinstance(value, str) else cls[value.upper()]
    except (KeyError, ValueError):
        allowed = ", ".join(m.name.lower() for m in cls)
        raise ScriptError(f"{where}: {value!r} is not one of {allowed}") from None


def load(path: Path = DATA) -> Script:
    try:
        raw = tomllib.loads(path.read_text(encoding="utf-8"))
    except OSError as e:
        raise ScriptError(f"cannot read {path}: {e}") from e
    except tomllib.TOMLDecodeError as e:
        raise ScriptError(f"{path} is not valid TOML: {e}") from e

    block = raw.get("block", {})
    c_base, v_base = block.get("consonant_base"), block.get("vowel_base")
    glide = block.get("glide_offset")
    if not all(isinstance(n, int) for n in (c_base, v_base, glide)):
        raise ScriptError("[block] needs integer consonant_base, vowel_base, glide_offset")

    marks = {
        key: Mark(key, m["glyph"], m["feature"], m.get("description", ""))
        for key, m in raw.get("mark", {}).items()
    }

    consonants = tuple(
        Consonant(
            offset=c["offset"],
            glyph=c["glyph"],
            roman=c["roman"],
            ipa=c["ipa"],
            place=c["place"],
            manner=c["manner"],
            voiced=bool(c["voiced"]),
            derivation=(
                Derivation(c["derives_from"], c["mark"])
                if ("derives_from" in c) or ("mark" in c)
                else None
            ),
        )
        for c in _table(raw, "consonant")
    )

    # Six declared vowels become twelve. The glide is a feature, not an entry.
    plain = tuple(
        Vowel(
            offset=v["offset"],
            glyph=v["glyph"],
            roman=v["roman"],
            ipa=v["ipa"],
            height=_enum(Height, v["height"], f"vowel {v['glyph']}"),
            backness=_enum(Backness, v["backness"], f"vowel {v['glyph']}"),
            glide=False,
        )
        for v in _table(raw, "vowel")
    )
    vowels = plain + tuple(
        Vowel(
            offset=v.offset,
            glyph=f"v_w{v.glyph.removeprefix('v_')}",
            roman=f"w{v.roman}",
            ipa=f"w{v.ipa}",
            height=v.height,
            backness=v.backness,
            glide=True,
        )
        for v in plain
    )

    script = Script(
        name=raw.get("language", {}).get("name", "unnamed"),
        consonants=consonants,
        vowels=vowels,
        marks=marks,
        consonant_base=c_base,
        vowel_base=v_base,
        glide_offset=glide,
    )
    _check(script)
    return script


def _check(s: Script) -> None:
    """Everything that must hold before anything downstream may assume it."""
    for kind, offsets in (
        ("consonant", [c.offset for c in s.consonants]),
        ("vowel", [v.offset for v in s.vowels if not v.glide]),
    ):
        if sorted(offsets) != list(range(len(offsets))):
            raise ScriptError(f"{kind} offsets must be 0..{len(offsets) - 1}, got {offsets}")

    # Annotated because unpacking two differently typed tuples into one widens
    # the element type to object, and then nothing on it is reachable.
    letters: tuple[Consonant | Vowel, ...] = (*s.consonants, *s.vowels)

    glyphs = [x.glyph for x in letters]
    if len(set(glyphs)) != len(glyphs):
        dupes = sorted({g for g in glyphs if glyphs.count(g) > 1})
        raise ScriptError(f"duplicate glyph names: {', '.join(dupes)}")

    if s.glide_offset < len({v.offset for v in s.vowels}):
        raise ScriptError(
            f"glide_offset {s.glide_offset} is smaller than the vowel run, "
            "so glide and plain vowels would overlap"
        )

    last_consonant = s.consonant_base + len(s.consonants) - 1
    if last_consonant >= s.vowel_base:
        raise ScriptError(
            f"consonants reach U+{last_consonant:04X}, overrunning "
            f"vowel_base U+{s.vowel_base:04X}"
        )

    points = [s.codepoint(x) for x in letters]
    if len(set(points)) != len(points):
        raise ScriptError("codepoint collision")

    outside = [p for p in points if not PUA_FIRST <= p <= PUA_LAST]
    if outside:
        raise ScriptError(
            f"U+{outside[0]:04X} is outside the private use area "
            f"U+{PUA_FIRST:04X}..U+{PUA_LAST:04X}"
        )

    by_glyph = {c.glyph for c in s.consonants}
    for c in s.consonants:
        if c.derivation is None:
            continue

        if c.derivation.base not in by_glyph:
            raise ScriptError(f"{c.glyph} derives from unknown glyph {c.derivation.base}")

        if c.derivation.mark not in s.marks:
            raise ScriptError(f"{c.glyph} uses unknown mark {c.derivation.mark!r}")
