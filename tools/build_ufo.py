"""Generate the UFO skeleton from the declaration.

The vowel marks are real outlines, because their geometry is derived: a chevron
is a bearing, a length and a thickness, and the model already knows the
bearing. The consonants are placeholder boxes, because their shapes are
drawings nobody has made yet.

Regenerating is safe only while that stays true. Once real consonant outlines
land in the UFO, this script must learn to leave them alone.

Coordinates: the specimen sheets work in a 100x100 box with y pointing down.
Fonts point y up and put the baseline at zero, so everything passes through
`pt()` once, here, rather than being re-derived per glyph.
"""

from __future__ import annotations

import math
import shutil
from pathlib import Path

import ufoLib2
from ufoLib2.objects import Glyph

from ronesathwasha import Direction, Script, load

UPM = 1000
BASELINE = 74.0  # in specimen units: where y=0 falls
SCALE = 10.0
ADVANCE = 1000  # every syllable occupies the same square, Hangul style

CENTRE = (50.0, 50.0)
CHEVRON_REACH = 44.0  # centre to vertex
CHEVRON_ARM = 22.0
TICK_REACH = 38.0
TICK_ARM = 11.0
RING_RADIUS = 34.0
PEN = 4.6  # stroke thickness, in specimen units

KAPPA = 0.5522847498


def pt(x: float, y: float) -> tuple[float, float]:
    """Specimen space to font space: scale up, flip y, sit on the baseline."""
    return (round(x * SCALE), round((BASELINE - y) * SCALE))


def _bar(glyph: Glyph, a: tuple[float, float], b: tuple[float, float]) -> None:
    """One stroke as a filled quadrilateral, drawn in specimen coordinates.

    Chevrons are two of these overlapping at the vertex. Overlap is fine:
    both contours wind the same way, so nonzero fill unions them, and
    fontmake removes the overlap on export anyway.
    """
    (ax, ay), (bx, by) = a, b
    dx, dy = bx - ax, by - ay
    length = math.hypot(dx, dy)
    # Perpendicular of the unit vector, scaled to half the pen width.
    nx, ny = -dy / length * PEN / 2, dx / length * PEN / 2

    corners = [(ax + nx, ay + ny), (bx + nx, by + ny), (bx - nx, by - ny), (ax - nx, ay - ny)]
    p = glyph.getPen()
    p.moveTo(pt(*corners[0]))
    for c in corners[1:]:
        p.lineTo(pt(*c))
    p.closePath()


def _circle(glyph: Glyph, cx: float, cy: float, r: float, clockwise: bool) -> None:
    """A circle as four cubic segments. Direction sets whether it fills or cuts."""
    k = r * KAPPA
    quads = [((r, 0), (r, k), (k, r), (0, r)),
             ((0, r), (-k, r), (-r, k), (-r, 0)),
             ((-r, 0), (-r, -k), (-k, -r), (0, -r)),
             ((0, -r), (k, -r), (r, -k), (r, 0))]
    if clockwise:
        quads = [(d, c, b, a) for a, b, c, d in reversed(quads)]

    p = glyph.getPen()
    p.moveTo(pt(cx + quads[0][0][0], cy + quads[0][0][1]))
    for _, c1, c2, end in quads:
        p.curveTo(
            pt(cx + c1[0], cy + c1[1]),
            pt(cx + c2[0], cy + c2[1]),
            pt(cx + end[0], cy + end[1]),
        )
    p.closePath()


def _unit(d: Direction) -> tuple[float, float]:
    x, y = d.value
    length = math.hypot(x, y)
    # Font y is up, specimen y is down, so the bearing's y flips on the way in.
    return (x / length, -y / length)


def draw_chevron(glyph: Glyph, direction: Direction) -> None:
    """A V pointing along the bearing, vertex outermost.

    The two arms leave the vertex at 45 degrees either side of the way back to
    centre, which is what makes `e` a bare `<` and `i` a corner: same
    construction, rotated.
    """
    ux, uy = _unit(direction)
    vx, vy = CENTRE[0] + ux * CHEVRON_REACH, CENTRE[1] + uy * CHEVRON_REACH

    for sign in (+1, -1):
        angle = math.atan2(-uy, -ux) + sign * math.pi / 4
        _bar(glyph, (vx, vy), (vx + math.cos(angle) * CHEVRON_ARM,
                               vy + math.sin(angle) * CHEVRON_ARM))


