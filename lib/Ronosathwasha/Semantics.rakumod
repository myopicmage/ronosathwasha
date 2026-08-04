=begin pod

=head1 Ronosathwasha::Semantics

Meaning as values, and the corpus that states it.

The dimensions here are the ones the language currently marks, not a complete
theory of anything. A dimension earns a place when a morpheme in
C<data/morphology.toml> realizes it, so evidentiality and politeness are absent
because the language does not mark them and not because they were ruled out.

=head2 Status is not provenance alone

C<Attested> means Kevin wrote the sentence, so it is evidence about the
language. C<Derived> means it was recombined from declared morphemes and is
usable but proves nothing. C<Reviewed> means he has read a derived sentence and
accepted it. C<Rejected> means he has read one and it is wrong.

C<Rejected> is the valuable one. A sentence the rules permit and a speaker
would not is a rule the declarations have not captured, and deleting it throws
that finding away.

=end pod

unit module Ronosathwasha::Semantics;

use X::Ronosathwasha;

use Ronosathwasha::Types;
use Ronosathwasha::Data;

our enum SpeechAct  is export <Declarative Interrogative Imperative>;
our enum QuestionKind is export <OpenQuestion SelectiveQuestion>;
our enum Tense      is export <Past Present Future>;
our enum Aspect     is export <Simple Continuous>;
our enum Polarity   is export <Affirmative Negative>;
our enum Modality   is export <Asserted Potential>;
our enum Reference  is export <Proximal Medial Distal>;
our enum Argument   is export <Subject Object>;
our enum Status     is export <Attested Derived Reviewed Rejected>;

#| The argument shape, derived rather than declared, because the corpus states
#| which arguments are present and the shape is a reading of that.
our enum Shape is export <NoArguments SubjectOnly ObjectOnly Transitive>;

#| Whether a sentence puts its predicate in time, derived from whether it carries
#| a tense at all.
#|
#| Decision 22 made this contrastive rather than incidental. `Lari mirireswe` says
#| what somebody is and `Lari miriresweme` says what they are doing at the moment,
#| which is roughly English "I am a teacher" against "I am being a teacher". So the
#| absence of a tense is a meaning here, not a gap in the record.
#|
#| Derived and never declared, for the same reason as `Shape`: it is a reading of
#| the tense field rather than a second fact about the sentence, so there is no way
#| for a corpus entry to claim one thing and carry another.
#|
#| Deliberately not a fourth `Tense`. Past, present and future are three points on
#| a line and this is not a fourth point on it, so every caller asking what tense
#| a sentence has would get an answer that is not one.
our enum Predication is export <Timeless Anchored>;

#| Which constituent the interrogative marker attaches to.
#|
#| Scope and kind are independent axes. This says *where the question landed*;
#| `QuestionKind` says whether it asks openly or selects from a salient set. The
#| open-versus-polar distinction English draws is deliberately absent; a review
#| proposed importing it and was corrected.
#|
#| The values enumerate the constituents these types can currently name, which is
#| the honest bound. `toduruu` used as a bare temporal adjunct has nowhere to go
#| here, because `Utterance` has no field for one either. That is a limit of the
#| interface and not a claim about the language.
#|
#| `Questions-` prefixed for the reason `MorphemeRole` is `Marks-` prefixed: an
#| enum's values become symbols in every importing scope, and `Subject`, `Object`
#| and `Predicate` are all words this repo wants for other things.
#| `QuestionsUnmarkedConstituent` is the honest fallback, and the name records
#| evidence rather than a role: not that the word is inherently unclassifiable,
#| but that no case, locative or predication marker classifies it in this
#| sentence. Predicate, subject, object and locative are all constituents too,
#| which is why the bare `Constituent` name said less than it seemed to; `026`
#| made the point and the rename is its answer. Decision 17 frees every position
#| before the verb and the particles say what each word is, so a questioned word
#| carrying no particle is grammatical and has no role these types can name.
#| `Sho thinəme.` is the declarative precedent: the corpus records its arguments
#| as empty, because an unmarked word is not an argument as far as this file is
#| concerned. Naming that case is what `023` asked for, which is that an interface
#| limit be stated rather than disguised as a fact about the language.
our enum QuestionScope is export <
    QuestionsPredicate QuestionsSubject QuestionsObject QuestionsLocative
    QuestionsUnmarkedConstituent
