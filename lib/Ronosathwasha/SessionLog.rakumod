=begin pod

=head1 Ronosathwasha::SessionLog

The durable edge of a chatbot session.

C<ConversationState> is deliberately short-lived: fitting it to a model window
folds old turns into summaries. C<LanguageEvidence> is deliberately in memory:
it is the accumulator a caller may use while deciding what to do next. Neither
is a transcript. This module keeps that transcript as append-only JSON Lines so
that a session can be inspected or resumed after the process exits.

The records are observations, not language declarations. Writing one never
changes the canonical data files, and exporting one copies the record rather
than promoting it into the language.

=end pod

unit module Ronosathwasha::SessionLog;

use JSON::Fast;

use Ronosathwasha::Dialogue;
use Ronosathwasha::LanguageEvidence;

#| One durable event in a session. The event-specific fields live in C<data>
#| so the log can grow without changing the envelope or making old records
#| unreadable.
class SessionRecord is export {
    has Int:D $.sequence  is required;
    has Str:D $.event     is required;
    has Str:D $.timestamp is required;
    has %.data;

    method as-hash(--> Hash:D) {
        %(
            |%!data,
            sequence  => $!sequence,
            event     => $!event,
            timestamp => $!timestamp,
        )
    }
}

#| A durable append-only session log.
class SessionLog is export {
    has IO::Path:D $.path is required;
    has Int:D $.next-sequence is rw is required;

    #| Read the current file every time. This keeps the object honest if a
    #| caller inspects a log after another process appended to the same file.
    method records(--> List) {
        records-from($!path)
    }

    #| Append one event and return the exact record written.
    method append(Str:D $event, *%data --> SessionRecord:D) {
        $!path.parent.mkdir unless $!path.parent.d;

        my $record = SessionRecord.new(
            :sequence($!next-sequence),
            :$event,
            :timestamp(DateTime.now.Str),
            :%data,
        );

        my $handle = $!path.open(:a);
        $handle.say(to-json($record.as-hash, :!pretty));
        $handle.close;

        $!next-sequence++;
        $record
    }

    #| Keep the turn without retaining live domain objects in the file.
    method record-exchange(Exchange:D $exchange --> SessionRecord:D) {
        self.append(
            'exchange',
            heard          => $exchange.heard,
            understanding  => $exchange.understood
                ?? 'understood'
                !! $exchange.understanding.summary,
            understood     => $exchange.understood,
            intent         => $exchange.intent.defined ?? $exchange.intent.summary !! Nil,
            said           => $exchange.said.defined ?? $exchange.said !! Nil,
            inadmissible   => $exchange.inadmissible.defined
                ?? $exchange.inadmissible.summary
                !! Nil,
        )
    }

    #| Keep the candidate observation alongside the exchange that produced it.
    method record-evidence(LanguageEvidence:D $evidence --> SessionRecord:D) {
        self.append(
            'evidence',
            findings => $evidence.findings.map(-> $finding {
                %(
                    kind   => $finding.kind.key,
                    subject => $finding.subject,
                    detail => $finding.detail,
                    seen   => $finding.seen,
                )
            }).List,
        )
    }

    #| Copy the JSONL stream for explicit export. The destination may be
    #| outside the working directory, but it is still just a transcript copy.
    method export(IO::Path:D $destination --> IO::Path:D) {
        $destination.parent.mkdir unless $destination.parent.d;
        $destination.spurt($!path.e ?? $!path.slurp !! '');
        $destination
    }
}

#| Open a log and recover its next sequence number from existing records.
sub session-log(IO::Path:D $path --> SessionLog:D) is export {
    my @records = records-from($path);
    my Int $highest = @records
        ?? @records.map(*.sequence).max.Int
        !! 0;
    my Int $next = $highest + 1;
    SessionLog.new(:$path, :next-sequence($next))
}

#| Parse the append-only stream into typed envelopes. A malformed line is a
#| broken durable record, so fail at the boundary instead of silently skipping
#| evidence.
sub records-from(IO::Path:D $path --> List) {
    return () unless $path.e;

    my @records;
    for $path.lines.kv -> $line-number, $line {
        next unless $line.trim.chars;

        my $raw = from-json($line);
        die "session log line { $line-number + 1 } is not an object"
            unless $raw ~~ Associative;

        my %data = $raw.Hash;
        my $sequence  = %data<sequence>;
        my $event     = %data<event>;
        my $timestamp = %data<timestamp>;

        die "session log line { $line-number + 1 } has no sequence"
            unless $sequence.defined;
        die "session log line { $line-number + 1 } has no event"
            unless $event.defined;
        die "session log line { $line-number + 1 } has no timestamp"
            unless $timestamp.defined;

        %data<sequence>:delete;
        %data<event>:delete;
        %data<timestamp>:delete;

        @records.push: SessionRecord.new(
            :sequence($sequence.Int),
            :event($event.Str),
            :timestamp($timestamp.Str),
            :%data,
        );
    }

    @records.List
}
