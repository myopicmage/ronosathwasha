# Glossary

Font and typography terms as they're used in this repo. Ordered roughly by when
you meet them, not alphabetically. Terms get added here the first time they're
used in the work.

## Characters and glyphs

**Character**: an abstract unit of text with a code point. `U+E000` is a
character. It has no shape.

**Glyph**: a drawn shape in a font. `c_m` is a glyph. It has no meaning.

The distinction does real work: one character can render as different glyphs in
different contexts, and one glyph can serve several characters. Everything
before shaping deals in characters; everything after deals in glyphs.

**Code point**: a character's number. Written `U+E000`.

**cmap**: the table inside a font that maps code points to glyphs. It is the
only bridge between the two worlds, and it is one-directional.

**.notdef**: the glyph a font renders for a character it has no glyph for.
Conventionally an empty or crossed box. This is the "tofu" you see for missing
characters, and it is drawn by *whatever font gets used*, not by the font that
lacked the character.

**AGL**: Adobe Glyph List. A convention mapping glyph *names* to code points,
so a glyph named `m` is assumed to mean U+006D. It's why our glyphs are named
`c_m` and `v_i`: the prefix opts out of the guess.

## Drawing

**UFO**: Unified Font Object. The source format: a directory of XML files, one
per glyph, that diffs and merges like code. The opposite of a binary `.ttf`.

**GLIF**: the per-glyph XML file inside a UFO.

**Contour**: one closed path inside a glyph. A glyph is a set of contours.

**Winding direction**: which way round a contour is drawn. It decides fill
versus hole: a ring is an outer contour one way and an inner contour the other.
Fonts fill by the *nonzero* rule, so two contours wound the same way that
overlap simply merge, which is why a chevron can be two overlapping bars.

**Component**: a glyph that references another glyph instead of copying its
outline, optionally transformed. Draw the shape once, use it in ten places, fix
it in one. The font equivalent of a symbol in a vector editor.

**Centreline**: the path down the middle of a stroke, as opposed to the
outline around it. This script is drawn with a pen, so its sources are
centrelines and its outlines are derived.

**Stroke expansion**: turning a centreline plus a nib width into a filled
outline. A stroke has a width and no inside; a glyph has an inside and no
width, and something has to convert. `skia-pathops` does it here.

**Quadratic vs cubic**: the two curve types. TrueType stores quadratics (one
control point), PostScript and UFO sources use cubics (two). A quadratic
converts to a cubic exactly; the other direction is an approximation, which is
why sources are cubic and the conversion happens on export.

**Conic**: a rational quadratic: a quadratic with a weight, able to describe a
true circular arc, which neither plain quadratics nor cubics can do exactly.
Skia's stroker emits them for round caps and joins. Nothing in the font world
reads them, so they have to be converted on the way out.

**em** and **units per em (UPM)**: the coordinate grid a glyph is drawn on,
independent of any real-world size. This font uses 1000. Point size scales the
em; the numbers inside never change.

**Baseline**: y = 0. The line letters sit on.

**Ascender / descender**: how far above and below the baseline the design
reaches. Here 750 and −250, which fills the 1000-unit em.

**Advance width**: how far the drawing pen moves right after setting a glyph.
Not the width of the ink: the width of the ink *plus its side bearings*.

**Side bearing**: the gap between a glyph's ink and the edges of its advance.
Left and right. A **mark** has an advance of zero, so it takes up no space and
whatever follows lands in the same place.

## Turning text into type

**Shaping**: the process that turns a sequence of code points into a sequence
of positioned glyphs. Substitution, reordering, and positioning all happen here.

**Shaper**: the engine that does it. HarfBuzz (Linux, Chrome, Android),
CoreText (Apple), DirectWrite (Windows). They mostly agree. Mostly.

**Cluster**: the number a shaper attaches to each output glyph, saying which
input character it came from. It survives substitution, which is how a text
editor still knows where to put the cursor after two characters became one
glyph.

**hb-shape**: HarfBuzz's command line shaper. Prints exactly what a font does
to a string:

    [c_r=0+1000|v_o=1@-1000,0+0]
     └glyph  └cluster └offset  └advance

## OpenType layout

**OpenType feature**: a named bundle of rules, identified by a four-character
tag. The shaper decides which features to run; the font decides what they do.

**GSUB**: Glyph Substitution table. Rules that replace glyphs with other
glyphs. Ligatures live here.

**GPOS**: Glyph Positioning table. Rules that *move* glyphs without changing
which ones they are. Kerning and mark attachment live here.

