=begin pod

=head1 Ronosathwasha::TestModel

Models that answer the same way every time.

=head2 Why the fake takes raw answers

C<Scripted> is given the hashes a real model would send, and validates them
itself through C<intent-from>. It could have been given ready-made
C<ResponseIntent> objects, which would be less typing and would mean that every
dialogue test ran a path no real model ever takes: the one where validation
already happened somewhere else.

So the fake differs from C<LlamaCpp> in exactly one respect, the absence of a
network. A test can hand it a predicate that does not exist and watch the
refusal travel the same route it will travel in production.

=head2 What it records

C<Scripted> keeps every context it was handed. A dialogue loop that assembles
the wrong prompt is otherwise invisible: the answers are canned, so the loop
passes its tests while feeding a real model nonsense. The recording is what
makes the prompt assertable.

=end pod

unit module Ronosathwasha::TestModel;

use X::Ronosathwasha;

use Ronosathwasha::Types;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Morphology;
use Ronosathwasha::Semantics;
use Ronosathwasha::Intent;
use Ronosathwasha::Model;
use Ronosathwasha::PromptContext;

#| Answers a prepared list in order, validating each as a real model's output.
class Scripted does Model is export {
    has Lexicon:D    $.lexicon    is required;
    has Morphology:D $.morphology is required;

    #| Raw answers, in the shape a model sends them.
    has @.answers;

    #| Every context this was asked with, in order. Tests assert on it.
    has @.seen;

    has Int $!at = 0;

    method respond(PromptContext:D $context) {
        @!seen.push: $context;

        fail X::Ronosathwasha::Answer::Exhausted.new(:given(@!answers.elems))
            if $!at >= @!answers.elems;

        my $raw = @!answers[$!at++];

        intent-from($!lexicon, $!morphology, $raw);
    }

    method asked(--> Int) { $!at }

    method spent(--> Bool) { $!at >= @!answers.elems }
}

#| Always reports the same gap. The useful default for testing anything that has
#| to survive a model which cannot say what it wants: `CHATBOT.md` treats that
#| as the system working, so it should be the easy case to set up rather than
#| the elaborate one.
class Silent does Model is export {
    has Str $.wanted  = 'something';
    has Str $.missing = 'a decision nobody has made';

    method respond(PromptContext:D $context) {
        Gap.new(:$!wanted, :$!missing);
    }
}

#| Answers a fixed intent forever, for tests about the loop rather than about
#| the answers.
class Fixed does Model is export {
    has ResponseIntent:D $.intent is required;

    method respond(PromptContext:D $context) { $!intent }
}

#| Build a scripted model from answers written as an ordinary list of hashes.
#|
#| `**@answers`, not `*@answers`. The single star is the flattening slurpy, so
#| two hashes arrive as four pairs and every field of every answer reads as
#| undefined. The double star takes one element per argument and leaves the
#| structure alone, which is what a list of answers means.
sub scripted(
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    **@answers,
) is export {
    Scripted.new(:$lexicon, :$morphology, :@answers);
}
