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

=head2 The third line, and why it has two shapes

Leipzig's layout is three lines: the object line, the gloss, and a free
translation. The first two are morphology and the third is meaning, and keeping
them apart is what resolves C<thinəme>.

C<thinə-me> glosses as C<food-PRS>, which is exactly right, and a speaker reads
it as "eats". Both are true at once. The gloss line reports what was written and
the translation line reports what it means, so neither has to compromise.

B<The derivation is Ronosathwasha's; only the English word is English's.> Kevin
made this correction and it is worth keeping straight, because the obvious
reading of C<food-PRS> is that the glosser has failed at something.

It has not. C<thinəswe> is C<thinə> plus the infinitive, and "to food" is a
perfectly good way to build a verb: the language derives the predicate from the
noun productively, and that rule is declared. What is peculiar to English is the
I<lexeme>. English happens to keep separate words for the substance and the act,
so no single English word glosses the Rono stem in both of its uses, and the
label has to pick one.

C<data/lexicon.toml> in fact holds both: C<thinə> is "food" and C<thinəswe> is
"to eat (food-verb)". The noun is listed directly and the verb stem is recovered
from its infinitive, so the noun wins, and C<thinəme> glosses as C<food-PRS>
where C<eat-PRS> was meant. Choosing between them would mean reading the rest of
the word, which is the same unresolved question the copularizer raises below.

B<Fluent English still comes from the corpus.> Not because the derivation is
foreign, but because "(I) eat that food (over there)" is a sentence somebody
wrote, and assembling one here would be inventing. So the translation has two
sources and they render differently, because a reader who cannot tell them apart
will trust the wrong one:

=begin code
Sho thinə-me            la-ri  miri-me
that.over.there food-PRS  I-SBJ  teach-PRS
'(I) eat that food (over there)'    [teach: declarative, present simple]
=end code

Single quotes mean C<data/utterances.toml> says so, in Kevin's words. Square
brackets mean nobody has translated this sentence and the line was assembled
from the reading. The bracketed form is not a translation and does not pretend
to be one.

An unattested sentence is the common case for a chatbot, since a sentence the
model just produced is by definition not in the corpus yet. That is the case the
bracketed form exists for.

=head2 Zero-marked features are omitted from the bracketed line

Affirmative polarity and asserted modality have no morpheme, so printing them
would report a decision the writer never made. They appear only when marked,
which is the same rule C<Ronosathwasha::Capabilities> applies for the same
reason.

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
use Ronosathwasha::Semantics;
use Ronosathwasha::Words;
use Ronosathwasha::Actions;

#| The label an unglossable stem takes. Named because it appears in the module,
#| in the tests and in anything that reads a gloss line looking for holes.
constant UNGLOSSED is export = '?';

#| Where the third line came from, which decides how it is punctuated.
#|
#| `FromCorpus` rather than `Attested`, and `FromReading` rather than `Derived`.
#| Both of those names are already `Ronosathwasha::Semantics::Status` values, and
#| Raku installs an enum's values as symbols in every importing scope, so either
#| one would break any module using both. `AGENTS.md` records this; it is the
#| fifth time it has come up.
enum TranslationSource is export <FromCorpus FromReading Unavailable>;

#| The free translation line.
class Translation is export {
    has TranslationSource:D $.source is required;
    has Str                 $.text;

