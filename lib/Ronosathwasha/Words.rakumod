=begin pod

=head1 Ronosathwasha::Words

A word into the morphemes it is built from.

Decision 16 fixed the order: modality, negation, speech act, predicate, and the
tense and aspect markers after it. This grammar recognises that shape without
naming a single morpheme, because C<data/morphology.toml> names them all and
C<data/lexicon.toml> holds the stems.

=head2 Position is what disambiguates

C<me> is the present tense and it is also the negator. C<mo> is the same pair
the other way round. Nothing about the letters distinguishes them, and the
lexicon spent five lines of comment saying so.

Here the two never compete: prefixes are matched from the prefix inventory and
suffixes from the suffix inventory, both taken from the declaration, so a C<me>
before the stem can only be negation and a C<me> after it can only be tense.
The comment became a field, and the field became a lookup.

=head2 Why this is a regex and not a token

Raku's C<token> ratchets: its quantifiers never give back what they matched.
That is usually what you want and here it is fatal. C<medime> is the stem
C<medi> with a present tense, but C<me> is also a legal prefix, so a ratcheting
C<< <prefix>* >> takes it, leaves C<dime> to the stem, and fails without ever
reconsidering. Declaring C<parse> a C<regex> restores backtracking, and the
grammar tries the other division.

=end pod

unit module Ronosathwasha::Words;

use X::Ronosathwasha;

use Ronosathwasha::Types;
use Ronosathwasha::Script;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Morphology;


#| One word, divided. The morphemes are named by identity rather than by form,
#| so a caller never has to ask what a `me` was doing.
class WordParse is export {
    has Str      $.text    is required;
    has Morpheme @.prefixes;
    has Str      @.stems;
    has Morpheme @.suffixes;

    method morpheme-ids(--> Seq) {
        (@!prefixes.map(*.id), @!suffixes.map(*.id)).flat;
    }

    method has-role(MorphemeRole $role --> Bool) {
        so (@!prefixes, @!suffixes).flat.first(*.role == $role);
    }

    method with-role(MorphemeRole $role) {
        (@!prefixes, @!suffixes).flat.first(*.role == $role);
    }
}

grammar Morphemes is export {
    # A regex rather than a token, so the quantifiers can give back. See the
    # module documentation: `medime` depends on it.
    #
    # `<stem>+?` is frugal rather than greedy, and the difference is a genuine
    # ambiguity rather than a tuning choice. `thinəmedi` divides two ways: the
    # stem `thinə` with a present tense and a continuous aspect, which is "I am
    # eating", or the stems `thinə` and `medi`, which is "food" and "go" run
    # together. Both are built entirely from declared morphemes.
    #
    # Taking the fewest stems prefers inflection over compounding, which is the
    # reading the corpus attests. It is a default, not a resolution: reporting
    # that a word has more than one division belongs with the parse result,
    # where a caller can be told rather than quietly given one answer.
    regex TOP { <prefix>* <stem>+? <suffix>* }

    token prefix { @*PREFIXES }
    token suffix { @*SUFFIXES }
    token stem   { @*STEMS }
}

#| Every stem a word may be built on.
#|
#| The lexicon's own entries, plus verb stems recovered by removing an
#| infinitive marker. `rorothwaswo` is listed and `rorothwa` is not, yet
#| `LANGUAGE.md` decision 16 inflects the latter, so the stem is derived rather
#| than demanded of the file.
sub stems-from(Lexicon:D $lexicon, Morphology:D $morphology --> Seq) {
    my $infinitive = $morphology.by-id('infinitive');
    my @markers = $infinitive.forms;

    # The bound morphology is in the lexicon too, and must not be offered as a
    # stem. Left in, `di` and `me` and `yi` compete with real stems, and
    # `medime` divides as negation plus `di` plus `me`, which is three
    # morphemes that all exist and a word that means nothing.
    my $affixes = $lexicon.affixes.map(*.roman).Set;

    my @listed = $lexicon.entries
        .map(*.roman)
        .grep({ not $affixes{$_} and not .contains(' ') });

    my @bare = @listed.map(-> $form {
        @markers.first({ $form.ends-with($_) && $form.chars > .chars })
            ?? $form.substr(0, $form.chars - @markers.first({ $form.ends-with($_) }).chars)
            !! Empty
    });

    (@listed, @bare).flat.unique;
}

#| Split one word into its morphemes.
#|
#| No return type, so a failure stays inert; see `Ronosathwasha::Types`.
#| `$grammar` exists so a caller can divide the same word under a different
#| rule and compare. `Morphemes` is frugal with stems; a greedy subclass gives
#| the other reading of an ambiguous word, and two answers that differ are how
#| ambiguity is detected rather than assumed.
sub parse-word(
    Lexicon:D     $lexicon,
    Morphology:D  $morphology,
    Str:D         $word,
    Mu           :$grammar = Morphemes,
) is export {
    my @current = $morphology.current;

    my @prefix-morphemes = @current.grep(*.position == Prefix);
    my @suffix-morphemes = @current.grep(*.position == Suffix);

    my @*PREFIXES = @prefix-morphemes.map({ .forms.Slip }).unique;
    my @*SUFFIXES = @suffix-morphemes.map({ .forms.Slip }).unique;
    my @*STEMS    = stems-from($lexicon, $morphology);

    my $text = $word.lc;
    my $match = $grammar.parse($text);

    fail X::Ronosathwasha::Word::Unrecognised.new(:word($word)) without $match;

    # Resolving a form to a morpheme is a lookup restricted by position, which
    # is the whole reason the declaration records position at all. Without it
    # `me` has two answers here and no way to choose.
    my Morpheme @prefixes = $match<prefix>.map(-> $m {
        @prefix-morphemes.first({ .forms.first(~$m).defined })
    });

    my Morpheme @suffixes = $match<suffix>.map(-> $m {
        @suffix-morphemes.first({ .forms.first(~$m).defined })
    });

    WordParse.new(
        :$text,
        :@prefixes,
        :stems($match<stem>.map({ ~$_ })),
        :@suffixes,
    );
}
