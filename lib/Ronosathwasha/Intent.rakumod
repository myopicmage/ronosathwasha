=begin pod

=head1 Ronosathwasha::Intent

What a model is allowed to return, and the checking that admits it.

=head2 The model does not write Ronosathwasha

It chooses a meaning. C<Ronosathwasha::Sentence> writes the text. That is the
architectural commitment of the whole project and this file is where it becomes a
type rather than a promise: there is no field anywhere in C<ResponseIntent> that
holds Ronosathwasha, so a model cannot put a word on the screen even if it invents a
very convincing one.

Everything it names is checked against the declarations before it is accepted. A
predicate the lexicon does not list is rejected here, with the value it sent, and
never reaches the realizer.

=head2 Failing is a first-class answer

C<Gap> is not an error path. C<CHATBOT.md> says the model's confusion is the useful
part, and a learner who wants to say something the language cannot express has
produced the most valuable output this system has: evidence about what is missing.

Every instinct in a chat model resists this. It will paper over a gap with an
approximation given any opening, so the type gives it somewhere better to go and the
prompt has to keep pointing at it.

=head2 Why this is not in C<Ronosathwasha::Model>

It was, until stop 9. The role that returns these types belongs with the transport
and the types themselves belong with the language, and keeping them together closed a
compile-time cycle: C<Model> wanted C<PromptContext>, which holds a
C<ConversationState>, which reaches for C<Express> and C<Gap> to write its summaries,
which lived in C<Model>.

So the role could not name the type of its own C<$context> parameter, and the
constraint had to live in every implementation instead. Splitting the file is what
lets the interface state its own contract. Nothing here imports the role, and nothing
here should.

=end pod

unit module Ronosathwasha::Intent;

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
#|
#| `Asks` carries the speech act and, when that act is `Interrogative`, which
#| constituent the question landed on. Composed rather than restated, because this is
#| the third type to hold that pair and review `023` objected to exactly that: an
#| invariant written out once per type is an invariant with three chances to disagree
#| with itself. `Semantics::Utterance` declares it, `Actions::Reading` derives it from
#| a sentence, and this receives it from a model.
class Express does ResponseIntent does Asks is export {
    has Str       $.predicate  is required;
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

        # A summary is lossy on purpose, but not about this. A question whose
        # summary reads the same as another question's is the record of a
        # distinction the interface accepted and then stopped carrying.
        @parts.push("questions { $.question-scope.key.subst('Questions', '').lc }")
            if $.question-scope.defined;

        my $kind = $!nominal-predicate ?? ' is-a' !! '';

        "{ $.speech-act.key }$kind { $!predicate } ({ @parts.join(', ') })"
    }
}

#| I want to say this and the language cannot. The output worth having.
class Gap does ResponseIntent is export {
    has Str $.wanted  is required;
    has Str $.missing is required;

    method summary(--> Str) { "gap: $!wanted, needs $!missing" }
}


my constant %SPEECH-ACT = (
    declarative => Declarative, interrogative => Interrogative, imperative => Imperative,
);
my constant %TENSE    = (past => Past, present => Present, future => Future);
my constant %ASPECT   = (simple => Simple, continuous => Continuous);
my constant %POLARITY = (affirmative => Affirmative, negative => Negative);
my constant %MODALITY = (asserted => Asserted, potential => Potential);
my constant %ROLE     = (subject => Subject, object => Object);

#| The wire names for `Semantics::QuestionScope`.
#|
#| Unprefixed, because the reason the enum's values carry `Questions` is a Raku one:
#| an enum's values become symbols in every importing scope, and `Subject`, `Object`
#| and `Predicate` are words this repo wants for other things. A model has no import
#| table to collide with, and `subject` here is the same string `%ROLE` uses for the
#| same constituent.
#|
#| No open-versus-polar entry, deliberately. `to-` makes a question and does not imply
#| a yes-or-no one, so there is no such choice for a model to get wrong.
my constant %SCOPE    = (
    predicate   => QuestionsPredicate,
    subject     => QuestionsSubject,
    object      => QuestionsObject,
    locative    => QuestionsLocative,
    constituent => QuestionsConstituent,
);

#| Which strings a model may send for each enumerated field.
#|
#| Exposed because the JSON schema in `Ronosathwasha::ModelProtocol` has to enumerate
#| exactly these, and a schema listing its own copy of them is a second place for the
#| vocabulary to live. That has already gone wrong once tonight, in `Morphology`: an
#| enum grew, the string table beside it did not, and the symptom was a type check
#| complaining about the wrong thing entirely.
#|
#| Sorted, so a schema built from this is stable between runs and a diff of one means
#| something changed.
sub answer-vocabulary(--> Hash) is export {
    %(
        # Not from a table, because the discriminator is not decoded through one:
        # `intent-from` branches on it directly. Listed here so the schema and the
        # branch cannot disagree about which kinds exist.
        kind       => <express gap>,

        speech_act => %SPEECH-ACT.keys.sort.List,
        tense      => %TENSE.keys.sort.List,
        aspect     => %ASPECT.keys.sort.List,
        polarity   => %POLARITY.keys.sort.List,
        modality   => %MODALITY.keys.sort.List,
        role       => %ROLE.keys.sort.List,
    );
}

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

            # `(~%raw{$field}).chars`, parenthesised. `~` is looser than a method
            # call, so `~%raw{$field}.chars` stringifies the *count* and yields
            # `"0"` for an empty string, which is true. The guard read as written
            # and tested as `True`, so an empty `wanted` passed it for as long as
            # it has existed.
            die X::Ronosathwasha::Answer::Malformed.new(:reason("gap without $field"))
                unless %raw{$field}.defined && (~%raw{$field}).chars;
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

    # Decoded here and checked in `Asks`. The pair rule is one rule, so it lives in
    # the role all three meaning types compose rather than being restated as a third
    # guard beside the two above. What escapes is therefore
    # `X::Ronosathwasha::Meaning::ScopeDisagrees` rather than an `Answer` exception,
    # and that is the honest report: the shape of the answer was fine and the meaning
    # it named was not.
    my QuestionScope $scope = %raw<question_scope>.defined
        ?? pick(%SCOPE, %raw<question_scope>, 'question_scope')
        !! QuestionScope;

    return Express.new(
        :$predicate,
        :speech-act(pick(%SPEECH-ACT, %raw<speech_act>, 'speech_act')),
        :question-scope($scope),
        :nominal-predicate($nominal),
        :tense($timeless ?? Tense !! pick(%TENSE, %raw<tense>, 'tense')),
        :aspect(pick(%ASPECT, %raw<aspect>, 'aspect')),
        :polarity(pick(%POLARITY, %raw<polarity>, 'polarity')),
        :modality(pick(%MODALITY, %raw<modality>, 'modality')),
        :@participants,
    );

    CATCH { default { .fail } }
}
