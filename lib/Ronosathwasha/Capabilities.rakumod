=begin pod

=head1 Ronosathwasha::Capabilities

What the language can currently express, derived from the declarations.

=head2 The block that had no declaration behind it

C<PromptContext> requires two invariants and, until this module, B<nothing in C<lib/>
built either one>. Every prompt that had ever existed was assembled by hand in a test or
a probe script. The schema half was safe, because C<response-schema> derives its
enumerations from C<answer-vocabulary>, C<predicate-roots> and
C<participant-stems>. The prose telling the model what
the language can do was the one part of the prompt with no source.

That is not a tidiness problem. A hand-written block can assert a morpheme that does not
exist, and no test, type or validator will notice, because there is nothing for it to
disagree with. It happened: a probe's capabilities line claimed a C<habitual> aspect.
There is no habitual morpheme, C<%ASPECT> is C<simple> and C<continuous> only, and the
model was told otherwise by the only authority it had.

=head2 It builds the axes from the same source as the schema

C<answer-vocabulary>, which is also what C<response-schema> enumerates. That is the point
rather than a convenience: the model is told which values exist by the same table that
decides which values the decoder will accept, so the prompt cannot offer a choice the
grammar refuses or withhold one it permits.

The morpheme inventory comes from C<Morphology.current>, so a superseded morpheme cannot
appear. C<continuous-ji> lost to C<continuous> in decision 10 and is absent here for the
same reason it is absent from a realized word.

=head2 What it deliberately leaves out

B<Morphotactic order.> The model never spells anything. It answers with a semantic
intent, and C<realize-intent> assembles the morphemes: prefixes for modality, polarity and
speech act, then the stem, then tense and aspect. Telling the model the order would be
telling it how to do a job it does not have, and decision C<019> is specifically wary of
inviting it to manufacture forms.

B<The lexicon, with one exception.> Every nameable stem is already in the schema, where it
costs nothing: C<response_format> becomes a sampling grammar and never enters the context.
Repeating 88 stems in the prompt would move them from free to expensive for no gain.

The exception is the interrogative words, and it is not a softening of that rule. A stem
in the schema is a stem the decoder will accept; these five carry a I<constraint> as well,
because naming one commits the whole answer to being a question about the constituent
holding it, and C<intent-from> refuses the answer otherwise. A JSON schema cannot say
that: the same C<if>/C<then> limitation that stops it requiring a scope only for
interrogatives. So the constraint has nowhere to live but here, and the five words have to
come with it or it names nothing.

Derived from C<Lexicon.interrogative-words> rather than typed out, for the reason
everything in this module is derived. A sixth interrogative appears in the prompt the day
it appears in the lexicon.

B<Both allomorphs as separate entries.> Harmony is stated as a rule and the pair is shown
once, because C<Harmony> decides which one appears and the model does not choose.

=head2 Why the composition sentence is load-bearing

An inventory invites a false negative. Given tense values and aspect values as two lists
and no statement about how they relate, a model can conclude that a particular pairing is
unavailable, and one did: asked for a past continuous it reported that Ronosathwasha
"lacks a past continuous tense construction". It composes without difficulty,
C<thinəsedi> and C<tonoothasodu>.

B<A false gap is worse than an invented morpheme.> An invented morpheme is conspicuous and
C<intent-from> rejects it outright. A false gap looks exactly like a real finding, and the
entire value of the gap channel is that Kevin can trust it. So the block says the axes are
independent rather than leaving it to be inferred.

=head2 What plan 039's boundary added, and what it deliberately did not

Two of the three additions are constraints the model would otherwise break. Naming a
question word commits the answer to being a question about that constituent, and breaking
that is a malformed answer that ends the turn: this is the one rule here whose absence
costs a conversation rather than a nuance. Beside it, the fact that makes the constraint
survivable: the question series is open, so questioning an ordinary noun is how you ask
about anything the five listed words do not cover.

B<The third addition tells the model to stop worrying, which is the point.> C<Dialogue>
verifies that every sentence it writes reads back to the meaning that was chosen, and a
handful of inflections do land on words the lexicon already lists. Naming them here would
be an inventory of traps, and this module's own history says what an inventory does to a
model: it reads restrictions into it and reports gaps that are not there. The model cannot
predict a collision and does not need to, so the block says so and says the checking is
handled.

=end pod

unit module Ronosathwasha::Capabilities;

use Ronosathwasha::Intent;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Morphology;
use Ronosathwasha::PromptContext;
use Ronosathwasha::Types;

#| The axis a morpheme role marks, named as the answer vocabulary names it.
#|
#| `MarksSpeechAct` becomes `speech act`, matching `speech_act` with its underscore
#| relaxed. The prefixes exist because an enum's values collide with class names on
#| import, which `CLAUDE.md` records; they carry no meaning here and come off.
sub axis-of(MorphemeRole:D $role --> Str) {
    $role.key.subst(/^ Marks /, '').subst(/(<[a..z]>)(<[A..Z]>)/, { "$0 $1" }, :g).lc;
}

