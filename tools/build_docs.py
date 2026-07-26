"""Hand-written pages, rebuilt with the font inside them.

    python3 -m tools.build_docs        docs/*.html -> build/*.html

`docs/` is where a page is written and edited. It refers to the font the way a
source file should, by name and by path, which is convenient locally and wrong
everywhere else: the path points into `build/`, which is not tracked, and the
`local()` before it silently prefers whatever is installed, which may be a
different vintage of the font than the page was written against.

Both failures are quiet. A missing font renders as tofu, which at least looks
broken; a stale installed one renders as confident nonsense, because private-use
code points get whatever letters that font happens to keep at those addresses.

So the served copy is a different artefact from the source copy. This rewrites
the `@font-face` rule to carry the font it was just compiled against, and writes
the result to `build/`, which is the directory to point a tunnel at.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Final

from ronesathwasha import load
from tools.webfont import FAMILY, compile_woff2, face

ROOT: Final = Path(__file__).resolve().parent.parent
DOCS: Final = ROOT / "docs"
OUT: Final = ROOT / "build"

# The whole @font-face rule for our family, however its src is spelled. Matched
# rather than string-replaced because the src is the part that varies, and a
# rule this file did not recognise must be an error, not a silent pass-through.
FACE = re.compile(
    r"@font-face\s*\{[^}]*?font-family:\s*[\"']?" + FAMILY + r"[\"']?[^}]*?\}",
    re.IGNORECASE,
)


class DocError(Exception):
    """A page cannot be served as-is and this cannot fix it."""


def inline(source: str, path: Path, woff2: bytes) -> str:
    """Swap the page's @font-face rule for one carrying the font."""
    found = FACE.findall(source)
    if len(found) != 1:
        raise DocError(
            f"{path.name}: expected exactly one @font-face rule for {FAMILY}, "
            f"found {len(found)}. A page that shows the script needs one, and "
            f"this cannot guess which of several to replace."
        )

    return FACE.sub(lambda _: face(woff2), source, count=1)


def pages() -> list[Path]:
    return sorted(DOCS.glob("*.html"))


def main() -> None:
    script = load()
    OUT.mkdir(parents=True, exist_ok=True)
    woff2 = compile_woff2(script, OUT)

    for path in pages():
        out = OUT / path.name
        out.write_text(
            inline(path.read_text(encoding="utf-8"), path, woff2), encoding="utf-8"
        )
        print(f"{out.relative_to(Path.cwd())}: {out.stat().st_size:,} bytes")


if __name__ == "__main__":
    main()
