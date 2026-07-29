"""Generate the UFO from the declaration and the centrelines.

Every glyph in this font is a path traced with one nib, so every glyph is built
the same way: assemble a centreline, transform it into font space, stroke it,
draw the result. Consonants come from `sources/strokes.py`; vowel marks are
derived from the model, because a chevron is a bearing plus two arm lengths and
the model already knows the bearing.

Coordinates: the specimen box is 100x100 with y pointing down. Fonts point y up
and put the baseline at zero. That conversion happens once, in `TRANSFORM`.
"""

from __future__ import annotations

import math
import shutil
from pathlib import Path

import pathops
import ufoLib2
from fontTools.pens.qu2cuPen import Qu2CuPen
from fontTools.pens.transformPen import TransformPen
from fontTools.svgLib.path import parse_path
from fontTools.misc.transform import Transform
from ufoLib2.objects import Glyph

from ronesathwasha import Direction, Script, load
from sources.strokes import CONSONANTS, PEN

UPM = 1000
BASELINE = 74.0  # in specimen units: where y=0 falls
SCALE = 10.0
ADVANCE = 1000  # every syllable occupies the same square, Hangul style

# Specimen space to font space: scale up, flip y, sit on the baseline.
TRANSFORM = Transform(SCALE, 0, 0, -SCALE, 0, BASELINE * SCALE)
NIB = PEN * SCALE

CENTRE = (50.0, 50.0)
CHEVRON_REACH = 44.0
CHEVRON_ARM = 22.0
TICK_REACH = 38.0
TICK_ARM = 11.0
RING_RADIUS = 34.0
KAPPA = 0.5522847498

# Decision 20: a long vowel is its mark written twice, so the second mark has to
# sit somewhere the first is not. It moves inward along the same bearing, which
# keeps the letter pointing where the vowel sits in the mouth and reads as one
# doubled mark rather than two crowded ones.
#
# The ring has no bearing to move along, and two rings at the same radius are
# one ring. It goes downward instead, which is the direction the schwa's glide
# tick already takes by convention for the same reason.
LENGTH_STEP = 8.0

# The ring is the one mark doubling cannot express by moving, because two rings
# of one radius in one place are one ring and a mark cannot draw a smaller copy
# of itself. So a doubled schwa substitutes *both* marks for a smaller variant
# and stacks them, which keeps a long vowel inside one mark's footprint instead
# of sprawling into two.
RING_LONG_RADIUS = 20.0
RING_LONG_STEP = 22.0
SCHWA_LONG = "v_schwa_long"


def ink(glyph: Glyph, centrelines: list[str]) -> None:
    """Trace the centrelines with the nib and draw what the nib covered.

    Stroking is why the source can stay a path. A stroke has a width and no
    inside; a glyph outline has an inside and no width, and something has to
    convert between them. skia-pathops does it, and it is already here as a
    dependency of ufo2ft, which uses it to remove overlaps.

    Round cap and round join because the script is drawn with a pen, and a pen
    has no corners.
    """
    path = pathops.Path()
    pen = TransformPen(path.getPen(), TRANSFORM)
    for centreline in centrelines:
        parse_path(centreline, pen)

    path.stroke(NIB, pathops.LineCap.ROUND_CAP, pathops.LineJoin.ROUND_JOIN, 4.0)
    # Round caps and joins come back as conics, Skia's rational quadratics.
    # Nothing downstream reads those: not simplify, not the UFO format, not
    # TrueType. Convert them to plain quadratics first.
    path.convertConicsToQuads()
    # Strokes that cross (t's chevrons, sh's crossbar) leave overlapping
    # contours. Union merges them into one outline with a single inside.
    path.simplify()
    # And back to cubics on the way into the UFO, which is conventionally
    # cubic. Not `all_cubic`: a round cap is a closed loop of curves with no
    # on-curve point anywhere on it, which cubics cannot express and
    # TrueType-flavoured quadratics can. Those few contours stay quadratic.
    path.draw(Qu2CuPen(glyph.getPen(), max_err=0.1))


def chevron(direction: Direction) -> list[str]:
    """A V pointing along the bearing, vertex outermost.

    The arms leave the vertex at 45 degrees either side of the way back to
    centre, which is what makes `e` a bare `<` and `i` a corner: one
    construction, rotated.
    """
    x, y = direction.value
    length = math.hypot(x, y)
    ux, uy = x / length, -y / length  # font y is up, specimen y is down
    vx, vy = CENTRE[0] + ux * CHEVRON_REACH, CENTRE[1] + uy * CHEVRON_REACH

    arms = []
    for sign in (+1, -1):
        angle = math.atan2(-uy, -ux) + sign * math.pi / 4
        arms.append(
            f"M{vx:.2f},{vy:.2f} "
            f"L{vx + math.cos(angle) * CHEVRON_ARM:.2f},"
            f"{vy + math.sin(angle) * CHEVRON_ARM:.2f}"
        )
    return arms