def draw_tick(glyph: Glyph, direction: Direction) -> None:
    """The glide tick: a short bar at the chevron's tail, across the bearing.

    A ring has no tail, so the schwa's tick is placed by convention, straight
    down. That case is the model telling us CENTRE is its own opposite.
    """
    tail = direction.opposite
    ux, uy = (0.0, -1.0) if tail is Direction.CENTRE else _unit(tail)
    reach = RING_RADIUS + 12.0 if tail is Direction.CENTRE else TICK_REACH

    cx, cy = CENTRE[0] + ux * reach, CENTRE[1] + uy * reach
    px, py = -uy, ux  # perpendicular, so the tick crosses the bearing
    _bar(glyph, (cx - px * TICK_ARM, cy - py * TICK_ARM),
                (cx + px * TICK_ARM, cy + py * TICK_ARM))


def draw_ring(glyph: Glyph) -> None:
    _circle(glyph, *CENTRE, RING_RADIUS + PEN / 2, clockwise=False)
    _circle(glyph, *CENTRE, RING_RADIUS - PEN / 2, clockwise=True)


def draw_dotted_circle(glyph: Glyph) -> None:
    """U+25CC, the ring of dots a shaper shows around an orphaned mark.

    Complex-script shapers insert this themselves. The default shaper does not,
    so for an unencoded script the font has to do it, which is what the ccmp
    rule below is for.
    """
    for i in range(12):
        angle = i * math.tau / 12
        _circle(
            glyph,
            CENTRE[0] + math.cos(angle) * 26.0,
            CENTRE[1] + math.sin(angle) * 26.0,
            3.4,
            clockwise=False,
        )


def draw_placeholder(glyph: Glyph, label_offset: int) -> None:
    """An open frame in the consonant core, tallied so slots are told apart.

    Deliberately not a guess at the real letterform: it marks the space a
    drawing will occupy and nothing more. Open rather than solid, and the
    tally lives inside it, because everything outside the core belongs to the
    vowel and a placeholder has no business colliding with a real mark.
    """
    x0, y0, x1, y1 = 30.0, 30.0, 70.0, 70.0
    for a, b in (((x0, y0), (x1, y0)), ((x1, y0), (x1, y1)),
                 ((x1, y1), (x0, y1)), ((x0, y1), (x0, y0))):
        _bar(glyph, a, b)

    for i in range(label_offset + 1):
        x = 34.0 + i * 2.6
        _bar(glyph, (x, 38.0), (x, 62.0))


def features(script: Script) -> str:
    """Everything ufo2ft's writers do not produce for us.

    They generate `mark` from the anchors, which is the whole of normal
    rendering. What they cannot know is which sequences are illegal, so that
    part is written here and generated from the model.
    """
    consonants = " ".join(c.glyph for c in script.consonants)
    vowels = " ".join(v.glyph for v in script.vowels)
    inserts = "\n".join(f"    sub {v.glyph} by dottedcircle {v.glyph};" for v in script.vowels)

    return f"""\
# Generated by tools/build_ufo.py. Do not edit; edit the generator.
#
# ufo2ft writes the `mark` feature itself, from the anchors in the UFO, so it
# is deliberately absent here. This file covers only the case the anchors
# cannot express: a vowel with no consonant to attach to.

@consonant = [{consonants}];
@vowel = [{vowels}];

# A vowel is a zero-width mark. Orphaned, it does not fail: it silently piles
# onto whatever glyph happens to precede it, so `na` + a stray `e` renders as
# two vowels stacked on one consonant with no hint that anything is wrong.
#
# Complex-script shapers insert U+25CC around an orphaned mark automatically.
# The default shaper, which is all an unencoded script gets, does not. So the
# font inserts it: one glyph becomes two, and the vowel gets something legal
# to sit on.
lookup orphan_vowel {{
{inserts}
}} orphan_vowel;

feature ccmp {{
    # Everything a consonant introduces is well formed; leave it alone.
    ignore sub @consonant @vowel';

    # Anything else reaching a vowel means no onset, which this language
    # does not have.
    sub @vowel' lookup orphan_vowel;
}} ccmp;
"""


