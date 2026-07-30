=begin pod

=head1 X::Ronosathwasha

Every exception this project can raise, in one place.

=head2 Why they are all here

C<X::> is Raku's convention for exceptions and it is only a convention: the
compiler attaches no meaning to the name. What matters is that the tree is
rooted, so C<X::Ronosathwasha::Model::Unknown> reads unambiguously as ours and
C<X::TypeCheck::Binding::Parameter> reads unambiguously as the language's.

They were previously declared inside the modules that raise them, which nested
them: C<Ronosathwasha::Model::X::Model::Unknown> is what
C<class X::Model::Unknown> produces inside C<unit module Ronosathwasha::Model>,
with the module name written twice and the C<X::> looking like a claim on the
root that it was not making.

The ecosystem does it this way. C<Config::TOML>, this distribution's one
dependency, ships C<X::Config::TOML> at the root.

=head2 Two strategies, and which is which

The classes here are used two different ways, and the distinction is
deliberate rather than accidental.

C<Declaration> is infrastructure. A file that will not load means the program is
broken, so those are raised with C<fail>, travel as inert C<Failure> values, and
propagate by method dispatch through code containing no guards.

C<Model::Unknown> and the rest are domain refusals. They are raised the same way
but mean something a caller is expected to handle rather than something that
should abort: a model naming a word that does not exist is the system working.

What is I<not> here: the outcomes in C<Ronosathwasha::ParseResult>. A word that
does not parse is an ordinary value rather than an exception, because in a
chatbot it is the expected case and not a fault.

=end pod

unit module X::Ronosathwasha;

# Nothing here is exported and the groups are named for what went wrong rather
# than for the module that raises it. Both are forced by the same thing: an
# intermediate package leaks into an importing scope, so a group called `Model`
# collides with the role of that name and a group called `Morphology` with the
# class. Grouping by failure reads better regardless, since `Form::NoClass` and
# `Form::MixedStem` are the same problem reached from realization and from
# lookup, and nothing about them is per-module.

# --------------------------------------------------------------- programming ---

#| A functional update named a field that does not exist. Not a domain failure
#| at all: it is a typo, and it is here because Raku's own `.clone` would have
#| accepted it silently and produced a copy with nothing changed.
#|
#| Ungrouped, unlike everything below, because it is a mistake in the code
#| rather than a thing the language or a model can do wrong.
class NoSuchAttribute is Exception {
    has Str $.type   is required;
    has     @.wanted is required;
    has     @.known  is required;

    method message(--> Str) {
        "$!type has no attribute { @!wanted.join(', ') }; it has { @!known.join(', ') }"
    }
}

#| A budget that reserves as much as it has, or more. Not a runtime condition to
#| be handled: it is a configuration that cannot mean anything, so it fails when
#| the budget is built rather than when a prompt first fails to fit.
class Budget::Impossible is Exception {
    has Int $.total    is required;
    has Int $.reserved is required;

    method message(--> Str) {
        "a budget of $!total reserving $!reserved leaves nothing for a prompt"
    }
}

#| The window is too small for what has to go in it.
#|
#| Two subclasses because they want different fixes and a caller cannot tell them
#| apart from an arithmetic. The first is configuration: no conversation, however
#| short, will make room. The second is a conversation whose accumulated summary
#| has outgrown the window, which is a runtime condition and a real one, since
#| folding adds a line every time it removes a turn.
#|
#| Named for the window rather than for `PromptContext` or `ContextPolicy`,
#| following the note above: an intermediate package leaks into an importing
#| scope, and this file has already lost `Model` and `Morphology` that way.
class Window is Exception { }

class Window::Invariants is Window {
    has Int $.available is required;
    has Int $.cost      is required;
    has     @.labels;

    method message(--> Str) {
        "the prompt must always carry { @!labels.join(' and ') }, which costs "
        ~ "$!cost against $!available available. Nothing can be folded to make "
        ~ "room, because none of it may be shortened."
    }
}

class Window::Conversation is Window {
    has Int $.available is required;
    has Int $.cost      is required;
    has Int $.folded    is required;