def length_anchor(direction: Direction) -> dict[str, float]:
    """Where the second copy of a mark goes, in font units.

    The offset is a delta rather than a position, because the mark it carries is
    drawn at the origin like every other: `mkmk` lands the second glyph's
    `_vowel` on this point, translating the whole shape by it.

    Specimen space has y downward and font space has it upward, so the y
    component flips on the way out. Everything else in this file goes through
    `TRANSFORM` for that; an anchor is a single point and does it directly.
    """
    x, y = direction.value

    if (x, y) == (0, 0):
        # A ring, with no bearing. Downward, matching the glide tick's own
        # convention for the same vowel.
        return {"x": 0.0, "y": -RING_LONG_STEP * SCALE}

    length = math.hypot(x, y)
    ux, uy = x / length, -y / length

    return {"x": -ux * LENGTH_STEP * SCALE, "y": uy * LENGTH_STEP * SCALE}


def tick(direction: Direction) -> list[str]:
    """The glide tick: a short bar at the chevron's tail, across the bearing.

    A ring has no tail, so the schwa's tick is placed by convention, straight
    down. That case is the model telling us CENTRE is its own opposite.
    """
    tail = direction.opposite
    if tail is Direction.CENTRE:
        ux, uy, reach = 0.0, 1.0, RING_RADIUS + 12.0
    else:
        x, y = tail.value
        length = math.hypot(x, y)
        ux, uy, reach = x / length, -y / length, TICK_REACH

    cx, cy = CENTRE[0] + ux * reach, CENTRE[1] + uy * reach
    px, py = -uy, ux  # perpendicular, so the tick crosses the bearing
    return [
        f"M{cx - px * TICK_ARM:.2f},{cy - py * TICK_ARM:.2f} "
        f"L{cx + px * TICK_ARM:.2f},{cy + py * TICK_ARM:.2f}"
    ]


def circle(cx: float, cy: float, r: float) -> str:
    """A closed circle as four cubics. Stroked, so this is a centreline too."""
    k = r * KAPPA
    return (
        f"M{cx - r:.2f},{cy:.2f} "
        f"C{cx - r:.2f},{cy - k:.2f} {cx - k:.2f},{cy - r:.2f} {cx:.2f},{cy - r:.2f} "
        f"C{cx + k:.2f},{cy - r:.2f} {cx + r:.2f},{cy - k:.2f} {cx + r:.2f},{cy:.2f} "
        f"C{cx + r:.2f},{cy + k:.2f} {cx + k:.2f},{cy + r:.2f} {cx:.2f},{cy + r:.2f} "
        f"C{cx - k:.2f},{cy + r:.2f} {cx - r:.2f},{cy + k:.2f} {cx - r:.2f},{cy:.2f} Z"
    )


def dotted_circle() -> list[str]:
    """U+25CC, the ring of dots shown around an orphaned mark.

    Complex-script shapers insert this themselves. The default shaper, which is
    all an unencoded script gets, does not, so the font's ccmp rule does.
    """
    return [
        circle(CENTRE[0] + math.cos(i * math.tau / 12) * 26.0,
               CENTRE[1] + math.sin(i * math.tau / 12) * 26.0,
               1.2)
        for i in range(12)
    ]


def features(script: Script) -> str:
    """Everything ufo2ft's writers do not produce for us.

    They generate `mark` from the anchors, which is the whole of normal
    rendering. What they cannot know is which sequences are illegal, so that
    part is written here and generated from the model.
    """
    consonants = " ".join(c.glyph for c in script.consonants)
    vowels = " ".join(v.glyph for v in script.vowels)
    inserts = "\n".join(f"    sub {v.glyph} by dottedcircle {v.glyph};" for v in script.vowels)

    # Decision 20: a long vowel is the mark twice, so a vowel after a vowel is
    # now legal. Written out per vowel rather than as `@vowel @vowel'`, because
    # only a repetition is a word: `thii` is one, `thie` is not, and the loose
    # rule would render both without complaint.
    #
    # The second mark is always the plain vowel. A long glide is the glide mark
    # then the plain one, matching the romanisation `waa`, because the
    # labialisation happens once at the start and the vowel is what continues.
    schwa = next(v for v in script.vowels if v.direction is Direction.CENTRE and not v.glide)

    plain = {v.roman: v for v in script.vowels if not v.glide}
    lengths = "\n".join(
        f"    ignore sub {before.glyph} {plain[roman].glyph}';"
        for roman, short in plain.items()
        for before in (short, *(g for g in script.vowels
                                if g.glide and g.roman == f"w{roman}"))
    )

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

