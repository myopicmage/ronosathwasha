=begin pod

=head1 Ronosathwasha::Gloss

Interlinear glossing: the morpheme-by-morpheme line that goes under an example.

=head2 What this is for

C<Nari toro?> is opaque to anybody who does not already know the language, and
that includes Kevin at the moment he is deciding whether a form is right. The
gloss makes the grammar visible:

=begin code
Na-ri     to-ro
you-SBJ   Q-person
=end code

The layout follows the Leipzig Glossing Rules, which are the de facto standard
for this: one hyphen in the gloss line per hyphen in the object line, grammatical
morphemes in capitals, lexical ones in lower case.

=head2 Nothing here writes a label

Every label is read from a declaration. A morpheme's comes from its C<gloss>
field in C<data/morphology.toml>, which the loader requires, and a stem's comes
from its entry in C<data/lexicon.toml>. This module owns the arrangement and
none of the content.

That is deliberate and it is the second time this project has needed the rule.
The capabilities block was hand-written prose about the language, and it told a
model the language had a habitual aspect that does not exist. A table of gloss
labels in this file would be the same defect wearing different clothes: it could
name a morpheme C<data/> does not declare, and nothing would disagree.

So the failure mode here is a missing label rather than a wrong one, and a
missing one is impossible for a morpheme because the field is required.

=head2 An unknown stem glosses as C<?>

A word can parse without its stem being a declared word, because
C<Ronosathwasha::Words> admits an open nominal so that a person's name does not
have to be added to the dictionary before somebody can be introduced. Such a
stem has no gloss and gets C<?>, which says so.

The alternative was to repeat the stem on the gloss line, and that reads as an
answer. C<?> reads as the question it is.

=head2 A lexicon gloss is prose and a gloss label is not

C<miriswe> glosses as "to teach" and C<mwatheya> as "believe"; C<thwasha> is
"language, tongue" and C<toro> is "who (question-person)". Those are dictionary
entries written for a reader, and an interlinear line needs one short label per
morpheme.

C<short-gloss> reduces them mechanically: the parenthetical comes off, the first
comma-separated sense is taken, a leading "to " goes, and any remaining space
becomes a period, which is Leipzig's rule for a multi-word gloss of a single
morpheme. It can shorten and it cannot invent, and the full entry stays in the
lexicon where a reader wants it.

=head2 The stem list is the one from C<Words>, deliberately

C<stem-glosses> recovers bare verb stems by stripping an infinitive marker, the
same way C<Ronosathwasha::Words> recovers them for parsing. It has to be the same
set: a stem the parser will divide a word into and this module cannot gloss would
show up as C<?> on a word that is perfectly well understood.

=end pod

unit module Ronosathwasha::Gloss;

use X::Ronosathwasha;

use Ronosathwasha::Types;
use Ronosathwasha::Script;
use Ronosathwasha::Lexicon;
use Ronosathwasha::Morphology;
use Ronosathwasha::Harmony;
use Ronosathwasha::Words;

#| The label an unglossable stem takes. Named because it appears in the module,
#| in the tests and in anything that reads a gloss line looking for holes.
constant UNGLOSSED is export = '?';

#| One word, aligned against its gloss.
class GlossedWord is export {
    has Str $.text     is required;
    has Str @.segments is required;
    has Str @.labels   is required;

    #| The word rewritten with its morpheme boundaries shown.
    method form(--> Str) { @!segments.join('-') }

    #| The gloss line, with the same number of hyphens by construction.
    method line(--> Str) { @!labels.join('-') }

    #| Whether any morpheme in this word went unglossed.
    method complete(--> Bool) { not @!labels.grep(UNGLOSSED).elems }
}

class GlossedSentence is export {
    has Str          $.text  is required;
    has GlossedWord  @.words is required;

    method form(--> Str) { @!words.map(*.form).join(' ') }
    method line(--> Str) { @!words.map(*.line).join(' ') }

    method complete(--> Bool) { not @!words.grep({ not .complete }).elems }

    #| The two lines with their columns lined up, which is the whole point of
    #| calling a gloss interlinear.
    #|
    #| Padded per word to the wider of the two, so a long label pushes the word
    #| after it along on both lines rather than only on one. Two spaces between
    #| columns, because one leaves `Q-person` touching its neighbour.
    method aligned(--> Str) {
        my @widths = @!words.map({ .form.chars max .line.chars });

        my @top = @!words.kv.map(-> $i, $w { sprintf('%-*s', @widths[$i], $w.form) });
        my @bot = @!words.kv.map(-> $i, $w { sprintf('%-*s', @widths[$i], $w.line) });

        (@top.join('  ').trim-trailing, @bot.join('  ').trim-trailing).join("\n");
    }
}

