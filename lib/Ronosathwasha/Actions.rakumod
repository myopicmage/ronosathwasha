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
    has Bool      $.nominal-predicate = False;
    has Bool      $.explicit-copula   = False;
    has Bool      $.explicit-tense    = True;

    #| Words that divided more than one way. The frugal reading was taken, and
    #| this records that a choice was made rather than hiding it.
    has Str @.ambiguous;

    #| Every word except the verb, in the order it was written.
    #|
    #| The semantic fields above say a sentence had a subject; these say which
    #| noun it was. Realization needs both, and the split is on purpose: a
    #| model choosing what to say works in the fields, and only the realizer
    #| needs the words.
    #|
    #| The order is kept although decision 17 makes it free, because it is the
    #| order someone actually chose, and regenerating a sentence in a different
    #| order than it was written would be a change nobody asked for.
    has WordParse @.constituents;
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
    my Int       @open-nominals;
    my           %nominal-readings;

    for $sentence.words -> $word {
        my Int $position = @divisions.elems;
        my $nominal-reading = parse-nominal-predicate(
            $script, $morphology,
            $word.subst(/<[?.,!]>+$/, ''),
        );
        %nominal-readings{$position} = $nominal-reading
            if $nominal-reading.defined;

        my $outcome = classify($script, $lexicon, $morphology, $word);

        given $outcome {
            when Recognised { @divisions.push: .division }

            # The frugal division is taken and the word is noted. Refusing here
            # would reject `Lari thinəmedi`, which Kevin wrote.
            when Ambiguous {
                @divisions.push: .divisions.head;
                @ambiguous.push: .word;
            }

            when UnknownStem {
                if $nominal-reading.defined {
                    @divisions.push: $nominal-reading;
                    @open-nominals.push: $position;
                } else {
                    my $nominal = open-nominal($word.subst(/<[?.,!]>+$/, ''));
                    @divisions.push: $nominal;
                    @open-nominals.push: $position;
                }
            }

            default {
                return NotUnderstood.new(:$sentence, :$word, :because($outcome));
            }
        }
    }

    # A nominal predicate identifies itself with the copularizer. A verbal
    # predicate identifies itself with tense. The zero-copula form has neither,
    # so it is licensed only when a subject-marked nominal precedes one final
    # unmarked nominal.
    my $predicate-position = @divisions.first(*.has-role(MarksTense), :k);

    if $predicate-position.defined
        && (%nominal-readings{$predicate-position}:exists)
        && %nominal-readings{$predicate-position}.has-role(MarksTense)
    {
        @divisions[$predicate-position] = %nominal-readings{$predicate-position};
    }

    unless $predicate-position.defined {
        my Int $last = @divisions.end;

        if %nominal-readings{$last}:exists {
            @divisions[$last] = %nominal-readings{$last};
            $predicate-position = $last;
        }
    }

    my $predicate = $predicate-position.defined
        ?? @divisions[$predicate-position]
        !! WordParse;

    my Bool $nominal-predicate =
        $predicate.defined && $predicate.has-role(MarksPredication);
    my Bool $explicit-copula = $nominal-predicate;

    unless $predicate {
        my $subject-position = @divisions.first({
            my $case = .with-role(MarksCase);
            $case.defined && $case.id eq 'subject'
        }, :k);
        my Int $candidate-position = @divisions.end;
        my $candidate = @divisions.tail;

        if $subject-position.defined
            && $candidate-position != $subject-position
            && !$candidate.prefixes
            && !$candidate.suffixes
        {
            $predicate = $candidate;
            $predicate-position = $candidate-position;
            $nominal-predicate = True;
        }
    }

    return NotUnderstood.new(
        :$sentence,
        :word($sentence),
        :because(UnknownStem.new(:word($sentence))),
    ) without $predicate;

    # Open vocabulary is accepted only where the clause grammar proves that it
    # is the nominal predicate. Elsewhere an unknown writable word remains an
    # unknown word rather than silently becoming a name.
    with @open-nominals.first({ $_ != $predicate-position }) -> $unknown-position {
        my $unknown = @divisions[$unknown-position];

        return NotUnderstood.new(
            :$sentence,
            :word($unknown.text),
            :because(UnknownStem.new(:word($unknown.text))),
        );
    }

    # Decision 17. Every other constituent is free, because the particles say
    # what each one is; the verb is fixed because no particle identifies it.
    return WrongOrder.new(:$sentence, :verb($predicate.text))
        unless $predicate-position == @divisions.end;

    my $tense-marker = $predicate.with-role(MarksTense);
    my $aspect       = $predicate.with-role(MarksAspect);
    my $modality     = $predicate.with-role(MarksModality);
    my $act          = $predicate.with-role(MarksSpeechAct);
    my $polarity     = $predicate.with-role(MarksPolarity);

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
        :predicate($predicate.stems.join),
        :tense(do given $tense-marker.defined ?? $tense-marker.id !! '' {
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
        :$nominal-predicate,
        :$explicit-copula,
        :explicit-tense($tense-marker.defined),
        :@ambiguous,
        :constituents(@divisions[0 ..^ @divisions.end]),
    ));
}
