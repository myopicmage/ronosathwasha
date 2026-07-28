"""The sentence examples and the page that renders them, held in step.

`data/examples.toml` and `docs/basic-sentences.html` are the same fourteen
sentences twice. Nothing generates one from the other, so nothing stopped them
disagreeing, and they did: the page tracked six months of decisions while the
file stayed at its original transcription. Every form on the page was current
and every form in the file was not, and both looked authoritative.

These tests are the substitute for a generator. They do not check that the
language is correct, which `test_lexicon.py` and `test_docs.py` do. They check
that the two statements of it are the same statement.
"""

from __future__ import annotations

import html
import re
import tomllib
from pathlib import Path
from typing import Any

import pytest

ROOT = Path(__file__).resolve().parent.parent
PAGE = ROOT / "docs" / "basic-sentences.html"
EXAMPLES = ROOT / "data" / "examples.toml"

ARTICLE = re.compile(r"<article>(.*?)</article>", re.S)
HEADING = re.compile(r"<h2>(.*?)</h2>", re.S)
GLOSS = re.compile(r'<p class="gloss">(.*?)</p>', re.S)
COMMON = re.compile(r'<div class="common">(.*?)</div>', re.S)
LABEL = re.compile(r'aria-label="([^"]+)"')
ROMAN = re.compile(r'<p class="roman">(.*?)</p>', re.S)
TAG = re.compile(r"<[^>]+>")


def _text(fragment: str) -> str:
    """Collapse a chunk of markup to the words a reader would see."""
    return re.sub(r"\s+", " ", html.unescape(TAG.sub("", fragment))).strip()


class Article:
    """One sentence as the page states it."""

    def __init__(self, fragment: str) -> None:
        heading = HEADING.search(fragment)
        assert heading is not None, "an article with no heading"
        self.english = _text(heading.group(1))

        labels = LABEL.findall(fragment)
        assert labels, f"{self.english}: no native-script line"
        self.form = html.unescape(labels[0])

        gloss = GLOSS.search(fragment)
        self.analysis = _text(gloss.group(1)) if gloss else ""

        self.common: str | None = None
        self.common_note: str | None = None
        block = COMMON.search(fragment)
        if block is not None:
            inner = block.group(1)
            found = LABEL.findall(inner)
            self.common = html.unescape(found[0]) if found else None
            roman = ROMAN.search(inner)
            if roman is not None:
                # The note is whatever follows the last form, so split on the
                # closing tag rather than deleting every italic. Two variants
                # render as `<i>a</i> or <i>b</i>`, and stripping all of them
                # leaves the joining "or" looking exactly like a note.
                trailing = _text(roman.group(1).rsplit("</i>", 1)[-1])
                self.common_note = trailing.strip("()") or None


def _articles() -> list[Article]:
    return [Article(f) for f in ARTICLE.findall(PAGE.read_text(encoding="utf-8"))]


def _examples() -> list[dict[str, Any]]:
    with EXAMPLES.open("rb") as handle:
        data: dict[str, Any] = tomllib.load(handle)
    examples: list[dict[str, Any]] = data["example"]
    return examples


def _pairs() -> list[tuple[dict[str, Any], Article]]:
    return list(zip(_examples(), _articles(), strict=True))


def test_the_file_is_no_longer_declared_historical() -> None:
    """The frozen-transcription era is over, and the file should say so.

    Its forms are now maintained against `LANGUAGE.md` like every other TOML
    file here. A `status` left at "historical" would invite the next reader to
    treat a current sentence as attested 2023 evidence.
    """
    with EXAMPLES.open("rb") as handle:
        data: dict[str, Any] = tomllib.load(handle)

    assert data["source"]["status"] == "current"


def test_the_page_and_the_file_hold_the_same_sentences() -> None:
    examples = _examples()
    articles = _articles()

    assert len(examples) == len(articles), (
        f"{len(examples)} examples against {len(articles)} articles on the page"
    )
    assert [e["english"] for e in examples] == [a.english for a in articles]


@pytest.mark.parametrize("example, article", _pairs(), ids=lambda v: None)
def test_every_sentence_matches_its_article(
    example: dict[str, Any], article: Article
) -> None:
    where = example["english"]

    assert example["ronesathwasha"] == article.form, where
    assert " ".join(example["analysis"]) == article.analysis, where

    expected_common = example.get("common")
    if expected_common is None:
        assert article.common is None, f"{where}: the page has a variant, the file none"
    else:
        assert article.common is not None, f"{where}: the file has a variant, the page none"
        assert " or ".join(expected_common) == article.common, where

    assert example.get("common_note") == article.common_note, where