**GDEF**: Glyph Definition table. Declares what kind of thing each glyph is:
base, ligature, mark, or component. Everything else relies on it; if a mark
isn't declared as a mark, positioning quietly misbehaves.

**Base**: a glyph that other glyphs attach to. Our consonants.

**Mark**: a zero-advance glyph that attaches to a base rather than sitting
beside it. Our vowels.

**Anchor**: a named point on a glyph used for attachment. A base carries
`vowel`; a mark carries `_vowel`. The underscore is the convention for "this is
the mark's side of the join".

**Mark class**: a set of marks that all attach to the same named anchor.

**mark** (the feature): the GPOS feature that attaches marks to bases. It works
by matching a base's anchor to a mark's anchor and moving the mark so they
coincide.

**mkmk**: mark-to-mark attachment, for a mark riding on another mark. Not used
here: our glide tick is part of the vowel's own outline.

**ccmp**: glyph composition and decomposition. Runs before everything else,
and can split one glyph into several or fuse several into one. Not used here
either, for the same reason.

**.fea / feature file**: the source language for OpenType features, from the
Adobe Font Development Kit. Compiled into GSUB and GPOS.

**Feature writer**: a tool that generates feature code from the source instead
of you hand-writing it. ufo2ft has writers for `mark`, `mkmk` and `kern`, and
skips any feature the source already defines.

**Lookup**: one rule set inside GSUB or GPOS. Features don't contain rules;
they contain references to lookups, in order. The indirection lets several
features share one lookup, and lets a contextual rule invoke another lookup at
a matched position.

**Glyph class**: a named set of glyphs, written `@vowel = [v_i v_u ...]`. Rules
match against the class rather than listing members.

**Contextual substitution**: a rule that fires only when its neighbours match.
Written with a prime: `sub @vowel' by X` means *substitute the vowel*, and
anything unprimed is context that must be present but is left alone.

**`ignore sub`**: declares a context where a later rule must *not* fire.
Listed before the general rule, since lookups match in order and stop at the
first hit. It's how you say "unless", which the syntax otherwise can't express.

**Dotted circle (U+25CC)**: the ring of dots conventionally shown around a
combining mark that has nothing to attach to. Shapers insert it automatically
for scripts they know about. For an unencoded script they don't, so the font
does it itself.

## Vertical metrics

Three separate sets of numbers claim to say how tall the font is, and different
platforms believe different ones. Getting them to disagree is the classic way to
ship a font whose line spacing changes between macOS and Windows.

**hhea ascender / descender / lineGap**: the original TrueType metrics. What
macOS reads.

**OS/2 sTypo ascender / descender / lineGap**: the typographic metrics, meant
to express design intent.

**OS/2 usWin ascent / descent**: a clipping box, historically. Always positive
numbers, even the descent.

**USE_TYPO_METRICS**: bit 7 of the OS/2 `fsSelection` field. Set it and
everything is told to use the sTypo numbers, which is the only way to make all
three agree in practice. Set all three families to the same values and turn this
on; that's what Google Fonts requires and there's no reason to do otherwise.

## Input

**Dead key**: a key that emits nothing and changes what the *next* key does.
The `´` on a French layout is one: press it, nothing appears, press `e` and you
get `é`. Standard on every platform, and a natural fit for a syllabary, where
one glyph is two keystrokes by definition.

**`.keylayout`**: macOS's keyboard layout format. XML describing a state
machine: which physical key produces which action, and what each action does in
each state. Lives in `~/Library/Keyboard Layouts/`.

**Virtual key code**: the number identifying a physical key position,
independent of what's printed on it. `0` is where `a` sits on a US keyboard.

**Terminator**: what a dead key emits if it's abandoned instead of completed.

**IME (Input Method Editor)**: the heavier alternative: a running program that
buffers keystrokes, shows candidates, and commits text. What Japanese and
Chinese input need. A dead-key layout needs no process, no UI and no signing.

## Tools

**fontTools**: the Python library underneath everything. Reads and writes every
font format.

**ufoLib2**: reads and writes UFO sources as Python objects.

**ufo2ft**: compiles a UFO into a binary font, running filters and feature
writers on the way.

**fontmake**: the command-line front end that orchestrates the above. The
Google Fonts pipeline.

**TTF vs OTF**: two flavours of the same container. TTF stores outlines as
quadratic curves, OTF as cubic. fontmake converts as needed; the choice barely
matters for a script like this one.

**PUA**: Private Use Area. Ranges of Unicode permanently left unassigned, so
anyone may use them privately. Three ranges; we use U+E000–U+F8FF. A PUA
character has no script, no properties, and no meaning outside an agreement
between a font and whoever installed it.
