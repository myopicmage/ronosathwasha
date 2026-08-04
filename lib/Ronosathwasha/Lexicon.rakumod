=begin pod

=head1 Ronosathwasha::Lexicon

The words, as declared in C<data/lexicon.toml>.

Each section is a table of romanisation to gloss, and this module keeps exactly
that. It deliberately does not interpret a gloss: the strings on the affix
entries currently also state role, position and harmony class, and that is a
second copy of what C<data/morphology.toml> owns. Reading grammar out of prose
here would make the copy load-bearing rather than merely present.

=end pod

unit module Ronosathwasha::Lexicon;

use X::Ronosathwasha;

use Ronosathwasha::Types;
use Ronosathwasha::Data;

class Entry is export {
    has Str $.section is required;
    has Str $.roman   is required;
    has Str $.gloss   is required;
}

class Lexicon is export {
    has Entry @.entries is required;

    method in-section(Str:D $section) {
        @!entries.grep(*.section eq $section);
    }

    #| The bound morphology, which is the part `data/morphology.toml` also
    #| describes. Derivational markers have their own section because their
    #| spellings may remain content roots: agentive `-ro` and person `ro` are
    #| both real, and erasing one by surface spelling would erase the paradigm.
    method affixes {
        @!entries.grep({
            .section eq 'marker'
                || .section eq 'particle'
                || .section eq 'derivational_marker'
        });
    }

    #| The entries available as stems under the reader's established policy.
    #|
    #| Inflectional marker spellings block a same-spelled content entry. This is
    #| what keeps `me` and `no` from multiplying old divisions throughout the
    #| grammar. Derivational markers do not: their source or result may itself
    #| be the content root they resemble, as agentive `-ro` now demonstrates.
    #| The marker entries themselves are never stems in either case. Neither
    #| are `[derived]` entries: those belong in the dictionary because their
    #| conventional meanings matter, but their declared pieces remain the
    #| language structure that readers and model intents operate on.
    method stem-entries {
        my $blocked = @!entries
            .grep({ .section eq 'marker' || .section eq 'particle' })
            .map(*.roman)
            .Set;

        @!entries
            .grep({
                .section ne 'marker'
                    && .section ne 'particle'
                    && .section ne 'derivational_marker'
                    && .section ne 'derived'
            })
            .grep({ not $blocked{.roman} });
    }

    method forms(--> Set) {
        @!entries.map(*.roman).Set;
    }

    #| The words that already spell an interrogative, as stems.
    #|
    #| Here rather than in `Ronosathwasha::Actions`, where it began, because three
    #| layers need it and they do not all sit above reading. Reading asks whether
    #| the marker is there, realization asks whether to write one, and `Intent`
    #| now asks whether a model named a question word while claiming to declare.
    #| `Intent` cannot import `Actions` without closing a cycle, and every caller
    #| already imports this module, so the section name lives once beside the
    #| other section queries.
    #|
    #| **Not "the word starts with `to`".** `tono` does, `tono` is a listed word,
    #| and it is not a question. The `[interrogative]` section is what separates
    #| the two.
    method interrogative-words(--> Set) {
        self.in-section('interrogative').map(*.roman).Set;
    }

    method sections(--> Seq) {
        @!entries.map(*.section).unique;
    }
}

#| Load the words. No return type, so a failure stays inert; see
#| `Ronosathwasha::Types`.
sub load-lexicon(IO::Path:D $path) is export {
    my $doc = read-toml($path);

    my Entry @entries;

    # Every top-level table is a part of speech, and its keys are words. The
    # file grows a section whenever the language does, so nothing here names
    # the sections it expects.
    for $doc.data.kv -> $section, $words {

        fail X::Ronosathwasha::Declaration::BadValue.new(
            :$path,
            :field<section>,
            :subject("[$section]"),
            :found($words),
        ) unless $words ~~ Associative;

        for $words.kv -> $roman, $gloss {

            fail X::Ronosathwasha::Declaration::BadValue.new(
                :$path,
                :field<gloss>,
                :subject("[$section] $roman"),
                :found($gloss),
            ) unless $gloss ~~ Str;

            @entries.push: Entry.new(:$section, :$roman, :$gloss);
        }
    }

    return Lexicon.new(:@entries);

    CATCH { default { .fail } }
}
