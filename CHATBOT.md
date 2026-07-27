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

The chatbot becomes Ronesathwasha's **first permanent second-language learner**.
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

## Guardrail against overfitting

Do not automatically turn every awkward sentence into a new grammar rule. That
would overfit the language to one conversation.

For each proposed change, the system should generate nearby cases and ask
whether the same rule applies. If it only solves one phrase, it may be an
idiom. If it explains a family of constructions, it may have earned grammatical
status.

That is earned abstraction applied to language design.

## Context boundaries

The system must distinguish:

- temporary conversational context;
- the current grammar;
- established linguistic decisions;
- tentative experiments;
- obsolete rules preserved for archaeology.

The language develops through usage while the system preserves **why the
language became what it is**.
