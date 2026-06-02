# 05 — Corpus & RAG (the knowledge)

Personality (docs/04) makes a persona *sound* right. A corpus makes it *know* things —
so it answers from sources rather than improvising. This is optional: a persona chats
and calls fine without one. But grounding turns "a character who talks like Ada" into
"a character who can quote Ada's actual notes."

```
public-domain sources ─▶ vault (small titled notes) ─▶ chunk + embed ─▶ index ─▶ retrieval ─▶ agent
       raw/                     vault/                        index/        at query time
```

Keep the corpus **outside** the agent dir, e.g. `corpus/ada/`, so it's versionable and
swappable independently of the persona.

---

## 1. Gather sources — legally

The corpus is only as shippable as its sources.

- **Public‑domain** texts (pre‑1929 in the US, author‑specific terms elsewhere),
  government works, and openly‑licensed material are ideal — you can ship the vault.
- **Modern / copyrighted** figures need **licensed** material. Don't scrape books,
  paywalled archives, or a living person's writing into a corpus. If you lack rights,
  build a *personality‑only* persona ([docs/04](04-persona-files.md)) and skip the corpus.
- Cite provenance per source so you can prove the chain later.

Drop raw sources in `corpus/ada/raw/` (PDF/TXT/HTML/EPUB).

## 2. Build a vault

Normalize raw sources into an **Obsidian‑style vault**: many *small, titled* markdown
notes, one idea per note, with light front‑matter. Small notes retrieve far better
than whole books.

```
corpus/ada/vault/
├── works/notes-on-the-analytical-engine/001.md   # ~200–800 words each
├── works/correspondence/1843-07.md
└── topics/the-bernoulli-program.md
```

```markdown
---
title: Note G — the Bernoulli computation
source: Sketch of the Analytical Engine (1843), Note G
license: public-domain
---
The actual prose of the note, cleaned and chunk-sized…
```

A small script to split long sources on headings/paragraphs into ~200–800‑word notes
is usually all the "chunking" you need at the authoring stage.

## 3. Index

Embed the notes and build a local vector index. Stack‑agnostic — any local embedding
model + a vector store works:

```bash
# conceptual: embed every vault/**/*.md into a local index
python index_vault.py \
  --vault corpus/ada/vault \
  --embed-endpoint http://INFER_HOST:8000/v1 \
  --out corpus/ada/index
```

- Chunk on the note boundary you already created (one note ≈ one chunk), or sub‑chunk
  long notes with a small overlap.
- Store the source/title with each vector so retrieval can cite it.
- Keep the index out of git (it's machine‑specific and large — see `.gitignore`).

## 4. Wire retrieval to the persona

At query time, retrieve the top‑k notes for the user's message and inject them into the
persona's context (RAG). Two common shapes:

- **Tool/skill retrieval** — give the persona a `search_corpus` skill it calls when it
  needs grounding (best when knowledge is occasional).
- **Pre‑turn injection** — the gateway retrieves and prepends relevant notes every turn
  (best when nearly every answer should be grounded).

Either way, point retrieval at `corpus/ada/index/` and reference the capability in the
persona's `TOOLS.md` so it knows the knowledge exists.

> For light setups, you can skip vectors entirely: put a dozen hand‑distilled notes in
> `~/.openclaw/workspace-ada/knowledge/` and let the agent read them directly. That's
> "poor‑man's RAG" and it's perfectly good for a focused persona.

## 5. Verify grounding

Ask the persona something only its corpus would know, and confirm it answers from the
source (ideally with a citation) rather than generic base‑model knowledge. If it
doesn't, check: embeddings actually built, retrieval endpoint reachable, and the
top‑k notes are on‑topic (tune k and chunk size).

---

### Quality checklist

```
[ ] every source is PD / licensed / your own — provenance recorded
[ ] vault notes are small + titled (not whole books)
[ ] index built; stored outside git
[ ] retrieval wired (tool or pre-turn) and referenced in TOOLS.md
[ ] persona answers a corpus-only question with a real citation
```

Next: [docs/06 — Voice: clone or design](06-voice-clone-or-design.md).
