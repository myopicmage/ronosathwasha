=begin pod

=head1 Ronosathwasha::Actions

Divided words into meaning.

C<Ronosathwasha::Words> says which morphemes a word is made of.  This module
says what they mean together: which word carries the predicate, what tense it
is in, whether anything negated it, and which arguments the sentence supplies.

=head2 The predicate is found, not assumed

Ronosathwasha does not fix the order of words, only the order of morphemes
inside one. So the verb is not "the last word": it is the word carrying a tense
marker. C<Thinəswe twame> puts an infinitive first and the finite verb second,
and C<Sho thinəme> opens with a demonstrative. Both are attested.

=head2 Deixis is read from the vowel

Decision 9 moved the demonstratives to C<she>, C<sha> and C<sho> so that
distance would be "visible as a progression through the vowel space: front C<e>,
central C<a>, back C<o>."

That makes the deictic distance derivable. A demonstrative's vowel is already
declared in C<script.toml> with its backness, so front is proximal, central is
medial and back is distal, and no table anywhere has to repeat it. A fourth
demonstrative would be classified correctly the day it is coined.

=end pod

unit module Ronosathwasha::Actions;

use Ronosathwasha::Types;
use Ronosathwasha::Script;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Morphology;
use Ronosathwasha::Semantics;
use Ronosathwasha::Words;
use Ronosathwasha::ParseResult;

#| What a sentence was found to mean. Deliberately not `Semantics::Utterance`:
#| that type is a declaration, carrying an English gloss, a review status and a
#| source. This one is derived, and the point of the pair is that they can be
#| compared.
class Reading is export {
    has Str       $.text       is required;
    has SpeechAct $.speech-act is required;
    has Str       $.predicate  is required;
    has Tense     $.tense      is required;
    has Aspect    $.aspect     is required;
    has Polarity  $.polarity   is required;
    has Modality  $.modality   is required;
    has Argument  @.arguments;
    has Reference $.reference;
    has Str       $.locative;

    #| Words that divided more than one way. The frugal reading was taken, and
    #| this records that a choice was made rather than hiding it.
    has Str @.ambiguous;
}

role SentenceOutcome is export { }

class Understood does SentenceOutcome is export {
    has Reading $.reading is required;
}

class NotUnderstood does SentenceOutcome is export {
    has Str          $.sentence is required;
    has Str          $.word     is required;
    has ParseOutcome $.because  is required;

    method summary(--> Str) { "$!sentence: { $!because.summary }" }
}

#| Every word divided, and the verb is not last. Decision 17 fixes that
#| position and frees every other, so this is the one ordering error the
#| language has.
class WrongOrder does SentenceOutcome is export {
    has Str $.sentence is required;
    has Str $.verb     is required;

    method summary(--> Str) {
        "$!sentence: the verb $!verb.raku() must come last"
    }
}

#| Front is near, central is middle, back is far. See the module documentation:
#| this is decision 9's vowel progression read back out of the script.
sub deixis-of(Script:D $script, Str:D $stem --> Reference) {
    my $vowel = $stem.comb.first({ $script.is-vowel($_) });

    return Reference without $vowel;

    given $script.backness-of($vowel) {
        when Front   { Proximal }
        when Central { Medial   }
        when Back    { Distal   }
        default      { Reference }
    }
}

#| Read a sentence into meaning.
sub read-sentence(
    Script:D     $script,
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Str:D        $sentence,
    --> SentenceOutcome
) is export {
    my Set $demonstratives = $lexicon.in-section('demonstrative').map(*.roman).Set;

    my WordParse @divisions;
    my Str       @ambiguous;

    for $sentence.words -> $word {
        my $outcome = classify($script, $lexicon, $morphology, $word);

        given $outcome {
            when Recognised { @divisions.push: .division }

            # The frugal division is taken and the word is noted. Refusing here
            # would reject `Lari thinəmedi`, which Kevin wrote.
            when Ambiguous {
                @divisions.push: .divisions.head;
                @ambiguous.push: .word;
            }

            default {
                return NotUnderstood.new(:$sentence, :$word, :because($outcome));
            }
        }
    }

    # The verb is identified by its tense marker rather than by its position,
    # and then its position is checked. Those are separate steps on purpose: a
    # sentence with the verb in the wrong place is a well-formed sentence
    # written wrongly, and saying so is more useful than failing to find a verb.
    my $verb = @divisions.first(*.has-role(MarksTense));

    return NotUnderstood.new(
        :$sentence,
        :word($sentence),
        :because(UnknownStem.new(:word($sentence))),
    ) without $verb;

    # Decision 17. Every other constituent is free, because the particles say
    # what each one is; the verb is fixed because no particle identifies it.
    return WrongOrder.new(:$sentence, :verb($verb.text))
        unless @divisions.tail === $verb;

    my $tense-marker = $verb.with-role(MarksTense);
    my $aspect       = $verb.with-role(MarksAspect);
    my $modality     = $verb.with-role(MarksModality);
    my $act          = $verb.with-role(MarksSpeechAct);
    my $polarity     = $verb.with-role(MarksPolarity);

    my Argument @arguments = @divisions
        .map({ .with-role(MarksCase) })
        .grep(*.defined)
        .map({ .id eq 'subject' ?? Subject !! Object });

    my $locative = @divisions.map({ .with-role(MarksLocative) }).first(*.defined);

    my $pointer = @divisions.first({ .stems.first({ $demonstratives{$_} }).defined });

    my $reference = $pointer.defined
        ?? deixis-of($script, $pointer.stems.first({ $demonstratives{$_} }))
        !! Reference;

    Understood.new(reading => Reading.new(
        :text($sentence),
        :speech-act(do given $act.defined ?? $act.id !! '' {
            when 'question' { Interrogative }
            when 'command'  { Imperative    }
            default         { Declarative   }
        }),
        :predicate($verb.stems.head),
        :tense(do given $tense-marker.id {
            when 'past'   { Past    }
            when 'future' { Future  }
            default       { Present }
        }),
        :aspect($aspect.defined ?? Continuous !! Simple),
        :polarity($polarity.defined ?? Negative !! Affirmative),
        :modality($modality.defined ?? Potential !! Asserted),
        :@arguments,
        :$reference,
        :locative($locative.defined ?? $locative.id !! Str),
        :@ambiguous,
    ));
}
