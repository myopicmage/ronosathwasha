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

=head2 Position is not enough for C<swe>

One pair of morphemes defeats it. The infinitive and the copularizer are both
suffixes and share both surface forms, so the position lookup above has two
answers and used to take whichever C<data/morphology.toml> listed first. That is
the infinitive, so C<mirireswe>, "I am a teacher", came back with a nonfinite
verb marker on a noun.

It is the only such pair. Checked rather than assumed: across every current
morpheme, grouped by position, C<swe> and C<swo> are the only forms with more
than one claimant.

B<The rest of the word decides.> A word carrying a tense, an aspect or a speech
act is verbal, so its C<swe> is the infinitive; one carrying a case, a number or
a locative is nominal, so its C<swe> is the copularizer. When no other morpheme
says, the stem does: C<mirire> is listed under C<[noun]> and C<miri> is recovered
from a C<[verb]> entry.

This reads C<attaches_to> and does not enforce it. Kevin's ruling stands that
anything attaches to anything and sense is contextual, so nothing here refuses a
word: a form with two possible morphemes gets the reading its context suggests,
and a word whose context says nothing keeps the old first-listed answer rather
than being rejected.

The circularity is only apparent. Host inference looks at morphemes whose form
has exactly one claimant, which C<swe> by definition does not, so the ambiguous
ones are resolved after the unambiguous ones have voted and never during.

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
use Ronosathwasha::Harmony;


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

#| The lexicon section whose entries are predicates. Everything else that can be
#| a stem is nominal, which is one rule rather than a section-to-host table: a
#| table would be a second place to drift, and it could name a section
#| `data/lexicon.toml` does not have.
#|
#| An adjective landing on the nominal side is correct rather than convenient.
#| `-swe` on one gives "to be red", which is the copularizer doing exactly its
#| declared job.
#| Exported because `Ronosathwasha::Gloss` splits a stem's senses on the same
#| signal. If the two read different sections, a stem could be verbal for the
#| parser and nominal for the gloss of the very same word.
constant VERB-SECTION is export = 'verb';

#| Which host class each stem can be, as the lexicon has it.
#|
#| A stem can be both. `thinə` is listed under `[noun]` as "food" and is also
#| recovered from `thinəswe` under `[verb]`, so it belongs to each, and a word
#| built on it needs its affixes to say which is meant. That is not a defect in
#| the lexicon; it is decision 16's derivation showing through.
sub stem-hosts(Lexicon:D $lexicon, Morphology:D $morphology --> Map) is export {
    my @markers = $morphology.by-id('infinitive').forms;
    my $affixes = $lexicon.affixes.map(*.roman).Set;

    my %hosts;

    for $lexicon.entries.grep({ not $affixes{.roman} and not .roman.contains(' ') }) -> $entry {
        my $host = $entry.section eq VERB-SECTION ?? VerbStem !! NominalStem;
        my Str $roman = $entry.roman;

        %hosts{$roman}{$host} = True;

        with @markers.first({ $roman.ends-with($_) && $roman.chars > .chars }) -> $marker {
            %hosts{ $roman.substr(0, $roman.chars - $marker.chars) }{$host} = True;
        }
    }

    %hosts.map({ .key => .value.keys.map({ Host::{$_} }).Set }).Map;
}

#| The host class the word's own morphology implies, or `Host` if nothing says.
#|
#| Only morphemes whose form has a single claimant get a vote, which is what
#| keeps this from needing the answer it is computing. If those disagree, or
#| there are none, the stem decides; if the stem is both, nothing does.
sub infer-host(Map:D $stem-hosts, @stems, @candidates --> Host) {
    # `my @voted`, not `my $voted`. Every stage here returns a `Seq`, which is
    # one-shot: asking `.elems` iterates it, and the `.head` after that would
    # throw about an already-iterated sequence. Binding to an array caches it.
    #
    # `NounStem` folds into `NominalStem` because the distinction is about which
    # nominals a morpheme suits, and the question being asked is only verbal
    # against nominal.
    my @voted = @candidates
        .grep(*.elems == 1)
        .map(*.head.hosts)
        .grep(*.elems == 1)
        .map(*.head)
        .map({ $_ == VerbStem ?? VerbStem !! NominalStem })
        .unique;

    return @voted.head if @voted.elems == 1;

    my $from-stem = $stem-hosts{ @stems.join } // $stem-hosts{ @stems.head } // Set.new;

    $from-stem.elems == 1 ?? $from-stem.keys.head !! Host;
}

