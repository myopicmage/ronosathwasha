=begin pod

=head1 Ronosathwasha::Projection

One canonical semantic shape, so two meanings can be compared without either
one's spelling getting a vote.

=head2 Why comparison needs its own type

The three meaning types do not share a representation. C<Intent::Express>
holds participants with stems, C<Actions::Reading> holds argument roles in one
list and parsed constituents in another, and C<Semantics::Utterance> declares
both. "Compare the typed meaning" therefore has no direct implementation:
every pairwise comparison would pick its own subset of axes and its own
notion of equality, and review C<029> asked for the one place where that
choice is made once.

The immediate customers are the C<miriswe> contract test, which proves that
realizing an intent and reading the result preserves meaning, and the
C<make model-eval> oracle, which compares a live model's parsed answer
against an expected meaning. Both compare through this module, so the
in-process test and the live oracle cannot disagree about what preservation
means.

=head2 What is compared, and what is deliberately not

The compared axes: predicate root, whether the predication is nominal, speech
act, question scope, tense, aspect, polarity, modality, and the participants
as role-stem pairs.

Participants are a C<Bag>, not a C<Set> and not a list. Constituent order is
not semantic in Rono, decision 17 frees it, so order must not distinguish two
meanings. Multiplicity must: nothing has ruled C<subject la, subject la>
equivalent to C<subject la>, and a C<Set> would silently declare that
repetition means nothing. Review C<029> corrected exactly that; the C<Bag>
discards what the language discards and keeps what it has not yet ruled on.

Excluded by construction, because they are facts about spelling rather than
meaning: allomorph choice, which C<Harmony> decides; whether the copularizer
was written, which decision 22 lets ordinary speech drop; constituent order;
punctuation; and the sentence text itself.

=head2 An interrogative word projects as the noun it was built from

Kevin's ruling, recorded with the question-scope work: an interrogative word is
C<to-> plus a relevant noun I<by formation>, so the series is open and the
C<to+mwu+yu> / C<tomwu+yu> surface collapse is convergence rather than
ambiguity. The normalisation was flagged there and not built.

This is where it had to be built, because it is a statement about I<canonical
meaning> and nowhere else gets a vote. Asking about the object C<mwu> ("thing")
writes C<tomwuyu>, and the reader necessarily divides that as the listed word
C<tomwu> ("what"), since it is one. Compared unnormalised, the round trip
reports a changed participant on a sentence that is in the corpus and perfectly
correct.

B<Both constructors normalise, not just the reading.> Halving it would only move
the mismatch: an intent that names C<toro> directly realizes and reads back as
C<toro>, so normalising one side alone would break the case that already worked.
The rule is the same on both, which is what makes it a canonical form rather
than a repair.

Unconditional, and deliberately not gated on the question scope. A lexical
interrogative carries its question inside the word, so it is its base noun under
a question wherever it appears; the scope is compared as its own axis anyway,
and a normalisation that consulted it would be answering the same question
twice.

=end pod

unit module Ronosathwasha::Projection;

use Ronosathwasha::Types;
use Ronosathwasha::Semantics;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Morphology;
use Ronosathwasha::Words;
use Ronosathwasha::Actions;
use Ronosathwasha::Intent;

#| The comparable shape. Every attribute is a meaning; none of them is text.
class SemanticProjection is export {
    has Str           $.predicate  is required;
    has Bool          $.nominal    is required;
    has SpeechAct     $.speech-act is required;
    has QuestionScope $.question-scope;
    has QuestionKind  $.question-kind;
    has Tense         $.tense;
    has Aspect        $.aspect     is required;
    has Polarity      $.polarity   is required;
    has Modality      $.modality   is required;
    has Bag           $.participants is required;

    #| The projection as plain data, which is what `eqv` compares structurally.
    method canonical(--> Map) {
        Map.new(
            'predicate'      => $!predicate,
            'nominal'        => $!nominal,
            'speech-act'     => $!speech-act,
            'question-scope' => $!question-scope,
            'question-kind'  => $!question-kind,
            'tense'          => $!tense,
            'aspect'         => $!aspect,
            'polarity'       => $!polarity,
            'modality'       => $!modality,
            'participants'   => $!participants,
        );
    }

