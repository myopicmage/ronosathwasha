"""The font, compiled and packaged for a page to carry.

Shared by everything that emits HTML, because a page that shows this script has
no choice but to embed the font. The code points are private use: with no font
they render as tofu, and with the wrong font they render as somebody else's
letters at the same addresses, which looks like text and is not.

Always compiled here, in the calling process, from `data/script.toml`. Never
read from `build/` and never resolved through `local()`, both of which can hand
back an older vintage, and an older vintage renders as fluent nonsense rather
than as an error.
"""

from __future__ import annotations

import base64
import io
from pathlib import Path
from typing import Final

from ufo2ft import compileTTF

from ronesathwasha import Script
from tools.build_ufo import build

FAMILY: Final = "Ronesathwasha"


def compile_woff2(script: Script, work: Path) -> bytes:
    """Compile the font and return it as WOFF2 bytes.

    WOFF2 rather than the TTF because it is roughly half the size, and because
    the flake already carries brotli for exactly this: a WOFF2 container is
    Brotli-compressed by spec, so fontTools cannot write one without it.
    """
    ufo = build(script, work / f"{FAMILY}.ufo")
    ttf = compileTTF(ufo)
    ttf.flavor = "woff2"
    buffer = io.BytesIO()
    ttf.save(buffer)
    return buffer.getvalue()


def data_uri(woff2: bytes) -> str:
    return f"data:font/woff2;base64,{base64.b64encode(woff2).decode('ascii')}"


def face(woff2: bytes) -> str:
    """A complete `@font-face` rule with the font inside it.

    `font-display: block` rather than the browser default of `auto`: an unstyled
    flash would show the reader a paragraph of tofu, and the font is already in
    the page, so there is nothing to wait for anyway.
    """
    return (
        f"@font-face {{\n"
        f'  font-family: "{FAMILY}";\n'
        f'  src: url({data_uri(woff2)}) format("woff2");\n'
        f"  font-display: block;\n"
        f"}}"
    )
