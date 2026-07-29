# Glossary

Terms of art as they're used in this repo, ordered roughly by when you meet
them rather than alphabetically. Terms get added here the first time they're
used in the work.

Most of it is font and typography, which is where the unfamiliar vocabulary
mostly lives. **Language construction** at the end is a separate vocabulary
that arrived later, and is kept separate because the two rarely meet: a
question about a mark class is never also a question about an auxlang.

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

**Precomposed**: one code point standing for a whole combination. Latin `é` is
U+00E9, a single character with the accent already in it.

**Decomposed**: the same text as a base plus separate combining characters. `é`
again, as U+0065 `e` followed by U+0301 combining acute.

Both are legal and both mean the same letter, which is the whole problem. The
tradeoff is combinatorial: precomposed is trivial to shape and to compare, and
costs a code point for every combination, so N independent features want 2^N
characters. Decomposed stays linear at one character per feature and pays in
mark positioning rules.

We make the cut in one place: **the syllable is decomposed, everything below it
is precomposed.** A syllable is two code points, a consonant then a vowel, and
the vowel is a zero-width mark that the `mark` feature attaches to the consonant
from the UFO anchors. We do not encode 132 syllable characters.

Below that line nothing decomposes. Voicing, place and labialisation are already
inside their code points: `v_wa` is one character, not `v_a` plus a glide mark,
and `c_r` is one character, not `c_l` plus a crossbar. The `mk_stem`,
`mk_crossbar` and `mk_glide` entries in `data/script.toml` describe how a glyph
is *drawn* from its relative, which is derivation at build time and says nothing
about encoding.

Hangul is the same choice made twice. Unicode encodes Korean both ways: 11,172
precomposed syllable blocks and a set of conjoining jamo that compose at render
time. We took the jamo route, for the reason above: 11 + 12 code points instead
of 132, and a keyboard that can refuse an illegal pair because it can still see
two units.

The cost of the line being where it is: any new vowel feature multiplies the
vowel run rather than adding to it. Encoding length as a precomposed vowel takes
12 vowels to 24. Encoding it as a combining mark leaves 12 and adds one.

**Length took a third option this paragraph did not consider**, and the
paragraph is kept because being shown the option you missed is the useful part.
Decision 20 writes a long vowel as the vowel's own mark twice, which adds no
code point at all. Japanese does this and it is why: `おばあさん` is five kana
and the length is its own あ, so nothing ever goes back to modify a character
already written.

The price is paid on the other side of the line. **A syllable is no longer
always two code points**; a long one is three, and the second mark attaches to
the first rather than to the consonant, which needs `mkmk` as well as `mark`.
That is more decomposition rather than less, so it moves the same way the line
already leans.

**Normalisation (NFC / NFD)**: Unicode's rules for converting between the two,
so text that means the same thing compares equal. NFC composes wherever a
precomposed character exists, NFD decomposes. Operating systems, editors and
file systems apply it constantly and invisibly, which is why encoded scripts can
mostly ignore the distinction.

It does nothing for us. Normalisation works from Unicode's own decomposition
data, and a PUA code point has none, so nothing will ever relate `c_n` `v_a` to
a single character or tell anyone the pair belongs together. Every equivalence
our script has is one we assert ourselves, in the font and in the keyboard. It
is the clearest single case of what the Private Use Area leaves us to do alone.

Worth knowing despite the name: our `ccmp` feature composes and decomposes
nothing. It inserts a dotted circle around a vowel that has no consonant to sit
on, which is the one illegal sequence the anchors cannot express.

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

## Variable fonts

**Variable font**: one font file that contains a continuous range of designs
rather than a single one. Added in OpenType 1.8 (2016). Everything it adds sits
on the glyph side of the `cmap`, so it changes no code points, no shaping logic
and no keyboard: only the outlines and metrics that come out the other end.

**Axis**: one dimension of that range, named by a four-character tag. `wght` for
weight, `wdth` for width, `opsz` for optical size. An axis has a minimum,
maximum and default.

**`opsz` (optical size)**: the axis for drawing differently at different sizes,
which is the old metal-type practice made continuous. A 6pt cut was never a
shrunk 12pt cut: it had thicker strokes, looser spacing and less fine detail.
Unlike every other axis, `opsz` is applied *automatically* by the renderer from
the point size. CoreText will use it without being asked.

**`fvar`**: the table declaring the axes and the named instances. **`gvar`**:
the per-glyph outline deltas that do the actual interpolating. `HVAR` does the
same for advance widths, and `GDEF`'s variation store does it for anchors, so
mark attachment can move along an axis too.

**Master**: one of the designs the font interpolates between, drawn at an
extreme of an axis. One UFO each.

**Designspace**: the `.designspace` file naming the axes and saying where each
master sits on them. fontmake reads it and produces the variable font.

**Interpolation compatibility**: the constraint that makes all of it work. Every
master's version of a glyph must have the same number of contours, in the same
order, with the same number of points, of the same on-curve and off-curve types,
in the same order. Miss any of that and the glyph cannot interpolate, because
there is nothing to interpolate *between*.

This is the whole difficulty for a generated font like ours. We draw centrelines
and stroke them with a nib, and a stroke is a boolean operation whose output
topology depends on its input geometry, so two masters at different nib widths
do not automatically agree. Measured on this repo, at nibs of 4.6 and 7.4
specimen units:

