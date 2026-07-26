"""Generate the macOS keyboard layout from the declaration.

The layout is a dead-key state machine. A consonant key enters a state and
emits nothing; a vowel key leaves it and emits the whole syllable at once. That
shape is not a convenience, it is the phonotactics: there is no keystroke
sequence that produces a bare vowel, a bare consonant, or a cluster, because
there is no state in which those are reachable.

Shift means one thing on both halves of the keyboard: add the mark. On a
consonant it gives the derived letter (t -> d, s -> sh), on a vowel the glide
(a -> wa). The keyboard is featural because the script is.
"""

from __future__ import annotations

import re
from pathlib import Path
from xml.sax.saxutils import quoteattr

from ronesathwasha import Consonant, Script, Vowel, load

# macOS virtual key codes, ANSI. Every consonant sits on the letter it is
# romanised with, so the layout needs no diagram: you type what you would
# write. Nothing is shifted except the glide.
CONSONANT_KEYS: dict[str, int] = {
    "m": 46,
    "n": 45,
    "t": 17,
    "d": 2,
    "s": 1,
    "l": 37,
    "r": 15,
    "y": 16,
}

# The digraphs, completed by pressing H after their first letter. This works
# because /h/ is not a phoneme here, so a `t` followed by an `h` can only ever
# have meant `th`. H alone does nothing, like every other illegal input.
DIGRAPH_KEY = 4  # h
DIGRAPHS: dict[str, str] = {
    "t": "th",
    "d": "dh",
    "s": "sh",
}

VOWEL_KEYS: dict[str, int] = {
    "a": 0,
    "e": 14,
    "i": 34,
    "o": 31,
    "u": 32,
    "ə": 41,   # ; , the one vowel with no letter to claim
}

LAYOUT_ID = -19217

# Everything that is not a letter of this script. An unmapped key in a
# .keylayout emits nothing at all, so anything left out here is a key that
# silently does not work: that is how the first version shipped without a
# working delete.
#
# (unshifted, shifted). Shift means "add the mark" on the letter keys, so it
# has no meaning here and just gives the usual Latin pair.
PASSTHROUGH: dict[int, tuple[str, str]] = {
    # Editing and navigation. These are ordinary characters to a keylayout;
    # the system turns them into cursor movement and deletion.
    51: ("", ""),   # delete
    117: ("", ""),  # forward delete
    53: ("", ""),   # escape
    123: ("", ""),  # left
    124: ("", ""),  # right
    126: ("", ""),  # up
    125: ("", ""),  # down
    115: ("", ""),  # home
    119: ("", ""),  # end
    116: ("", ""),  # page up
    121: ("", ""),  # page down
    49: (" ", " "),             # space
    36: ("\r", "\r"),           # return
    76: ("", ""),   # keypad enter
    48: ("\t", "\t"),           # tab
    # Latin digits and punctuation, because the script has none of its own and
    # borrows them. `;` is absent: that key carries the schwa.
    18: ("1", "!"), 19: ("2", "@"), 20: ("3", "#"), 21: ("4", "$"),
    23: ("5", "%"), 22: ("6", "^"), 26: ("7", "&"), 28: ("8", "*"),
    25: ("9", "("), 29: ("0", ")"),
    27: ("-", "_"), 24: ("=", "+"),
    47: (".", ">"), 43: (",", "<"), 44: ("/", "?"),
    39: ("'", '"'), 33: ("[", "{"), 30: ("]", "}"), 42: ("\\", "|"),
    50: ("`", "~"),
}


def _hex(text: str) -> str:
    """Code points as XML character references.

    Private-use characters are invisible in an editor, and a layout file that
    looks empty where its output should be is unreviewable.

    Note that control characters below U+0020 make this file not strictly
    valid XML 1.0, which forbids references to them. macOS accepts them and
    Ukelele writes them the same way, but any conforming parser will refuse
    the file. `sanitised()` exists so the structure can still be checked.
    """
    return "".join(f"&#x{ord(ch):04X};" for ch in text)


