=begin pod

=head1 Ronosathwasha::Sentence

A whole sentence, generated.

C<Ronosathwasha::Realizer> builds the verb, which is where the morphology is
hard. This builds everything else and puts the verb at the end, which is where
the morphology is easy and the invariants are interesting.

=head2 Each word chooses its own alternants

Harmony's domain is the phonological word, so a sentence is not harmonised: its
words are, independently and possibly to opposite classes. C<Lasa runəru
thinəme> has a neutral word, a back word and a front word standing next to each
other, and every particle in it was selected by the stem it attached to rather
than by anything else in the sentence.

That is why realization is per-word and why nothing here passes a harmony class
down from the sentence. There is no such thing.

=head2 Order is reproduced, not chosen

Decision 17 leaves everything before the verb free, so a realizer could put the
constituents in any order it liked. It uses the order they were written in,
because that order was somebody's choice and regenerating a sentence
differently arranged would be a change nobody asked for.

Generating from scratch, with no source sentence to preserve, is a different
job and will need a canonical order. It does not need one yet.

=end pod

unit module Ronosathwasha::Sentence;

use X::Ronosathwasha;

use Ronosathwasha::Types;
use Ronosathwasha::Script;
use Ronosathwasha::Morphology;
use Ronosathwasha::Harmony;
use Ronosathwasha::Semantics;
use Ronosathwasha::Words;
use Ronosathwasha::Actions;
use Ronosathwasha::Realizer;

#| Build one non-verb word: its stems, then whatever particle it carries, with
#| the alternant chosen by the stems' own class.
#|
#| A compound takes its class from the whole compound rather than from its
#| head. `shamwu` is `sha` plus `mwu`, central then back, so the object marker
#| is the back `yu`. Reading the class off `sha` alone would give `yi`, which is
#| the error that stood in the corpus from December 2023 until yesterday.
sub realize-constituent(
    Script:D     $script,
    Morphology:D $morphology,
    WordParse:D  $word,
) is export {
    realize-word($script, $morphology, $word.stems, $word.suffixes);
}

#| The same thing without a parse to read it from.
#|
#| Rebuilding a sentence has a `WordParse` for every word, because it came from
#| one. Generating a sentence from a model's intent does not: the model names a
#| role and a stem, and there is nothing to divide. So the actual work lives
#| here and both callers reach it.
sub realize-word(
    Script:D     $script,
    Morphology:D $morphology,
    @stems,
    @suffixes,
) is export {
    my Str $stem = @stems.join;

    my $class = profile-of($script, $stem);

    fail X::Ronosathwasha::Form::NoClass.new(:$stem) if $class == MixedWord;

    $stem ~ @suffixes.map({ .form-for($class) }).join;
}

#| Build a whole sentence from a reading.
#|
#| No return type, so a failure stays inert; see `Ronosathwasha::Types`.
sub realize-sentence(
    Script:D     $script,
    Morphology:D $morphology,
    Reading:D    $reading,
) is export {
    my @words = $reading.constituents.map({
        realize-constituent($script, $morphology, $_)
    });

    if $reading.nominal-predicate {
        @words.push: realize-nominal-predicate(
            $script, $morphology, $reading.predicate,
            :copularized($reading.explicit-copula),
            :tense($reading.tense),
            :aspect($reading.aspect),
        );
    } else {
        @words.push: realize-verb(
            $script, $morphology, $reading.predicate,
            :speech-act($reading.speech-act),
            :tense($reading.tense),
            :aspect($reading.aspect),
            :polarity($reading.polarity),
            :modality($reading.modality),
        );
    }

    # English punctuation, borrowed whole, because the script has none of its
    # own. The marks are redundant with the morphology, since `te-/to-` already
    # made this a question, and they are written anyway: a convention every
    # reader can parse costs nothing while the script has no answer of its own.
    #
    # A command takes a full stop rather than an exclamation mark. English uses
    # `!` for force rather than for the imperative itself, and this language
    # marks no such thing, so inventing an emphasis distinction here would put
    # a dimension in the punctuation that the grammar does not have.
    my Str $end = $reading.speech-act == Interrogative ?? '?' !! '.';

    return @words.join(' ') ~ $end;

    CATCH { default { .fail } }
}