#| Reduce a dictionary gloss to one interlinear label.
#|
#| Mechanical, in this order, and the order matters: the parenthetical comes off
#| first so that a comma inside it cannot be mistaken for a sense boundary.
#| "who (question-person)" would otherwise split at nothing and keep the whole
#| parenthetical, and "and, and then, furthermore (clause-level discourse
#| continuation)" would split correctly by luck rather than by rule.
sub short-gloss(Str:D $gloss --> Str) is export {
    # `.head`, not `[0]`. In a whitespace-continued method chain a `[` straight
    # after a closing paren is parsed as a bracketed infix operator, and the
    # error is "Missing infix inside []" rather than anything about indexing.
    $gloss.subst(/ \s* '(' <-[)]>* ')' /, '', :g)
          .split(',')
          .head
          .subst(/^ 'to ' /, '')
          .trim
          .subst(/ \s+ /, '.', :g);
}

#| Every stem that can appear in a division, with the label it glosses as.
#|
#| The listed words minus the bound morphology, plus verb stems recovered from
#| their infinitives, which is exactly `Ronosathwasha::Words`' stem set. A bare
#| stem takes its infinitive's gloss: `miri` is "teach" because `miriswe` is
#| "to teach", and the lexicon has no separate entry for the bare form.
sub stem-glosses(Lexicon:D $lexicon, Morphology:D $morphology --> Map) is export {
    my @markers = $morphology.by-id('infinitive').forms;
    my $affixes = $lexicon.affixes.map(*.roman).Set;

    my %glosses;

    # `-> $entry` rather than the implicit `$_`, which is not style. The `with`
    # block below rebinds `$_` to the marker, so `.roman` inside it would be
    # asked of a `Str` and die about a missing method rather than about anything
    # to do with the lexicon.
    for $lexicon.entries.grep({ not $affixes{.roman} and not .roman.contains(' ') }) -> $entry {
        my Str $label = short-gloss($entry.gloss);
        my Str $roman = $entry.roman;

        %glosses{$roman} = $label;

        # `$roman.chars > .chars` guards the marker being the whole word: without
        # it a hypothetical entry spelled `swe` would recover the empty stem and
        # claim a gloss for it.
        with @markers.first({ $roman.ends-with($_) && $roman.chars > .chars }) -> $marker {
            %glosses{ $roman.substr(0, $roman.chars - $marker.chars) } //= $label;
        }
    }

    %glosses.Map;
}

#| Gloss one divided word.
#|
#| No return type, so a failure stays inert; see `Ronosathwasha::Types`. The one
#| way this fails is a stem with no vowel class, which is the same word
#| `realize-constituent` cannot rebuild either.
sub gloss-word(
    Script:D     $script,
    Morphology:D $morphology,
    WordParse:D  $word,
    Map:D        $stem-glosses,
) is export {

    # From the joined stems, not from each stem or from the whole word. That is
    # the same rule `realize-word` follows and for the same reason: a compound
    # takes its class from the whole compound, so `shamwu` selects the back `yu`
    # where reading `sha` alone would give `yi`.
    my Str $stem = $word.stems.join;
    my $class = profile-of($script, $stem);

    fail X::Ronosathwasha::Form::NoClass.new(:$stem) if $class == MixedWord;

    my @segments = (
        $word.prefixes.map({ .form-for($class) }),
        $word.stems.Slip,
        $word.suffixes.map({ .form-for($class) }),
    ).flat;

    my @labels = (
        $word.prefixes.map(*.gloss),
        $word.stems.map({ $stem-glosses{$_} // UNGLOSSED }),
        $word.suffixes.map(*.gloss),
    ).flat;

    return GlossedWord.new(:text($word.text), :@segments, :@labels);

    CATCH { default { .fail } }
}

#| Gloss a whole sentence, parsing it on the way.
#|
#| The punctuation strip matches `read-sentence`'s, because a gloss of
#| `Nari toro?` should say the same thing about `toro` that reading it does, and
#| the question mark is not a morpheme.
#|
#| A word the parser refuses becomes one open nominal, which is what
#| `read-sentence` does with an unknown stem. Refusing the whole sentence would
#| make a gloss useless in exactly the case a gloss is most wanted: the form
#| Kevin has just invented and is deciding about.
#|
#| No return type, so a failure stays inert; see `Ronosathwasha::Types`.
sub gloss-sentence(
    Script:D     $script,
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Str:D        $sentence,
) is export {
    my $stems = stem-glosses($lexicon, $morphology);

    my GlossedWord @words = $sentence.words.map(-> $written {
        my Str $bare = $written.subst(/<[?.,!]>+$/, '');

        my $division = parse-word($lexicon, $morphology, $bare);

        gloss-word(
            $script, $morphology,
            $division.defined ?? $division !! open-nominal($bare),
            $stems,
        );
    });

    return GlossedSentence.new(:text($sentence), :@words);

    CATCH { default { .fail } }
}
