"""The whole syllabary on one page, for looking at.

    python3 -m tools.build_syllabary        -> build/syllabary.html

A specimen sheet: every syllable the script can write, laid out so the
letterforms can be compared against each other rather than read. Type design
calls this a specimen, and it is the artefact a redraw is judged against.

Generated rather than hand-written, for the reason `build_dictionary.py` gives.
The syllabary is the Cartesian product of two lists that live in
`data/script.toml`, so writing it out by hand would put a second copy of the
inventory in a file nobody thinks to update. This one cannot go stale: it is
recomputed from the declaration on every build, and the font is compiled in this
same process so the page and the shapes it shows are the same vintage.

Four things the page adds beyond the grid, each answering a question that came
up while measuring:

- **Guides.** The em square with a crosshair through its centre and the band the
  consonants occupy, so "does this glyph sit in the middle with room for the
  chevrons" is a thing the eye checks rather than the caliper.
- **Sizes.** 23 and 34 are where the legibility arguments were made and where
  pairs stop being separable, so they are one click away rather than a zoom.
- **Length.** Both grids, swapped in place. The long forms are the tight case
  rather than a variant to note in passing: a doubled mark steps 11 inward along
  its bearing, so it is aimed at the space the consonant is already using. Every
  clearance figure taken off the short grid is the easy half of the problem.
- **Contrasts.** The derived pairs, side by side. Every one of them is a pair
  that a mark has to keep apart, and they are read off the `derivation` field
  rather than listed here, so a change to the derivation scheme moves them.
"""

from __future__ import annotations

import html
from collections.abc import Iterable
from pathlib import Path
from typing import Final

from ronosathwasha import Consonant, Script, Syllable, Vowel, load
from tools.webfont import compile_woff2, face, family

ROOT: Final = Path(__file__).resolve().parent.parent
OUT: Final = ROOT / "build" / "syllabary.html"

# Where the specimen box lands relative to the text baseline, as a fraction of
# the em. `tools/build_ufo.py` puts specimen y=0 at font y=740 with a 1000 unit
# em, so the box runs from 0.74em above the baseline to 0.26em below it. The
# font's ascender is 750, so a line box of exactly 1em puts its own top one
# hundredth of an em higher: that difference is the offset below, and without it
# every guide sits a hairline out.
BOX_DROP: Final = 0.01

# Where the consonants actually sit, in specimen units out of 100, as
# left/right/top/bottom. Measured off the compiled font across all eleven bare
# consonants rather than quoted: `SCRIPT.md` says "about 24 to 76", which was
# true when it was written and is now a unit and a half tight on each side.
#
# There is no second band for the vowels. Every one of the 132 syllables fits
# inside -0.3 and 100.3, so vowel ink now runs the full width of the square and
# the em box drawn below *is* the vowel boundary. That is also a change since
# `SCRIPT.md`, which puts the vowel reach at 6 and 94: moving the marks to the
# rim spent the whole margin, and there is no room left at the periphery.
CONSONANT_BAND: Final = (21.7, 78.3, 21.7, 77.3)

# The sizes worth a click. 23 and 34 are where `SCRIPT.md` made its arguments
# about pairs collapsing, and the large end is for drawing rather than reading.
SIZES: Final = (23, 34, 48, 64, 96, 144)
DEFAULT_SIZE: Final = 64


def refs(codepoints: Iterable[int]) -> str:
    """Code points as numeric character references.

    References rather than literal characters, the way `docs/` writes them: a
    private-use code point pasted into a source file is an invisible blob in
    every editor that does not have the font, and this file has to stay
    diffable.
    """
    return "".join(f"&#x{cp:04X};" for cp in codepoints)


def cell(script: Script, syllable: Syllable) -> str:
    """One syllable, short or long, encoded by the model rather than by hand.

    Both the code points and the label come from the `Syllable`, which is what
    keeps the `waa` rather than `wawa` rule out of this file. It lived here for a
    while and that was the wrong home: it is a fact about the language, and a page
    generator holding one means the rule has two places to be wrong in.
    """
    return (
        f'<span class="glyph" lang="x-rsw" translate="no"'
        f' title="{html.escape(syllable.roman)}">'
        f"{refs(script.encode([syllable]))}</span>"
    )


