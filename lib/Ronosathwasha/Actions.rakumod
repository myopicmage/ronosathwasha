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
class Reading does Asks is export {
    has Str       $.text       is required;
    has Str       $.predicate  is required;
    has Aspect    $.aspect     is required;
    has Polarity  $.polarity   is required;
    has Modality  $.modality   is required;
    has Argument  @.arguments;

    #| Absent when no tense morpheme was written, which decision 22 makes a
    #| meaning rather than a silence: `Lari mirireswe` says what somebody is and
    #| `Lari miriresweme` says what they are doing at the moment.
    #|
    #| This replaced an `explicit-tense` flag beside a tense that defaulted to
    #| `Present`. The two were perfectly correlated, so one of them was redundant,
    #| and the one that stayed is the one a careless reader cannot misuse: an
    #| undefined tense forces a decision at every call site, where `Present` next
    #| to a flag hands out a confident wrong answer to anyone who reads only the
    #| first field. `Semantics::Utterance` encodes it the same way, which matters
    #| because comparing the two types is what that pair is for.
    has Tense     $.tense;

    has Reference $.reference;
    has Str       $.locative;
    has Bool      $.nominal-predicate = False;
    has Bool      $.explicit-copula   = False;

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

#| A sentence the grammar accepts and the semantic type cannot yet hold.
#|
#| Decision 25 makes more than one question marker grammatical, each questioning
#| its own host, and `Reading` holds exactly one scope. Keeping the first marker
#| and erasing the rest would read a simpler sentence than the one written,
#| which is the meaning-preservation bug this codebase keeps refusing in new
#| clothes; refusing to guess is the honest outcome.
#|
#| An ordinary value rather than an exception, because a grammatical sentence
#| must not land on a fault path: `Dialogue::take-turn` carries every
#| non-`Understood` outcome as a turn with no typed meaning, and this is one.
#| Not `NotUnderstood`, because the sentence was understood far enough to name
#| exactly what cannot be held.
class NotRepresentable does SentenceOutcome is export {
    has Str $.sentence is required;
    has Str @.markers  is required;

    method summary(--> Str) {
        "$!sentence: { @!markers.join(' and ') }, "
            ~ 'and a reading holds one question scope'
    }
}

#| Whether this word carries the interrogative, by either of the two routes it has.
#|
#| The prefix is the productive one: `te-` on `thinə` gives `tethinəme`. The lexicon
#| section is the lexicalised one, and it is a declaration rather than a guess.
#| `toro` divides as one listed word under `e0662af`, so the marker inside it is not
#| a prefix any longer and nothing in the division can see it.
#|
#| **Not "the word starts with `to`".** `tono` does, `tono` is a listed word, and it
#| is not a question. The `[interrogative]` section is what separates the two, the
#| same way `[demonstrative]` is what finds a pointer below.
sub questions(Set $interrogatives, WordParse:D $word --> Bool) {
    my $act = $word.with-role(MarksSpeechAct);

    return True if $act.defined && $act.id eq 'question';

    so $word.stems.first({ $interrogatives{$_} });
}

#| How this word asks, said so a refusal can name every marker it found.
#|
#| The two routes `questions` checks, told apart because the difference is
#| real to a reader of the refusal: a productive prefix was written by choice,
#| while `toro` carries its question in the dictionary and could not shed it.
sub question-evidence(Set $interrogatives, WordParse:D $word --> Str) {
    my $act = $word.with-role(MarksSpeechAct);

    return "a question marker on { $word.text }"
        if $act.defined && $act.id eq 'question';

    "the question inside { $word.stems.first({ $interrogatives{$_} }) }";
}

#| Where the interrogative landed, given the word carrying it.
#|
#| Read off the particles, because those are what say a word's role. A questioned
#| word with no particle that is not the predicate is grammatical and unnameable
#| here, which `QuestionsUnmarkedConstituent` records rather than guessing at:
#| the name states the evidence, that nothing classifies the word, not a role.
sub scope-of(WordParse:D $word, Bool:D $is-predicate --> QuestionScope) {
    return QuestionsPredicate if $is-predicate;

    my $case = $word.with-role(MarksCase);

    return $case.id eq 'subject' ?? QuestionsSubject !! QuestionsObject
        if $case.defined;

    return QuestionsLocative if $word.has-role(MarksLocative);

    QuestionsUnmarkedConstituent;
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

        # Decision 26: the subject-drop and copula-drop licenses compose. A
        # single unmarked nominal standing alone is a subjectless zero-copula
        # identity, which is how `Narame.` means hello and bare `Ya.` finally
        # reads as the withdrawal decision 4 says it is. One constituent only:
        # two bare nominals in a row stay unreadable, because nothing marks
        # which would be the predicate, and that ambiguity is the language's.
        if !$predicate && @divisions.elems == 1
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

    # The interrogative is looked for across the whole sentence, and every other
    # feature is read off the predicate alone. That asymmetry is the language's:
    # tense, aspect, polarity and modality are properties of the predication and
    # can only be written on the predicate, and `to-` attaches to whichever
    # constituent is being asked about.
    #
    # Reading it off the predicate was the bug. `Nari toro?` came back as
    # `Declarative`, so `nari toro.` was the round trip and the question was gone;
    # `Tomwuyu thinəme?` lost it the same way with the marker sitting on the object.
    my Set $interrogatives = $lexicon.interrogative-words;

    # Every questioned word, not the first one. `first` was 026's finding: it
    # accepted `Tororu tethinəme?` and `Tororu dethinəme?`, recorded one marker,
    # and silently realized a simpler sentence than the one written. Decision 25
    # then made the multi-marked forms grammatical, so the refusal below names
    # the representation as the limit, never the grammar.
    my @asked = @divisions.pairs.grep({ questions($interrogatives, .value) });

    # A command marker can only conflict from the predicate, and only when the
    # questioned word is elsewhere: the prefix slot is shared, so a questioned
    # predicate carries `question` there and a command cannot coexist with it
    # on the same word.
    my Str @markers = @asked.map({ question-evidence($interrogatives, .value) });

    @markers.push: "a command marker on { $predicate.text }"
        if @asked && $act.defined && $act.id eq 'command';

    return NotRepresentable.new(:$sentence, :@markers) if @markers.elems > 1;

    my $asked-at = @asked ?? @asked.head.key !! Nil;

    my QuestionScope $question-scope = $asked-at.defined
        ?? scope-of(@divisions[$asked-at], $asked-at == $predicate-position)
        !! QuestionScope;

    my SpeechAct $speech-act = do {
        if $asked-at.defined                        { Interrogative }
        elsif $act.defined && $act.id eq 'command'  { Imperative    }
        else                                        { Declarative   }
    };

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
        :$speech-act,
        :$question-scope,
        :predicate($predicate.stems.join),
        # Undefined when nothing was written, rather than Present. A verb always
        # carries a tense morpheme, so the absence only ever arises on the nominal
        # predicates decision 22 introduced, and there it is the point.
        :tense(do given $tense-marker.defined ?? $tense-marker.id !! '' {
            when 'past'    { Past    }
            when 'future'  { Future  }
            when 'present' { Present }
            default        { Tense   }
        }),
        :aspect($aspect.defined ?? Continuous !! Simple),
        :polarity($polarity.defined ?? Negative !! Affirmative),
        :modality($modality.defined ?? Potential !! Asserted),
        :@arguments,
        :$reference,
        :locative($locative.defined ?? $locative.id !! Str),
        :$nominal-predicate,
        :$explicit-copula,
        :@ambiguous,
        :constituents(@divisions[0 ..^ @divisions.end]),
    ));
}
