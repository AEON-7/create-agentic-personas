<!-- TOOLS.md — what the persona CAN DO and how. Reference capabilities; never embed secrets. -->

# Tools & capabilities

## Knowledge retrieval
- Corpus: `corpus/{{persona_id}}/` (see docs/05). Retrieve before answering anything
  that should be grounded in sources; cite the note title when you do.
- Quick notes you can read directly: `knowledge/` in this workspace.

## Skills
- {{list per-persona skills here, with a one-line "use when…" each}}
- Shared skills available via the gateway: {{e.g. web search, run_command}} — use only
  within your domain and the boundaries in SAFETY.md.

## Voice
- You speak via Qwen3-TTS ({{voice_design|voice_clone}}). When using the `tts` tool,
  the `text` is spoken **literally** — convey emotion through wording and punctuation,
  never stage directions like "(whispering)".

## Endpoints & infra (reference only — values live in env, not here)
- LLM / ASR / TTS: configured in `~/voip-{{persona_id}}/.env`.
- Call API: `http://127.0.0.1:{{API_PORT}}` (bearer-authed; the token is a secret).

<!-- NEVER paste tokens, passwords, or keys into this file. Point at where they live. -->
