=begin pod

=head1 Ronosathwasha::Model

The interface a model satisfies, and nothing else.

One method, so a fake and a local server are interchangeable and the dialogue loop
can be tested without either.

=head2 The parameter has a type now

Until stop 9 this role declared C<method respond($context --> ResponseIntent)> with
the parameter unconstrained, and the comment explaining why was longer than the file
it apologised for. Naming C<PromptContext> closed a compile-time cycle:
C<Model> wanted it, C<PromptContext> holds a C<ConversationState>, and that reached
back for C<Express> and C<Gap> to write its summaries, which lived here.

Moving the intent types to C<Ronosathwasha::Intent> broke the loop, so the role can
finally say what it takes.

B<It says it rather than enforces it, and the difference is worth knowing.> A Raku
role with a stubbed method requires an implementation of that I<name> and does not
check its signature, so a class declaring C<method respond($context)> still satisfies
this role and will still accept a C<Str>. Verified rather than assumed. Rust traits
and Java interfaces bind the signature; Raku does not.

So the enforcement still lives in each implementation, exactly where it did before,
and what changed is that the contract is now written where somebody about to write an
implementation will read it. That is worth the split on its own, and it is less than
the split first appeared to buy.

=head2 Why the file is this small

Because the split is the point. The types a model returns are about the language, and
they are used by eight things that have no interest in transport:
C<ConversationState> summarising a turn, C<LanguageEvidence> recording a gap, the
corpus tests, the context tests. Three things want the interface.

A file holding only a role reads thin, and it is the shape that lets the other eight
stop importing an interface they never call.

=end pod

unit module Ronosathwasha::Model;

use Ronosathwasha::Intent;
use Ronosathwasha::PromptContext;

#| The interface a model satisfies.
#|
#| `PromptContext:D`, not a bare `$context`. A model is handed the whole prompt,
#| invariants and conversation together, already fitted to a budget by
#| `Ronosathwasha::ContextPolicy`. It is not handed a `ConversationState` and left to
#| work out what else it needs, and it is not handed a string.
role Model is export {
    method respond(PromptContext:D $context --> ResponseIntent) { ... }
}
