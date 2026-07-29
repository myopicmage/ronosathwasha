"""Drive the generated layout's state machine and check what it can produce.

A keyboard layout is normally verified by installing it and typing, which tests
nothing repeatable. The `.keylayout` file is a complete description of a state
machine, so it can be executed instead, and the interesting question asked
exhaustively: not "does it type the right thing" but "can it type a wrong one".
"""

from __future__ import annotations

import re
import xml.etree.ElementTree as ET
from dataclasses import dataclass, field
from pathlib import Path

import pytest

from ronesathwasha import Consonant, ParseFailure, Script, Vowel, load
from tools.build_keylayout import (
    CONSONANT_KEYS,
    DIGRAPHS,
    DIGRAPH_KEY,
    VOWEL_KEYS,
    build,
    parseable,
    unshift_controls,
)

PLAIN, SHIFT = 0, 1


@dataclass
class Keyboard:
    """The layout as an executable machine."""

    keymaps: dict[int, dict[int, str]]

    # Per action, per state: what it writes and where it leaves the machine. A
    # `when` may do both, which is how a vowel emits its syllable and still
    # remembers what it was so a repeat of it can lengthen it.
    actions: dict[str, dict[str, tuple[str, str]]]
    terminators: dict[str, str]
    state: str = "none"
    typed: list[str] = field(default_factory=list)

    @classmethod
    def parse(cls, xml: str) -> Keyboard:
        root = ET.fromstring(parseable(xml))
        keymaps = {
            int(km.attrib["index"]): {
                int(k.attrib["code"]): k.attrib["action"] for k in km.findall("key")
            }
            for km in root.findall("keyMapSet/keyMap")
        }
        actions = {
            a.attrib["id"]: {
                w.attrib["state"]: (
                    unshift_controls(w.attrib.get("output", "")),
                    w.attrib.get("next", "none"),
                )
                for w in a.findall("when")
            }
            for a in root.findall("actions/action")
        }
        terminators = {
            w.attrib["state"]: unshift_controls(w.attrib.get("output", ""))
            for w in root.findall("terminators/when")
        }
        return cls(keymaps, actions, terminators)

    def press(self, code: int, shift: bool = False) -> Keyboard:
        action = self.keymaps[SHIFT if shift else PLAIN].get(code)
        if action is None:
            return self  # unmapped key: nothing happens at all

        output, following = self.actions[action][self.state]
        if output:
            self.typed.append(output)
        self.state = following
        return self

    def finish(self) -> str:
        """Flush any pending dead key, the way losing focus would."""
        if self.state != "none":
            self.typed.append(self.terminators[self.state])
            self.state = "none"
        return "".join(self.typed)


@pytest.fixture(scope="session")
def script() -> Script:
    return load()


@pytest.fixture(scope="session")
def xml(script: Script) -> str:
    return build(script)


@pytest.fixture
def keyboard(xml: str) -> Keyboard:
    return Keyboard.parse(xml)



def keystrokes(script: Script, letter: Consonant | Vowel) -> list[tuple[int, bool]]:
    """The key presses for one letter. Digraphs take two; the glide takes shift."""
    if isinstance(letter, Consonant):
        if letter.roman in CONSONANT_KEYS:
            return [(CONSONANT_KEYS[letter.roman], False)]

        first = next(f for f, whole in DIGRAPHS.items() if whole == letter.roman)
        return [(CONSONANT_KEYS[first], False), (DIGRAPH_KEY, False)]

    if letter.glide:
        return [(VOWEL_KEYS[letter.roman.removeprefix("w")], True)]

    return [(VOWEL_KEYS[letter.roman], False)]


def test_generated_layout_is_well_formed() -> None:
    """Parsed after sanitising, because the real file is not strict XML.

    Control characters below U+0020 cannot be written as references in XML 1.0.
    macOS requires them anyway and Ukelele writes them the same way, so the
    structure is checked on a copy with those references swapped out.
    """
    path = Path("layouts/Ronesathwasha.keylayout")
    assert path.exists(), "run python3 -m tools.build_keylayout"
    ET.fromstring(parseable(path.read_text(encoding="utf-8")))


def test_every_key_a_keyboard_needs_is_mapped(xml: str) -> None:
    """An unmapped key in a .keylayout emits nothing at all.

    The first version shipped with delete, escape, the arrows, the digits and
    all punctuation silently dead, because the exhaustive sweep only ever
    tested keys the layout already defined. It could not miss what was absent.
    """
    board = Keyboard.parse(xml)
    mapped = set(board.keymaps[PLAIN])
    essential = {
        51: "delete", 117: "forward delete", 53: "escape",
        123: "left", 124: "right", 125: "down", 126: "up",
        49: "space", 36: "return", 48: "tab",
        18: "1", 29: "0", 47: ".", 43: ",", 27: "-",
    }
    missing = [name for code, name in essential.items() if code not in mapped]
    assert not missing, f"unmapped: {', '.join(missing)}"


def test_delete_cancels_a_pending_consonant(script: Script, xml: str) -> None:
    """Backspacing an armed dead key should undo that keystroke and no more."""
    board = Keyboard.parse(xml)
    board.press(CONSONANT_KEYS["m"])
    assert board.state != "none"

    board.press(51)
    assert board.state == "none", "delete left the dead key armed"
    assert board.finish() == "", "delete emitted a character as well as cancelling"


def test_delete_emits_backspace_when_nothing_is_pending(xml: str) -> None:
    board = Keyboard.parse(xml)
    board.press(51)
    assert board.finish() == ""


