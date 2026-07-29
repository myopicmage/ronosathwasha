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

class Utterance is export {
    has Str       $.text       is required;
    has Str       $.english    is required;
    has Status    $.status     is required;
    has SpeechAct $.speech-act is required;
    has Str       $.predicate  is required;
    has Tense     $.tense      is required;
    has Aspect    $.aspect     is required;
    has Polarity  $.polarity   is required;
    has Modality  $.modality   is required;
    has Argument  @.arguments;

    has Reference $.reference;
    has Str       $.locative;
    has Str       $.complement;

    has Str $.source;
    has Str $.derived-from;
    has Str $.derivation;
    has Str $.rejected-because;

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

#| What the model-selection gate in stop 10 requires before it can run. Named
#| here rather than there because the corpus is what has to satisfy it, and a
#| floor stated far from the thing it measures drifts away from it.
our constant %REQUIRED is export = (
    'speech act' => (Declarative, Interrogative, Imperative),
    'tense'      => (Past, Present, Future),
    'aspect'     => (Simple, Continuous),
    'polarity'   => (Affirmative, Negative),
    'modality'   => (Asserted, Potential),
    'reference'  => (Proximal, Medial, Distal),
    'shape'      => (SubjectOnly, Transitive, NoArguments),
);

class Coverage is export {
    has Utterance @.utterances is required;

    method !values-for(Str $dimension, @from) {
        given $dimension {
            when 'speech act' { @from.map(*.speech-act) }
            when 'tense'      { @from.map(*.tense)      }
            when 'aspect'     { @from.map(*.aspect)     }
            when 'polarity'   { @from.map(*.polarity)   }
            when 'modality'   { @from.map(*.modality)   }
            when 'shape'      { @from.map(*.shape)      }
            when 'reference'  { @from.map(*.reference).grep(*.defined) }
            default           { () }
        }
    }

    #| Every required value the corpus does not reach, as
    #| `"dimension: value"`. Empty means the gate may run.
    method missing(--> Seq) {
        %REQUIRED.keys.sort.map(-> $dimension {
            my @have = self!values-for($dimension, @!utterances);
            %REQUIRED{$dimension}
                .grep({ @have.grep(* == $_).elems == 0 })
                .map({ "$dimension: $_" })
                .Slip
        });
    }

    #| The same question asked of evidence only. A gate satisfied entirely by
    #| sentences nobody has read is satisfied on paper.
    method missing-from-evidence(--> Seq) {
        my @evidence = @!utterances.grep(*.is-evidence);

        %REQUIRED.keys.sort.map(-> $dimension {
            my @have = self!values-for($dimension, @evidence);
            %REQUIRED{$dimension}
                .grep({ @have.grep(* == $_).elems == 0 })
                .map({ "$dimension: $_" })
                .Slip
        });
    }

    method has-locative(--> Bool) {
        @!utterances.grep(*.locative.defined).elems > 0;
    }

    method predicates(--> Seq) { @!utterances.map(*.predicate).unique.sort }

    method counts(--> Hash) {
        my %n;
        %n{ .status.key }++ for @!utterances;
        %n;
    }
}

my constant %SPEECH-ACT = (
    declarative => Declarative, interrogative => Interrogative, imperative => Imperative,
);
my constant %TENSE     = (past => Past, present => Present, future => Future);
my constant %ASPECT    = (simple => Simple, continuous => Continuous);
my constant %POLARITY  = (affirmative => Affirmative, negative => Negative);
my constant %MODALITY  = (asserted => Asserted, potential => Potential);
my constant %REFERENCE = (proximal => Proximal, medial => Medial, distal => Distal);
my constant %ARGUMENT  = (subject => Subject, object => Object);
my constant %STATUS    = (
    attested => Attested, derived => Derived, reviewed => Reviewed, rejected => Rejected,
);

sub decode(%table, $found, Str:D $field, Str:D $subject, IO::Path:D $path) {
    my $value = %table{ $found // '' };

    fail X::Ronosathwasha::Declaration::BadValue.new(:$path, :$field, :$subject, :$found)
        without $value;

    $value;
}

#| Load the corpus. No return type; see `Ronosathwasha::Types`.
sub load-utterances(IO::Path:D $path) is export {
    my $doc = read-toml($path);

    my Utterance @utterances = @(require-table($doc, 'utterance')).map: -> %u {
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
            :tense(decode(%TENSE, %u<tense>, 'tense', $text, $path)),
            :aspect(decode(%ASPECT, %u<aspect>, 'aspect', $text, $path)),
            :polarity(decode(%POLARITY, %u<polarity>, 'polarity', $text, $path)),
            :modality(decode(%MODALITY, %u<modality>, 'modality', $text, $path)),
            :@arguments,
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

    return Coverage.new(:@utterances);

    CATCH { default { .fail } }
}