def grid(script: Script, *, long: bool = False) -> str:
    """Consonants down, vowels across, in the order `Script.syllables()` yields."""
    heads = "".join(
        f'<span class="col-head">'
        f"{html.escape(v.lengthened if long else v.roman)}</span>"
        for v in script.vowels
    )
    rows = "".join(
        f'<span class="row-head">{html.escape(c.roman)}'
        f'<i>{html.escape(c.ipa)}</i></span>'
        + "".join(cell(script, Syllable(c, v, long=long)) for v in script.vowels)
        for c in script.consonants
    )
    return f'<span class="corner"></span>{heads}{rows}'


def bare(script: Script, letters: tuple[Consonant | Vowel, ...]) -> str:
    """One letter per cell, with no partner.

    A consonant alone and a vowel alone are both legal to render and neither is
    a syllable, which is the point: this is the row where a base form is judged
    without a chevron sitting on top of it.
    """
    return "".join(
        f'<span class="base">'
        f'<span class="glyph" lang="x-rsw" translate="no">'
        f"{refs([script.codepoint(letter)])}</span>"
        f"<b>{html.escape(letter.roman)}</b></span>"
        for letter in letters
    )


def consonant_contrasts(script: Script) -> tuple[tuple[Consonant, Consonant], ...]:
    """Every pair a derivation has to keep apart, read off the declaration.

    Derived from `Consonant.derivation` rather than listed, so retiring a mark
    or deriving a new letter changes this page without anybody editing it.
    """
    by_glyph = {c.glyph: c for c in script.consonants}
    return tuple(
        (by_glyph[c.derivation.base], c)
        for c in script.consonants
        if c.derivation is not None and c.derivation.base in by_glyph
    )


def vowel_contrasts(script: Script) -> tuple[tuple[Vowel, Vowel], ...]:
    """The mirror pairs: same height, opposite backness, no glide.

    `SCRIPT.md` accepts these as a known cost of encoding backness as direction.
    Accepted is not the same as unwatched, so they get shown.

    Opposite backness, not merely different: schwa is mid and central, so it
    shares a height with both `e` and `o` and an ordering test pairs it with each
    of them. Neither is a reflection of anything, which is the property being
    looked at here, so the test is that the two backnesses cancel.
    """
    plain = [v for v in script.vowels if not v.glide]
    return tuple(
        (front, back)
        for front in plain
        for back in plain
        if front.height == back.height
        and front.backness.value == -back.backness.value
        and back.backness.value > 0
    )


def contrast(script: Script, pair: tuple[Consonant, Consonant] | tuple[Vowel, Vowel],
             partner: Consonant | Vowel) -> str:
    """One pair, bare and then carried by a neutral partner.

    Bare is where the mark is easiest to see and the least honest, because
    nothing is competing with it. The partnered pair is the real test: `SCRIPT.md`
    records the crossbar fusing into its host and a stem vanishing into a stroke
    the letter already had, and neither shows up on a letter standing alone.
    """
    left, right = pair
    both = f"{left.roman}/{right.roman}"

    def shown(letter: Consonant | Vowel) -> str:
        if isinstance(letter, Consonant) and isinstance(partner, Vowel):
            return refs(script.encode([Syllable(letter, partner)]))

        if isinstance(letter, Vowel) and isinstance(partner, Consonant):
            return refs(script.encode([Syllable(partner, letter)]))

        return refs([script.codepoint(letter)])

    return (
        f'<div class="contrast">'
        f"<h3>{html.escape(both)}</h3>"
        f'<div class="pair">'
        f'<span class="glyph" lang="x-rsw" translate="no">'
        f"{refs([script.codepoint(left)])}</span>"
        f'<span class="glyph" lang="x-rsw" translate="no">'
        f"{refs([script.codepoint(right)])}</span>"
        f"</div>"
        f'<div class="pair">'
        f'<span class="glyph" lang="x-rsw" translate="no">{shown(left)}</span>'
        f'<span class="glyph" lang="x-rsw" translate="no">{shown(right)}</span>'
        f"</div>"
        f"</div>"
    )


def contrasts(script: Script) -> str:
    """Consonant pairs against a central vowel, vowel pairs against the lightest host.

    `a` is central, so it favours neither member of a place contrast. `m` is a
    single bar, the sparsest consonant there is, so a vowel shown on it is
    competing with as little ink as the script can offer.
    """
    neutral = next(v for v in script.vowels if v.roman == "a")
    lightest = next(c for c in script.consonants if c.roman == "m")

    return "".join(
        [contrast(script, pair, neutral) for pair in consonant_contrasts(script)]
        + [contrast(script, pair, lightest) for pair in vowel_contrasts(script)]
    )


