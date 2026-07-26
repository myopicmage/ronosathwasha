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

from pathlib import Path
from xml.sax.saxutils import quoteattr

from ronesathwasha import Consonant, Script, Vowel, load

# macOS virtual key codes, ANSI. Chosen for the romanisation, not ergonomics:
# this is a layout you learn once by knowing how the language is written.
CONSONANT_KEYS: dict[str, int] = {
    "m": 46,   # m
    "n": 45,   # n
    "t": 17,   # t, shift -> d
    "ch": 8,   # c, shift -> j
    "th": 4,   # h, shift -> dh
    "s": 1,    # s, shift -> sh
    "l": 37,   # l, shift -> r
    "y": 16,   # y
}
VOWEL_KEYS: dict[str, int] = {
    "a": 0,    # a
    "e": 14,   # e
    "i": 34,   # i
    "o": 31,   # o
    "u": 32,   # u
    "ə": 41,   # ; , the one with no letter to claim
}

SPACE, RETURN, TAB = 49, 36, 48
LAYOUT_ID = -19217


def _hex(text: str) -> str:
    """Code points as XML character references.

    Private-use characters are invisible in an editor, and a layout file that
    looks empty where its output should be is unreviewable.
    """
    return "".join(f"&#x{ord(ch):04X};" for ch in text)


def _plan(script: Script) -> tuple[
    dict[int, tuple[Consonant, Consonant | None]],
    dict[int, tuple[Vowel, Vowel]],
]:
    """Which letter each physical key produces, plain and shifted.

    Shift is derivation: a consonant with a `derives_from` sits on its base's
    key, and a glide vowel on its plain twin's. Anything left over is a hole in
    the mapping and raises rather than quietly falling off the keyboard.
    """
    by_roman = {c.roman: c for c in script.consonants}
    derived = {c.derivation.base: c for c in script.consonants if c.derivation}

    consonants: dict[int, tuple[Consonant, Consonant | None]] = {}
    for roman, code in CONSONANT_KEYS.items():
        base = by_roman[roman]
        consonants[code] = (base, derived.get(base.glyph))

    placed = {c.glyph for pair in consonants.values() for c in pair if c}
    missing = [c.roman for c in script.consonants if c.glyph not in placed]
    if missing:
        raise ValueError(f"consonants with no key: {', '.join(missing)}")

    plain = {v.roman: v for v in script.vowels if not v.glide}
    glides = {v.roman.removeprefix("w"): v for v in script.vowels if v.glide}
    vowels = {VOWEL_KEYS[r]: (plain[r], glides[r]) for r in VOWEL_KEYS}

    if len(vowels) != len(plain):
        raise ValueError("every plain vowel needs a key")

    return consonants, vowels


def build(script: Script) -> str:
    consonants, vowels = _plan(script)
    states = [c.glyph for pair in consonants.values() for c in pair if c]

    def key_rows(shifted: bool) -> str:
        rows: list[str] = []
        for code, (base, derived) in sorted(consonants.items()):
            consonant = derived if shifted and derived else base
            rows.append(f'      <key code="{code}" action="press_{consonant.glyph}"/>')
        for code, (plain, glide) in sorted(vowels.items()):
            vowel = glide if shifted else plain
            rows.append(f'      <key code="{code}" action="press_{vowel.glyph}"/>')
        for code in (SPACE, RETURN, TAB):
            rows.append(f'      <key code="{code}" action="press_{code}"/>')
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

    # A vowel completes the pending syllable. In state none it emits nothing at
    # all, which is what makes an onsetless syllable untypeable rather than
    # merely wrong.
    letters = {c.glyph: c for pair in consonants.values() for c in pair if c}
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

    # Space, return and tab pass through and abandon any pending consonant.
    for code, out in ((SPACE, " "), (RETURN, "\r"), (TAB, "\t")):
        passthrough = "\n".join(
            f'      <when state={quoteattr(s)} output="{_hex(out)}"/>'
            for s in ["none", *states]
        )
        actions.append(f'    <action id="press_{code}">\n{passthrough}\n    </action>')

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

    consonants, vowels = _plan(script)
    print(f"{out.relative_to(Path.cwd())}")
    print(f"  {len(consonants)} consonant keys + {len(vowels)} vowel keys "
          f"= {len(consonants) + len(vowels)} physical keys")
    print(f"  shift adds the mark: "
          + ", ".join(f"{b.roman}->{d.roman}" for b, d in consonants.values() if d))


if __name__ == "__main__":
    main()
