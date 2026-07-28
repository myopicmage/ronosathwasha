"""The lexicon as a searchable page.

    python3 -m tools.build_dictionary        -> build/dictionary.html

One self-contained file with the font inlined, because the script lives in the
private use area. A PUA code point means nothing to anyone else's machine: with
the wrong font it renders as tofu, and with a font that happens to occupy the
same block it renders as somebody else's letters, which is worse. So the page
carries its own decoder rather than hoping the reader installed one.

The font is compiled here, in this process, from `data/script.toml`. Never read
from `build/`, for the reason the README gives about the keyboard: a page one
encoding behind the font renders as fluent nonsense rather than as an error.
"""

from __future__ import annotations

import html
import tomllib
from pathlib import Path
from typing import Any, Final

from ronesathwasha import Entry, Lexicon, ParseFailure, Script, load, load_lexicon
from tools.webfont import FAMILY, compile_woff2, face

ROOT: Final = Path(__file__).resolve().parent.parent
OUT: Final = ROOT / "build" / "dictionary.html"

# Written by `tools/paradigms.raku`. Choosing `-se` over `-so` is morphology and
# belongs to the Raku half; rendering a form as private-use text with a font
# beside it is typography and belongs here. The file is a computed result rather
# than a second copy of a declaration, so deleting it costs one build.
PARADIGMS: Final = ROOT / "build" / "paradigms.toml"

# The one non-ASCII romanisation. Folded so the search box is reachable from a
# plain keyboard: nobody types a schwa to look up a word.
FOLD: Final = {"ə": "e"}


def canonical(entry: Entry) -> str:
    """The entry respelled in its own romanisation, one form per letter.

    The file accepts both spellings of the dental fricatives, so `ða` and `dha`
    are the same word written two ways. Searching wants one of them, and the
    parse is where that choice has already been made.
    """
    return " ".join(
        "".join(syllable.roman for syllable in word) for word in entry.words
    )


def searchable(entry: Entry) -> str:
    """Everything the search box matches against.

    Never the private-use text. A PUA code point has no case, no decomposition
    and no collation weight, so every Unicode algorithm that makes search
    forgiving is unavailable to it. Matching happens on the romanisation and the
    gloss, which are ordinary Latin text and get all of it.
    """
    forms = {entry.roman, canonical(entry), entry.gloss}
    folded = {"".join(FOLD.get(c, c) for c in form) for form in forms}
    return " ".join(sorted(forms | folded)).lower()


def card(script: Script, entry: Entry) -> str:
    return f"""      <li class="entry" data-key="{html.escape(searchable(entry))}">
        <span class="script" lang="x-rsw" translate="no">{html.escape(entry.text(script))}</span>
        <span class="roman">{html.escape(canonical(entry))}</span>
        <span class="gloss">{html.escape(entry.gloss)}</span>
      </li>"""


def section(script: Script, name: str, entries: tuple[Entry, ...]) -> str:
    cards = "\n".join(card(script, e) for e in entries)
    return f"""  <section class="section" data-section="{html.escape(name)}">
    <h2>{html.escape(name)}</h2>
    <ul class="entries">
{cards}
    </ul>
  </section>"""


def native(script: Script, roman: str) -> str:
    """One word as private-use text, or empty if it will not parse.

    A form that fails here is a real defect rather than a display problem: the
    realizer built it from declared morphemes, so it should be writable. Falling
    back to nothing keeps the page honest instead of showing a romanisation
    styled as if it were script.
    """
    parsed = script.parse(roman)
    if isinstance(parsed, ParseFailure):
        return ""

    return "".join(chr(cp) for cp in script.encode(parsed))


def paradigm_row(script: Script, cells: list[str], verb: dict[str, Any]) -> str:
    columns = "\n".join(
        f"""        <td>
          <span class="script" lang="x-rsw" translate="no">"""
        f"""{html.escape(native(script, verb[cell]))}</span>
          <span class="roman">{html.escape(verb[cell])}</span>
        </td>"""
        for cell in cells
    )
    return f"""      <tr>
        <th scope="row">
          <span class="roman">{html.escape(verb["stem"])}</span>
          <span class="gloss">{html.escape(verb["gloss"])}</span>
        </th>
{columns}
      </tr>"""


