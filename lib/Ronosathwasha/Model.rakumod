=begin pod

=head1 Ronosathwasha::Model

What a model is allowed to return, and the role any model must satisfy.

=head2 The model does not write Ronosathwasha

It chooses a meaning. C<Ronosathwasha::Sentence> writes the text. That is the
architectural commitment of the whole project and this file is where it becomes
a type rather than a promise: there is no field anywhere in C<ResponseIntent>
that holds Ronosathwasha, so a model cannot put a word on the screen even if it
invents a very convincing one.

Everything it names is checked against the declarations before it is accepted.
A predicate the lexicon does not list is rejected here, with the value it sent,
and never reaches the realizer.

=head2 Failing is a first-class answer

C<Gap> is not an error path. C<CHATBOT.md> says the model's confusion is the
useful part, and a learner who wants to say something the language cannot
express has produced the most valuable output this system has: evidence about
what is missing.

Every instinct in a chat model resists this. It will paper over a gap with an
approximation given any opening, so the type gives it somewhere better to go and
the prompt will have to keep pointing at it.

=end pod

unit module Ronosathwasha::Model;

use X::Ronosathwasha;

use Ronosathwasha::Types;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Morphology;
use Ronosathwasha::Semantics;



#| One argument: which role it fills and which stem fills it.
class Participant is export {
    has Argument $.role is required;
    has Str      $.stem is required;
}

role ResponseIntent is export {
    method summary(--> Str) { ... }
}

#| Say this. Every field is a meaning; none of them is text.
class Express does ResponseIntent is export {
    has Str       $.predicate  is required;
    has SpeechAct $.speech-act is required;
    has Aspect    $.aspect     is required;
    has Polarity  $.polarity   is required;
    has Modality  $.modality   is required;
    has Participant @.participants;

    #| Whether the predicate is a nominal taking a copularizer rather than a verb.
    #|
    #| The last of the three meaning types to learn decision 22. `Reading` knew it
    #| from the start and `Semantics::Utterance` gained it with the corpus, and
    #| until now a model could not choose to say what something *is*: every intent
    #| it produced was a verb, because there was no field for anything else.
    has Bool      $.nominal-predicate = False;

    #| Absent for a timeless identity. Only legal on a nominal predicate, since a
    #| verb always carries a tense morpheme, and `intent-from` refuses the
    #| combination rather than realizing something ill-formed.
    has Tense     $.tense;

    method summary(--> Str) {
        my @parts = (
            ($!tense.defined ?? $!tense.key !! 'untensed'),
            $!aspect.key, $!polarity.key, $!modality.key,
        );
        my $kind = $!nominal-predicate ?? ' is-a' !! '';

        "{ $!speech-act.key }$kind { $!predicate } ({ @parts.join(', ') })"
    }
}

#| I want to say this and the language cannot. The output worth having.
class Gap does ResponseIntent is export {
    has Str $.wanted  is required;
    has Str $.missing is required;

    method summary(--> Str) { "gap: $!wanted, needs $!missing" }
}

#| The interface a model satisfies. One method, so a fake and a local server are
#| interchangeable and the dialogue loop can be tested without either.
#|
#| `$context` is untyped here and typed in every implementation, which is not the
#| arrangement anyone would choose. `Ronosathwasha::PromptContext` holds a
#| `ConversationState`, and that holds `Express` and `Gap` for its summaries, so
#| naming the type here closes a compile-time `use` cycle back into this file.
#|
#| The honest fix is that `ResponseIntent` and its two cases do not belong in the
#| same file as the role that returns them, and separating them is stop 9's problem
#| rather than a change to make while wiring the policy in. Until then the
#| constraint lives at each end: every implementation declares
#| `PromptContext:D $context`, and `Dialogue.take-turn` will not build anything
#| else to hand it.
role Model is export {
    method respond($context --> ResponseIntent) { ... }
}

my constant %SPEECH-ACT = (
    declarative => Declarative, interrogative => Interrogative, imperative => Imperative,
);
my constant %TENSE    = (past => Past, present => Present, future => Future);
my constant %ASPECT   = (simple => Simple, continuous => Continuous);
my constant %POLARITY = (affirmative => Affirmative, negative => Negative);
my constant %MODALITY = (asserted => Asserted, potential => Potential);
my constant %ROLE     = (subject => Subject, object => Object);

