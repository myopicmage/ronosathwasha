=begin pod

=head1 Ronosathwasha::TokenCounter

How much of the window something costs, and how much of it there is.

=head2 Counting is a model's opinion, not a property of the text

A token is whatever a particular tokenizer says it is. The same sentence costs
different amounts to different models, non-ASCII text costs disproportionately
more in most of them, and no rule of thumb survives contact with a script in the
private use area.

So this is a role. The real implementation asks C<llama.cpp> and arrives at
stop 9. What lives here are a fake for tests and an estimate that is named to be
distrusted.

=head2 Reserving is the part people forget

A budget is not the window. If a prompt is allowed to fill the window then there
is no room for the answer, and the failure arrives at generation time as a
truncated or refused response rather than at assembly time as an overflow.

So C<Budget> holds a total and a reservation and answers questions about what
remains. Nothing in this project is allowed to ask how big the window is; it
asks what is available.

=end pod

unit module Ronosathwasha::TokenCounter;

use X::Ronosathwasha;

role TokenCounter is export {
    method count(Str:D $text --> Int) { ... }
}

#| One token per whitespace-separated word. Not what any real tokenizer does,
#| and that is the point: a test asserting boundary behaviour needs an arithmetic
#| it can predict, not a plausible one.
class PerWord does TokenCounter is export {
    method count(Str:D $text --> Int) { $text.words.elems }
}

#| The four-characters-per-token rule of thumb, kept because it is what people
#| reach for, and named so that reaching for it is visible in a diff.
#|
#| It is wrong here in a specific direction, and not the one it first appears.
#| The model never sees the private use area: everything from `read-sentence` to
#| the realizer works in romanisation, and the PUA exists only for the font.
#|
#| What it does see is invented words in a mostly-Latin alphabet, which is worse
#| for the estimate than it sounds. A tokenizer's merges were learned from a
#| corpus that has never contained `rorothwamo`, so the word fragments rather
#| than combining, and `ə` and `ð` are non-ASCII on top of that. Ronosathwasha
#| costs several times what English of the same length costs, and this charges
#| the same for both.
class Approximate does TokenCounter is export {
    has Numeric:D $.chars-per-token = 4;

    method count(Str:D $text --> Int) {
        ($text.chars / $!chars-per-token).ceiling;
    }
}

#| What a prompt is allowed to spend.
class Budget is export {
    has Int:D $.total    is required;

    #| Held back for the model's answer. Never spendable by the prompt.
    has Int:D $.reserved is required;

    submethod TWEAK {
        die X::Ronosathwasha::Budget::Impossible.new(:$!total, :$!reserved)
            if $!reserved >= $!total;
    }

    method available(--> Int) { $!total - $!reserved }

    method fits(Int:D $cost --> Bool) { $cost <= self.available }

    #| How far over, or zero. Callers trim by this rather than by guessing.
    method overflow(Int:D $cost --> Int) { max(0, $cost - self.available) }

    method remaining(Int:D $cost --> Int) { self.available - $cost }
}