# Control characters are shifted into an unused stretch of the private use
# area to survive an XML parser, and shifted back by `unshift_controls`. Well
# clear of U+E000..U+E02B, which is the script itself.
CONTROL_SHIFT = 0xE100
_CONTROL_REF = re.compile(r"&#x00(0[0-8BCEF]|1[0-9A-F]);")


def parseable(xml: str) -> str:
    """The layout in a form a conforming XML parser will accept.

    XML 1.0 forbids references to most control characters, which macOS
    requires, so validation and the state-machine tests both read this instead
    of the real file. Round-trips exactly: nothing is lost, only moved.
    """
    return _CONTROL_REF.sub(lambda m: f"&#x{CONTROL_SHIFT + int(m.group(1), 16):04X};", xml)


def unshift_controls(text: str) -> str:
    """Undo `parseable` on a single output string."""
    return "".join(
        chr(ord(c) - CONTROL_SHIFT) if CONTROL_SHIFT <= ord(c) < CONTROL_SHIFT + 0x20 else c
        for c in text
    )


def _plan(script: Script) -> tuple[
    dict[int, Consonant],
    dict[Consonant, Consonant],
    dict[int, tuple[Vowel, Vowel]],
]:
    """Which key produces which letter, and which digraphs H completes.

    Every consonant is on the letter it is romanised with. Anything left over
    is a hole in the mapping and raises rather than quietly falling off the
    keyboard, which is how the first version shipped without a delete key.
    """
    by_roman = {c.roman: c for c in script.consonants}

    consonants = {code: by_roman[roman] for roman, code in CONSONANT_KEYS.items()}
    digraphs = {by_roman[first]: by_roman[whole] for first, whole in DIGRAPHS.items()}

    placed = {*consonants.values(), *digraphs.values()}
    missing = [c.roman for c in script.consonants if c not in placed]
    if missing:
        raise ValueError(f"consonants with no key: {', '.join(missing)}")

    plain = {v.roman: v for v in script.vowels if not v.glide}
    glides = {v.roman.removeprefix("w"): v for v in script.vowels if v.glide}
    vowels = {VOWEL_KEYS[r]: (plain[r], glides[r]) for r in VOWEL_KEYS}

    if len(vowels) != len(plain):
        raise ValueError("every plain vowel needs a key")

    return consonants, digraphs, vowels


