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
from pathlib import Path
from typing import Final

from ronesathwasha import Entry, Lexicon, Script, load, load_lexicon
from tools.webfont import FAMILY, compile_woff2, face

ROOT: Final = Path(__file__).resolve().parent.parent
OUT: Final = ROOT / "build" / "dictionary.html"

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


def page(script: Script, lexicon: Lexicon, woff2: bytes) -> str:
    sections = "\n".join(
        section(script, name, entries) for name, entries in lexicon.sections()
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
