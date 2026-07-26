from __future__ import annotations

from pathlib import Path

import pytest

from ronesathwasha import (
    Backness,
    Direction,
    Height,
    ParseFailure,
    Script,
    ScriptError,
    Syllable,
    load,
)


@pytest.fixture(scope="session")
def script() -> Script:
    return load()


def test_inventory_is_thirteen_by_twelve(script: Script) -> None:
    assert len(script.consonants) == 13
    assert len(script.vowels) == 12
    assert len(list(script.syllables())) == 156


def test_glide_vowels_are_derived_not_declared(script: Script) -> None:
    plain = [v for v in script.vowels if not v.glide]
    glides = [v for v in script.vowels if v.glide]
    assert len(plain) == len(glides) == 6

    for p, g in zip(plain, glides, strict=True):
        assert g.roman == "w" + p.roman
        assert g.glyph == "v_w" + p.glyph.removeprefix("v_")
        # Same vowel, one feature apart: the phonology must not drift.
        assert (g.height, g.backness) == (p.height, p.backness)
        assert script.codepoint(g) - script.codepoint(p) == script.glide_offset


def test_chevron_bearing_is_the_trapezoid_cell(script: Script) -> None:
    expected = {
        ("i", Height.CLOSE, Backness.FRONT): Direction.UP_LEFT,
        ("u", Height.CLOSE, Backness.BACK): Direction.UP_RIGHT,
        ("e", Height.MID, Backness.FRONT): Direction.LEFT,
        ("o", Height.MID, Backness.BACK): Direction.RIGHT,
        ("ə", Height.MID, Backness.CENTRAL): Direction.CENTRE,
        ("a", Height.OPEN, Backness.CENTRAL): Direction.DOWN,
    }
    by_roman = {v.roman: v for v in script.vowels if not v.glide}
    for (roman, height, backness), direction in expected.items():
        v = by_roman[roman]
        assert (v.height, v.backness) == (height, backness)
        assert v.direction is direction


def test_unused_bearings_are_exactly_the_empty_cells(script: Script) -> None:
    used = {v.direction for v in script.vowels}
    assert set(Direction) - used == {
        Direction.UP,          # close central
        Direction.DOWN_LEFT,   # open front
        Direction.DOWN_RIGHT,  # open back
    }


def test_glide_tick_is_antipodal(script: Script) -> None:
    for v in script.vowels:
        if not v.glide:
            assert v.tick is None
            continue

        assert v.tick is not None
        x, y = v.direction.value
        assert v.tick.value == (-x, -y)

    # The ring has no point, so its tick is placed by convention, not derived.
    schwa = next(v for v in script.vowels if v.glide and v.roman == "wə")
    assert schwa.tick is Direction.CENTRE


def test_derivations_use_only_two_marks(script: Script) -> None:
    derived = {c.roman: c.derivation for c in script.consonants if c.derivation}
    assert {c: d.mark for c, d in derived.items() if d} == {
        "d": "stem",
        "j": "stem",
        "dh": "stem",
        "sh": "crossbar",
        "r": "crossbar",
    }


def test_voicing_stem_only_ever_voices(script: Script) -> None:
    by_glyph = {c.glyph: c for c in script.consonants}
    for c in script.consonants:
        if c.derivation is None or c.derivation.mark != "stem":
            continue

        base = by_glyph[c.derivation.base]
        assert c.voiced and not base.voiced
        assert (c.place, c.manner) == (base.place, base.manner)


def test_autonym_round_trips(script: Script) -> None:
    parsed = script.parse("ronesathwasha")
    assert not isinstance(parsed, ParseFailure)
    assert [s.roman for s in parsed] == ["ro", "ne", "sa", "thwa", "sha"]
    assert script.encode(parsed) == (
        0xE00B, 0xE023,  # ro
        0xE001, 0xE022,  # ne
        0xE008, 0xE024,  # sa
        0xE006, 0xE02A,  # thwa
        0xE009, 0xE024,  # sha
    )


def test_parse_prefers_the_longest_spelling(script: Script) -> None:
    # `sh` must beat `s`, and `wa` must beat `a`, or the glide vanishes silently.
    for word, syllables in [
        ("sha", ["sha"]),
        ("sa", ["sa"]),
        ("thwa", ["thwa"]),
        ("tha", ["tha"]),
        ("chime", ["chi", "me"]),
    ]:
        parsed = script.parse(word)
        assert not isinstance(parsed, ParseFailure), parsed
        assert [s.roman for s in parsed] == syllables


def test_ipa_spelling_of_the_dental_fricatives_is_accepted(script: Script) -> None:
    # The original notes write these as ð and θ rather than dh and th.
    for word in ["niðə", "ðo", "θə"]:
        assert not isinstance(script.parse(word), ParseFailure), word


def test_unwritable_words_fail_with_a_position(script: Script) -> None:
    for word, position in [("hiðə", 0), ("yəwə", 2), ("ro!", 2)]:
        failure = script.parse(word)
        assert isinstance(failure, ParseFailure), word
        assert failure.position == position


def test_bare_vowel_is_unwritable(script: Script) -> None:
    # No onsetless syllables: the model refuses what the phonotactics forbid.
    assert isinstance(script.parse("a"), ParseFailure)


def test_every_syllable_encodes_to_two_codepoints(script: Script) -> None:
    seen: set[tuple[int, ...]] = set()
    for s in script.syllables():
        pair = script.encode([s])
        assert len(pair) == 2
        seen.add(pair)
    assert len(seen) == 156


def _write(tmp_path: Path, body: str) -> Path:
    path = tmp_path / "script.toml"
    path.write_text(body, encoding="utf-8")
    return path


MINIMAL = """
[block]
consonant_base = 0xE000
vowel_base = 0xE020
glide_offset = 6
[mark.stem]
glyph = "mk_stem"
feature = "voicing"
[[consonant]]
offset = 0
glyph = "c_m"
roman = "m"
ipa = "m"
place = "labial"
manner = "nasal"
voiced = true
[[vowel]]
offset = 0
glyph = "v_a"
roman = "a"
ipa = "a"
height = "open"
backness = "central"
"""


def test_minimal_declaration_loads(tmp_path: Path) -> None:
    assert load(_write(tmp_path, MINIMAL)).name == "unnamed"


@pytest.mark.parametrize(
    ("mutation", "message"),
    [
        ('offset = 0\nglyph = "c_m"', "offsets must be"),
        ('glyph = "v_a"', "duplicate glyph names"),
        ('height = "open"', "is not one of"),
        ("glide_offset = 6", "glide_offset"),
        ("vowel_base = 0xE020", "overrunning"),
    ],
)
def test_malformed_declarations_fail_at_load(
    tmp_path: Path, mutation: str, message: str
) -> None:
    broken = {
        "offsets must be": MINIMAL.replace("offset = 0\nglyph = \"c_m\"", "offset = 3\nglyph = \"c_m\""),
        "duplicate glyph names": MINIMAL.replace('glyph = "v_a"', 'glyph = "c_m"'),
        "is not one of": MINIMAL.replace('height = "open"', 'height = "middling"'),
        "glide_offset": MINIMAL.replace("glide_offset = 6", "glide_offset = 0"),
        "overrunning": MINIMAL.replace("vowel_base = 0xE020", "vowel_base = 0xE000"),
    }[message]

    with pytest.raises(ScriptError, match=message):
        load(_write(tmp_path, broken))


def test_syllable_roman_is_the_two_parts(script: Script) -> None:
    c = next(c for c in script.consonants if c.roman == "th")
    v = next(v for v in script.vowels if v.roman == "wa")
    assert Syllable(c, v).roman == "thwa"
