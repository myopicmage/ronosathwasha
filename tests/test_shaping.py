"""Assertions against the compiled font, shaped by the real engine.

Everything here goes through hb-shape rather than reasoning about the tables,
because the question is not what the font contains but what a shaper does with
it. The two came apart twice already: a mark that attached to nothing, and a
word that parsed to the wrong consonant and rendered without complaint.

No test embeds a code point. Encoded strings are built from the model, so a
test file never contains invisible private-use characters and moving the block
cannot silently invalidate a test.
"""

from __future__ import annotations

import pytest

from ronesathwasha import Consonant, Direction, Syllable, Vowel
from tests.harness import Built, Placed
from tools.build_ufo import ADVANCE


@pytest.fixture(scope="session")
def every_syllable(built: Built) -> list[tuple[Syllable, list[Placed]]]:
    syllables = list(built.script.syllables())
    runs = built.shape([built.text(s.roman) for s in syllables])
    return list(zip(syllables, runs, strict=True))


def test_every_syllable_is_two_glyphs(
    every_syllable: list[tuple[Syllable, list[Placed]]],
) -> None:
    assert len(every_syllable) == 156
    for syllable, run in every_syllable:
        assert [p.glyph for p in run] == [
            syllable.consonant.glyph,
            syllable.vowel.glyph,
        ], syllable.roman


def test_no_syllable_produces_notdef(
    every_syllable: list[tuple[Syllable, list[Placed]]],
) -> None:
    for syllable, run in every_syllable:
        assert not any(p.glyph == ".notdef" for p in run), syllable.roman


def test_every_syllable_occupies_one_square(
    every_syllable: list[tuple[Syllable, list[Placed]]],
) -> None:
    """The consonant carries the width; the vowel adds nothing."""
    for syllable, run in every_syllable:
        consonant, vowel = run
        assert consonant.advance == ADVANCE, syllable.roman
        assert vowel.advance == 0, syllable.roman


def test_every_vowel_is_pulled_back_onto_its_consonant(
    every_syllable: list[tuple[Syllable, list[Placed]]],
) -> None:
    """The mark follows the base in the text, so the pen has already moved.

    Attachment has to undo exactly that, which is the whole of this font.
    """
    for syllable, run in every_syllable:
        assert run[1].dx == -ADVANCE, syllable.roman
        assert run[1].dy == 0, syllable.roman


def test_clusters_survive_so_a_cursor_can_be_placed(
    every_syllable: list[tuple[Syllable, list[Placed]]],
) -> None:
    for syllable, run in every_syllable:
        assert [p.cluster for p in run] == [0, 1], syllable.roman


def test_marks_land_where_the_trapezoid_says(built: Built) -> None:
    """The model's claim, checked through the compiled binary.

    Each vowel's ink should sit off the consonant in the direction its bearing
    names. Compared centre to centre rather than edge to edge, because a
    diagonal chevron's bounding box overlaps the consonant's at the corner
    while the ink does not.

    Plain vowels only. A glide is a chevron plus a tick on the opposite side,
    so its box straddles the consonant and its centre lands back in the middle
    by construction. That balance is the antipodal rule showing up as a
    measurement, and it is what the next test checks; asserting a bearing on it
    here would be asserting against our own design.
    """
    consonant = built.script.consonants[0]
    c_box = built.bounds(consonant.glyph)
    assert c_box is not None
    c_mid = ((c_box[0] + c_box[2]) / 2, (c_box[1] + c_box[3]) / 2)

    for vowel in (v for v in built.script.vowels if not v.glide):
        v_box = built.bounds(vowel.glyph)
        assert v_box is not None, vowel.glyph

        if vowel.direction is Direction.CENTRE:
            # The ring is the one vowel that surrounds rather than sits beside.
            assert v_box[0] < c_box[0] and v_box[2] > c_box[2], vowel.roman
            continue

        dx, dy = vowel.direction.value
        v_mid = ((v_box[0] + v_box[2]) / 2, (v_box[1] + v_box[3]) / 2)
        for axis, want, got in (
            ("x", dx, v_mid[0] - c_mid[0]),
            ("y", dy, v_mid[1] - c_mid[1]),
        ):
            if want == 0:
                assert abs(got) < 40, f"{vowel.roman} should be centred on {axis}"
            else:
                assert got * want > 0, (
                    f"{vowel.roman} bears {vowel.direction.name} but sits "
                    f"{got:+.0f} on {axis}"
                )


