"""Ronosathwasha, spoken.

    python3 -m tools.speak "lari thinəme"     -> build/speech/lari-thinəme.wav
    python3 -m tools.speak --demo             -> the whole set

Phonemes come from `data/script.toml`, so this stays correct as the inventory
moves. Nothing here transcribes romanisation by eye, which would go stale the
next time a letter changes and would be wrong in a way nobody could hear.

Why this is Python rather than Raku, given that the language belongs to the Raku
half: it adds no rule that exists anywhere else. Syllable parsing is already
here for the font, and the only new thing is a table mapping IPA to espeak's
phoneme names, which lives once. The boundary is about not stating a rule twice,
not about which language gets to touch the letters.

espeak-ng rather than macOS `say` because it takes phonemes directly. `say`
would have to be handed romanisation and would read it as English.
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path
from typing import Final

from ronesathwasha import ParseFailure, Script, load

ROOT: Final = Path(__file__).resolve().parent.parent
OUT: Final = ROOT / "build" / "speech"

# espeak-ng's phoneme names for the sounds this language has. Every IPA symbol
# in `data/script.toml` must appear here; `tests/test_speech.py` fails if one
# does not, so adding a consonant without a pronunciation is caught rather than
# discovered as a KeyError months later.
ESPEAK: Final = {
    "m": "m", "n": "n", "t": "t", "d": "d", "θ": "T", "ð": "D",
    "s": "s", "ʃ": "S", "l": "l", "ɹ": "r", "j": "j",
    "i": "i", "u": "u", "e": "e", "o": "o", "a": "a", "ə": "@",
}

# Decision 19: every word is stressed on its first syllable, always, including
# when a prefix supplies it. So stress is a default rather than a question, and
# the parameter survives only so that the demo can still show what varying it
# sounds like.
INITIAL: Final = 0

# Length is still open. It is a parameter with no default because there is no
# rule to default to.
NO_LENGTH: Final = None


def phonemes(
    script: Script,
    word: str,
    stress: int = INITIAL,
    long_at: int | None = NO_LENGTH,
) -> str:
    """One romanised word as espeak phonemes.

    `stress` defaults to decision 19 and is only worth passing to demonstrate
    what the rule rules out. `long_at` has no default because vowel length has
    no rule yet.
    """
    parsed = script.parse(word)
    if isinstance(parsed, ParseFailure):
        raise SystemExit(f"{word}: {parsed}")

    out = []
    for i, syllable in enumerate(parsed):
        mark = "'" if i == stress else ""

        # A glide vowel carries its own `w` in the IPA, so the base vowel is the
        # last character and the glide is spelled separately for espeak.
        glide = "w" if syllable.vowel.glide else ""
        vowel = ESPEAK[syllable.vowel.ipa[-1]] + (":" if i == long_at else "")

        out.append(f"{mark}{ESPEAK[syllable.consonant.ipa]}{glide}{vowel}")

    return "".join(out)


def utterance(script: Script, text: str, **kw: object) -> str:
    return " ".join(phonemes(script, w, **kw) for w in text.split())  # type: ignore[arg-type]


def render(name: str, parts: list[str], speed: int = 130) -> Path:
    """Write one file. Parts are separated by a pause so they can be compared."""
    OUT.mkdir(parents=True, exist_ok=True)
    out = OUT / f"{name}.wav"

    subprocess.run(
        ["espeak-ng", "-v", "en", "-s", str(speed), "-w", str(out),
         " _ _ ".join(f"[[{p}]]" for p in parts)],
        check=True,
    )
    return out


def demo(script: Script) -> None:
    """The set worth having, including the two open questions.

    Files 4 to 6 were the experiment that produced decision 19. English has no
    phonemic length and uses duration as a stress cue, so an English ear hears a
    long vowel as a stressed one; holding one still while varying the other is
    how you find out whether that survives.

    They are kept rather than deleted. File 5 now demonstrates something the
    language forbids, which is worth being able to hear: fixed initial stress is
    only a decision if you can tell what the alternative sounded like.
    """
    cons = "".join(f"'{ESPEAK[c.ipa]}a " for c in script.consonants)
    vows = "".join(f"'t{ESPEAK[v.ipa]} " for v in script.vowels if not v.glide)

    files = [
        render("01-autonym", [phonemes(script, "ronosathwasha")]),
        render("02-inventory", [cons, vows], speed=110),
        render("03-sentences", [
            utterance(script, "lari thinəme"),
            utterance(script, "nari tethinəme"),
            utterance(script, "lari she runəyu rorothwamo"),
            utterance(script, "lari runəyu merorothwamo"),
        ]),
        # length varied, stress pinned
        render("04-length", [
            phonemes(script, "tono", stress=0),
            phonemes(script, "tono", stress=0, long_at=0),
            phonemes(script, "tono", stress=0, long_at=1),
        ], speed=110),
        # stress varied, which decision 19 now forbids: kept so the rule can
        # be heard as a choice rather than as the only thing that was tried
        render("05-stress", [
            phonemes(script, "tono", stress=0),
            phonemes(script, "tono", stress=1),
        ], speed=110),
        # both at once, which is the case that would actually be ambiguous
        render("06-both", [
            phonemes(script, "tono", stress=0, long_at=0),
            phonemes(script, "tono", stress=1, long_at=0),
        ], speed=110),
    ]

    for path in files:
        print(f"{path.relative_to(ROOT)}")


def main() -> None:
    script = load()
    args = sys.argv[1:]

    if not args or args[0] == "--demo":
        demo(script)
        return

    text = " ".join(args)
    path = render(text.replace(" ", "-"), [utterance(script, text)])
    print(f"{path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
