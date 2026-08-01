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

=head2 The question is written once, wherever it belongs

Every other feature of a sentence is a property of its predication and is written
on the predicate. The interrogative is not: C<to-> attaches to whichever
constituent is being asked about, so a reading's speech act is a fact about the
sentence and not an instruction for the predicate word.

Handing it to the predicate regardless produced both failures the question scope
was introduced to fix, one in each direction. C<Tororu thinəme?> came back as
C<tororu tethinəme?>, with the marker on the questioned subject and a second one
on the verb. And before the scope existed at all, the same sentence came back as
C<tororu thinəme.>, because the reader looked for the marker only on the predicate
and found nothing.

So C<act-to-write> decides, and it says no in two distinct cases: another
constituent carries the marker, or the predicate is a word that already spells one.
The second is why this module now needs the lexicon. C<toro> is "who" and the
question is inside it, so the check has to be a declaration rather than a look at
the spelling.

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
use Ronosathwasha::Lexicon;
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
    realize-word(
        $script, $morphology, $word.stems, $word.suffixes,
        :prefixes($word.prefixes),
    );
}

#| The same thing without a parse to read it from.
#|
#| Rebuilding a sentence has a `WordParse` for every word, because it came from
#| one. Generating a sentence from a model's intent does not: the model names a
#| role and a stem, and there is nothing to divide. So the actual work lives
#| here and both callers reach it.
#|
#| Prefixes exist for generated questions: `te-/to-` or `twe-/two-` goes on the
#| constituent being asked about. The alternant is chosen by the word's own class, like
#| every suffix: `tomwuyu` is back because `mwu` is, and nothing else in the
#| sentence has a say.
sub realize-word(
    Script:D     $script,
    Morphology:D $morphology,
    @stems,
    @suffixes,
    :@prefixes,
) is export {
    my Str $stem = @stems.join;

    # Once, from the stems, before anything is attached on either side. An affix
    # cannot vote on the class that selects it.
    my $class = profile-of($script, $stem);

    fail X::Ronosathwasha::Form::NoClass.new(:$stem) if $class == MixedWord;

    @prefixes.map({ .form-for($class) }).join
        ~ $stem
        ~ @suffixes.map({ .form-for($class) }).join;
}

#| Which speech act to write on the predicate, which is not always the sentence's.
#|
#| A statement and a command are properties of the predication and are always
#| written there. A question is not: `to-` attaches to whichever constituent is
#| being asked about, so the predicate carries it only when the predicate is what
#| is being asked about, and only when it does not already spell one.
#|
#| **`Declarative` here means "write no speech-act prefix".** The realizer maps only
#| the question and the command to morphemes, so the declarative is the unmarked
#| value and passing it is how a caller says nothing goes on the front. That is a
#| slightly uncomfortable way to express "somewhere else carries this", and the
#| alternative is a second parameter that can disagree with the first.
#|
#| `Asks:D` rather than `Reading:D`, because `Express` obeys the same rule when a
#| sentence is generated instead of rebuilt, and two copies of this decision would
#| be two chances for `totoro`. The role does not promise `.predicate`; both types
#| that compose it carry one, and Raku checks at the call, which `CLAUDE.md`'s
#| role-stub note is about.
sub act-to-write(Lexicon:D $lexicon, Asks:D $reading --> SpeechAct) is export {
    return $reading.speech-act unless $reading.speech-act == Interrogative;

    # Another constituent carries it, and that word is rebuilt from its own
    # division with the marker still attached, so writing one here would duplicate
    # it. `Tororu thinəme?` became `tororu tethinəme?` for exactly this reason.
    return Declarative unless $reading.question-scope == QuestionsPredicate;

    # Or the predicate is a word that already spells it. `toro` is "who", and
    # prefixing the marker to it again gives `totoro`, which is a film.
    return Declarative if $lexicon.interrogative-words{ $reading.predicate };

    Interrogative;
}

#| Build a whole sentence from a reading.
#|
#| No return type, so a failure stays inert; see `Ronosathwasha::Types`.
sub realize-sentence(
    Script:D     $script,
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Reading:D    $reading,
) is export {
    my SpeechAct $act = act-to-write($lexicon, $reading);
    my @words = $reading.constituents.map({
        realize-constituent($script, $morphology, $_)
    });

    if $reading.nominal-predicate {
        @words.push: realize-nominal-predicate(
            $script, $morphology, $reading.predicate,
            :copularized($reading.explicit-copula),
            :speech-act($act),
            :question-kind($reading.question-kind // OpenQuestion),
            :tense($reading.tense),
            :aspect($reading.aspect),
            :polarity($reading.polarity),
            :modality($reading.modality),
        );
    } else {
        @words.push: realize-verb(
            $script, $morphology, $reading.predicate,
            :speech-act($act),
            :question-kind($reading.question-kind // OpenQuestion),
            :tense($reading.tense),
            :aspect($reading.aspect),
            :polarity($reading.polarity),
            :modality($reading.modality),
        );
    }

    # English punctuation, borrowed whole, because the script has none of its
    # own. The marks are redundant with the morphology, since the question prefix already
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