>;

#| The speech act, and where the question landed when it is one.
#|
#| A role because three types carry this pair and the invariant between them is one
#| rule: `Utterance` declares it, `Actions::Reading` derives it from a sentence, and
#| `Intent::Express` receives it from a model. Written out three times it would be
#| three chances to write it differently, which is the shape of the bug `023`
#| objected to in the first place.
#|
#| The role owns both attributes rather than only the scope, because a `TWEAK` can
#| only read attributes its own composition unit declared, and because the point is
#| that the two are one fact.
role Asks is export {
    has SpeechAct     $.speech-act is required;
    has QuestionScope $.question-scope;
    has QuestionKind  $.question-kind;

    #| An interrogative says what it questions, and nothing else may.
    #|
    #| The meaning-preservation contract from review `023`, in the one place both
    #| halves are visible: if the interface accepts a distinction, it has to keep it.
    #| The bug that prompted it was the same shape, a type accepting polarity on a
    #| nominal predicate that the realizer then discarded, and a field which may or
    #| may not agree with its neighbour is that bug with the pieces moved around.
    #|
    #| Raku cannot make the pair unrepresentable. It checks types when values bind
    #| and has no way to tie one attribute's definedness to another's value, so
    #| `TWEAK` is the earliest point at which the question can be asked at all.
    submethod TWEAK {
        my Bool $asking = $!speech-act == Interrogative;
        my Bool $scoped = $!question-scope.defined;

        # Existing questions predate the distinction and are open questions.
        # Defaulting here keeps that meaning while a selective question must say
        # so explicitly. A non-question keeps the type object, meaning absent.
        $!question-kind = OpenQuestion if $asking && not $!question-kind.defined;

        my Bool $kinded = $!question-kind.defined;

        die X::Ronosathwasha::Meaning::ScopeDisagrees.new(
            :speech-act($!speech-act.key.lc),
            :scope($scoped ?? $!question-scope.key !! 'none'),
        ) if $asking != $scoped;

        die X::Ronosathwasha::Meaning::QuestionKindDisagrees.new(
            :speech-act($!speech-act.key.lc),
            :question-kind($!question-kind.key.lc),
        ) if $asking != $kinded;
    }
}

class Utterance does Asks is export {
    has Str       $.text       is required;
    has Str       $.english    is required;
    has Status    $.status     is required;
    has Str       $.predicate  is required;
    has Aspect    $.aspect     is required;
    has Polarity  $.polarity   is required;
    has Modality  $.modality   is required;
    has Argument  @.arguments;

    #| Absent on a timeless predication, and absent means something. Decision 22
    #| gives the copularizer an identity reading with no time attached, so a
    #| sentence with no tense is not an incomplete record of one that has a tense.
    #|
    #| Grouped with `reference` rather than left among the required fields, because
    #| this is now the second dimension the language declines to mark.
    has Tense     $.tense;

    #| Whether the predicate is a nominal carrying a copularizer rather than a verb.
    #|
    #| `Actions::Reading` has known this since decision 22 and this type did not,
    #| which meant the corpus could not state the construction the decision
    #| introduced. `t/09` found it the honest way: it rebuilds a verb from these
    #| fields and checks the result appears in the text, and for `Lari miriswemedi.`
    #| it built `mirimedi`, because nothing here said a copula was in there.
    #|
    #| Declared rather than derived. `Shape` and `Predication` are readings of other
    #| fields, but nothing else in this type records whether `-swe` was written, so
    #| there is nothing to read it off.
    has Bool      $.nominal-predicate = False;