    method matches(SemanticProjection:D $other --> Bool) {
        self.canonical eqv $other.canonical;
    }

    #| The axes on which two projections disagree, for a report that explains
    #| a mismatch instead of announcing one.
    method differences(SemanticProjection:D $other --> List) {
        my %mine   = self.canonical;
        my %theirs = $other.canonical;

        %mine.keys.sort.grep({ not %mine{$_} eqv %theirs{$_} }).List;
    }
}

#| Each lexical interrogative paired with the noun it was built from.
#|
#| Derived rather than listed, which is the same discipline `data/morphology.toml`
#| already documents: `toro` is `to` + `ro`, and the five entries are consequences
#| of the rule rather than five primitives. A sixth interrogative therefore needs
#| no edit here.
#|
#| The listed-word guard is what stops it stripping by accident: `tono` ("drink")
#| begins with `to` and is not a question, so only words the `[interrogative]`
#| section names are candidates, and even then only when what remains is itself a
#| declared word.
sub interrogative-bases(Lexicon:D $lexicon, Morphology:D $morphology --> Map) is export {
    my @prefixes = $morphology.by-id('question').forms;
    my Set $listed = $lexicon.forms;

    my %bases;

    for $lexicon.interrogative-words.keys -> $word {
        for @prefixes -> $prefix {
            next unless $word.starts-with($prefix);

            my Str $base = $word.substr($prefix.chars);

            next unless $listed{$base};

            %bases{$word} = $base;
            last;
        }
    }

    %bases.Map;
}

#| The canonical stem: an interrogative word becomes its noun, everything else
#| stays as it is.
sub canonical-stem(Map:D $bases, Str:D $stem --> Str) {
    $bases{$stem} // $stem;
}

#| One participant, as the string the `Bag` counts.
sub participant-key(Str:D $role, Str:D $stem --> Str) {
    "$role $stem";
}

#| What a model chose to say.
multi sub semantic-projection(
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Express:D    $intent,
    --> SemanticProjection
) is export {
    my Map $bases = interrogative-bases($lexicon, $morphology);

    SemanticProjection.new(
        :predicate(canonical-stem($bases, $intent.predicate)),
        :nominal($intent.nominal-predicate),
        :speech-act($intent.speech-act),
        :question-scope($intent.question-scope),
        :question-kind($intent.question-kind),
        :tense($intent.tense),
        :aspect($intent.aspect),
        :polarity($intent.polarity),
        :modality($intent.modality),
        :participants($intent.participants.map({
            participant-key(.role.key.lc, canonical-stem($bases, .stem))
        }).Bag),
    );
}

#| What the grammar read back off a sentence.
#|
#| Participants come from the constituents rather than from `Reading`'s own
#| argument list, because the roles there have already lost their stems: the
#| pairing lives in the words, where the case particle sits beside the stem it
#| marks. `MarksCase` ids are `subject` and `object`, the same strings
#| `Argument`'s keys lowercase to, so the two constructors meet in one
#| vocabulary.
multi sub semantic-projection(
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Reading:D    $reading,
    --> SemanticProjection
) is export {
    my Map $bases = interrogative-bases($lexicon, $morphology);

    my @pairs = $reading.constituents.map(-> $word {
        my $case = $word.with-role(MarksCase);

        $case.defined
            ?? participant-key($case.id, canonical-stem($bases, $word.stems.join))
            !! Empty;
    });

    SemanticProjection.new(
        :predicate(canonical-stem($bases, $reading.predicate)),
        :nominal($reading.nominal-predicate),
        :speech-act($reading.speech-act),
        :question-scope($reading.question-scope),
        :question-kind($reading.question-kind),
        :tense($reading.tense),
        :aspect($reading.aspect),
        :polarity($reading.polarity),
        :modality($reading.modality),
        :participants(@pairs.Bag),
    );
}