    #| Quoted when somebody wrote it, bracketed when nothing did.
    #|
    #| Leipzig puts a free translation in single quotes. The bracketed form
    #| deliberately breaks that convention rather than extending it, because the
    #| one thing this line must never do is let an assembled feature list read as
    #| a translation somebody stands behind.
    method render(--> Str) {
        given $!source {
            when FromCorpus  { "'$!text'" }
            when FromReading { "[$!text]"  }

            # `Unavailable` still carries text when the reader said why it could
            # not read the sentence. "[no reading]" alone is the least useful
            # thing this line could say: the whole reason somebody glosses a
            # sentence they just wrote is to find out what is wrong with it.
            default { $!text.defined ?? "[$!text]" !! '[no reading]' }
        }
    }
}

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
    has Str          $.text        is required;
    has GlossedWord  @.words       is required;
    has Translation  $.translation is required;

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

    #| All three lines, which is what Leipzig means by an interlinear gloss.
    #|
    #| The translation is not padded into the columns, because it is a statement
    #| about the whole sentence rather than about any word in it.
    method render(--> Str) {
        (self.aligned, $!translation.render).join("\n");
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

#| What one stem glosses as, which can be two things.
#|
#| `thinə` is "food" under `[noun]` and "eat" under `[verb]`, and the two are the
#| same string because `thinəswe` derives the predicate from the noun. Storing
#| one label and letting the noun win was the bug: `thinəme` glossed as
#| `food-PRS` where the tense had already said which sense was live.
class StemGloss is export {
    has Str $.nominal;
    has Str $.verbal;

    #| The sense the word's morphology selected.
    #|
    #| Both, joined, when nothing selected one and the stem really has two. That
    #| is a bare `thinə` with no affixes at all, where the language genuinely has
    #| not said, and a gloss that picked silently would be inventing the answer
    #| rather than reporting it. Same discipline as `UNGLOSSED`.
    #| A stem nobody declared has no senses to choose between, so the type object
    #| answers rather than throwing. `:U` and `:D` invocants rather than a
    #| `.defined` guard inside one method, because attribute access on a type
    #| object throws before any guard could run: the error is "Cannot look up
    #| attributes in a type object", which names neither the stem nor the caller.
    multi method label(StemGloss:U: Host --> Str) { UNGLOSSED }

    multi method label(StemGloss:D: Host $host --> Str) {
        return $!verbal  if $host.defined && $host == VerbStem    && $!verbal.defined;
        return $!nominal if $host.defined && $host == NominalStem && $!nominal.defined;

        my @senses = ($!nominal, $!verbal).grep(*.defined).unique;

        @senses.elems ?? @senses.join('/') !! UNGLOSSED;
    }
}

#| Every stem that can appear in a division, with the label it glosses as.
#|
#| The listed words minus the bound morphology, plus verb stems recovered from
#| their infinitives, which is exactly `Ronosathwasha::Words`' stem set. A bare
#| stem takes its infinitive's gloss: `miri` is "teach" because `miriswe` is
#| "to teach", and the lexicon has no separate entry for the bare form.
sub stem-glosses(Lexicon:D $lexicon, Morphology:D $morphology --> Map) is export {
    my @markers = $morphology.by-id('infinitive').forms;

    my %nominal;
    my %verbal;

    # `-> $entry` rather than the implicit `$_`, which is not style. The `with`
    # block below rebinds `$_` to the marker, so `.roman` inside it would be
    # asked of a `Str` and die about a missing method rather than about anything
    # to do with the lexicon.
    for $lexicon.stem-entries.grep({ not .roman.contains(' ') }) -> $entry {
        my Str $label = short-gloss($entry.gloss);
        my Str $roman = $entry.roman;

        # The section is the same signal `Ronosathwasha::Words` uses for stem
        # hosts, and it has to be, or a stem could be verbal for the parser and
        # nominal for the gloss of the very same word.
        my %side := $entry.section eq VERB-SECTION ?? %verbal !! %nominal;

        %side{$roman} = $label;

        # `$roman.chars > .chars` guards the marker being the whole word: without
        # it a hypothetical entry spelled `swe` would recover the empty stem and
        # claim a gloss for it.
        with @markers.first({ $roman.ends-with($_) && $roman.chars > .chars }) -> $marker {
            %side{ $roman.substr(0, $roman.chars - $marker.chars) } //= $label;
        }
    }

    # `// Str` on each, because a missing hash key is `Any` and a `Str` attribute
    # refuses it. The `Str` type object is the absence this wants; `Any` is a
    # different absence and the error names the attribute rather than the lookup.
    (%nominal.keys, %verbal.keys).flat.unique.map({
        $_ => StemGloss.new(
            :nominal(%nominal{$_} // Str),
            :verbal(%verbal{$_}  // Str),
        )
    }).Map;
}

#| Both stem tables, carried together.
#|
#| A pair of bare `Map` parameters side by side is a call waiting to be made in
#| the wrong order, and the symptom would be every stem glossing as `?` rather
#| than anything that points at the mistake. One typed argument cannot be
#| transposed.
class StemTables is export {
    has Map:D $.glosses is required;
    has Map:D $.hosts   is required;
}

sub stem-tables(Lexicon:D $lexicon, Morphology:D $morphology --> StemTables) is export {
    StemTables.new(
        :glosses(stem-glosses($lexicon, $morphology)),
        :hosts(stem-hosts($lexicon, $morphology)),
    );
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
    StemTables:D $tables,
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

    # What the rest of the word says this one is. `thinə` under a tense is "eat"
    # and under a case marker is "food", and the affixes have already decided
    # before this asks.
    my $host = word-host($tables.hosts, $word);

    my @labels = (
        $word.prefixes.map(*.gloss),
        $word.stems.map({ ($tables.glosses{$_} // StemGloss).label($host) }),
        $word.suffixes.map(*.gloss),
    ).flat;

    return GlossedWord.new(:text($word.text), :@segments, :@labels);

    CATCH { default { .fail } }
}

#| The reading, written out as a feature list rather than as English.
#|
#| Affirmative polarity and asserted modality are omitted because they are
#| zero-marked: no morpheme was written, so printing them would report a choice
#| the writer never made. A timeless predication says so, since decision 22
#| makes an absent tense a meaning rather than a silence.
#|
#| A question leads with what it questions, in place of the bare `interrogative`,
#| which said less: `Tororu thinəme?` and `Tomwuyu thinəme?` are different
#| questions, and a line that rendered both as `interrogative` would be the
#| meaning-preservation bug from review `023` wearing this module's clothes. The
#| wording comes off the enum key, so this stays a report and never a label.
#|
#| The predicate is given by its gloss label where one exists, so this line and
#| the gloss line above it name the same thing the same way.
#|
#| `nominal-predicate` supplies the host here, where the gloss line got it from
#| the affixes. That is the reading's own answer to the same question, so an
#| identity clause glosses its predicate as a noun and a verbal one as a verb.
#| An undeclared stem keeps its own spelling rather than becoming `?`, because a
#| name is the usual case and printing `laari` says more than a question mark.
proto sub reading-summary(|) is export {*}

multi sub reading-summary(Reading:D $reading, StemTables:D $tables --> Str) {
    my $host = $reading.nominal-predicate ?? NominalStem !! VerbStem;
    my $sense = $tables.glosses{ $reading.predicate };

    my Str $predicate = $sense.defined ?? $sense.label($host) !! $reading.predicate;

    # `Asks` guarantees an interrogative reading carries a scope, so the fallback
    # to the bare speech act is for the two acts that question nothing.
    #
    # The camel split is for the two-word value: `QuestionsUnmarkedConstituent`
    # must render as "unmarked constituent", not mash into one word. Same
    # transform `Capabilities::axis-of` applies to `MorphemeRole`.
    my @features = $reading.question-scope.defined
        ?? "{ $reading.question-kind == SelectiveQuestion ?? 'selectively questions' !! 'questions' } the { $reading.question-scope.key
            .subst(/^ Questions /, '')
            .subst(/(<[a..z]>)(<[A..Z]>)/, { "$0 $1" }, :g)
            .lc }"
        !! $reading.speech-act.key.lc;

    @features.push: $reading.tense.defined
        ?? "{ $reading.tense.key.lc } { $reading.aspect.key.lc }"
        !! 'timeless';

    @features.push: 'negative'  if $reading.polarity == Negative;
    @features.push: 'potential' if $reading.modality == Potential;
    @features.push: $reading.reference.key.lc if $reading.reference.defined;

    "$predicate: { @features.join(', ') }";
}

multi sub reading-summary(
    CoordinatedReading:D $reading,
    StemTables:D         $tables,
    --> Str
) {
    my Str @parts;

    for $reading.clauses.kv -> $index, $clause {
        @parts.push: reading-summary($clause, $tables);
        @parts.push: $reading.connectors[$index]
            if $index < $reading.connectors.elems;
    }

    @parts.join(' ');
}

#| What the corpus says this sentence means, if it says anything.
#|
#| Matched on the text with case and trailing punctuation ignored, because
#| `Sho thinəme.` and `sho thinəme` are the same sentence and the corpus writes
#| the tidy one. Nothing looser than that: a near-match would attach somebody
#| else's English to a sentence Kevin did not write.
#| `Coverage` rather than a list of `Utterance`, because that is what
#| `load-utterances` hands back and unwrapping it at every call site would be a
#| second shape for one fact. Undefined is an ordinary answer: a caller with no
#| corpus loaded gets `Unavailable` rather than an error.
sub corpus-translation(Coverage $corpus, Str:D $sentence --> Translation) {
    return Translation.new(:source(Unavailable)) without $corpus;

    my sub key(Str:D $s) { $s.trim.subst(/<[?.,!]>+$/, '').fc }

    my $found = $corpus.entries.first({ key(.text) eq key($sentence) });

    return Translation.new(:source(Unavailable)) without $found;

    Translation.new(:source(FromCorpus), :text($found.english));
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
#| `:$corpus` is optional, and its absence yields the bracketed reading rather
#| than nothing. A caller with `data/utterances.toml` loaded gets Kevin's English
#| for the sentences he has written; a caller without one is not made to load a
#| file in order to gloss a word.
sub gloss-sentence(
    Script:D     $script,
    Lexicon:D    $lexicon,
    Morphology:D $morphology,
    Str:D        $sentence,
    Coverage    :$corpus,
) is export {
    my $tables = stem-tables($lexicon, $morphology);

    my GlossedWord @words = $sentence.words.map(-> $written {
        my Str $bare = $written.subst(/<[?.,!]>+$/, '');

        my $division = parse-word($lexicon, $morphology, $bare);

        gloss-word(
            $script, $morphology,
            $division.defined ?? $division !! open-nominal($bare),
            $tables,
        );
    });

    # The corpus first, because a translation somebody wrote beats one this
    # module assembled. Falling back the other way would hide Kevin's own words
    # behind a feature list.
    my $translation = corpus-translation($corpus, $sentence);

    if $translation.source == Unavailable {
        my $outcome = read-sentence($script, $lexicon, $morphology, $sentence);

        $translation = $outcome ~~ Understood
            ?? Translation.new(
                   :source(FromReading),
                   :text(reading-summary($outcome.reading, $tables)),
               )
            !! Translation.new(:source(Unavailable), :text($outcome.summary));
    }

    return GlossedSentence.new(:text($sentence), :@words, :$translation);

    CATCH { default { .fail } }
}
