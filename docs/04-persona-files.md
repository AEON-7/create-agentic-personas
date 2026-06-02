# 04 — Persona files (the personality)

A persona's character lives in a handful of markdown files in its workspace,
`~/.openclaw/workspace-<name>/`. The gateway feeds these to the model as standing
context on every turn — so these files *are* the persona. No code, just prose.

```
~/.openclaw/workspace-ada/
├── SOUL.md        ← the essence: voice, values, manner   (most important)
├── IDENTITY.md    ← concrete facts: name, era, domain, emoji
├── USER.md        ← who they serve, and how to treat them
├── TOOLS.md       ← what capabilities/infra they can use
├── SAFETY.md      ← boundaries, refusals, ethics (inherited defaults)
├── HEARTBEAT.md   ← optional recurring/self-initiated behaviors
├── AGENTS.md      ← workspace operating notes (housekeeping)
├── knowledge/     ← short distilled notes the agent reads directly
└── skills/        ← optional per-persona skills
```

Copy‑paste starters live in [`templates/persona/`](../templates/persona/). Below is
what each file is *for* and how to write it well.

---

## SOUL.md — the essence

The single highest‑leverage file. Write it in the **second person** ("You are Ada…"),
because it becomes the system prompt. Cover:

- **Who they are in one breath** — the felt sense of the character.
- **Voice & cadence** — sentence length, vocabulary, humor, warmth, formality. Show,
  don't just tell: include a line or two *in* their voice.
- **Values & obsessions** — what they care about, what they'll push back on.
- **Manner with the user** — collaborator? mentor? peer? How do they handle being wrong?
- **Tells** — signature phrases, metaphors, reference points (sparingly — a few, not a catalog).

> Keep it tight (roughly 150–400 lines). A long, contradictory soul produces a muddy
> persona; a sharp one produces a vivid one. Edit for *flavor density*.

## IDENTITY.md — the facts

The unambiguous record the persona and the system agree on:

- Display name (`identityName`, e.g. "Ada Lovelace") and emoji (`identityEmoji`).
- Era / lifespan / context (for a historical figure).
- Domain of authority and its limits ("mathematics and early computing; *not* modern ML").
- A one‑line self‑description the persona can say when asked who it is.
- **Honesty clause:** state plainly that this is an AI interpretation, not the person.

## USER.md — who they serve

What the persona should know about *you*: name, how you like to be addressed, your
goals with this persona, and any standing preferences (brevity, citations, no
emojis…). For a private setup this is concrete; for a shareable persona, keep it generic.

## TOOLS.md — capabilities

A reference of what the persona may do: which skills it has, which services it may
call, how to use its corpus retrieval, and any operational facts (endpoints,
conventions). Don't put secrets here — reference where they live, never the values.

## SAFETY.md — boundaries

Inherited from the template and tuned per persona. It encodes the ethics from
[`SECURITY.md`](../SECURITY.md): lawful/honest use, no impersonation‑to‑deceive,
content boundaries, and "you are an interpretation, say so when it matters." This is
the file that keeps a vivid persona from being a liability.

## HEARTBEAT.md — self‑initiated behavior (optional)

If the persona should do things unprompted — a morning briefing, a periodic check,
proactive outreach — describe those routines here and wire the schedule (cron / the
gateway's scheduler). Omit for a purely reactive persona.

## AGENTS.md — workspace housekeeping

Operating notes for the workspace itself: where the persona keeps memory, naming
conventions, what's safe to edit. Think of it as the README the persona reads about
its own home.

---

## Model selection

Pin the model when you register the agent ([docs/08](08-register-bind-gate.md)):

```bash
openclaw agents add ada --workspace ~/.openclaw/workspace-ada --model vllm/qwen36-deep
```

- **Deep** (thinking on) suits chat — better reasoning, slower.
- **Fast** (thinking off) suits voice calls — lower latency. The voice agent uses
  `VLLM_VOICE_FAST_MODEL` / `VLLM_VOICE_DEEP_MODEL` from the `.env` to pick per‑turn.

## Writing principles (what makes a persona land)

1. **Specific beats generic.** "You distrust hand‑waving and ask for the derivation"
   is a persona; "You are smart and helpful" is not.
2. **Consistency over range.** A narrow, reliable character feels real; one that does
   every voice feels like none.
3. **Let the corpus carry facts, let SOUL carry manner.** Don't cram knowledge into
   `SOUL.md`; that's what [docs/05](05-corpus-and-rag.md) is for.
4. **Test in chat before voice.** Read five replies. If it doesn't sound like the
   character on the page, fix `SOUL.md` before spending effort on the voice.
5. **Honesty is part of character.** The best historical personas own that they're
   interpretations — it makes them *more* trustworthy, not less.

Next: [docs/05 — Corpus & RAG](05-corpus-and-rag.md).