    method message(--> Str) {
        my $lines = $!folded == 1 ?? 'summary line' !! 'summary lines';

        "every turn is folded and the prompt still costs $!cost against "
        ~ "$!available available, carrying $!folded $lines. Folding cannot help "
        ~ "further: it removes a turn by adding a line."
    }
}

# ------------------------------------------------------------- declarations ---

#| Base for anything wrong with a declaration file. Catching this catches every
#| way a declaration can be unusable, which is the granularity a caller loading
#| several files actually wants.
#|
#| Subclasses reach `path` as `$.path` rather than `$!path`. The twigils are not
#| interchangeable: `$!` is the attribute and is private to the class that
#| declared it, so it is not in scope in a subclass at all. `$.` is the
#| generated accessor, which is inherited like any other method.
class Declaration is Exception {
    has IO::Path $.path is required;
}

#| The file could not be read or parsed at all.
class Declaration::Unreadable is Declaration {
    has Str $.reason is required;

    method message(--> Str) { "could not read $.path: $!reason" }
}

#| The file parsed, and does not contain something required.
class Declaration::MissingTable is Declaration {
    has Str $.table is required;

    method message(--> Str) { "$.path has no [$!table]" }
}

#| A declared value is outside the set this code understands. Not a default and
#| not a warning: a backness of "fornt" is a typo that would otherwise become a
#| harmony class.
class Declaration::BadValue is Declaration {
    has Str $.field   is required;
    has Str $.subject is required;
    has     $.found;

    method message(--> Str) {
        "$.path: $!subject has $!field { $!found.raku }, which is not declared"
    }
}

# ---------------------------------------------------------------- the language ---

#| Asking which alternant a disharmonic stem selects has no answer, because such
#| a stem has no harmony class to select with. A question about a broken word
#| rather than a broken declaration.
class Form::MixedStem is Exception {
    has Str $.morpheme is required;

    method message(--> Str) {
        "$!morpheme has no alternant for a stem that is neither front nor back"
    }
}

#| A word that could not be read as syllables, with the offset reached. The
#| position is the useful part: it says where the word stopped being writable.
class Word::NotWritable is Exception {
    has Str $.word     is required;
    has Int $.position is required;

    method message(--> Str) {
        my $seen = $!word.substr(0, $!position);
        my $rest = $!word.substr($!position);

        "$!word is not writable: $seen.raku() parses, then $rest.raku() does not"
    }
}

class Word::Unrecognised is Exception {
    has Str $.word is required;

    method message(--> Str) {
        "$!word is writable but is not a word this grammar recognises"
    }
}

#| A stem with no harmony class cannot select an alternant, so a disharmonic
#| stem is not something to be realized around. It is a broken word.
class Form::NoClass is Exception {
    has Str $.stem is required;

    method message(--> Str) {
        "$!stem is neither front nor back, so no affix can agree with it"
    }
}

class Form::NoSuchMorpheme is Exception {
    has Str $.wanted is required;

    method message(--> Str) { "the declaration has no current morpheme $!wanted.raku()" }
}

# ----------------------------------------------------------------- the model ---

#| The model named something the declarations do not contain. Carries what it
#| sent, because that string is evidence: a model reaching repeatedly for a word
#| that does not exist is telling you the lexicon has a hole.
class Answer::Unknown is Exception {
    has Str $.field is required;
    has     $.value;

    method message(--> Str) {
        "the model gave $!field as { $!value.raku }, which is not declared"
    }
}

class Answer::Malformed is Exception {
    has Str $.reason is required;

    method message(--> Str) { "the model's answer was malformed: $!reason" }
}

#| A scripted model was asked for more answers than it was given. Only a fake
#| can raise this, and it is a fault in a test rather than in the language: a
#| dialogue that ran longer than its script means the test was not describing
#| what it thought it was.
class Answer::Exhausted is Exception {
    has Int $.given is required;

    method message(--> Str) {
        "the scripted model has only $!given answer{ $!given == 1 ?? '' !! 's' }"
    }
}