def test_every_syllable_is_typeable(
    script: Script, xml: str
) -> None:
    for syllable in script.syllables():
        board = Keyboard.parse(xml)
        for letter in (syllable.consonant, syllable.vowel):
            for code, shift in keystrokes(script, letter):
                board.press(code, shift)

        want = "".join(chr(c) for c in script.encode([syllable]))
        assert board.finish() == want, syllable.roman


def test_a_consonant_alone_emits_nothing(script: Script, xml: str) -> None:
    """Half a syllable is not a thing this language can write."""
    for consonant in script.consonants:
        board = Keyboard.parse(xml)
        for code, shift in keystrokes(script, consonant):
            board.press(code, shift)
        assert board.state != "none", consonant.roman  # armed, not emitted
        assert board.finish() == "", consonant.roman


def test_a_vowel_alone_emits_nothing(script: Script, xml: str) -> None:
    """The whole point: an onsetless syllable is untypeable, not merely wrong."""
    for vowel in script.vowels:
        board = Keyboard.parse(xml)
        for code, shift in keystrokes(script, vowel):
            board.press(code, shift)
        assert board.finish() == "", vowel.roman


def test_two_consonants_discard_the_first(script: Script, xml: str) -> None:
    board = Keyboard.parse(xml)
    board.press(CONSONANT_KEYS["m"]).press(CONSONANT_KEYS["n"])
    board.press(VOWEL_KEYS["a"])

    only = script.parse("na")
    assert not isinstance(only, ParseFailure)
    assert board.finish() == "".join(chr(c) for c in script.encode(only))


def test_space_passes_through_and_abandons_a_pending_consonant(
    script: Script, xml: str
) -> None:
    board = Keyboard.parse(xml)
    board.press(CONSONANT_KEYS["m"])
    board.press(49)
    assert board.finish() == " "


def test_the_autonym_is_typeable(script: Script, xml: str) -> None:
    parsed = script.parse("ronesathwasha")
    assert not isinstance(parsed, ParseFailure)

    board = Keyboard.parse(xml)
    for syllable in parsed:
        for letter in (syllable.consonant, syllable.vowel):
            for code, shift in keystrokes(script, letter):
                board.press(code, shift)

    assert board.finish() == "".join(chr(c) for c in script.encode(parsed))


def test_no_two_keystrokes_can_produce_illegal_text(script: Script, xml: str) -> None:
    """Exhaustive over every pair of keys the layout defines.

    Every combination must produce nothing, whitespace, or a well-formed
    syllable. There is no sequence that yields a bare vowel, a bare consonant,
    or a cluster, because the machine has no state in which those are
    reachable. Space, return and tab are keys too, so they are in the sweep.
    """
    board = Keyboard.parse(xml)
    codes = sorted(board.keymaps[PLAIN])
    presses = [(code, shift) for code in codes for shift in (False, True)]
    legal = {
        "".join(chr(c) for c in script.encode([s])) for s in script.syllables()
    }

    checked = 0
    for first in presses:
        for second in presses:
            trial = Keyboard.parse(xml)
            trial.press(*first).press(*second)
            out = trial.finish()
            checked += 1

            # Latin digits, punctuation and whitespace pass straight through
            # and are legal. The invariant is about this script's own code
            # points: every run of them must be a well-formed syllable.
            for run in re.findall("[\ue000-\ue0ff]+", out):
                assert run in legal, f"{first} then {second} produced {run!r}"

    assert checked == len(presses) ** 2
    assert checked > 1000, f"only {checked} combinations swept"


def test_a_repeated_vowel_lengthens_it(xml: str, script: Script) -> None:
    """Decision 20, typed. Pressing the vowel again writes its mark again.

    The second press emits immediately, like every other. Nothing waits to find
    out whether a longer vowel is coming, which was the cost of the modifier-free
    design that used a terminator instead.
    """
    consonant = script.consonants[0]
    for vowel in (v for v in script.vowels if not v.glide):
        board = Keyboard.parse(xml)
        for code, shift in keystrokes(script, consonant):
            board.press(code, shift)
        code, shift = keystrokes(script, vowel)[0]
        board.press(code, shift)
        board.press(code, shift)

        want = "".join(chr(script.codepoint(x)) for x in (consonant, vowel, vowel))
        assert board.finish() == want, vowel.roman


def test_a_long_glide_is_the_glide_then_the_plain_vowel(
    xml: str, script: Script
) -> None:
    """Shift then unshifted, matching the romanisation `waa`."""
    consonant = script.consonants[0]
    glide = next(v for v in script.vowels if v.glide)
    plain = next(v for v in script.vowels if not v.glide and glide.roman == f"w{v.roman}")

    board = Keyboard.parse(xml)
    for code, shift in keystrokes(script, consonant):
        board.press(code, shift)
    board.press(*keystrokes(script, glide)[0])
    board.press(*keystrokes(script, plain)[0])

    want = "".join(chr(script.codepoint(x)) for x in (consonant, glide, plain))
    assert board.finish() == want


def test_a_different_vowel_after_a_vowel_writes_nothing(
    xml: str, script: Script
) -> None:
    """There are still no onsetless syllables, and length is not a licence."""
    consonant, (first, second) = script.consonants[0], [
        v for v in script.vowels if not v.glide
    ][:2]

    board = Keyboard.parse(xml)
    for code, shift in keystrokes(script, consonant):
        board.press(code, shift)
    board.press(*keystrokes(script, first)[0])
    board.press(*keystrokes(script, second)[0])

    want = "".join(chr(script.codepoint(x)) for x in (consonant, first))
    assert board.finish() == want
