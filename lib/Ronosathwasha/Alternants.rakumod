=begin pod

=head1 Ronosathwasha::Alternants

Whether a word chose the right half of an alternating affix.

=head2 What this catches that harmony does not

C<Ronosathwasha::Harmony> asks whether a word's vowels agree with each other.
That is a real invariant and it is not this one. C<thwaswo> is C<a> plus C<o>,
neutral plus back, so its vowels agree perfectly and C<judge> returns
C<Harmonic>. It is nevertheless wrong, because its stem C<thwa> is neutral and
governance is by the stem: neutral counts as front, so the infinitive must be
C<-swe>.

B<Agreement and alternant choice are different properties, and only one of them
was being enforced.> Decision 5 declared the harmony repair complete on
2026-07-28 backed by "the writable lexicon now contains no disharmonious
entries", and three entries survived that check for four days because they were
never disharmonious. They were built from the wrong alternant. This module is
the missing half.

=head2 Two engines, because a listed word will not divide

The obvious implementation is one call to C<parse-word> and a rebuild. It finds
nothing in the lexicon, and the reason is worth stating rather than
rediscovering.

C<parse-word> prefers a word the lexicon defines over the productive division of
it, and C<stems-from> offers every listed word as a stem. So C<thwaswo> matches
as a single stem with no affixes, rebuilds to itself, and reports no problem.
Passing C<Morphemes> explicitly does not help: the stem inventory still contains
the whole word, and the grammar's longest-token alternation still takes it.

That is correct behaviour for reading and useless for auditing. So:

=item B<Decomposition> tries every base that is a proper prefix of the word and
segments the remainder into affixes. This is what checks the lexicon against
itself.

=item B<Rebuilding> parses the word normally and reassembles it from the stem's
harmony class. This is what checks inflected forms in running text, which is
where the lexicon's own entries appear already divided.

Both run. A word that is listed I<and> appears inflected in a sentence is worth
catching from either direction.

=head2 The bases

Listed words, minus the bound morphology, plus the verb stems recovered by
removing an infinitive marker. The last part matters: C<rorothwa> is inflected
throughout the corpus and appears in no file, exactly as C<Words::stems-from>
already documents.

=end pod

unit module Ronosathwasha::Alternants;

use Ronosathwasha::Types;
use Ronosathwasha::Script;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Morphology;
use Ronosathwasha::Harmony;
use Ronosathwasha::Words;

#| One word's verdict: what was written, and what the rules give instead.
class Misalternation is export {
    has Str:D $.word    is required;
    has Str:D $.correct is required;

    method gist(--> Str) { "$!word -> $!correct" }
}

#| The audit, built once and asked many times.
#|
#| A class rather than a sub because the base list costs a pass over the whole
#| lexicon and the caller checks thousands of words. Rebuilding it per word made
#| the sweep take minutes instead of seconds.
class Alternants is export {
    has Script:D     $.script     is required;
    has Lexicon:D    $.lexicon    is required;
    has Morphology:D $.morphology is required;

    has @!bases;
    has @!suffixes;
    has @!prefixes;

    submethod TWEAK {
        # Only morphemes that genuinely alternate. `-sa` is wholly neutral, so
        # there is no wrong half of it to choose.
        my @alternating = $!morphology.current.grep({
            .front-stem.defined && .back-stem.defined && .front-stem ne .back-stem
        });

        @!suffixes = @alternating.grep(*.position == Suffix);
        @!prefixes = @alternating.grep(*.position == Prefix);

        my %bound = $!lexicon.affixes.map(*.roman).Set;
        my @listed = $!lexicon.entries.map(*.roman).unique;

        my $infinitive = $!morphology.by-id('infinitive');
        my @recovered = @listed.map({
            my $w = $_;
            ($infinitive.front-stem, $infinitive.back-stem)
                .first({ $w.ends-with($_) && $w.chars > $_.chars })
                andthen $w.substr(0, $w.chars - .chars)
                orelse Empty;
        }).grep(*.defined);

        @!bases = (@listed.grep({ not %bound{$_}:exists }), @recovered)
            .flat.unique.sort({ .chars });
    }

    #| The word the rules give, or an undefined `Str` when the word is already
    #| right, is not divisible, or has no alternating affix to get wrong.
    method check(Str:D $word --> Str) {
        return $_ with self!by-decomposition($word);
        return $_ with self!by-rebuilding($word);

        Str;
    }

    #| Split the word into a listed base and a run of affixes, then ask what
    #| those affixes should have been.
    method !by-decomposition(Str:D $word --> Str) {
        for @!bases.grep({ .chars < $word.chars && $word.starts-with($_) }) -> $base {
            my $parts = self!segment($word.substr($base.chars));
            next unless $parts.defined && $parts.elems;

            my $class = profile-of($!script, $base);
            next if $class == MixedWord;

            my $correct = $base ~ $parts.map({ .form-for($class) }).join;
            next if $correct eq $word;

            return $correct;
        }

        Str;
    }

    #| Parse the word as the grammar would and reassemble it from the stem's
    #| class. Catches inflected forms, which decomposition misses whenever the
    #| stem is not itself a listed word.
    method !by-rebuilding(Str:D $word --> Str) {
        my $parse = parse-word($!lexicon, $!morphology, $word);

        return Str unless $parse.defined;
        return Str unless $parse.prefixes || $parse.suffixes;

        my $stem  = $parse.stems.join;
        my $class = profile-of($!script, $stem);

        return Str if $class == MixedWord;

        my $correct = (
            $parse.prefixes.map({ .form-for($class) }),
            $stem,
            $parse.suffixes.map({ .form-for($class) }),
        ).flat.join;

        return Str if $correct eq $word;

        $correct;
    }

    #| A remainder read as a sequence of alternating suffixes, either half
    #| accepted. `Nil` when it does not divide cleanly, which is the ordinary
    #| case and not an error.
    method !segment(Str:D $rest --> List) {
        return () unless $rest.chars;

        for @!suffixes -> $m {
            for ($m.front-stem, $m.back-stem) -> $surface {
                next unless $rest.starts-with($surface);

                my $tail = self!segment($rest.substr($surface.chars));
                next unless $tail.defined;

                return ($m, |$tail).List;
            }
        }

        Nil;
    }
}

#| The ordinary way to build one.
sub alternants(
    Script:D     $script,
    Lexicon:D    $lexicon,
    Morphology:D $morphology
    --> Alternants
) is export {
    Alternants.new(:$script, :$lexicon, :$morphology);
}