def build(script: Script) -> str:
    consonants, digraphs, vowels = _plan(script)
    letters = {c.glyph: c for c in (*consonants.values(), *digraphs.values())}
    states = list(letters)

    def key_rows(shifted: bool) -> str:
        rows: list[str] = []
        for code, consonant in sorted(consonants.items()):
            rows.append(f'      <key code="{code}" action="press_{consonant.glyph}"/>')
        rows.append(f'      <key code="{DIGRAPH_KEY}" action="press_digraph"/>')
        for code, (plain, glide) in sorted(vowels.items()):
            vowel = glide if shifted else plain
            rows.append(f'      <key code="{code}" action="press_{vowel.glyph}"/>')
        for code, (plain_out, shift_out) in sorted(PASSTHROUGH.items()):
            prefix = "shift" if shifted and shift_out != plain_out else "press"
            rows.append(f'      <key code="{code}" action="{prefix}_{code}"/>')
        return "\n".join(rows)

    actions: list[str] = []

    # A consonant always enters its own state, from anywhere. Pressing two in a
    # row therefore discards the first rather than emitting a cluster.
    for state in states:
        arm = "\n".join(
            f'      <when state={quoteattr(s)} next={quoteattr(state)}/>'
            for s in ["none", *states]
        )
        actions.append(f'    <action id="press_{state}">\n{arm}\n    </action>')

    # H completes a digraph: it moves t -> th, d -> dh, s -> sh and does
    # nothing anywhere else. Safe because /h/ is not a phoneme here, so a `t`
    # followed by an `h` can only ever have meant `th`.
    digraph_whens = ['      <when state="none" output=""/>']
    for first, whole in digraphs.items():
        digraph_whens.append(
            f'      <when state={quoteattr(first.glyph)} next={quoteattr(whole.glyph)}/>'
        )
    for state in states:
        if state not in {c.glyph for c in digraphs}:
            digraph_whens.append(f'      <when state={quoteattr(state)} output=""/>')
    actions.append(
        '    <action id="press_digraph">\n' + "\n".join(digraph_whens) + "\n    </action>"
    )

    # A vowel completes the pending syllable. In state none it emits nothing at
    # all, which is what makes an onsetless syllable untypeable rather than
    # merely wrong.
    for _, pair in sorted(vowels.items()):
        for vowel in pair:
            whens = ['      <when state="none" output=""/>']
            for state, consonant in letters.items():
                text = "".join(
                    chr(script.codepoint(x)) for x in (consonant, vowel)
                )
                whens.append(
                    f'      <when state={quoteattr(state)} output="{_hex(text)}"/>'
                )
            body = "\n".join(whens)
            actions.append(
                f'    <action id="press_{vowel.glyph}">\n{body}\n    </action>'
            )

    # Everything else passes through and abandons any pending consonant, except
    # delete, which cancels it instead. A dead key is one keystroke as far as
    # the typist is concerned, so backspacing it should undo that keystroke
    # rather than also eating the character before it.
    for code, (plain_out, shift_out) in sorted(PASSTHROUGH.items()):
        armed = "" if code == 51 else plain_out
        whens = [f'      <when state="none" output="{_hex(plain_out)}"/>']
        whens += [
            f'      <when state={quoteattr(s)} output="{_hex(armed)}"/>'
            for s in states
        ]
        actions.append(
            f'    <action id="press_{code}">\n' + "\n".join(whens) + "\n    </action>"
        )
        if shift_out != plain_out:
            armed = shift_out
            whens = [f'      <when state="none" output="{_hex(shift_out)}"/>']
            whens += [
                f'      <when state={quoteattr(s)} output="{_hex(armed)}"/>'
                for s in states
            ]
            actions.append(
                f'    <action id="shift_{code}">\n' + "\n".join(whens) + "\n    </action>"
            )

    # An abandoned consonant emits nothing. It is half a syllable, and half a
    # syllable is not a thing this language can write.
    terminators = "\n".join(
        f'    <when state={quoteattr(s)} output=""/>' for s in states
    )

    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE keyboard SYSTEM "file://localhost/System/Library/DTDs/KeyboardLayout.dtd">
<!--
  Generated by tools/build_keylayout.py. Do not edit; edit the generator.

  Install: copy to ~/Library/Keyboard Layouts/ and log out and in, then add it
  under System Settings > Keyboard > Input Sources.

  Consonants are dead keys: they emit nothing and arm a state. Vowels fire,
  emitting both code points at once. Shift adds the mark on either half, so it
  gives the derived consonant or the glide vowel.
-->
<keyboard group="126" id="{LAYOUT_ID}" name="Ronesathwasha">
  <layouts>
    <layout first="0" last="17" modifiers="modifiers" mapSet="keys"/>
  </layouts>
  <modifierMap id="modifiers" defaultIndex="0">
    <keyMapSelect mapIndex="0">
      <modifier keys=""/>
    </keyMapSelect>
    <keyMapSelect mapIndex="1">
      <modifier keys="anyShift"/>
    </keyMapSelect>
  </modifierMap>
  <keyMapSet id="keys">
    <keyMap index="0">
{key_rows(shifted=False)}
    </keyMap>
    <keyMap index="1">
{key_rows(shifted=True)}
    </keyMap>
  </keyMapSet>
  <actions>
{chr(10).join(actions)}
  </actions>
  <terminators>
{terminators}
  </terminators>
</keyboard>
"""


def main() -> None:
    script = load()
    out = Path(__file__).resolve().parent.parent / "layouts" / "Ronesathwasha.keylayout"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(build(script), encoding="utf-8")

    consonants, digraphs, vowels = _plan(script)
    keys = len(consonants) + len(vowels) + 1
    print(f"{out.relative_to(Path.cwd())}")
    print(f"  {len(consonants)} consonants + H + {len(vowels)} vowels = {keys} letter keys")
    print("  digraphs: " + ", ".join(f"{a.roman}+h={b.roman}" for a, b in digraphs.items()))
    print("  shift is only the glide, and no consonant is shifted at all")


if __name__ == "__main__":
    main()
