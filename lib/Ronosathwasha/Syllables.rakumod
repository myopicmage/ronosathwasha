=begin pod

=head1 Ronosathwasha::Syllables

The first grammar: a romanised word into its syllables.

Every syllable is exactly one consonant and one vowel. There are no onsetless
syllables, no codas and no clusters, so this grammar is almost the whole of the
phonotactics, and a string that fails it is not a word of the language.

=head2 The inventory comes from the declaration

The tokens hold no letters. C<data/script.toml> lists the eleven consonants and
six vowels, and the grammar reads them through a dynamic variable set by
C<syllables-of>. Writing them out here would be the second copy this repository
keeps deleting, and it would go stale the next time the inventory moves, as it
did when the affricates were dropped.

=head2 Longest match is free

Raku's C<|> is longest-token matching rather than first-match, and interpolating
an array into a regex uses it. So C<th> beats C<t> and C<wa> beats C<a> without
the inventory being sorted, which the Python parser in C<ronosathwasha/script.py>
has to do by hand with a comment explaining why. Ordering the declaration
differently cannot break this grammar.

Use C<||> and that guarantee disappears: it takes the first alternative that
matches, so C<t> would shadow C<th> and every dental fricative would fail.

=end pod

unit module Ronosathwasha::Syllables;

use X::Ronosathwasha;

use Ronosathwasha::Types;
use Ronosathwasha::Script;


grammar Syllabary is export {
    token TOP { <syllable>+ }

    #| Decision 20: a long vowel is its mark written twice, so the optional
    #| tail is a backreference to the vowel's own base rather than another
    #| `<vowel>`. That enforces agreement in the grammar itself: `thii` is a
    #| word and `thie` is two vowels and not one.
    #|
    #| The base, not the whole vowel, because a long glide is `waa`. The
    #| labialisation happens once at the onset and the vowel is what continues.
    #| `<{ ... }>` evaluates the block and matches its result as a pattern.
    #| Plain `$<vowel><base>` in regex position parses as a method call on the
    #| grammar, which is a confusing error rather than a subtle one.
    token syllable { <consonant> <vowel> $<long>=[ <{ ~$<vowel><base> }> ]? }

    token consonant { @*CONSONANTS }

    #| The glide is written before the vowel it marks, so `wa` is one vowel
    #| rather than a consonant and a vowel. It marks labialisation and does not
    #| change which vowel it is, which is why harmony reads `thwa` as `a`.
    token vowel { <glide>? $<base>=[ @*VOWELS ] }

    token glide { 'w' }
}

#| Split a word into syllables, each a pair of spellings as written.
#|
#| No return type, so a failure stays inert; see `Ronosathwasha::Types`.
sub syllables-of(Script:D $script, Str:D $word) is export {
    my @*CONSONANTS = $script.consonant-spellings;
    my @*VOWELS     = $script.vowel-spellings;

    my $match = Syllabary.parse($word);

    # `.parse` anchors to the whole string and returns Nil on failure, which
    # says nothing about where it went wrong. `.subparse` matches as far as it
    # can, so the offset it reached is the first position that is not writable.
    without $match {
        my $partial = Syllabary.subparse($word);

        fail X::Ronosathwasha::Word::NotWritable.new(
            :$word,
            :position($partial ?? $partial.to !! 0),
        );
    }

    #| Each syllable as consonant to vowel, with the vowel carrying its own
    #| length: `thii` gives `th => ii`.
    $match<syllable>.map({ ~.<consonant> => ~.<vowel> ~ (.<long> // '') });
}