    #| Whether the copularizer was actually written. Decision 22 lets ordinary
    #| speech drop it in an unmarked identity, so `Lari mirire.` and
    #| `Lari mirireswe.` are the same meaning differently spelled, and a corpus
    #| that could not tell them apart would rebuild the wrong one.
    #|
    #| Defaults true, because a nominal predicate normally carries it and the
    #| omission is the marked case. Meaningless on a verbal entry, where nothing
    #| reads it.
    has Bool      $.explicit-copula = True;

    has Reference $.reference;
    has Str       $.locative;
    has Str       $.complement;

    has Str $.source;
    has Str $.derived-from;
    has Str $.derivation;
    has Str $.rejected-because;

    #| Whether this sentence locates its predicate in time.
    method predication(--> Predication) { $!tense.defined ?? Anchored !! Timeless }

    method shape(--> Shape) {
        my Bool $subject = @!arguments.grep(* == Subject).elems > 0;
        my Bool $object  = @!arguments.grep(* == Object).elems > 0;

        return Transitive  if $subject && $object;
        return SubjectOnly if $subject;
        return ObjectOnly  if $object;

        NoArguments;
    }

    #| Whether this sentence is evidence about the language, as opposed to
    #| merely permitted by it.
    method is-evidence(--> Bool) {
        # `so`, because `Attested | Reviewed` is a Junction rather than an
        # alternation. It compares against both and stays a Junction, which
        # works in a boolean test and fails a `--> Bool` return.
        so $!status == Attested | Reviewed;
    }
}

#| One reviewed utterance containing several independently typed clauses.
#|
#| The clauses remain ordinary `Utterance` values so every existing semantic
#| invariant applies to each one. The wrapper owns the complete text and English
#| translation, while the connector list states how those clauses relate.
class CoordinatedUtterance is export {
    has Str        $.text       is required;
    has Str        $.english    is required;
    has Status     $.status     is required;
    has Utterance  @.clauses    is required;
    has Str        @.connectors is required;
    has Str        $.source;
    has Str        $.derivation;

    submethod TWEAK {
        die 'a coordinated utterance requires at least two clauses'
            if @!clauses.elems < 2;

        die 'a coordinated utterance requires exactly one connector between each pair of clauses'
            if @!connectors.elems != @!clauses.elems - 1;
    }

    method is-evidence(--> Bool) {
        so $!status == Attested | Reviewed;
    }
}

#| What the model-selection gate in stop 10 requires before it can run. Named
#| here rather than there because the corpus is what has to satisfy it, and a
#| floor stated far from the thing it measures drifts away from it.
#| `predication` is here and `tense` stays, and both are needed.
#|
#| The tense line is ticked only by sentences that have one, so a corpus of nothing
#| but timeless identity statements cannot report tense as covered. But that alone
#| would stop watching the timeless construction entirely: delete the only sentence
#| with no tense and the tense line is still ticked by the ordinary verbs, so the
#| gate would pass having lost a whole construction. The `predication` line is what
#| notices.
our constant %REQUIRED is export = (
    'speech act'  => (Declarative, Interrogative, Imperative),
    'question kind' => (OpenQuestion, SelectiveQuestion),
    'tense'       => (Past, Present, Future),
    'predication' => (Timeless, Anchored),
    'aspect'      => (Simple, Continuous),
    'polarity'    => (Affirmative, Negative),
    'modality'    => (Asserted, Potential),
    'reference'   => (Proximal, Medial, Distal),
    'shape'       => (SubjectOnly, Transitive, NoArguments),
);

class Coverage is export {
    has Utterance @.utterances is required;
    has CoordinatedUtterance @.coordinations;

    #| Every top-level corpus item, for exact-text lookup and status counts.
    method entries(--> Seq) {
        gather {
            take $_ for @!utterances;
            take $_ for @!coordinations;
        }
    }

    #| Every independently meaningful clause, for grammatical coverage.
    method clauses(--> Seq) {
        gather {
            take $_ for @!utterances;

            for @!coordinations -> $coordination {
                take $_ for $coordination.clauses;
            }
        }
    }