def test_glide_tick_is_on_the_far_side_from_the_chevron(built: Built) -> None:
    """The antipodal rule surviving all the way into outlines.

    If a tick were drawn on the same side as its chevron's point, the glyph
    would still compile, still shape, and still position. Only the shape would
    be wrong, so the box has to be what notices.
    """
    plain = {v.roman: v for v in built.script.vowels if not v.glide}
    for glide in (v for v in built.script.vowels if v.glide):
        base = plain[glide.roman.removeprefix("w")]
        p_box, g_box = built.bounds(base.glyph), built.bounds(glide.glyph)
        assert p_box is not None and g_box is not None

        dx, dy = glide.direction.value
        if dx:
            grew = g_box[0] < p_box[0] if dx > 0 else g_box[2] > p_box[2]
            assert grew, f"{glide.roman} tick is not opposite its point on x"
        if dy:
            grew = g_box[1] < p_box[1] if dy > 0 else g_box[3] > p_box[3]
            assert grew, f"{glide.roman} tick is not opposite its point on y"


def test_the_autonym(built: Built) -> None:
    run = built.shape([built.text("ronesathwasha")])[0]
    assert [p.glyph for p in run] == [
        "c_r", "v_o", "c_n", "v_e", "c_s", "v_a", "c_th", "v_wa", "c_sh", "v_a",
    ]
    assert sum(p.advance for p in run) == 5 * ADVANCE


def test_a_space_is_a_space_and_not_tofu(built: Built) -> None:
    run = built.shape([built.text("mi", "nu")])[0]
    assert [p.glyph for p in run] == ["c_m", "v_i", "space", "c_n", "v_u"]
    assert built.bounds("space") is None, "a space should draw nothing"
    assert next(p for p in run if p.glyph == "space").advance > 0


def test_orphaned_vowels_get_a_dotted_circle(built: Built) -> None:
    consonant = built.script.consonants[0]
    vowel = built.script.vowels[0]
    c, v = chr(built.script.codepoint(consonant)), chr(built.script.codepoint(vowel))

    alone, doubled, leading = built.shape([v, c + v + v, v + c + v])

    assert [p.glyph for p in alone] == ["dottedcircle", vowel.glyph]
    assert [p.glyph for p in doubled] == [
        consonant.glyph, vowel.glyph, "dottedcircle", vowel.glyph,
    ]
    assert [p.glyph for p in leading] == [
        "dottedcircle", vowel.glyph, consonant.glyph, vowel.glyph,
    ]

    # The circle exists to be attached to. An orphan that sails past it and
    # lands on the next glyph is the bug this rule was written to fix.
    for run in (alone, doubled, leading):
        for previous, current in zip(run, run[1:], strict=False):
            if previous.glyph == "dottedcircle":
                assert current.dx == -ADVANCE


def test_a_legal_syllable_never_triggers_the_orphan_rule(
    every_syllable: list[tuple[Syllable, list[Placed]]],
) -> None:
    for syllable, run in every_syllable:
        assert not any(p.glyph == "dottedcircle" for p in run), syllable.roman


def test_cmap_covers_every_declared_letter(built: Built) -> None:
    cmap = built.ttf["cmap"].getBestCmap()
    declared: tuple[Consonant | Vowel, ...] = (
        *built.script.consonants,
        *built.script.vowels,
    )
    letters = [(built.script.codepoint(x), x.glyph) for x in declared]
    for codepoint, glyph in letters:
        assert cmap.get(codepoint) == glyph, f"U+{codepoint:04X}"

    assert cmap.get(0x0020) == "space"
    assert len(cmap) == len(letters) + 2  # plus space and dottedcircle


def test_line_metrics_agree_across_all_three_families(built: Built) -> None:
    os2, hhea = built.ttf["OS/2"], built.ttf["hhea"]
    assert os2.fsSelection & (1 << 7), "USE_TYPO_METRICS is off"
    assert (hhea.ascender, hhea.descender, hhea.lineGap) == (
        os2.sTypoAscender,
        os2.sTypoDescender,
        os2.sTypoLineGap,
    )
    assert (os2.usWinAscent, -os2.usWinDescent) == (hhea.ascender, hhea.descender)