def paradigms(script: Script) -> str:
    """The conjugation tables, from the file the Raku side computed.

    Absent when only the Python half has been built, which is ordinary: the
    section disappears rather than the build failing, because a dictionary
    without paradigms is still a dictionary.
    """
    if not PARADIGMS.exists():
        return ""

    with PARADIGMS.open("rb") as handle:
        data = tomllib.load(handle)

    cells: list[str] = data["cells"]
    verbs: list[dict[str, Any]] = data["verb"]

    heads = "\n".join(f"        <th scope=\"col\">{html.escape(c)}</th>" for c in cells)
    rows = "\n".join(paradigm_row(script, cells, v) for v in verbs)

    return f"""  <section class="section paradigms" data-section="conjugation">
    <h2>conjugation</h2>
    <p class="note">
      Every verb across the seven marked forms. A front stem and a back stem
      differ in every column, because each affix agrees with the stem it
      attaches to. The negative disagrees with both, on purpose.
    </p>
    <div class="scroller">
      <table>
        <thead>
          <tr>
            <th scope="col">stem</th>
{heads}
          </tr>
        </thead>
        <tbody>
{rows}
        </tbody>
      </table>
    </div>
  </section>"""


def page(script: Script, lexicon: Lexicon, woff2: bytes) -> str:
    sections = "\n".join(
        [section(script, name, entries) for name, entries in lexicon.sections()]
        + [p for p in (paradigms(script),) if p]
    )
    return TEMPLATE.format(
        family=FAMILY,
        face=face(woff2),
        sections=sections,
        count=len(lexicon.writable()),
        blocked=len(lexicon.blocked()),
    )


def main() -> None:
    script = load()
    lexicon = load_lexicon(script)
    OUT.parent.mkdir(parents=True, exist_ok=True)

    woff2 = compile_woff2(script, OUT.parent)
    OUT.write_text(page(script, lexicon, woff2), encoding="utf-8")

    print(f"{OUT.relative_to(Path.cwd())}: {OUT.stat().st_size:,} bytes, "
          f"{len(lexicon.writable())} entries, font {len(woff2):,} bytes")