# A ring cannot nest inside itself the way a chevron nests inside itself, so a
# long schwa shrinks both of its marks instead and stacks them. One substitution
# applied twice, in context, because a rule cannot rewrite two glyphs at once.
lookup shrink_schwa {{
    sub {schwa.glyph} by {SCHWA_LONG};
}} shrink_schwa;

feature ccmp {{
    # The long schwa comes first, because everything below it is an `ignore` and
    # an ignore that matches stops the rules after it from being tried. Put
    # after them, this never fires: `ignore sub @consonant @vowel'` claims the
    # first mark of `thəə` before anything can shrink it.
    #
    # The first rule catches the leading mark; the second catches the trailing
    # one, by which point the leader has already changed and can be matched on.
    sub {schwa.glyph}' lookup shrink_schwa {schwa.glyph};
    sub {SCHWA_LONG} {schwa.glyph}' lookup shrink_schwa;

    # Everything a consonant introduces is well formed; leave it alone.
    ignore sub @consonant @vowel';

    # So is a vowel repeated after itself, which is how length is written. Each
    # pair is named: a vowel after a *different* vowel is still an error.
{lengths}

    # Anything else reaching a vowel means no onset, which this language
    # does not have.
    sub @vowel' lookup orphan_vowel;
}} ccmp;
"""


def build(script: Script, out: Path) -> ufoLib2.Font:
    missing = [c.glyph for c in script.consonants if c.glyph not in CONSONANTS]
    if missing:
        raise ValueError(f"no centrelines drawn for: {', '.join(missing)}")

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
    # Shown by font editors when the UFO is opened, which is the moment someone
    # is about to lose work by editing it.
    info.note = (
        "GENERATED by tools/build_ufo.py and overwritten on every build. "
        "Edit sources/strokes.py for the letterforms and data/script.toml for "
        "the inventory. Changes made here will not survive a rebuild, and "
        "pytest will fail the moment they exist."
    )

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
    ink(notdef, ["M30,30 L70,30 L70,70 L30,70 Z", "M30,30 L70,70"])

    # A font with no space renders the commonest character in any text as
    # tofu, or hands it to whatever fallback font the system picks, which is
    # then also choosing its width.
    space = font.newGlyph("space")
    space.width = ADVANCE // 2
    space.unicode = 0x0020

    ring = font.newGlyph("dottedcircle")
    ring.width = ADVANCE
    ring.unicode = 0x25CC
    ink(ring, dotted_circle())
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
        ink(g, CONSONANTS[c.glyph])
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
            centrelines = [circle(*CENTRE, RING_RADIUS)]
        else:
            centrelines = chevron(v.direction)

        if v.glide:
            centrelines += tick(v.direction)

        ink(g, centrelines)

        # `_vowel` attaches this mark to a consonant; `vowel` is where the next
        # mark attaches to this one, which is what makes `mkmk` possible and so
        # what makes a long vowel two code points rather than a new letter.
        g.appendAnchor({"name": "_vowel", "x": 0, "y": 0})
        g.appendAnchor({"name": "vowel", **length_anchor(v.direction)})
        order.append(v.glyph)
        categories[v.glyph] = "mark"

        # The schwa's long variant: a smaller ring, substituted in for both
        # marks when one follows the other. No code point, because it is not a
        # letter; `ccmp` is the only thing that can produce it.
        if v.direction is Direction.CENTRE and not v.glide:
            small = font.newGlyph(SCHWA_LONG)
            small.width = 0
            ink(small, [circle(*CENTRE, RING_LONG_RADIUS)])
            small.appendAnchor({"name": "_vowel", "x": 0, "y": 0})
            small.appendAnchor(
                {"name": "vowel", "x": 0.0, "y": -RING_LONG_STEP * SCALE}
            )
            order.append(SCHWA_LONG)
            categories[SCHWA_LONG] = "mark"

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
    contours = sum(len(g.contours) for g in font)
    print(f"{out.relative_to(Path.cwd())}: {len(font)} glyphs, {contours} contours")
    print(f"  every glyph stroked at a {NIB:.0f}-unit nib, round cap and join")


if __name__ == "__main__":
    main()