    method !values-for(Str $dimension, @from) {
        given $dimension {
            when 'speech act'  { @from.map(*.speech-act)  }
            when 'question kind' { @from.map(*.question-kind).grep(*.defined) }
            when 'aspect'      { @from.map(*.aspect)      }
            when 'polarity'    { @from.map(*.polarity)    }
            when 'modality'    { @from.map(*.modality)    }
            when 'shape'       { @from.map(*.shape)       }
            when 'predication' { @from.map(*.predication) }

            # The two optional dimensions, and the same treatment. An undefined
            # value witnesses nothing, so a timeless sentence cannot tick a tense
            # box and a sentence with no demonstrative cannot tick a reference one.
            when 'tense'       { @from.map(*.tense).grep(*.defined)     }
            when 'reference'   { @from.map(*.reference).grep(*.defined) }

            default            { () }
        }
    }

    #| Every required value the corpus does not reach, as
    #| `"dimension: value"`. Empty means the gate may run.
    method missing(--> Seq) {
        %REQUIRED.keys.sort.map(-> $dimension {
            my @have = self!values-for($dimension, self.clauses);
            %REQUIRED{$dimension}
                .grep({ @have.grep(* == $_).elems == 0 })
                .map({ "$dimension: $_" })
                .Slip
        });
    }

    #| The same question asked of evidence only. A gate satisfied entirely by
    #| sentences nobody has read is satisfied on paper.
    method missing-from-evidence(--> Seq) {
        my @evidence = self.clauses.grep(*.is-evidence);

        %REQUIRED.keys.sort.map(-> $dimension {
            my @have = self!values-for($dimension, @evidence);
            %REQUIRED{$dimension}
                .grep({ @have.grep(* == $_).elems == 0 })
                .map({ "$dimension: $_" })
                .Slip
        });
    }

    method has-locative(--> Bool) {
        self.clauses.grep(*.locative.defined).elems > 0;
    }

    method predicates(--> Seq) { self.clauses.map(*.predicate).unique.sort }

    method counts(--> Hash) {
        my %n;
        %n{ .status.key }++ for self.entries;
        %n;
    }
}

my constant %SPEECH-ACT = (
    declarative => Declarative, interrogative => Interrogative, imperative => Imperative,
);
my constant %QUESTION-KIND = (
    open => OpenQuestion, selective => SelectiveQuestion,
);
my constant %TENSE     = (past => Past, present => Present, future => Future);
my constant %ASPECT    = (simple => Simple, continuous => Continuous);
my constant %POLARITY  = (affirmative => Affirmative, negative => Negative);
my constant %MODALITY  = (asserted => Asserted, potential => Potential);
my constant %REFERENCE = (proximal => Proximal, medial => Medial, distal => Distal);
my constant %ARGUMENT  = (subject => Subject, object => Object);

#| Named for the constituent rather than for the morpheme, so an entry says
#| `questioned = "subject"` and not `questioned = "to"`. The corpus states
#| meaning; which allomorph spells it is the realizer's business.
#|
#| All five values, where the wire's `%SCOPE` in `Intent` offers three. The
#| difference is deliberate and each table says why: an `Express` cannot carry
#| a locative or an unmarked word, so the wire does not offer them, while the
#| corpus records sentences that exist, and `Toro thinəme?` exists. Review
#| `026` found the gap: the reader could derive the fallback scope and the
#| declarative source could not state it.
my constant %QUESTION-SCOPE = (
    predicate => QuestionsPredicate, subject  => QuestionsSubject,
    object    => QuestionsObject,    locative => QuestionsLocative,
    'unmarked-constituent' => QuestionsUnmarkedConstituent,
);
my constant %STATUS    = (
    attested => Attested, derived => Derived, reviewed => Reviewed, rejected => Rejected,
);