def lengths(script: Script) -> str:
    """Every vowel short over long, on the letter with the least room to spare.

    `d` is the worst host in the script: 28.3 sideways and 27.3 downward, the
    only glyph at the top of both rankings. A doubled mark steps 11 inward along
    its bearing, which puts its inner edge 27.63 from centre, so this row is
    where the second copy either clears the letter or does not.
    """
    host = next(c for c in script.consonants if c.roman == "d")
    heads = "".join(
        f'<span class="col-head">{html.escape(v.roman)}</span>' for v in script.vowels
    )
    rows = "".join(
        f'<span class="row-head">{label}</span>'
        + "".join(
            cell(script, Syllable(host, v, long=long)) for v in script.vowels
        )
        for label, long in (("short", False), ("long", True))
    )
    return f'<span class="corner"></span>{heads}{rows}'


def page(script: Script, woff2: bytes) -> str:
    buttons = "".join(
        f'<button type="button" data-size="{size}"'
        f'{" aria-pressed=\"true\"" if size == DEFAULT_SIZE else ""}>'
        f"{size}px</button>"
        for size in SIZES
    )
    return TEMPLATE.format(
        family=family(script),
        face=face(script, woff2),
        buttons=buttons,
        grid=grid(script),
        long_grid=grid(script, long=True),
        lengths=lengths(script),
        consonants=bare(script, script.consonants),
        vowels=bare(script, script.vowels),
        contrasts=contrasts(script),
        columns=len(script.vowels),
        count=len(script.consonants) * len(script.vowels),
        both=2 * len(script.consonants) * len(script.vowels),
        default=DEFAULT_SIZE,
        drop=BOX_DROP,
        band_left=CONSONANT_BAND[0],
        band_right=100 - CONSONANT_BAND[1],
        band_top=CONSONANT_BAND[2],
        band_bottom=100 - CONSONANT_BAND[3],
    )


def main() -> None:
    script = load()
    OUT.parent.mkdir(parents=True, exist_ok=True)

    woff2 = compile_woff2(script, OUT.parent)
    OUT.write_text(page(script, woff2), encoding="utf-8")

    syllables = len(script.consonants) * len(script.vowels)
    print(f"{OUT.relative_to(Path.cwd())}: {OUT.stat().st_size:,} bytes, "
          f"{syllables} syllables short and {syllables} long, "
          f"font {len(woff2):,} bytes")


TEMPLATE: Final = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ronosathwasha syllabary</title>
<style>
/* The font is the decoder, not a style. Without it the private-use code points
   below are unreadable, so it travels with the page rather than being linked. */
{face}

:root {{
  color-scheme: light dark;
  --bg: #fbfaf7;
  --panel: #ffffff;
  --ink: #1b1a17;
  --muted: #6b6558;
  --line: #e4e0d6;
  --accent: #8a5a2b;
  --guide: #c8422e;
  --glyph: {default}px;
}}
@media (prefers-color-scheme: dark) {{
  :root {{
    --bg: #16151a;
    --panel: #1e1d23;
    --ink: #ece9e3;
    --muted: #9a938a;
    --line: #302e37;
    --accent: #d9a066;
    --guide: #e2664e;
  }}
}}

* {{ box-sizing: border-box; }}

body {{
  margin: 0;
  padding: 2.5rem 1.5rem 5rem;
  background: var(--bg);
  color: var(--ink);
  font-family: Inter, ui-sans-serif, system-ui, -apple-system, sans-serif;
}}

.sheet {{ max-width: 78rem; margin: 0 auto; }}

h1 {{
  margin: 0 0 0.35rem;
  font-family: Georgia, "Times New Roman", serif;
  font-size: clamp(2rem, 5vw, 3rem);
  font-weight: 500;
  letter-spacing: -0.03em;
}}

.lede {{ margin: 0 0 2rem; max-width: 44rem; color: var(--muted); line-height: 1.6; }}

h2 {{
  margin: 3rem 0 0.25rem;
  font-size: 0.8rem;
  font-weight: 650;
  letter-spacing: 0.1em;
  text-transform: uppercase;
  color: var(--accent);
}}

.note {{ margin: 0 0 1.25rem; max-width: 44rem; color: var(--muted); font-size: 0.9rem; line-height: 1.55; }}

