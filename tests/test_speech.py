"""The pronunciation table, checked against the inventory it claims to cover.

A missing entry here is a `KeyError` at the moment somebody tries to hear a
word, which is both late and confusing. Adding a consonant is exactly when it
should be caught, and this is the only thing standing between the two.

Nothing here runs espeak. Whether the audio sounds right is a question for
Kevin's ears, and the tests can only check that the mapping is total.
"""

from __future__ import annotations

from ronosathwasha import Consonant, Script, Vowel
from tools.speak import ESPEAK, phonemes


def letters(script: Script) -> list[Consonant | Vowel]:
    """Both inventories as one list, typed.

    Splatting them into a tuple gives mypy a heterogeneous literal it widens to
    `object`, and `.ipa` then does not exist on it.
    """
    return [*script.consonants, *script.vowels]


def test_every_sound_in_the_inventory_can_be_spoken(script: Script) -> None:
    missing = [
        f"{letter.roman} ({letter.ipa})"
        for letter in letters(script)
        if letter.ipa[-1] not in ESPEAK
    ]
    assert not missing, f"no espeak phoneme for: {', '.join(missing)}"


def test_the_table_has_nothing_the_language_does_not(script: Script) -> None:
    """A stale entry is a letter that was removed and not cleaned up.

    The affricates went in decision 1. If `tS` were still in the table nobody
    would notice, and it would quietly suggest the language still had them.
    """
    declared = {letter.ipa[-1] for letter in letters(script)}
    stale = sorted(set(ESPEAK) - declared)
    assert not stale, f"the table speaks sounds the language does not have: {stale}"


def test_a_word_transcribes_to_phonemes(script: Script) -> None:
    assert phonemes(script, "thinəme") == "'Tin@me"


def test_the_glide_is_spelled_out(script: Script) -> None:
    """`thwa` is one syllable: a consonant and a glide vowel, not two."""
    assert phonemes(script, "thwasha") == "'TwaSa"


def test_stress_and_length_are_choices(script: Script) -> None:
    """Neither is decided, so neither has a default the code imposes quietly."""
    # The mark precedes the syllable it belongs to, so stressing the second one
    # puts it between them rather than inside the first.
    assert phonemes(script, "tono", stress=1) == "to'no"
    assert phonemes(script, "tono", stress=0, long_at=0) == "'to:no"
    assert phonemes(script, "tono", stress=0, long_at=1) == "'tono:"