#| The same question asked of a word already divided.
#|
#| Every morpheme is resolved by this point, so each one is its own singleton
#| candidate list and `infer-host` needs no second implementation. Exported
#| because `Ronosathwasha::Gloss` asks it in order to choose between a stem's
#| senses, which is the same question in a different coat: `thinə` with a tense
#| is "eat" and with a case marker is "food".
sub word-host(Map:D $stem-hosts, WordParse:D $word --> Host) is export {
    infer-host(
        $stem-hosts,
        $word.stems,
        ($word.prefixes, $word.suffixes).flat.map({ ($_,) }),
    );
}

#| Pick the morpheme a matched form meant, given what the word turned out to be.
#|
#| Falls back to the first candidate rather than failing, because a word whose
#| context says nothing is still a word. Refusing it here would turn a
#| descriptive declaration into the filter Kevin ruled out.
sub choose-morpheme(@candidates, Host $host --> Morpheme) {
    return @candidates.head if @candidates.elems == 1 or not $host.defined;

    @candidates.first({ .declared-for($host) }) // @candidates.head;
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
    #
    # `.grep` rather than `.first`, because position leaves `swe` with two
    # claimants and the module documentation explains what settles it. Every
    # other form has exactly one, so this list is a singleton everywhere else and
    # `choose-morpheme` returns its head untouched.
    my @prefix-candidates = $match<prefix>.map(-> $m {
        @prefix-morphemes.grep({ .forms.first(~$m).defined }).List
    });

    my @suffix-candidates = $match<suffix>.map(-> $m {
        @suffix-morphemes.grep({ .forms.first(~$m).defined }).List
    });

    my Str @stems = $match<stem>.map({ ~$_ });

    my $host = infer-host(
        stem-hosts($lexicon, $morphology),
        @stems,
        (@prefix-candidates, @suffix-candidates).flat,
    );

    my Morpheme @prefixes = @prefix-candidates.map({ choose-morpheme($_, $host) });
    my Morpheme @suffixes = @suffix-candidates.map({ choose-morpheme($_, $host) });

    WordParse.new(:$text, :@prefixes, :@stems, :@suffixes);
}

#| Treat a writable, undeclared form as one open nominal stem.
#|
#| Names are productive vocabulary. Requiring every person's name to appear in
#| the lexicon before an introduction can be read would turn the dictionary
#| into an accidental registry of people.
sub open-nominal(Str:D $word --> WordParse) is export {
    WordParse.new(:text($word.lc), :stems($word.lc));
}

#| Parse an open nominal carrying the productive copularizer, optionally
#| followed by tense and continuous aspect.
#|
#| This is separate from `parse-word`: the general parser deliberately accepts
#| only declared stems, while names are open vocabulary only in the grammatical
#| position that proves they are nominal predicates.
sub parse-nominal-predicate(
    Script:D     $script,
    Morphology:D $morphology,
    Str:D        $word,
    --> WordParse
) is export {
    my Str $text = $word.lc;
    my $copularizer = $morphology.by-id('copularizer');
    my @tenses = $morphology.current.grep(*.role == MarksTense);
    my $continuous = $morphology.by-id('continuous');

    my @sequences;
    @sequences.push: [$copularizer];

    for @tenses -> $tense {
        @sequences.push: [$copularizer, $tense];
        @sequences.push: [$copularizer, $tense, $continuous];
    }

    @sequences .= sort({
        $^b.map(*.forms.map(*.chars).max).sum
            <=>
        $^a.map(*.forms.map(*.chars).max).sum
    });

    for @sequences -> @suffixes {
        my @endings = @suffixes.head.forms;

        for @suffixes.skip(1) -> $suffix {
            @endings = @endings X~ $suffix.forms;
        }

        for @endings -> $ending {
            next unless $text.ends-with($ending) && $text.chars > $ending.chars;

            my Str $stem = $text.substr(0, $text.chars - $ending.chars);
            my $class = profile-of($script, $stem);
            next if $class == MixedWord;
            next unless @suffixes.map({ .form-for($class) }).join eq $ending;

            return WordParse.new(:$text, :stems($stem), :@suffixes);
        }
    }

    fail X::Ronosathwasha::Word::Unrecognised.new(:word($word));
}
