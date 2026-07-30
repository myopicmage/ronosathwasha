from __future__ import annotations

import pytest
from fontTools.ttLib import TTFont
from ufo2ft import compileTTF

from ronosathwasha import Lexicon, Script, load, load_lexicon
from tests.harness import Built
from tools.build_ufo import build


@pytest.fixture(scope="session")
def script() -> Script:
    return load()


@pytest.fixture(scope="session")
def lexicon(script: Script) -> Lexicon:
    return load_lexicon(script)


@pytest.fixture(scope="session")
def built(tmp_path_factory: pytest.TempPathFactory) -> Built:
    """A font compiled from source inside the test run.

    Never the one in build/, which may be stale, and never the installed one,
    which may be a different vintage cached by the OS.
    """
    script = load()
    work = tmp_path_factory.mktemp("font")
    ufo = build(script, work / "Ronosathwasha.ufo")
    path = work / "Ronosathwasha.ttf"
    compileTTF(ufo).save(path)
    return Built(path, TTFont(path), script)