sub decode(%table, $found, Str:D $field, Str:D $subject, IO::Path:D $path) {
    my $value = %table{ $found // '' };

    fail X::Ronosathwasha::Declaration::BadValue.new(:$path, :$field, :$subject, :$found)
        without $value;

    $value;
}

#| Decode one independently meaningful clause from a corpus table.
sub load-utterance(%u, IO::Path:D $path --> Utterance) {
    my Str $text = ~(%u<text> // '');

    fail X::Ronosathwasha::Declaration::BadValue.new(
        :$path, :field<text>, :subject('an utterance'), :found(%u<text>),
    ) unless $text.chars;

    my Argument @arguments = @(%u<arguments> // []).map: {
        decode(%ARGUMENT, $_, 'arguments', $text, $path)
    };

    Utterance.new(
        :$text,
        :english(~%u<english>),
        :status(decode(%STATUS, %u<status>, 'status', $text, $path)),
        :speech-act(decode(%SPEECH-ACT, %u<speech_act>, 'speech_act', $text, $path)),
        :predicate(~%u<predicate>),
        :aspect(decode(%ASPECT, %u<aspect>, 'aspect', $text, $path)),
        :polarity(decode(%POLARITY, %u<polarity>, 'polarity', $text, $path)),
        :modality(decode(%MODALITY, %u<modality>, 'modality', $text, $path)),
        :@arguments,

        # Omitted rather than nulled. An absent `tense` key is a timeless
        # predication, and a present one that names something unknown is still a
        # bad value, so this cannot be a `// ''` that swallows both.
        :tense(%u<tense>.defined
            ?? decode(%TENSE, %u<tense>, 'tense', $text, $path)
            !! Tense),

        # Omitted rather than nulled, exactly as `tense` is: an absent key is a
        # sentence that asks nothing. A present one naming something unknown is
        # still a bad value, so this cannot collapse into a `// ''`.
        :question-scope(%u<questioned>.defined
            ?? decode(%QUESTION-SCOPE, %u<questioned>, 'questioned', $text, $path)
            !! QuestionScope),
        :question-kind(%u<question_kind>.defined
            ?? decode(%QUESTION-KIND, %u<question_kind>, 'question_kind', $text, $path)
            !! QuestionKind),

        # Defaults false, so every existing entry keeps meaning what it meant
        # and only a sentence that says so is read as copular.
        :nominal-predicate(?(%u<nominal_predicate> // False)),
        :explicit-copula(?(%u<explicit_copula> // True)),

        :reference(%u<reference>.defined
            ?? decode(%REFERENCE, %u<reference>, 'reference', $text, $path)
            !! Reference),
        :locative(%u<locative>.defined ?? ~%u<locative> !! Str),
        :complement(%u<complement>.defined ?? ~%u<complement> !! Str),
        :source(%u<source>.defined ?? ~%u<source> !! Str),
        :derived-from(%u<derived_from>.defined ?? ~%u<derived_from> !! Str),
        :derivation(%u<derivation>.defined ?? ~%u<derivation> !! Str),
        :rejected-because(%u<rejected_because>.defined ?? ~%u<rejected_because> !! Str),
    );
}

#| Load the corpus. No return type; see `Ronosathwasha::Types`.
sub load-utterances(IO::Path:D $path) is export {
    my $doc = read-toml($path);

    my Utterance @utterances = @(require-table($doc, 'utterance')).map: {
        load-utterance($_, $path)
    };

    my CoordinatedUtterance @coordinations = @($doc.data<coordination> // []).map: -> %u {
        my Str $text = ~(%u<text> // '');
        my Status $status = decode(%STATUS, %u<status>, 'status', $text, $path);

        my Utterance @clauses = @(%u<clauses> // []).map: -> %clause {
            my %declared = %clause.clone;
            %declared<status> = %u<status>;
            %declared<source> = %u<source> if %u<source>.defined;
            load-utterance(%declared, $path);
        };

        CoordinatedUtterance.new(
            :$text,
            :english(~%u<english>),
            :$status,
            :@clauses,
            :connectors(@(%u<connectors> // []).map(*.Str)),
            :source(%u<source>.defined ?? ~%u<source> !! Str),
            :derivation(%u<derivation>.defined ?? ~%u<derivation> !! Str),
        );
    };

    return Coverage.new(:@utterances, :@coordinations);

    CATCH { default { .fail } }
}
