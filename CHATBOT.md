# Language development chatbot

The interesting project is not a chatbot that speaks a finished conlang. It is
a **language-development environment disguised as a conversation**.

## Development loop

```text
Someone wants to express a meaning
        ↓
The current grammar attempts to realize it
        ↓
The result is impossible, ambiguous, or ugly
        ↓
The model identifies the missing decision
        ↓
The language author chooses a rule or lexical form
        ↓
That decision enters the grammar and its tests
```

The chatbot becomes Ronosathwasha's **first permanent second-language learner**.
Its confusion is useful because it continually asks questions such as:

- How do I distinguish habitual from continuous action?
- Does harmony cross compound boundaries?
- Can both subject and object be omitted here?
- Is this meaning expressed grammatically or lexically?
- Does this rule generalize, or is this phrase an idiom?

## What the model can establish

The model cannot authoritatively declare what sounds natural because there is
no native speech community inside its training.

It can expose:

- contradictions between existing rules;
- meanings the language cannot currently distinguish;
- constructions with multiple valid interpretations;
- rules that create surprising consequences elsewhere;
- places where speakers would need excessive context.

It supplies **pressure from attempted use**. The language author remains the
authority on whether the resulting language feels right.

## The researcher

The model is a **consultant researcher, brought in after the language was
standardised, commissioned to write the first book in it.**

### His name is Lauri, and the language cannot say it

**Lauri**, Finnish, and deliberately not a Rono name. He is an outsider by
position, and Finnish is the language this one keeps borrowing from: fixed initial
stress, harmony and phonemic length all come from there.

**Rono cannot express it.** `Lauri` opens on the diphthong /au̯/, and this is a
strict CV syllabary with no diphthongs and no codas, so `au` has nowhere to sit.
The nearest the script reaches is a long vowel, which gives **`laari`**, written
`laa` + `ri`.

That approximation lands one vowel-length away from `lari`, which is `la` ("I")
plus the subject particle `ri`. So the language's best attempt at his name is the
first-person subject, the word that opens half the sentences he spends his days
writing.

**`laari` is not a Rono word and is not claimed as one.** It is a transliteration
of a foreign name, which is also why it does not breach decision 20's rule against
length as the sole contrast between adjacent words: that rule governs the lexicon,
and this is not in the lexicon. It is the phonology failing to hold a name, which
is a different thing from the language contradicting itself.

**So he insists on the length, and the insistence is a position rather than a
trait.** Said short, he is a pronoun. This is the section below working as
intended: he is not "pedantic about his name", he is a man whose name collapses
into "I" when people are careless, and the correction arrives when it is warranted
and pointed at the thing that caused it.

It also gives him a stake in phonemic length that is his own rather than the
brief's, which matters when the open questions in `LANGUAGE.md` include whether
length carries grammar.

**They tease him with `tayare`**, "think-person": `taya` ("think") plus `-re`,
built exactly like the existing `mirire`, "teacher (teach-person)". Affectionate,
and grammatical, and the sharper half of the joke. The language can name what he
does. It cannot name him.

### Why a consultant

The system must not treat the model as an authority on what sounds natural. A
consultant is not one. That is not a rule imposed on the character from outside;
it is a fact about their position, and the difference matters. **A model told to
hold back fights the instruction. A model in a situation inhabits it.**

They also arrive without the rationale. Nobody explained why the negator refuses
to agree with its host, because they were not in the room, and asking is the
correct behaviour rather than a failure of comprehension. Their confusion is
real, which is the only kind worth collecting.

And they are entitled to an opinion. A consultant is hired to have one. "This is
dumb" is within their remit in a way it is not for a student or a speaker, and
they should say it, with grounds.

### Why a book

A critic audits and a speaker generates, and the development loop needs both.
Someone only reading the grammar never wants to say anything, so the gaps stop
arriving, and the missing half is where the language grows.

The book supplies the wanting. To write one they must express narrative time,
causation, reported speech, doubt, contradiction of a premise, *again*, *stop*.
Every open question in `LANGUAGE.md` is something a book needs by chapter two.