/* Sticky, because the whole point of a size button is comparing the same glyph
   at two sizes, and a control that scrolls away makes that a round trip. */
.controls {{
  position: sticky;
  top: 0;
  z-index: 2;
  display: flex;
  flex-wrap: wrap;
  gap: 0.4rem;
  align-items: center;
  margin-bottom: 1.5rem;
  padding: 0.75rem 0;
  background: var(--bg);
  border-bottom: 1px solid var(--line);
}}

button {{
  padding: 0.35rem 0.7rem;
  border: 1px solid var(--line);
  border-radius: 0.4rem;
  background: var(--panel);
  color: var(--ink);
  font: inherit;
  font-size: 0.85rem;
  cursor: pointer;
}}
button[aria-pressed="true"] {{ border-color: var(--accent); color: var(--accent); font-weight: 650; }}
.controls .spacer {{ flex: 1; }}

/* Every glyph on the page. One em of advance per syllable, because consonants
   carry the full 1000 and the vowels are zero-advance marks, so a box of 1em is
   exactly the square the letter was drawn in. */
.glyph {{
  display: inline-block;
  position: relative;
  width: 1em;
  font-family: "{family}";
  font-size: var(--glyph);
  font-feature-settings: "ccmp" 1, "mark" 1, "mkmk" 1;
  line-height: 1;
  text-align: left;
  white-space: nowrap;
}}

/* The specimen box, with a crosshair through the middle. Sizes are in em so they
   track the size buttons, and the box is nudged down by {drop}em because the
   font's ascender is 750 while the specimen box top is at 740.
   The crosshair is the whole point: "sits nicely in the middle" is a judgement
   the eye makes against a centre it can see, and off-centre by three units is
   invisible without one. */
body.guides .glyph::before {{
  content: "";
  position: absolute;
  left: 0;
  top: {drop}em;
  width: 1em;
  height: 1em;
  pointer-events: none;
  outline: 1px solid color-mix(in srgb, var(--guide) 40%, transparent);
  background:
    linear-gradient(to right, transparent calc(50% - 0.5px),
      color-mix(in srgb, var(--guide) 22%, transparent) calc(50% - 0.5px),
      color-mix(in srgb, var(--guide) 22%, transparent) calc(50% + 0.5px),
      transparent calc(50% + 0.5px)),
    linear-gradient(to bottom, transparent calc(50% - 0.5px),
      color-mix(in srgb, var(--guide) 22%, transparent) calc(50% - 0.5px),
      color-mix(in srgb, var(--guide) 22%, transparent) calc(50% + 0.5px),
      transparent calc(50% + 0.5px));
}}

/* Where the consonants live, measured rather than intended. No band is drawn for
   the vowels because they now reach the edge of the square, so the outline above
   is already theirs. */
body.guides .glyph::after {{
  content: "";
  position: absolute;
  left: {band_left}%;
  right: {band_right}%;
  top: calc({drop}em + {band_top}%);
  bottom: calc(-{drop}em + {band_bottom}%);
  pointer-events: none;
  border: 1px dashed color-mix(in srgb, var(--guide) 50%, transparent);
}}

/* The gap is in em of the glyph rather than rem, because vowel ink reaches both
   edges of the square: at a fixed 2px the neighbouring syllable's chevron is
   almost touching at 144px and comfortably clear at 23px, which is backwards. */
.grid {{
  display: grid;
  grid-template-columns: auto repeat({columns}, auto);
  gap: calc(var(--glyph) * 0.2);
  justify-content: start;
  align-items: center;
  overflow-x: auto;
  padding-bottom: 0.5rem;
}}

.corner {{ }}
.col-head, .row-head {{
  font-size: 0.7rem;
  font-weight: 650;
  letter-spacing: 0.04em;
  color: var(--muted);
  text-align: center;
}}
.row-head {{ padding-right: 0.6rem; text-align: right; white-space: nowrap; }}
.row-head i {{ display: block; font-weight: 400; opacity: 0.7; }}

.bases {{ display: flex; flex-wrap: wrap; gap: calc(var(--glyph) * 0.25); }}
.base {{ display: flex; flex-direction: column; align-items: center; gap: 0.2rem; }}
.base b {{ font-size: 0.7rem; font-weight: 650; color: var(--muted); }}