| pipeline | glyphs that interpolate |
|---|---|
| as shipped | 14 of 26 |
| without `path.simplify()` | 22 of 26 |

`simplify()` is the union that merges crossing strokes into one outline. It is
also what makes the topology depend on the geometry, so it accounts for most of
the incompatibility. Dropping it is not a hack: **variable fonts conventionally
ship with overlapping contours**, because a boolean operation cannot be applied
to an outline that has not been interpolated yet. Nonzero winding renders the
overlaps correctly.

What survives that is `c_th`, and `c_dh` because it derives from it. Its
centrelines cross, and the stroker's own self-intersection handling changes with
width before `simplify()` ever runs. The two remaining failures are contour
*order*, which pathops does not promise to keep stable and a deterministic sort
would fix.

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

## On the web

**`@font-face`**: the CSS rule that declares a font for a page and says where to
fetch it. Without one, a page can only name fonts the reader already has.

**WOFF / WOFF2**: Web Open Font Format. A wrapper around an ordinary font with
the tables compressed. WOFF1 (2012) uses zlib; WOFF2 (2018) transforms `glyf`
and `loca` into a more compressible form and then compresses the lot with
**Brotli**, which is why writing one needs a Brotli implementation. Roughly half
the size of the TTF it wraps.

**Font fallback**: what a renderer does when the first font in the list has no
glyph for a character: it walks down the list, then to the system fonts, and
draws tofu only if every one of them fails. Ordinary and invisible for real
scripts. For a PUA character it is a hazard, because a fallback font may well
*have* a glyph at that code point, and will then confidently draw somebody
else's letter instead of failing.

**Embedding a font as a `data:` URI**: putting the font bytes into the CSS
itself, base64-encoded, instead of linking a file. Makes a page one
self-contained file. For an encoded script this is a size tradeoff; for a PUA
script it is the only way the page means anything on someone else's machine.

## Language construction

**Conlang**: a constructed language. One somebody designed, as against a
natural language that nobody did. The three categories below are the community's
usual division, and they name what a conlang is *for* rather than what it looks
like.

**Auxlang**: an auxiliary language, in full an international auxiliary language.
Built so that people with different native languages can talk to each other, and
meant to be everyone's second language and nobody's first. Optimised for ease of
learning: a small sound inventory, regular morphology, no irregular verbs, and
syllable shapes most people can already produce. Esperanto is the famous one;
Interlingua, Ido and Lingua Franca Nova are others.

**Artlang**: an artistic language, built for aesthetic or fictional purposes.
Tolkien's Quenya, Klingon, Dothraki. Optimised for beauty, character, or fit to
an invented culture, and irregularity is a feature here rather than a defect,
because real languages have it.

**Engelang**: an engineered language, built to test a hypothesis or satisfy a
formal constraint. Lojban goes for syntactic unambiguity, Toki Pona for radical
minimalism, Ithkuil for maximal precision. Optimised for the constraint, usually
at the cost of being comfortably speakable.

Ronosathwasha is an **artlang by construction and an auxlang by fiction**. The
decisions in `LANGUAGE.md` are made on artlang criteria: decision 1 drops the
affricates for fluidity and alienness, decision 3 gives negation anti-harmony
partly because the morpheme that contradicts should be the one that refuses to
agree. In the world it belongs to, it was built as an auxlang, to let speakers
of different languages communicate.

That gap is deliberate and worth keeping. A standards body that set out to build
an auxlang and produced something optimised for how it sounded is a very
ordinary committee, and it is roughly what happened to Esperanto.

**Phonestheme**: a sound associated with a family of meanings without being a
morpheme. English *gl-* in *glow*, *glint*, *gleam*, *glisten*. Speakers feel
the connection, but *gl-* has no meaning of its own and attaching it to a root
does not reliably make a word about light. Decision 13 uses this for the
recurring `-ya` in the cognitive vocabulary.

**Vowel harmony**: a rule requiring the vowels within some domain, usually the
word, to agree on a feature. Finnish, Turkish and Hungarian all have it. Here
the feature is backness and the domain is the phonological word, so a word's
vowels are all front or all back, with the two central vowels transparent
because they have no backness to agree about.

**Anti-harmony**: a morpheme that takes the opposite class to its host rather
than agreeing with it. Rare, and here it belongs to the negator alone.

**Deixis**: pointing with language. Words whose reference depends on the
situation rather than on their content: *this*, *that*, *here*, *now*, *you*.
Ronosathwasha's `she`, `sha` and `sho` are the spatial series, and decision 9
puts them on front, central and back vowels so the distance is readable from the
vowel.

**Pro-drop**: a language that lets you omit a pronoun the context supplies.
Spanish, Japanese and Italian do it; English mostly does not. Four of the
fourteen current examples here drop the subject, which is why decision 17
declines to make sentence-initial position grammatically meaningful.

**Agglutinative**: building words by stacking separable affixes, each carrying
one piece of meaning, without fusing them. `lumedororothwamo` is five morphemes
in a row and every boundary is findable. The opposite is fusional, where one
ending carries several meanings at once, as Latin's `-ō` carries first person,
singular, present, active and indicative together.
