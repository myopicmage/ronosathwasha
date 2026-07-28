=begin pod

=head1 Ronosathwasha::Harmony

Vowel harmony, as decided in C<LANGUAGE.md> decisions 2 and 3.

The domain is the phonological word. Harmony spans roots, compounds and bound
morphology, independent words choose their classes independently, and the
central vowels are transparent because they are actually central and so have no
backness to agree about.

=head2 What this module does not answer

Whether a word can be written at all. That is an orthography question, decided
by whether the script has glyphs for its letters, and the Python side owns it
along with the rest of the type pipeline. These functions assume a well-formed
word and answer only whether its vowels agree.

Whether the right morpheme was chosen. C<methinəme> uses the wrong negator, and
its vowels nevertheless agree perfectly, so it is C<Harmonic> here. Catching
that needs the grammar to know which morpheme was intended, which arrives with
recognition rather than with harmony.

=end pod

unit module Ronosathwasha::Harmony;

use Ronosathwasha::Types;
use Ronosathwasha::Script;
use Ronosathwasha::Morphology;

#| The vowels of a word, in order.
#|
#| Filtering characters is sufficient and not a shortcut around real parsing.
#| No consonant romanisation contains a vowel character: the eleven consonants
#| are built from `m n t d s l r y h`, and the two IPA alternates `ð` and `θ`
#| are non-ASCII by design. The glide is `w`, which marks labialisation on the
#| vowel it precedes and does not change which vowel that is, so `thwa` yields
#| `a` exactly as `tha` would.
#|
#| Syllable structure is a different question and arrives with the grammar.
sub vowels-of(Script:D $script, Str:D $word --> Seq) is export {
    $word.comb.grep({ $script.is-vowel($_) });
}

#| The harmony class of a whole word.
#|
#| A word with no front or back vowel at all is `NeutralWord`, which is a real
#| class rather than an exemption: such a word is compatible with either side
#| and the language resolves it to front when an affix has to choose.
sub profile-of(Script:D $script, Str:D $word --> VowelProfile) is export {
    my @backness = vowels-of($script, $word).map({ $script.backness-of($_) });

    # `.grep(...).elems`, not `so .first(...)`. An enum value in Raku is
    # numeric and the first one declared is 0, so `Front` is itself falsy:
    # `first` would return the matching element and boolean context would then
    # report that no match was found. Every word came back neutral.
    my Bool $front = @backness.grep(* == Front).elems > 0;
    my Bool $back  = @backness.grep(* == Back).elems > 0;

    return MixedWord if $front && $back;
    return FrontWord if $front;
    return BackWord  if $back;

    NeutralWord;
}

#| Whether a word obeys harmony, and if it does not, whether it is allowed to.
#|
#| The licensed case is the anti-harmonic negator of decision 3, and it is
#| checked rather than assumed: the prefix has to be the one its own remainder
#| would select. `mothinəme` qualifies because `thinəme` is front and negation
#| takes `mo` with a front stem. A word that merely happens to begin with those
#| two letters does not.
sub judge(Script:D $script, Morphology:D $morphology, Str:D $word --> HarmonyJudgment) is export {
    return Harmonic unless profile-of($script, $word) == MixedWord;

    my $negation = $morphology.by-id('negation');

    for ($negation.front-stem, $negation.back-stem) -> $prefix {
        next unless $word.starts-with($prefix);

        my $remainder = profile-of($script, $word.substr($prefix.chars));
        next if $remainder == MixedWord;

        return LicensedDisharmony if $negation.form-for($remainder) eq $prefix;
    }

    Violates;
}

#| One judgment per word. Harmony's domain is the word, so a phrase is judged
#| word by word and never as a whole; `thənəlayi tumamo` is two harmonic words
#| of opposite class, not one disharmonic string.
sub judge-phrase(Script:D $script, Morphology:D $morphology, Str:D $phrase --> Seq) is export {
    $phrase.words.map({ judge($script, $morphology, $_) });
}

sub profiles-of-phrase(Script:D $script, Str:D $phrase --> Seq) is export {
    $phrase.words.map({ profile-of($script, $_) });
}