.contrasts {{
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(min(100%, 11rem), 1fr));
  gap: 1rem;
}}
.contrast {{
  padding: 0.9rem;
  border: 1px solid var(--line);
  border-radius: 0.6rem;
  background: var(--panel);
}}
.contrast h3 {{
  margin: 0 0 0.6rem;
  font-family: ui-monospace, SFMono-Regular, Consolas, monospace;
  font-size: 0.85rem;
  font-weight: 650;
  color: var(--accent);
}}
.pair {{ display: flex; gap: calc(var(--glyph) * 0.25); align-items: flex-end; }}
.pair + .pair {{ margin-top: 0.6rem; padding-top: 0.6rem; border-top: 1px solid var(--line); }}

footer {{ margin-top: 4rem; color: var(--muted); font-size: 0.8rem; line-height: 1.6; }}
code {{ font-family: ui-monospace, SFMono-Regular, Consolas, monospace; }}
</style>
</head>
<body>
<div class="sheet">

<h1>syllabary</h1>
<p class="lede">Every syllable the script can write: {both} of them, {count} with a
short vowel and the same {count} again with a long one. One square each,
consonants down, vowels across. <b>Guides</b> draws the em square with a
crosshair through its centre and a dashed box around the band the consonants
actually occupy, measured off this font rather than intended.</p>

<div class="controls">
  {buttons}
  <span class="spacer"></span>
  <button type="button" id="length" aria-pressed="false">long</button>
  <button type="button" id="guides" aria-pressed="false">guides</button>
</div>

<div class="grid" data-length="short">{grid}</div>
<div class="grid" data-length="long" hidden>{long_grid}</div>

<h2>consonants alone</h2>
<p class="note">No chevron on top. This is where a base form is judged on its
own terms, and where the middle of the box is easiest to see.</p>
<div class="bases">{consonants}</div>

<h2>vowels alone</h2>
<p class="note">The six plain chevrons and the six glides. One construction
rotated, carrying height and backness at once. The ring of dots is U+25CC, which
the font carries on purpose: a mark with no consonant under it is an error, and a
shaper says so by drawing a placeholder rather than by dropping the mark.</p>
<div class="bases">{vowels}</div>

<h2>length</h2>
<p class="note">Every vowel short over long, on <i>d</i>, which is the worst host
in the script: 28.3 sideways and 27.3 downward, the only letter at the top of
both rankings. A doubled mark steps 11 units inward along its own bearing, which
puts its inner edge 27.63 from centre. So <i>doo</i> and <i>dee</i> overlap the
diamond by 0.67, and <i>daa</i> clears it by 0.33. Schwa is the exception by
construction: it has no bearing to step along, so its long form ligates into a
ring instead of doubling.</p>
<div class="grid lengths">{lengths}</div>

<h2>contrasts</h2>
<p class="note">Each derived pair bare, then carried: consonants on
<i>a</i> because it is central and favours neither place, vowels on <i>m</i>
because a single bar is the least ink available to compete with a mark. Turn the
size down to 23px, which is where these stop being separable.</p>
<div class="contrasts">{contrasts}</div>

<footer>
<p>Generated by <code>python3 -m tools.build_syllabary</code> from
<code>data/script.toml</code>. The font is compiled into this file, so it shows
the shapes as they are now rather than as they are installed.</p>
</footer>

</div>
<script>
const root = document.documentElement;
const sizes = [...document.querySelectorAll("button[data-size]")];

for (const button of sizes) {{
  button.addEventListener("click", () => {{
    root.style.setProperty("--glyph", button.dataset.size + "px");
    for (const other of sizes) {{
      other.setAttribute("aria-pressed", String(other === button));
    }}
  }});
}}

const guides = document.getElementById("guides");
guides.addEventListener("click", () => {{
  const on = document.body.classList.toggle("guides");
  guides.setAttribute("aria-pressed", String(on));
}});

/* Both grids are in the page and one is hidden, rather than one grid being
   rewritten. Swapping visibility keeps the two in the same place on screen, so
   comparing a cell short against long is a flicker instead of a scroll. */
const length = document.getElementById("length");
const short = document.querySelector('.grid[data-length="short"]');
const long = document.querySelector('.grid[data-length="long"]');
length.addEventListener("click", () => {{
  const showLong = !short.hidden;
  short.hidden = showLong;
  long.hidden = !showLong;
  length.setAttribute("aria-pressed", String(showLong));
}});
</script>
</body>
</html>
"""


if __name__ == "__main__":
    main()