#| The axes the model chooses among, in the order a reader wants them.
#|
#| `kind` is excluded because it is the discriminator of the answer envelope rather than
#| something the language expresses, and a model told that `kind` is a feature of
#| Ronosathwasha would be told something false.
sub semantic-axes(--> Seq) {
    my %v = answer-vocabulary();

    # `question_scope` sits beside `speech_act` because the two are one fact, which
    # is the same reason `Asks` owns both attributes.
    my @order = <speech_act question_scope tense aspect polarity modality role>;

    @order.map(-> $axis {
        # `role` is the argument's role, which the morphology marks as case. Renamed
        # here so the two lists in the block read as being about different things,
        # because they are: one is a semantic choice, the other is a morpheme group.
        my Str $label = $axis eq 'role' ?? 'argument role' !! $axis.subst('_', ' ');

        "  $label: { %v{$axis}.sort.join(', ') }";
    });
}

#| Current morphemes, grouped by what they mark.
#|
#| Only `current` ones, which is the check that keeps fiction out: this cannot name a
#| morpheme `data/morphology.toml` does not declare, because it has nothing to name one
#| from.
sub morpheme-groups(Morphology:D $morphology --> Seq) {
    my %by-axis;

    for $morphology.current -> $morpheme {
        %by-axis{ axis-of($morpheme.role) }.push: $morpheme;
    }

    %by-axis.keys.sort.map(-> $axis {
        my @entries = %by-axis{$axis}.sort(*.id).map({

            # `.forms` gives one entry for an invariant morpheme and both allomorphs for
            # a harmonic one, so the slash appears exactly when there is a choice to
            # describe. Nothing here decides which; see the harmony rule below.
            "{ .id } ({ .forms.join('/') })";
        });

        "  $axis: { @entries.join(', ') }";
    });
}

#| The rules that stop an inventory from being read as a set of restrictions.
#|
#| Every example here is a combination of values that appear in the lists above. Nothing
#| in this string may name a morpheme, a value or a feature that the declarations do not
#| carry, because a hand-written sentence is exactly the hole this module closes and a
#| plausible-sounding example is the easiest way to reopen it. The first draft of this
#| text said "a potential habitual-in-effect" and there is no habitual.
sub composition-rules(Lexicon:D $lexicon --> Str) {
    my Str $questions = $lexicon.interrogative-words.keys.sort.join(', ');

    qq:to/RULES/.trim;
    How these combine:

      - The axes above compose independently except for the pairing rules stated
        below. A past continuous, a negative interrogative future, a potential
        present: all of these are ordinary, and none of them is a gap.
      - Every axis always has a value. Some values are written with no morpheme at
        all, which makes them unmarked rather than absent, and that is the realizer's
        concern rather than yours.
      - A morpheme written as two forms separated by a slash is harmonic. Which form
        appears is decided by the stem's vowel class, not by you.
      - An absent tense is a timeless identity and is available only to a nominal
        predicate. A verb without a tense is not a well-formed word.
      - Continuous aspect requires a tense marker. A timeless identity uses simple
        aspect; never use continuous aspect with an absent tense.
      - A question scope accompanies an interrogative and nothing else. It says which
        constituent the question is about; a statement carries none, and a question
        always carries exactly one. Asking about the predicate asks what is
        happening; asking about the subject or object asks who or what.
      - Some stems already carry the question inside them, and naming one commits
        the whole answer: the speech act must be interrogative and the scope must
        name the very constituent you put it in. A statement that names one, or a
        question about somewhere else, is a self-contradiction and will be refused.
        Name at most one of them per answer. They are:
          $questions
      - You are not limited to those. A question word is the question marker plus an
        ordinary noun, so to ask about anything they do not cover, name the plain
        stem and set the scope to its constituent. The marker is written for you.

    You choose meaning, not spelling. Name the predicate and the features; the
    realizer assembles the word, applies harmony and orders the morphemes. Never
    report a gap because you are unsure how a form would be written.

    Nor because you suspect a word might collide with another one. Every sentence
    written for you is read back and checked against the meaning you chose, and the
    rare inflection that lands on some other listed word is handled without you.
    Choose the plainest meaning; do not work around a collision you cannot see.

    Two different kinds of limit, and they must not be confused:

      - Ronosathwasha cannot express it. This is a real gap and the most useful thing
        you can report.
      - Ronosathwasha can express it, but the answer format above gives you no way to
        select it. The morpheme list is the whole language; the choice list is only
        what this interface currently exposes, and it is smaller. Say which morpheme
        you needed, and that the limit is the interface.

    Reporting the second as though it were the first would tell Kevin his language has
    a hole it does not have.
    RULES
}

#| What the language can currently express, as a prompt invariant.
#|
#| Derived rather than written, so this cannot claim a morpheme the declarations lack
#| and cannot omit one they have.
sub capabilities-invariant(
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    --> PromptInvariant
) is export {
    my Str $text = (
        'This is the whole of what Ronosathwasha currently expresses. Anything absent'
            ~ ' from both lists below is a genuine gap and worth reporting.',
        '',
        'Choices the answer format lets you select:',
        |semantic-axes(),
        '',
        'Every morpheme the language currently declares, by what it marks. This list is'
            ~ ' larger than the one above, and the difference is the interface rather'
            ~ ' than the language:',
        |morpheme-groups($morphology),
        '',
        composition-rules($lexicon),
    ).join("\n");

    PromptInvariant.new(:label('language capabilities'), :$text);
}