def build(script: Script, out: Path) -> ufoLib2.Font:
    font = ufoLib2.Font()
    info = font.info
    info.familyName = "Ronesathwasha"
    info.styleName = "Regular"
    info.unitsPerEm = UPM
    info.ascender = 750
    info.descender = -250
    info.capHeight = 440
    info.xHeight = 440
    info.versionMajor = 0
    info.versionMinor = 1

    # Set all three metric families by hand and turn on USE_TYPO_METRICS.
    # Left alone, hhea says one thing and OS/2 says another, and the platforms
    # disagree about line height: macOS reads hhea, Windows reads OS/2 and
    # picks win or typo depending on this very bit. Same numbers everywhere,
    # bit set, no argument.
    info.openTypeHheaAscender = info.ascender
    info.openTypeHheaDescender = info.descender
    info.openTypeHheaLineGap = 0
    info.openTypeOS2TypoAscender = info.ascender
    info.openTypeOS2TypoDescender = info.descender
    info.openTypeOS2TypoLineGap = 0
    info.openTypeOS2WinAscent = info.ascender
    info.openTypeOS2WinDescent = -info.descender
    info.openTypeOS2Selection = [7]

    notdef = font.newGlyph(".notdef")
    notdef.width = ADVANCE
    draw_placeholder(notdef, 0)

    # A font with no space renders the commonest character in any text as
    # tofu, or hands it to whatever fallback font the system picks, which is
    # then also choosing its width.
    space = font.newGlyph("space")
    space.width = ADVANCE // 2
    space.unicode = 0x0020

    # Reached only by the ccmp rule, so it needs a code point of its own only
    # so the glyph is addressable; nothing types it.
    ring = font.newGlyph("dottedcircle")
    ring.width = ADVANCE
    ring.unicode = 0x25CC
    draw_dotted_circle(ring)
    # It needs the consonant's anchor, or the orphan it was inserted for sails
    # straight past it and lands on the next glyph instead. Standing in for a
    # missing base is the entire job.
    ring.appendAnchor({"name": "vowel", "x": 0, "y": 0})

    order = [".notdef", "space", "dottedcircle"]
    categories: dict[str, str] = {"space": "base", "dottedcircle": "base"}

    for c in script.consonants:
        g = font.newGlyph(c.glyph)
        g.width = ADVANCE
        g.unicode = script.codepoint(c)
        draw_placeholder(g, c.offset)
        # One anchor, at the origin. Every vowel is drawn in the consonant's own
        # coordinate space, so they all attach at the same point and a syllable
        # always occupies the same square.
        g.appendAnchor({"name": "vowel", "x": 0, "y": 0})
        order.append(c.glyph)
        categories[c.glyph] = "base"

    for v in script.vowels:
        g = font.newGlyph(v.glyph)
        g.width = 0  # a mark advances nothing; the consonant owns the width
        g.unicode = script.codepoint(v)
        if v.direction is Direction.CENTRE:
            draw_ring(g)
        else:
            draw_chevron(g, v.direction)

        if v.glide:
            draw_tick(g, v.direction)

        g.appendAnchor({"name": "_vowel", "x": 0, "y": 0})
        order.append(v.glyph)
        categories[v.glyph] = "mark"

    font.features.text = features(script)
    font.lib["public.glyphOrder"] = order
    font.lib["public.openTypeCategories"] = categories

    if out.exists():
        shutil.rmtree(out)

    out.parent.mkdir(parents=True, exist_ok=True)
    font.save(out)
    return font


def main() -> None:
    script = load()
    out = Path(__file__).resolve().parent.parent / "sources" / "Ronesathwasha.ufo"
    font = build(script, out)
    marks = sum(1 for g in font if g.width == 0)
    print(f"{out.relative_to(Path.cwd())}: {len(font)} glyphs, {marks} marks")
    print(f"  consonants U+{script.consonant_base:04X}.."
          f"U+{script.consonant_base + len(script.consonants) - 1:04X} (placeholder boxes)")
    print(f"  vowels     {len(script.vowels)} derived outlines")


if __name__ == "__main__":
    main()
