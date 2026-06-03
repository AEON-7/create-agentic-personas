# Create Agentic Personas

[![☕ Tips — Support the work](https://img.shields.io/badge/%E2%98%95_Tips-Support_the_work-ff5e5b?style=flat)](#-support-the-work)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow?style=flat)](LICENSE)

*A complete, reproducible blueprint for standing up a fully‑embodied AI persona —
one that lives in **Matrix chat**, holds **real‑time WebRTC voice calls**, speaks
in its **own cloned or designed voice**, and answers from a **private knowledge
corpus** — and for scaling that from one persona to a whole roster on a single box.*

This repo is the generalized, secret‑free writeup of a setup that runs a roster of
~30 distinct voice‑and‑chat personas on one workstation. Every persona is an
independent identity with its own Matrix account, voice, knowledge, and phone‑style
call line, yet they all share one inference backend and one homeserver.

> **Nothing in this repo contains live credentials.** Every host, domain, token,
> and key is a placeholder. See [`SECURITY.md`](SECURITY.md) for the secret map and
> [where real secrets live on disk](docs/08-register-bind-gate.md#where-secrets-live)
> (always outside the repo).

---

## What you get per persona

| Capability | Stack | Result |
|---|---|---|
| **Chat identity** | OpenClaw agent + Matrix account (Dendrite) | `@ada:matrix.example.com` you can DM or @‑mention in a room |
| **Personality** | A small set of workspace markdown files (`SOUL.md`, `IDENTITY.md`, …) | Consistent voice, values, and boundaries across every turn |
| **Knowledge** | Public‑domain corpus → Obsidian‑style vault → chunk + index → local RAG | Answers grounded in *its* sources, not just the base model |
| **Voice** | Qwen3‑TTS, either **voice clone** (from reference audio) or **voice design** (from a text description) | A distinct, persistent timbre that is recognizably *that* character |
| **Live voice calls** | `matrix-voip-agent` + PipeWire + Coturn/WebRTC + Qwen3‑ASR | Call the persona from Element and have a ~5–8 s‑latency spoken conversation |
| **Reachability** | Per‑agent HTTP API (`/call`, `/hangup`, `/status`) | The persona can call *you*, or be triggered by scripts/cron |

## The big picture

```
                                  ┌──────────────────────────────────────────────┐
                                  │  INFERENCE HOST (one GPU box) — "voice         │
                                  │  containers" + LLM, all OpenAI-compatible      │
                                  │                                                │
                                  │   vLLM    :8000   LLM   (Qwen3-class, fast+deep)│
                                  │   ASR     :8001   STT   (Qwen3-ASR)             │
                                  │   TTS     :8002   voice (Qwen3-TTS clone/design)│
                                  └───────────────▲───────────────▲────────────────┘
                                                  │               │
   Element / phone                                │ HTTP          │ HTTP
   (you, a human)                                 │               │
        │                                ┌────────┴───────────────┴─────────────────┐
        │ Matrix chat + WebRTC voice     │  AGENT HOST (one workstation)             │
        ▼                                │                                           │
 ┌─────────────────┐  m.call.invite      │  OpenClaw gateway ── chat for every agent │
 │ Dendrite HS     │◀───────────────────▶│  ├─ agent "ada"   (workspace-ada/ + Matrix│
 │ + Postgres      │                     │  │                 account binding)        │
 │ + Caddy (TLS)   │   WebRTC media      │  ├─ agent "tesla" …                       │
 │ + Coturn (TURN) │◀═══════════════════▶│  └─ … one per persona                     │
 └─────────────────┘                     │                                           │
                                         │  matrix-voip-agent-<name>.service  ──┐    │
                                         │   (one per persona, own .env + API)  │    │
                                         │  <name>-voip-stt / -tts (PipeWire) ──┘    │
                                         └───────────────────────────────────────────┘

   Voice-call data path (no Matrix in the conversation loop after pickup):
     caller voice ─WebRTC▶ PipeWire(loopback) ─▶ Qwen3-ASR ─▶ vLLM ─▶ Qwen3-TTS ─▶ PipeWire ─WebRTC▶ caller
```

Two machines is the reference shape (a GPU box for inference, a workstation for
agents + homeserver), but it collapses to one box fine. The homeserver and TURN can
also live on a small VPS if you want calls reachable from outside your LAN.

## Anatomy of one persona on disk

```
~/.openclaw/
├── agents/<name>/                      # OpenClaw agent state (sessions, model pin)
├── workspace-<name>/                   # the PERSONA: who they are
│   ├── SOUL.md  IDENTITY.md  USER.md   #   character, self, who they serve
│   ├── TOOLS.md SAFETY.md  HEARTBEAT.md#   capabilities, boundaries, routines
│   ├── AGENTS.md                       #   workspace operating guide
│   ├── knowledge/                      #   distilled notes the agent reads directly
│   └── skills/                         #   per-persona skills (optional)
└── credentials/
    └── matrix-<name>-allowFrom.json    # mention-gating: who may invoke this agent

~/voip-<name>/                          # the VOICE-CALL profile (one per persona)
├── .env            (mode 600)          #   all per-agent secrets + endpoints
├── secrets/                            #   key material
├── crypto-store/                       #   Matrix E2EE (olm/megolm) state
├── stt-loopback.sh  tts-loopback.sh    #   per-agent PipeWire virtual devices

corpus/<name>/                          # the KNOWLEDGE (kept out of the agent dir)
└── vault/ … → chunked + indexed → local RAG store
```

Everything that is *secret* lives in `.env`, `secrets/`, `crypto-store/`, and the
`credentials/` JSONs — all of which are git‑ignored and never belong in this repo.

## Repo map

| Path | What it is |
|---|---|
| [`AGENTS.md`](AGENTS.md) | **Start here.** The end‑to‑end runbook: take a blank box to a working voice‑and‑chat persona, step by step. |
| [`skills/create-agentic-persona/SKILL.md`](skills/create-agentic-persona/SKILL.md) | An **agent skill** so an existing OpenClaw agent (e.g. your operator persona) can scaffold new personas itself. |
| [`docs/01-inference-stack.md`](docs/01-inference-stack.md) | The inference + **voice containers**: vLLM (LLM), Qwen3‑ASR (STT), Qwen3‑TTS (voice). |
| [`docs/02-matrix-homeserver.md`](docs/02-matrix-homeserver.md) | Dendrite + Postgres + Caddy homeserver. |
| [`docs/03-turn-and-webrtc.md`](docs/03-turn-and-webrtc.md) | **Matrix TURN + WebRTC**: Coturn, Jitsi, and the Dendrite VoIP config. |
| [`docs/04-persona-files.md`](docs/04-persona-files.md) | The persona markdown files and how to write them. |
| [`docs/05-corpus-and-rag.md`](docs/05-corpus-and-rag.md) | Building a corpus → vault → index → retrieval. |
| [`docs/06-voice-clone-or-design.md`](docs/06-voice-clone-or-design.md) | Cloning a voice from audio **or** designing one from a description. |
| [`docs/07-voip-profile.md`](docs/07-voip-profile.md) | The per‑persona voice‑call instance: PipeWire, systemd, the call API. |
| [`docs/08-register-bind-gate.md`](docs/08-register-bind-gate.md) | Registering the agent, binding its Matrix account, mention‑gating, and **where secrets live**. |
| [`templates/`](templates/) | Copy‑paste: persona files, annotated `.env`, systemd units, `turnserver.conf`, `docker-compose`. |
| [`scripts/`](scripts/) | `new-persona.sh` (scaffold a persona) and `gen-secrets.sh` (mint tokens). |
| [`setup.sh`](setup.sh) · [`sync.sh`](sync.sh) | First‑time infra/tool validation; diff‑preview self‑updater. |
| [`ATTRIBUTION.md`](ATTRIBUTION.md) | Upstream credits + verified licenses for every component. |

## Quickstart (one persona, assuming infra is up)

```bash
# 0. One-time: stand up inference (docs/01), homeserver (docs/02), TURN (docs/03).
#    Then validate everything is reachable + tooling is present:
./setup.sh --infer-host INFER_HOST

# 1. Scaffold a new persona named "ada"
./scripts/new-persona.sh ada --port 8210

# 2. Write the personality (edit the seeded files)
$EDITOR ~/.openclaw/workspace-ada/SOUL.md      # voice, values, manner
$EDITOR ~/.openclaw/workspace-ada/IDENTITY.md  # who Ada is

# 3. Give Ada a voice (pick ONE)
#    a) clone:  drop 10-30s of clean reference audio and set VOXTRAL_TTS_MODE=voice_clone
#    b) design: write VOXTRAL_VOICE_DESCRIPTION="..." and set VOXTRAL_TTS_MODE=voice_design

# 4. Build her knowledge (optional but recommended)
#    gather public-domain sources -> corpus/ada/vault -> index (docs/05)

# 5. Register + bind + gate, then start her call line
openclaw agents add ada --workspace ~/.openclaw/workspace-ada --model vllm/qwen36-deep
#    bind Matrix account + mention-gating (docs/08), then:
systemctl --user enable --now ada-voip-stt ada-voip-tts matrix-voip-agent-ada

# 6. Say hi
#    @-mention @ada in a Matrix room, or place a WebRTC call to her from Element.
```

The long form of every step — with the *why*, the gotchas, and the verification
commands — is in [`AGENTS.md`](AGENTS.md).

## Design principles (learned the hard way)

- **One engine, many instances.** The chat gateway and the voice‑agent binary are
  shared. A persona is just a workspace + an `.env` + a Matrix account + a voice.
  Adding the 30th persona costs the same as the 2nd.
- **Per‑agent audio isolation.** Each persona gets its own PipeWire loopback
  devices, so dozens can hold simultaneous, non‑bleeding calls.
- **Public‑domain corpora.** Ground personas in sources you can legally ship.
  (Modern/copyrighted figures need licensed material — don't scrape it.)
- **Secrets live in `.env`/`secrets/`, never in the persona or the repo.**
- **Consent and honesty for voices.** Clone voices you have the right to clone;
  don't impersonate real people to deceive. See [`SECURITY.md`](SECURITY.md).

## ☕ Support the work

If this guide helped you stand up your own personas, tips are deeply appreciated — they
go directly toward more compute, more models, and more open releases. **Scan a QR with
your wallet, or click any address below to copy.**

<table align="center">
  <tr>
    <td align="center" width="50%">
      <strong>₿ Bitcoin (BTC)</strong><br/>
      <img src="assets/qr/btc.png" alt="BTC QR" width="200"/><br/>
      <sub><code>bc1q09xmzn00q4z3c5raene0f3pzn9d9pvawfm0py4</code></sub>
    </td>
    <td align="center" width="50%">
      <strong>Ξ Ethereum (ETH)</strong><br/>
      <img src="assets/qr/eth.png" alt="ETH QR" width="200"/><br/>
      <sub><code>0x1512667F6D61454ad531d2E45C0a5d1fd82D0500</code></sub>
    </td>
  </tr>
  <tr>
    <td align="center" width="50%">
      <strong>◎ Solana (SOL)</strong><br/>
      <img src="assets/qr/sol.png" alt="SOL QR" width="200"/><br/>
      <sub><code>DgQsjHdAnT5PNLQTNpJdpLS3tYGpVcsHQCkpoiAKsw8t</code></sub>
    </td>
    <td align="center" width="50%">
      <strong>ⓜ Monero (XMR)</strong><br/>
      <img src="assets/qr/xmr.png" alt="XMR QR" width="200"/><br/>
      <sub><code>836XrSKw4R76vNi3QPJ5Fa9ugcyvE2cWmKSPv3AhpTNNKvqP8v5ba9JRL4Vh7UnFNjDz3E2GXZDVVenu3rkZaNdUFhjAvgd</code></sub>
    </td>
  </tr>
</table>

> **Ethereum L2s (Base, Arbitrum, Optimism, Polygon, etc.) and EVM‑compatible tokens**
> can be sent to the same Ethereum address.

---

## License

MIT — see [`LICENSE`](LICENSE). The *guide* is freely reusable; the *model weights,
homeserver software, and any voice you clone* carry their own licenses and consent
requirements, which are yours to honor.
