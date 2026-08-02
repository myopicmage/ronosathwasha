=begin pod

=head1 Ronosathwasha::ParseResult

What happened when a word was read, as a value.

=head2 These are not failures

C<Ronosathwasha::Data> raises a C<Failure> when a declaration will not load,
because a missing C<script.toml> means the program is broken and nothing
downstream can proceed. Nothing here is like that.

A word that does not parse is the ordinary output of a chatbot doing its job.
C<CHATBOT.md> is explicit that the model's confusion is the useful part: a
learner writing C<yomirime> should be told that the command marker moved in
decision 16, not handed a stack trace. So every outcome below is an ordinary
value a caller inspects, and none of them propagates.

The split is worth stating once: the railway carries infrastructure failures,
and domain outcomes are values. Using C<Failure> for both would make "I do not
know that word" behave like "the disk is gone".

=head2 Ordering matters more than it looks

C<yomirime> is built from a stem the lexicon knows and a prefix that has not
existed since decision 16. Classified stem-first it is an unknown construction;
classified retirement-first it is a specific, dated, answerable fact. The second
is the one worth saying, so retirement is checked before anything else that
could also explain the failure.

=end pod

unit module Ronosathwasha::ParseResult;

use Ronosathwasha::Types;
use Ronosathwasha::Script;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Morphology;
use Ronosathwasha::Syllables;
use Ronosathwasha::Words;

role ParseOutcome is export {
    method word(--> Str)    { ... }
    method summary(--> Str) { ... }
}

#| The word divided, unambiguously.
class Recognised does ParseOutcome is export {
    has WordParse $.division is required;

    method word(--> Str) { $!division.text }

    method summary(--> Str) {
        my @parts = (
            $!division.prefixes.map(*.id),
            $!division.stems.map({ "[$_]" }),
            $!division.suffixes.map(*.id),
        ).flat;

        "{ self.word }: { @parts.join(' + ') }"
    }
}

#| The word divides more than one way, and both divisions use only declared
#| morphemes. `thinəmedi` is the attested case: a stem inflected for present
#| continuous, or two stems compounded.
class Ambiguous does ParseOutcome is export {
    has Str       $.word      is required;
    has WordParse @.divisions is required;

    method summary(--> Str) {
        my @readings = @!divisions.map({
            (.prefixes.map(*.id), .stems.map({ "[$_]" }), .suffixes.map(*.id)).flat.join(' + ')
        });

        "$!word divides { @!divisions.elems } ways: { @readings.join(' / ') }"
    }
}

#| Writable, and built on something the lexicon does not contain. This is the
#| outcome that asks Kevin for a word.
class UnknownStem does ParseOutcome is export {
    has Str $.word is required;

    method summary(--> Str) {
        "$!word is writable, and no declared stem accounts for it"
    }
}

#| Writable, and using a morpheme the language has replaced. The most useful
#| outcome here, because it can name the decision and the replacement.
class RetiredForm does ParseOutcome is export {
    has Str      $.word     is required;
    has Morpheme $.morpheme is required;
    has Morpheme $.replaced-by;

    method summary(--> Str) {
        my $now = $!replaced-by.defined
            ?? ", replaced by { $!replaced-by.id }"
            !! '';

        "$!word uses { $!morpheme.id }, retired by decision { $!morpheme.decision }$now"
    }
}

#| Not writable in the script at all, with the offset where it stopped being
#| so. A different kind of wrong from every outcome above: this one is not a
#| question about the language.
class Unwritable does ParseOutcome is export {
    has Str $.word     is required;
    has Int $.position is required;

    method summary(--> Str) {
        "$!word cannot be written: it stops parsing at character $!position"
    }
}

#| The frugal grammar's greedy twin, for detecting the words that divide both
#| ways. Grammar inheritance overrides one rule and keeps the rest.
grammar Greedy is Morphemes {
    regex TOP { <prefix>* <stem>+ <suffix>* }
}

#| Find a retired morpheme that would explain this word, if one does.
sub retirement-in(Morphology:D $morphology, Str:D $word --> Morpheme) {
    for $morphology.superseded -> $old {
        next unless $old.orthography == Writable;

        my $form = $old.form // '';
        next unless $form.chars;

        my Bool $found = $old.position == Prefix
            ?? $word.starts-with($form)
            !! $word.ends-with($form);

        return $old if $found;
    }

    Morpheme;
}

#| Classification is a pure function of the declarations and the bare word.
#|
#| `read-sentence` calls it once per word, and the inventory matrix reads many
#| different sentences built from the same small vocabulary. Keep the outcome,
#| not just the intermediate division: retirement, ambiguity and unwritable
#| results are all stable values too. Declaration objects are keyed by identity,
#| so a separately loaded or mutated declaration can never receive stale prose.
my %CLASSIFY-CACHE;

#| Read one word and say what happened, reusing a result for the same declarations.
sub classify(
    Script:D     $script,
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Str:D        $word,
    --> ParseOutcome
) is export {
    my $bare = $word.lc.subst(/<[?.,!]>+$/, '');

    my $key = "{ $script.WHICH }|{ $lexicon.WHICH }|{ $morphology.WHICH }|$bare";

    return %CLASSIFY-CACHE{$key} if %CLASSIFY-CACHE{$key}:exists;

    my $outcome = classify-uncached($script, $lexicon, $morphology, $bare);
    %CLASSIFY-CACHE{$key} = $outcome;
    $outcome;
}

sub classify-uncached(
    Script:D     $script,
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Str:D        $bare,
    --> ParseOutcome
) {

    my $syllables = syllables-of($script, $bare);

    without $syllables {
        return Unwritable.new(
            :word($bare),
            :position($syllables.self.exception.position),
        );
    }

    my $frugal = parse-word($lexicon, $morphology, $bare);

    # Retirement is checked before the division is trusted and before an
    # unknown stem is reported, because a retired morpheme explains the failure
    # more precisely than either.
    with retirement-in($morphology, $bare) -> $old {
        return RetiredForm.new(
            :word($bare),
            :morpheme($old),
            :replaced-by($old.superseded-by.defined ?? $morphology.by-id($old.superseded-by) !! Morpheme),
        ) unless $frugal.defined;
    }

    return UnknownStem.new(:word($bare)) without $frugal;

    my $greedy = parse-word($lexicon, $morphology, $bare, :grammar(Greedy));

    if $greedy.defined && $greedy.stems.List !eqv $frugal.stems.List {
        return Ambiguous.new(:word($bare), :divisions($frugal, $greedy));
    }

    Recognised.new(:division($frugal));
}
