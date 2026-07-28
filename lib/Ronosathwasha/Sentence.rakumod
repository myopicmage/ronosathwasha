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
    my Str $stem = $word.stems.join;

    my $class = profile-of($script, $stem);

    fail X::Realizer::NoClass.new(:$stem) if $class == MixedWord;

    $stem ~ $word.suffixes.map({ .form-for($class) }).join;
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

    @words.push: realize-verb(
        $script, $morphology, $reading.predicate,
        :speech-act($reading.speech-act),
        :tense($reading.tense),
        :aspect($reading.aspect),
        :polarity($reading.polarity),
        :modality($reading.modality),
    );

    # English punctuation, borrowed whole, because the script has no marks of
    # its own. The question mark is redundant with the `te-/to-` prefix that
    # already made this a question, and it is written anyway: a convention every
    # reader can already parse costs nothing.
    #
    # Only the question mark, because only the question mark is attested. A
    # declarative full stop would follow from the same borrowing and appears
    # nowhere Kevin has written, so it is not invented here.
    my Str $end = $reading.speech-act == Interrogative ?? '?' !! '';

    return @words.join(' ') ~ $end;

    CATCH { default { .fail } }
}