#| Raises rather than failing. A `Failure` handed to a constrained attribute
#| is type-checked, and the type-check error replaces the domain exception with
#| one about binding, so the caller learns nothing about what the model sent.
#| `intent-from` converts at its own edge instead.
sub pick(%table, $sent, Str:D $field) {
    my $value = %table{ $sent // '' };

    die X::Ronosathwasha::Answer::Unknown.new(:$field, :value($sent)) without $value;

    $value;
}

#| Every stem a model may name.
#|
#| The lexicon's words minus its bound morphology, plus the verb stems recovered
#| from their infinitives. Exactly the set `Ronosathwasha::Words` will divide a
#| word into, because a model naming something the grammar cannot then assemble
#| would be a gap that only appears at realization.
sub nameable(Lexicon:D $lexicon, Morphology:D $morphology --> Set) is export {
    my @markers = $morphology.by-id('infinitive').forms;
    my $affixes = $lexicon.affixes.map(*.roman).Set;

    my @listed = $lexicon.entries
        .map(*.roman)
        .grep({ not $affixes{$_} and not .contains(' ') });

    my @bare = @listed.map(-> $form {
        with @markers.first({ $form.ends-with($_) && $form.chars > .chars }) -> $marker {
            $form.substr(0, $form.chars - $marker.chars)
        } else {
            Empty
        }
    });

    (@listed, @bare).flat.Set;
}

#| Turn what a model sent into an intent, or refuse it.
#|
#| No return type, so a refusal stays inert; see `Ronosathwasha::Types`. The
#| checking is deliberately not trusting: a schema-constrained decoder can
#| guarantee the shape of the JSON and cannot guarantee that `thinu` is a word.
sub intent-from(
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    %raw,
) is export {
    my Str $kind = ~(%raw<kind> // '');

    if $kind eq 'gap' {
        for <wanted missing> -> $field {
            die X::Ronosathwasha::Answer::Malformed.new(:reason("gap without $field"))
                unless %raw{$field}.defined && ~%raw{$field}.chars;
        }

        return Gap.new(:wanted(~%raw<wanted>), :missing(~%raw<missing>));
    }

    die X::Ronosathwasha::Answer::Malformed.new(:reason("unknown kind { $kind.raku }"))
        unless $kind eq 'express';

    my Set $known = nameable($lexicon, $morphology);

    my Str $predicate = ~(%raw<predicate> // '');

    die X::Ronosathwasha::Answer::Unknown.new(:field<predicate>, :value(%raw<predicate>))
        unless $known{$predicate};

    my Participant @participants = @(%raw<arguments> // []).map: -> $a {

        # Checked rather than assumed, because the shape is easy to get subtly
        # wrong and the symptom is misleading. A hash written straight into an
        # array literal flattens into its pairs, so `[ %( role => ... ) ]` is
        # two Pairs and not one argument, and every field then reads as
        # undefined rather than as absent.
        die X::Ronosathwasha::Answer::Malformed.new(:reason('an argument is not an object'))
            unless $a ~~ Associative;

        my %a := $a;
        my Str $stem = ~(%a<stem> // '');

        # `:field('argument stem')`, not `:field<argument stem>`. The angle
        # brackets are the word-quoting construct, so a space inside them makes
        # a two-element List rather than a string with a space in it.
        die X::Ronosathwasha::Answer::Unknown.new(:field('argument stem'), :value(%a<stem>))
            unless $known{$stem};

        Participant.new(:role(pick(%ROLE, %a<role>, 'argument role')), :$stem);
    }

    # `return`, because the `CATCH` below is the last statement of the sub and
    # would otherwise supply its value.
    my Bool $nominal = ?(%raw<nominal_predicate> // False);

    # An absent tense is a timeless identity, and only a nominal predicate has one.
    # A verb without a tense morpheme is not a well-formed word, so this refuses the
    # pair rather than defaulting a tense in and realizing something nobody asked
    # for. Checked here because a schema-constrained decoder can guarantee that both
    # fields are the right shape and cannot guarantee that the combination means
    # anything.
    my Bool $timeless = not %raw<tense>.defined;

    die X::Ronosathwasha::Answer::Malformed.new(
        :reason('a verbal predicate with no tense; only an identity may be timeless'),
    ) if $timeless && not $nominal;

    return Express.new(
        :$predicate,
        :speech-act(pick(%SPEECH-ACT, %raw<speech_act>, 'speech_act')),
        :nominal-predicate($nominal),
        :tense($timeless ?? Tense !! pick(%TENSE, %raw<tense>, 'tense')),
        :aspect(pick(%ASPECT, %raw<aspect>, 'aspect')),
        :polarity(pick(%POLARITY, %raw<polarity>, 'polarity')),
        :modality(pick(%MODALITY, %raw<modality>, 'modality')),
        :@participants,
    );

    CATCH { default { .fail } }
}