TEMPLATE: Final = """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>ronesathwasha dictionary</title>
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
}}
@media (prefers-color-scheme: dark) {{
  :root {{
    --bg: #16151a;
    --panel: #1e1d23;
    --ink: #ece9e3;
    --muted: #9a938a;
    --line: #302e37;
    --accent: #d9a066;
  }}
}}

* {{ box-sizing: border-box; }}
body {{
  margin: 0;
  padding: 0 1.25rem 5rem;
  background: var(--bg);
  color: var(--ink);
  font: 16px/1.55 ui-sans-serif, -apple-system, "Segoe UI", system-ui, sans-serif;
}}
.wrap {{ max-width: 60rem; margin: 0 auto; }}

header {{ padding: 3rem 0 1rem; }}
h1 {{
  margin: 0;
  font-size: 1.6rem;
  font-weight: 600;
  letter-spacing: -0.01em;
}}
.tagline {{ margin: 0.4rem 0 0; color: var(--muted); }}

.searchbar {{
  position: sticky;
  top: 0;
  z-index: 2;
  padding: 1rem 0;
  background: linear-gradient(var(--bg) 70%, transparent);
}}
input[type="search"] {{
  width: 100%;
  padding: 0.7rem 0.9rem;
  border: 1px solid var(--line);
  border-radius: 0.5rem;
  background: var(--panel);
  color: inherit;
  font: inherit;
}}
input[type="search"]:focus {{
  outline: 2px solid var(--accent);
  outline-offset: 1px;
}}
.count {{
  margin: 0.55rem 0 0;
  font-size: 0.85rem;
  color: var(--muted);
}}

h2 {{
  margin: 2rem 0 0.75rem;
  font-size: 0.75rem;
  font-weight: 600;
  text-transform: uppercase;
  letter-spacing: 0.09em;
  color: var(--accent);
}}

.entries {{
  list-style: none;
  margin: 0;
  padding: 0;
  display: grid;
  gap: 0.6rem;
  grid-template-columns: repeat(auto-fill, minmax(15rem, 1fr));
}}
.entry {{
  display: grid;
  gap: 0.15rem;
  padding: 0.9rem 1rem 1rem;
  border: 1px solid var(--line);
  border-radius: 0.6rem;
  background: var(--panel);
}}

/* No feature settings are overridden on purpose. The shaper runs `ccmp` and
   `mark` by default, and those two are the whole of this script's shaping:
   `ccmp` catches a vowel with no consonant, `mark` puts the vowel on the
   consonant. Turning ligatures off here would take the marks with them. */
.script {{
  font-family: "{family}", serif;
  font-size: 2.1rem;
  line-height: 1.35;
  margin-bottom: 0.35rem;
  overflow-wrap: anywhere;
}}
.roman {{ color: var(--muted); font-size: 0.9rem; }}
.gloss {{ font-size: 1rem; }}

.note {{ margin: 0 0 1rem; max-width: 46rem; color: var(--muted); line-height: 1.55; }}

/* The table is wider than a phone and the script inside it does not wrap, so
   the scrolling is put on a container rather than on the page. */
.scroller {{ overflow-x: auto; }}

.paradigms table {{ border-collapse: collapse; }}

.paradigms th, .paradigms td {{
  padding: 0.6rem 0.9rem;
  border-bottom: 1px solid var(--line);
  text-align: left;
  vertical-align: baseline;
  white-space: nowrap;
}}

.paradigms thead th {{
  color: var(--muted);
  font-size: 0.78rem;
  font-weight: 600;
  letter-spacing: 0.06em;
  text-transform: uppercase;
}}

.paradigms tbody th {{ font-weight: 400; }}

.paradigms td .script {{ display: block; font-size: 1.6rem; }}
.paradigms th .gloss {{ display: block; }}

.section[hidden], .entry[hidden] {{ display: none; }}
.empty {{ color: var(--muted); padding: 2rem 0; }}
.empty[hidden] {{ display: none; }}

footer {{
  margin-top: 3rem;
  padding-top: 1.25rem;
  border-top: 1px solid var(--line);
  color: var(--muted);
  font-size: 0.85rem;
}}
footer code {{ font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }}
</style>
</head>
<body>
<div class="wrap">

<header>
  <h1>ronesathwasha</h1>
  <p class="tagline">{count} words. Search the English or the romanisation.</p>
</header>

<div class="searchbar">
  <input type="search" id="q" placeholder="dog, thwasha, to like&hellip;"
         autocomplete="off" autocapitalize="off" spellcheck="false" autofocus>
  <p class="count" id="count"></p>
</div>

<main id="results">
{sections}
</main>

<p class="empty" id="empty" hidden>Nothing matches.</p>

<footer>
  <p>Generated by <code>python3 -m tools.build_dictionary</code> from
  <code>data/lexicon.toml</code> and <code>data/script.toml</code>. The font is
  embedded, so the script renders here whether or not it is installed.</p>
  <p>{blocked} further entries are attested but currently unwritable, and are
  waiting in <code>[respell]</code>.</p>
</footer>

</div>
<script>
const q = document.getElementById("q");
const count = document.getElementById("count");
const empty = document.getElementById("empty");
const sections = [...document.querySelectorAll(".section")];
const entries = [...document.querySelectorAll(".entry")];

const render = () => {{
  const needle = q.value.trim().toLowerCase();
  let shown = 0;

  for (const entry of entries) {{
    const hit = !needle || entry.dataset.key.includes(needle);
    entry.hidden = !hit;
    if (hit) {{
      shown += 1;
    }}
  }}

  for (const section of sections) {{
    section.hidden = !section.querySelector(".entry:not([hidden])");
  }}

  empty.hidden = shown > 0;
  count.textContent = needle
    ? `${{shown}} of ${{entries.length}}`
    : `${{entries.length}} words`;
}};

q.addEventListener("input", render);
render();
</script>
</body>
</html>
"""


if __name__ == "__main__":
    main()
