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
    #| describes. Everything else in the lexicon is a root or a phrase.
    method affixes {
        @!entries.grep({ .section eq 'marker' || .section eq 'particle' });
    }

    method forms(--> Set) {
        @!entries.map(*.roman).Set;
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

        fail X::Declaration::BadValue.new(
            :$path,
            :field<section>,
            :subject("[$section]"),
            :found($words),
        ) unless $words ~~ Associative;

        for $words.kv -> $roman, $gloss {

            fail X::Declaration::BadValue.new(
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
