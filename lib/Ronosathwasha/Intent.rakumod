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

#| The wire names for `Semantics::QuestionScope`, and deliberately not all of it.
#|
#| Unprefixed, because the reason the enum's values carry `Questions` is a Raku one:
#| an enum's values become symbols in every importing scope, and `Subject`, `Object`
#| and `Predicate` are words this repo wants for other things. A model has no import
#| table to collide with, and `subject` here is the same string `%ROLE` uses for the
#| same constituent.
#|
#| Three of five, which is the enum read through what an `Express` can carry. A
#| `Reading` can question a locative or an unmarked word because the parsed sentence
#| contains the word the marker sat on. An intent contains only a predicate and
#| subject-or-object participants, so a scope beyond those would name a constituent
#| the answer has no way to hold, and realization would refuse it every time. A
#| decoder must not offer a choice that only ever ends in refusal; a model that
#| needs the locative reports the interface gap instead, which is the channel the
#| capabilities block teaches for exactly this.
#|
#| No open-versus-polar entry, deliberately. `to-` makes a question and does not imply
#| a yes-or-no one, so there is no such choice for a model to get wrong.
my constant %SCOPE    = (
    predicate => QuestionsPredicate,
    subject   => QuestionsSubject,
    object    => QuestionsObject,
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

        # Beside `speech_act` because the two are one fact: an interrogative names a
        # scope and nothing else may, which `Asks` enforces. The schema cannot say
        # "required iff interrogative" without `if`/`then`, so the wire treats it as
        # optional and the pairing is checked where the meaning types are built.
        question_scope => %SCOPE.keys.sort.List,

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

#| The exact keys each answer shape may carry, mirroring `response-schema`'s
#| properties one for one.
#|
#| Plan `014` requires rejecting unknown fields even when the server claims
#| schema success, and `ModelProtocol`'s pod has promised the check happens
#| twice since the beginning; review `027` found it happening once, in the
#| sampling grammar only. A key outside these sets is a model answering a
#| question nobody asked, and a `gap` carrying `predicate` is a model answering
#| two at once.
my constant $EXPRESS-KEYS = <
    kind predicate speech_act question_scope tense aspect polarity modality
    nominal_predicate arguments
>.Set;
my constant $GAP-KEYS      = <kind wanted missing>.Set;
my constant $ARGUMENT-KEYS = <role stem>.Set;

sub refuse(Str:D $reason) {
    die X::Ronosathwasha::Answer::Malformed.new(:$reason);
}

sub exact-keys(%raw, Set:D $allowed, Str:D $shape) {
    my @unknown = %raw.keys.grep({ not $allowed{$_} }).sort;

    refuse("$shape carrying { @unknown.join(', ') }, which it has no field for")
        if @unknown;
}

#| A required field: present, not null, and a string.
#|
#| Distinguished from absent-with-a-default, because JSON has three ways to not
#| say something and they do not mean the same thing: a missing key is an
#| omission the shape may define, an explicit null is a refusal to answer, and
#| a wrong type is a different answer entirely. `~`-coercion used to flatten
#| all three into a string, which is how `wanted = 42` became the well-typed
#| gap `"42"` on its way to the evidence log.
sub required-str(%raw, Str:D $field, Str:D $shape --> Str) {
    refuse("$shape without $field") unless %raw{$field}:exists;
    refuse("$field is null") unless %raw{$field}.defined;
    refuse("$field is { %raw{$field}.^name }, not a string")
        unless %raw{$field} ~~ Str;

    %raw{$field};
}

#| An optional field: absence is a meaning, so only presence is checked, and a
#| present value must be non-null and of the given type.
sub optional-typed(%raw, Str:D $field, Mu:U $type) {
    return unless %raw{$field}:exists;

    refuse("$field is null; omit the field to mean its absence")
        unless %raw{$field}.defined;
    refuse("$field is { %raw{$field}.^name }, not { $type.^name.lc }")
        unless %raw{$field} ~~ $type;
}

#| The single words the lexicon lists, which both vocabularies start from.
sub listed-words(Lexicon:D $lexicon --> Seq) {
    my $affixes = $lexicon.affixes.map(*.roman).Set;

    $lexicon.entries
        .map(*.roman)
        .grep({ not $affixes{$_} and not .contains(' ') });
}

#| The bare stem an infinitive recovers, or `Empty` for any other word.
sub bare-stem-of(Str:D $form, @markers) {
    with @markers.first({ $form.ends-with($_) && $form.chars > .chars }) -> $marker {
        $form.substr(0, $form.chars - $marker.chars)
    } else {
        Empty
    }
}

#| Every stem a model may name as a predicate: roots the realizer can inflect.
#|
#| The listed words minus the infinitive forms themselves, plus the bare stems
#| those infinitives recover. The exclusion is review `027`'s finding: one flat
#| set offered `miriswe` as a predicate root, and a surface verb already
#| wearing its infinitive morpheme cannot be inflected again without changing
#| meaning. `miriswese` is what the realizer built from it, and the reader
#| necessarily divides that as the nominal `miri` plus copula plus tense: a
#| verbal past became a nominal past, silently, end to end.
sub predicate-roots(Lexicon:D $lexicon, Morphology:D $morphology --> Set) is export {
    my @markers = $morphology.by-id('infinitive').forms;
    my @listed  = listed-words($lexicon);

    my @roots = @listed.map(-> $form {
        my @bare = bare-stem-of($form, @markers);

        @bare ?? @bare.Slip !! $form;
    });

    @roots.Set;
}

#| Every stem a model may name as a participant: whole words that can stand as
#| constituents.
#|
#| The infinitives stay in, because a nonfinite verb is a legal constituent and
#| `Thinəswe twame` is corpus. The bare stems stay out, because `miri` is the
#| piece of a word rather than a word, and a constituent built on it would not
#| survive reading. The old flat set was wrong in both directions at once.
#|
#| The morphology parameter is unused and kept anyway: the two vocabularies are
#| a pair, callers hold both arguments, and an asymmetric signature would make
#| the swap between them a refactor instead of a name change.
sub participant-stems(Lexicon:D $lexicon, Morphology:D $morphology --> Set) is export {
    listed-words($lexicon).Set;
}

#| Refuse an answer whose stems ask a question its other fields deny.
#|
#| `toro` is "who". A model naming it has asked something, whatever `speech_act`
#| claims, because the question is inside the word and no field can take it back
#| out. So the answer is self-inconsistent: not a language failure, not a gap,
#| just a model contradicting itself, and review `038` classifies it as
#| malformed for that reason.
#|
#| This is the check that needs nothing but decoded fields and declarations,
#| which is why plan `039` puts it here rather than above `intent-from`. It
#| cannot see spelling collisions and does not try; that is the boundary the
#| next stop builds, and it needs the realizer and the reader to see anything at
#| all.
#|
#| Forty of `t/28`'s forty-seven acknowledged mismatches are this one rule
#| unstated: five interrogatives times eight shapes, every one of them an answer
#| that named a question word and then described a sentence that was not a
#| question, or was a question about somewhere else.
sub check-interrogative-consistency(
    Lexicon:D      $lexicon,
    Str:D          $predicate,
    Participant    @participants,
    SpeechAct:D    $act,
    QuestionScope  $scope,
) {
    my Set $interrogatives = $lexicon.interrogative-words;

    # Every constituent that named one, paired with the scope that would agree
    # with it.
    #
    # `(QuestionsPredicate) => $predicate`, and the parentheses are load-bearing.
    # A bare identifier to the left of `=>` is auto-quoted, so writing it without
    # them yields the *string* "QuestionsPredicate" as the key, and the
    # comparison below then fails against every enum value forever. The parens
    # force it to be read as a term.
    my Pair @named = (
        ($interrogatives{$predicate} ?? ((QuestionsPredicate) => $predicate) !! Empty),
        @participants.grep({ $interrogatives{ .stem } }).map({
            .role == Subject
                ?? ((QuestionsSubject) => .stem)
                !! ((QuestionsObject)  => .stem)
        }),
    ).flat;

    return unless @named;

    # More than one, and the type cannot say which the marker sat on. The same
    # limit review `029` found for repeated roles, reached from the other side:
    # `Toro tomwuyu thinəme?` ("who eats what?") may well be grammatical Rono,
    # and this refuses to claim the interface can carry it rather than ruling on
    # the language.
    die X::Ronosathwasha::Answer::Malformed.new(
        :reason("{ @named.elems } question words ({ @named.map(*.value).join(', ') })"
            ~ ', and the scope can point at only one'),
    ) if @named > 1;

    # `.key` twice over would be two different `.key`s: the Pair's, then the enum
    # value's own name. Named once here rather than read as a chain.
    my Pair          $only   = @named[0];
    my QuestionScope $agrees = $only.key;
    my Str           $where  = $agrees.key.subst('Questions', '').lc;

    die X::Ronosathwasha::Answer::Malformed.new(
        :reason("{ $act.key.lc } naming the question word { $only.value.raku }"
            ~ ", which asks whatever the speech act says"),
    ) unless $act == Interrogative;

    die X::Ronosathwasha::Answer::Malformed.new(
        :reason("the question word { $only.value.raku } is the $where"
            ~ ", but the scope questions the "
            ~ ($scope.defined ?? $scope.key.subst('Questions', '').lc !! 'nothing named')),
    ) unless $scope.defined && $scope == $agrees;
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
        exact-keys(%raw, $GAP-KEYS, 'a gap');

        my Str $wanted  = required-str(%raw, 'wanted',  'a gap');
        my Str $missing = required-str(%raw, 'missing', 'a gap');

        # An empty string is the shape a model reaches for when the schema
        # demands a field it has nothing to put in, and a gap that reports
        # nothing is worse than no gap: the gap channel is the evidence log.
        refuse("a gap with an empty $_") for <wanted missing>.grep({ !%raw{$_}.chars });

        return Gap.new(:$wanted, :$missing);
    }

    die X::Ronosathwasha::Answer::Malformed.new(:reason("unknown kind { $kind.raku }"))
        unless $kind eq 'express';

    exact-keys(%raw, $EXPRESS-KEYS, 'an express');

    # The optional fields, where absence is a meaning the shape defines and an
    # explicit null is a refusal to answer. Checked before anything reads them,
    # because `.defined`-style reads treat null and absent alike, and review
    # `027` showed exactly what that flattening costs: `nominal_predicate =
    # "false"` was a nominal, and a null tense was a timeless identity nobody
    # declared.
    optional-typed(%raw, 'question_scope',    Str);
    optional-typed(%raw, 'tense',             Str);
    optional-typed(%raw, 'nominal_predicate', Bool);
    optional-typed(%raw, 'arguments',         Positional);

    # Two vocabularies, by semantic position. A predicate must be a root the
    # realizer can inflect and a participant must be a word that can stand as
    # a constituent, and review `027` showed what one flat set costs in each
    # direction.
    my Set $roots = predicate-roots($lexicon, $morphology);
    my Set $words = participant-stems($lexicon, $morphology);

    my Str $predicate = required-str(%raw, 'predicate', 'an express');

    die X::Ronosathwasha::Answer::Unknown.new(:field<predicate>, :value(%raw<predicate>))
        unless $roots{$predicate};

    for <speech_act aspect polarity modality> -> $field {
        required-str(%raw, $field, 'an express');
    }

    my Participant @participants = @(%raw<arguments> // []).map: -> $a {

        # Checked rather than assumed, because the shape is easy to get subtly
        # wrong and the symptom is misleading. A hash written straight into an
        # array literal flattens into its pairs, so `[ %( role => ... ) ]` is
        # two Pairs and not one argument, and every field then reads as
        # undefined rather than as absent.
        die X::Ronosathwasha::Answer::Malformed.new(:reason('an argument is not an object'))
            unless $a ~~ Associative;

        my %a := $a;

        exact-keys(%a, $ARGUMENT-KEYS, 'an argument');

        my Str $stem = required-str(%a, 'stem', 'an argument');

        # `:field('argument stem')`, not `:field<argument stem>`. The angle
        # brackets are the word-quoting construct, so a space inside them makes
        # a two-element List rather than a string with a space in it.
        die X::Ronosathwasha::Answer::Unknown.new(:field('argument stem'), :value(%a<stem>))
            unless $words{$stem};

        Participant.new(:role(pick(%ROLE, required-str(%a, 'role', 'an argument'), 'argument role')), :$stem);
    }

    # `return`, because the `CATCH` below is the last statement of the sub and
    # would otherwise supply its value. Typed by `optional-typed` above, so
    # this default fills absence only, never repairs a string pretending to be
    # a boolean.
    my Bool $nominal = (%raw<nominal_predicate>:exists) ?? %raw<nominal_predicate> !! False;

    # An absent tense is a timeless identity, and only a nominal predicate has one.
    # A verb without a tense morpheme is not a well-formed word, so this refuses the
    # pair rather than defaulting a tense in and realizing something nobody asked
    # for. Checked here because a schema-constrained decoder can guarantee that both
    # fields are the right shape and cannot guarantee that the combination means
    # anything.
    my Bool $timeless = not %raw<tense>.defined;
    my Aspect $aspect = pick(%ASPECT, %raw<aspect>, 'aspect');

    die X::Ronosathwasha::Answer::Malformed.new(
        :reason('a verbal predicate with no tense; only an identity may be timeless'),
    ) if $timeless && not $nominal;

    die X::Ronosathwasha::Answer::Malformed.new(
        :reason('continuous aspect requires a tense marker'),
    ) if $timeless && $aspect == Continuous;

    # Decoded here and checked in `Asks`. The pair rule is one rule, so it lives in
    # the role all three meaning types compose rather than being restated as a third
    # guard beside the two above. What escapes is therefore
    # `X::Ronosathwasha::Meaning::ScopeDisagrees` rather than an `Answer` exception,
    # and that is the honest report: the shape of the answer was fine and the meaning
    # it named was not.
    my QuestionScope $scope = %raw<question_scope>.defined
        ?? pick(%SCOPE, %raw<question_scope>, 'question_scope')
        !! QuestionScope;

    # A scope naming a constituent is a promise that the marker has exactly one
    # place to land. Zero was always refused; more than one is review `029`'s
    # finding: the schema permits repeated roles, so "question the subject"
    # with two subjects marked both (`telari tenari thinəme?`) while the type
    # recorded one scoped constituent, and nothing said which. Until the type
    # can identify a carrier, the combination is refused. This does not decide
    # whether repeated participants are grammatical Rono; it refuses to claim
    # the interface can question one without representing which one.
    my Argument $questioned = do given $scope {
        when QuestionsSubject { Subject }
        when QuestionsObject  { Object }
        default               { Argument }
    };

    my Int $carriers = $questioned.defined
        ?? @participants.grep(*.role == $questioned).elems
        !! 1;

    die X::Ronosathwasha::Answer::Malformed.new(
        :reason("a question about the { $questioned.key.lc } with "
            ~ ($carriers == 0
                ?? "no { $questioned.key.lc } to mark"
                !! "$carriers { $questioned.key.lc }s and a scope that names one")),
    ) if $carriers != 1;

    my SpeechAct $act = pick(%SPEECH-ACT, %raw<speech_act>, 'speech_act');

    check-interrogative-consistency($lexicon, $predicate, @participants, $act, $scope);

    return Express.new(
        :$predicate,
        :speech-act($act),
        :question-scope($scope),
        :nominal-predicate($nominal),
        :tense($timeless ?? Tense !! pick(%TENSE, %raw<tense>, 'tense')),
        :$aspect,
        :polarity(pick(%POLARITY, %raw<polarity>, 'polarity')),
        :modality(pick(%MODALITY, %raw<modality>, 'modality')),
        :@participants,
    );

    CATCH { default { .fail } }
}
