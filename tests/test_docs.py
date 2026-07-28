"""The hand-written pages, checked for the thing that only breaks off-machine.

Every failure here is invisible locally. A page that resolves the font through
`local()` or through `build/` looks perfect on the machine that built the font
and shows tofu or somebody else's letters anywhere else, and nobody proofreads
private-use text closely enough to notice the difference.
"""

from __future__ import annotations

import html
import re
from pathlib import Path

import pytest

from ronesathwasha import ParseFailure, Script
from tools.build_docs import DocError, inline, pages
from tools.webfont import FAMILY, compile_woff2

FACE_BLOCK = re.compile(r"@font-face\s*\{.*?\}", re.S)
SOURCE = re.compile(r"local\(\s*[^)]*\)|url\(\s*[\"']?(?P<target>[^\"')]*)")
WRITING = re.compile(
    r'<p class="writing" aria-label="(?P<label>[^"]+)">(?P<body>.*?)</p>',
    re.S,
)
TAG = re.compile(r"<[^>]+>")

# The private use area of the basic multilingual plane.
PUA = range(0xE000, 0xF900)


def test_there_are_pages_to_build() -> None:
    """A silent zero-page build would pass every other test in this file."""
    assert pages(), "docs/ has no .html pages"


@pytest.mark.parametrize("path", pages(), ids=lambda p: p.name)
def test_every_page_declares_one_face_this_can_replace(path: Path) -> None:
    source = path.read_text(encoding="utf-8")
    assert FAMILY in source, f"{path.name} never names the font"
    inline(source, path, b"")


def test_a_page_with_no_face_is_an_error_rather_than_a_silent_copy() -> None:
    """Silently serving a page that shows tofu is the failure being prevented."""
    with pytest.raises(DocError):
        inline("<html><body>no font here</body></html>", Path("x.html"), b"")


def test_a_page_with_two_faces_is_an_error_rather_than_a_guess() -> None:
    face = f'@font-face {{ font-family: "{FAMILY}"; src: url(a.ttf); }}'
    with pytest.raises(DocError):
        inline(face + face, Path("x.html"), b"")


def test_the_built_pages_carry_every_font_they_name(script: Script) -> None:
    """After inlining, no @font-face may resolve anything from outside the page.

    `local()` is the subtle one. It prefers the installed font, so a page using
    it renders from whatever vintage the OS has cached rather than the one it
    was built against, and the two disagree exactly when the inventory changed.
    """
    woff2 = compile_woff2(script, Path(__file__).resolve().parent.parent / "build")
    assert woff2[:4] == b"wOF2"

    for path in pages():
        built = inline(path.read_text(encoding="utf-8"), path, woff2)
        blocks = FACE_BLOCK.findall(built)
        assert blocks, f"{path.name} has no @font-face after inlining"

        for block in blocks:
            for match in SOURCE.finditer(block):
                target = match.group("target")
                assert target is not None, f"{path.name}: local() survived inlining"
                assert target.startswith("data:"), f"{path.name}: fetches {target}"


def test_sentence_page_script_matches_its_romanisation(script: Script) -> None:
    path = Path(__file__).resolve().parent.parent / "docs" / "basic-sentences.html"
    source = path.read_text(encoding="utf-8")
    matches = list(WRITING.finditer(source))
    assert matches, "basic-sentences.html has no native-script lines"

    for match in matches:
        label = html.unescape(match.group("label"))
        roman_words = [
            word.rstrip("?.,!").lower()
            for word in label.split()
            if word != "or"
        ]
        expected: list[tuple[int, ...]] = []
        for word in roman_words:
            parsed = script.parse(word)
            assert not isinstance(parsed, ParseFailure), f"{label}: {parsed}"
            expected.append(script.encode(parsed))

        body = html.unescape(TAG.sub("", match.group("body")))
        found = [
            tuple(ord(char) for char in token if ord(char) in PUA)
            for token in body.split()
            if any(ord(char) in PUA for char in token)
        ]
        assert found == expected, label
