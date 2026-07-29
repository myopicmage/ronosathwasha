=begin pod

=head1 Ronosathwasha::LanguageEvidence

What a conversation found out about the language, kept where a conversation
cannot lose it.

=head2 The counterweight to folding

C<ConversationState.fold> destroys what it summarises, deliberately and
visibly. This is where the parts worth keeping go first. Nothing here lives in
the rolling prompt, so a finding survives a conversation growing past its window
and survives the turn that produced it scrolling away.

=head2 Repetition is the signal

A gap the model hits once may be a fluke of phrasing. The same gap twelve times
is a hole in the language, and the number is the difference. So a finding is
recorded once and counted thereafter, and C<by-weight> puts the ones that keep
happening first.

=head2 This is a queue, not an authority

C<CHATBOT.md> is explicit: an observation is never promoted into C<LANGUAGE.md>,
canonical TOML, or executable grammar automatically. Nothing here writes
anything anywhere.

The shape enforces the intent as far as a shape can. A C<Finding> records what
was wanted and what was missing. There is no field for what the answer should
be, because the answer is Kevin's and a system that could store a proposed one
would eventually be asked why it is not applying them.

=end pod

unit module Ronosathwasha::LanguageEvidence;

use Ronosathwasha::Types;
use Ronosathwasha::Checked;
use Ronosathwasha::Model;
use Ronosathwasha::ParseResult;

#| What kind of hole this is.
#|
#| The four differ in what they ask Kevin for, which is the only distinction
#| worth drawing at this stage: a missing meaning wants a decision, a missing
#| word wants a coinage, an ambiguity wants a rule, and a retired form wants
#| nothing except to be noticed.
#|
#| `FindingKind` rather than `Finding::Kind`, because the nested form creates a
#| `Finding` package that collides with the class of that name the moment both
#| are exported. Third time this shape has bitten: a nested declaration claims
#| every name above it, and exporting it exports those too.
our enum FindingKind is export <
    MissingMeaning UnknownWord Ambiguity RetiredUsage
>;

class Finding is export {
    has FindingKind $.kind    is required;

    #| What it was about: the meaning wanted, the word reached for, the form
    #| that divided two ways. Also the identity: two findings with the same kind
    #| and subject are the same finding seen twice.
    has Str $.subject is required;

    has Str $.detail is required;
    has Int $.seen   = 1;

    method gist(--> Str) {
        "[{ $!kind.key }] $!subject: $!detail" ~ ($!seen > 1 ?? " (x$!seen)" !! '');
    }
}

class LanguageEvidence does Checked is export {
    has Finding @.findings;

    #| Record a finding, or count it again if it is already here.
    method record(FindingKind $kind, Str:D $subject, Str:D $detail --> LanguageEvidence) {
        with @!findings.first({ .kind == $kind && .subject eq $subject }) -> $seen {
            return self.with(:findings(@!findings.map({
                $_ === $seen ?? .clone(:seen(.seen + 1)) !! $_
            })));
        }

        self.with(:findings([|@!findings, Finding.new(:$kind, :$subject, :$detail)]));
    }

    #| Take note of whatever this is, if it is anything.
    #|
    #| Multi dispatch rather than a chain of type tests, so adding a fifth thing
    #| worth noticing is a new candidate rather than an edit to a conditional
    #| that everything else also passes through.
    multi method note(Gap:D $gap --> LanguageEvidence) {
        self.record(MissingMeaning, $gap.wanted, $gap.missing);
    }

    multi method note(UnknownStem:D $outcome --> LanguageEvidence) {
        self.record(UnknownWord, $outcome.word, 'writable, and no declared stem accounts for it');
    }

    multi method note(Ambiguous:D $outcome --> LanguageEvidence) {
        self.record(Ambiguity, $outcome.word, $outcome.summary);
    }

    multi method note(RetiredForm:D $outcome --> LanguageEvidence) {
        self.record(RetiredUsage, $outcome.word, $outcome.summary);
    }

    #| Everything else. A recognised word and an unwritable string are both
    #| uninformative: one is the language working and the other is a typo.
    multi method note($anything --> LanguageEvidence) { self }

    method of(FindingKind $kind) { @!findings.grep(*.kind == $kind) }

    #| Most-repeated first, because that is the order to read them in.
    method by-weight { @!findings.sort({ -.seen }) }

    method elems(--> Int) { @!findings.elems }

    method report(--> Str) {
        @!findings ?? self.by-weight.map(*.gist).join("\n") !! 'nothing found yet';
    }
}