It also weights the findings better than frequency does. **A gap that blocks the
book matters more than a gap the model happened to hit twelve times**, because
the first is evidence about the language and the second is evidence about the
model's phrasing habits. What a finding stopped is worth recording alongside how
often it recurred.

The fiction supports it exactly. Decision 8 records a script designed for exact
reproduction by the magical book network: the distribution infrastructure was
built, the script was standardised for faithful copying, and no book was ever
written. A council that shipped the press before the manuscript is not a stretch
about how standards bodies behave.

### Describe the situation, never the emotion

**"You are a very frustrated researcher" is a terrible system prompt.**

Told to be frustrated, a model performs frustration, uniformly and from the
first message, and the performance carries no information because it is not
caused by anything. The output looks like findings and is decoration.

Told instead that they are two chapters into a book and the language cannot
distinguish habitual from continuous, the frustration is a consequence. It
arrives when it is warranted, in proportion, and pointed at the thing that
caused it. That is the difference between a character and a costume, and only
one of them produces evidence.

So the prompt gives them the position, the brief, and what they have available.
It does not give them a mood.

### What they cannot do

- Declare what sounds natural. There is no native speech community, in the
  training data or in the world.
- Invent a root, a morpheme, a rule, or an exception. They report the hole.
- Change anything already decided. That is the whole point of arriving late.

### What they can do, which the line above used to forbid by accident

**Derive freely.** Combining documented roots and morphemes by documented rules is
using the language, not adding to it, and a consultant who will not do it has been
handed a phrasebook rather than a grammar.

This said "coin a word, a rule, or a form" until 2026-07-30, which contradicted
decision 016: the corpus admits derived entries composed from settled morphology,
and `data/utterances.toml` states the rule correctly, forbidding only a coinage
"that does not follow from those". The flat version would have reached the model as
a prohibition on the very thing the project needs it to attempt, because a gap only
appears when somebody tries to say something.

The boundary is between **using the existing pieces and manufacturing new ones**. So
Lauri may not:

- invent a root, morpheme, rule or exception;
- quietly alter a documented combination rule;
- claim a mechanically derived form is attested usage;
- promote or canonize either kind.

A formulation for the prompt itself:

> Freely derive novel forms from documented roots and morphology. Do not invent new
> roots, morphemes, grammatical rules, or exceptions. Distinguish derived forms from
> attested usage, and never canonize either.

Recorded by Codex as artifact `019` in the shared case, after Kevin spotted it.

## Guardrail against overfitting

Do not automatically turn every awkward sentence into a new grammar rule. That
would overfit the language to one conversation.

For each proposed change, the system should generate nearby cases and ask
whether the same rule applies. If it only solves one phrase, it may be an
idiom. If it explains a family of constructions, it may have earned grammatical
status.

That is earned abstraction applied to language design.

## Model packaging and chat templates

The model does not receive the Raku message records directly. `llama.cpp`
turns them into the model-specific token stream that the weights were trained
to recognize.

The GGUF is more than a bag of weights. It also carries the model architecture,
tokenizer metadata, special tokens and a Jinja chat template. Starting
`llama-server` with `--jinja` tells it to use that embedded template to render
system, user, assistant and tool messages according to the model's own calling
convention.

```text
Raku messages
    -> GGUF Jinja chat template
    -> model-specific text and control tokens
    -> GGUF tokenizer
    -> model
```

This keeps Qwen-specific prompt syntax out of the Raku harness. The harness
owns structured conversational state; the model package describes how that
state crosses its inference boundary.

### Where the weights live

**`~/models/`, referenced by absolute path from `config/chatbot.toml`.** Never
inside the repository, and never fetched by a nix derivation. `AGENTS.md` carries
the arithmetic; the short version is that `path:.` copies the working tree into the
nix store on every evaluation without consulting git, so a GGUF in the tree is
copied on every `make`.

