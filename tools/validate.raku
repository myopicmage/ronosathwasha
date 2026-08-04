#!/usr/bin/env raku

=begin pod

=head1 NAME

validate.raku - validate romanised Rono at an explicit language layer

=head1 SYNOPSIS

    make validate TEXT='Lari thinəme.'
    make validate LEVEL=word TEXT='modekevinsweme'
    make validate LEVEL=writing TEXT='nu'

=head1 LEVELS

=over 4

=item writing

Every word obeys the declared syllable structure and can be written in the
script. Vocabulary and grammar do not matter.

=item word

Every word is declared or can be divided into declared productive morphology.
A valid compound may have more than one reading.

=item sentence

The sentence has a grammatical clause head and a recoverable semantic reading.

=back

=end pod

use Ronosathwasha::Chatbot;
use Ronosathwasha::Script;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Morphology;
use Ronosathwasha::Syllables;
use Ronosathwasha::ParseResult;
use Ronosathwasha::Actions;

subset Level of Str where * eq <writing word sentence>.any;

sub words-in(Str:D $text --> Seq) {
    $text.words.map({ .subst(/<[?.,!]>+$/, '') }).grep(*.chars);
}

sub describe-count(Int:D $count --> Str) {
    "$count { $count == 1 ?? 'word' !! 'words' }"
}

sub validate-writing(Script:D $script, Str:D $text --> Bool) {
    my Str @words = words-in($text);

    unless @words {
        say 'INVALID writing';
        say 'reason: no words';
        return False;
    }

    for @words -> $word {
        my $syllables = syllables-of($script, $word.lc);

        unless $syllables.defined {
            say "INVALID writing";
            say "word: $word";
            say "reason: { $syllables.self.exception.message }";
            return False;
        }
    }

    say "VALID writing ({ describe-count(@words.elems) })";
    True;
}

sub validate-words(
    Script:D     $script,
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Str:D        $text,
    --> Bool
) {
    my Str @words = words-in($text);
    my Str @ambiguities;

    unless @words {
        say 'INVALID word';
        say 'reason: no words';
        return False;
    }

    for @words -> $word {
        given classify($script, $lexicon, $morphology, $word) {
            when Recognised { }
            when Ambiguous  { @ambiguities.push: .summary }
            default {
                say "INVALID word";
                say "word: { .word }";
                say "reason: { .summary }";
                return False;
            }
        }
    }

    say "VALID word ({ describe-count(@words.elems) })";
    @ambiguities.map({ say "ambiguous: $_" });
    True;
}

sub validate-sentence(
    Script:D     $script,
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Str:D        $text,
    --> Bool
) {
    sub report-clause(Reading:D $reading, Str:D $label = '') {
        my Str $kind = $reading.nominal-predicate ?? 'nominal' !! 'verbal';
        my Str $prefix = $label.chars ?? "$label " !! '';

        say "{$prefix}predicate: { $reading.predicate }";
        say "{$prefix}kind: $kind";
        say "{$prefix}speech-act: { $reading.speech-act.key }";
        # Reported as absent rather than as an implicit present. The old line
        # printed `tense: Present (implicit)` for a sentence decision 22 says
        # is not located in time, and a tool whose job is telling you what a
        # sentence means should not name a tense that is not there.
        say $reading.tense.defined
            ?? "{$prefix}tense: { $reading.tense.key }"
            !! "{$prefix}tense: none, an identity with no time attached";
    }

    given read-sentence($script, $lexicon, $morphology, $text) {
        when Understood {
            my $reading = .reading;

            say 'VALID sentence';

            if $reading ~~ CoordinatedReading {
                say "clauses: { $reading.clauses.elems }";
                say "connectors: { $reading.connectors.join(', ') }";

                for $reading.clauses.kv -> $index, $clause {
                    report-clause($clause, "clause { $index + 1 }");
                }
            } else {
                report-clause($reading);
            }

            return True;
        }

        when WrongOrder {
            say 'INVALID sentence';
            say "reason: { .summary }";
            return False;
        }

        # Not `INVALID`, deliberately. Decision 25 makes the sentence
        # grammatical; what fails is this software's one-scope representation,
        # and a tool that called the language broken for the code's limit
        # would be reporting the wrong defect.
        when NotRepresentable {
            say 'UNREPRESENTABLE sentence';
            say "reason: { .summary }";
            return False;
        }

        when NotUnderstood {
            say 'INVALID sentence';
            say "word: { .word }";
            say "reason: { .because.summary }";
            return False;
        }
    }
}

sub MAIN(
    Level :$level = 'sentence',
    *@text,
) {
    my Str $text = @text.elems ?? @text.join(' ') !! $*IN.slurp.trim;

    unless $text.chars {
        note 'Provide Rono as arguments or on standard input.';
        exit 2;
    }

    my IO::Path $data = repository-root.add('data');
    my $script     = load-script($data.add('script.toml'));
    my $lexicon    = load-lexicon($data.add('lexicon.toml'));
    my $morphology = load-morphology($data.add('morphology.toml'));

    my Bool $valid = do given $level {
        when 'writing' { validate-writing($script, $text) }
        when 'word'    { validate-words($script, $lexicon, $morphology, $text) }
        when 'sentence' {
            validate-sentence($script, $lexicon, $morphology, $text)
        }
    };

    exit($valid ?? 0 !! 1);
}