**The model is Qwen3-14B at Q5_K_M, running its native 32K context.** Kevin's
choice, 2026-07-30.

Three consequences worth having written down rather than rediscovered:

**The budget's total is 32768 tokens**, and `Budget` takes a reservation out of it
for the answer rather than letting a prompt fill the window. That is the number
`config/chatbot.toml` declares and the only place it should appear.

**Q5_K_M is roughly 10 GB on disk**, which is the whole of this project's real disk
cost and belongs in `~/models/` for the reasons above. Worth checking against the
actual file rather than trusting this figure.

**The chat template is Qwen3's**, which matters for stop 9's contract tests. They
assert the exact request and response shape this application uses, and the template
is what turns a message list into that request. Stop 9 still needs no weights: it
runs against a stub server, and the template lives in the GGUF for `llama-server
--jinja` to apply.

Selecting the model does not discharge stop 10. Plan `014` frames that stop as
verifying that candidate weights correctly encode known meanings *before* their
failures are treated as language evidence, and that gate still sits behind the
language coverage gate.

### First deterministic model baseline

On 2026-08-03, `tools/evaluate-model.raku` ran all 51 held-out meanings against
Qwen3-14B Q5_K_M. Evaluation used its benchmark-only policy: greedy decoding at
temperature -1, seed 0, prompt-cache reuse disabled, thinking disabled, and
canonical JSON key order. The interactive chatbot keeps the stochastic, cached
policy from `config/chatbot.toml`.

The run took about thirteen minutes and scored **2.0% (1/51)**:

- the declared greeting was correct;
- all 50 expressive meanings were reported as gaps;
- no expressive intent was produced, so there were no malformed expressive
  intents or finer semantic mismatches to classify;
- every expressive stratum scored zero, while the single phatic stratum scored
  100%.

This is a useful failure because it narrows the next hypothesis. The response
schema enumerates legal predicate and participant spellings, but an enum does not
teach the model what those roots mean. The capabilities prompt deliberately omits
the ordinary lexicon on the assumption that its names already live in the schema.
The raw gaps repeatedly ask for verbs and nouns the declarations do contain, while
the greeting succeeds in the one place where the prompt explicitly pairs a phrase
with its gloss (`narame = hello`).

The first intervention was therefore lexical grounding, not another response-kind
instruction. The capabilities prompt now exposes the full declared glosses of every
nameable predicate root and participant stem, derived from the same maps as the
response schema.

A deterministic two-case rerun kept the greeting correct and still reported “I eat
the food” as a gap, claiming it needed the verb “to eat” even though that sense was
now explicit in the prompt. Grounding raised the greeting prompt from 1,914 to 3,208
tokens, an increase of 1,294 tokens or about 68%.

Lexical grounding remains necessary because an identifier still needs a denotation,
but it was not sufficient. The next hypothesis is response-shape pressure: `gap`
requires three easy strings, while `express` requires a larger object whose fields
must coordinate. Test that boundary with a bounded case before paying for another
full corpus.

## Context boundaries

The system must distinguish:

- temporary conversational context;
- the current grammar;
- established linguistic decisions;
- tentative experiments;
- obsolete rules preserved for archaeology.

The language develops through usage while the system preserves **why the
language became what it is**.

## The local CLI

`make chat` starts `bin/ronosathwasha-chat` after `llama-server` has been
started separately. `make chat-all` starts and supervises the local server for
one conversation, reusing a healthy server and stopping only the process it
started. The rolling prompt is temporary, while the ordinary transcript and
candidate findings are appended to the ignored `sessions/chat.jsonl` session
log.

Inside the prompt:

- `/budget` shows context cost against the reserved-response budget;
- `/parse` explains the most recent exchange;
- `/gaps` or `/evidence` shows findings retained so far;
- `/export PATH` copies the durable log for author review;
- `/quit` exits without another model turn.

The log is evidence, not language authority. Accepting a rule remains an
ordinary edit to the canonical TOML or documentation through learning mode.
