# Attribution

`create-agentic-personas` is a **guide** that orchestrates third‑party software and
models. The guide, scripts, and templates in this repo are MIT (see [`LICENSE`](LICENSE)),
but **each component below carries its own license and terms — honor them.**

Licenses verified against upstream as of June 2026; confirm against the source before
relying on them commercially, as projects relicense over time.

## Infrastructure & runtime

| Project | Role here | License |
|---|---|---|
| [Matrix](https://matrix.org) / [Dendrite](https://github.com/element-hq/dendrite) | Homeserver + protocol — chat identity & call signaling | Apache‑2.0 |
| [PostgreSQL](https://www.postgresql.org) | Dendrite's database | PostgreSQL License |
| [Caddy](https://github.com/caddyserver/caddy) | TLS reverse proxy + `.well-known` discovery | Apache‑2.0 |
| [Coturn](https://github.com/coturn/coturn) | TURN/STUN relay for WebRTC media | BSD‑3‑Clause |
| [Jitsi](https://github.com/jitsi) (Videobridge, Meet) | Optional group/video | Apache‑2.0 |
| [WebRTC](https://webrtc.org) | Real‑time media transport | BSD‑3‑Clause (royalty‑free) |
| [PipeWire](https://gitlab.freedesktop.org/pipewire/pipewire) | Per‑agent audio loopback isolation | MIT |
| [Docker](https://github.com/moby/moby) / Compose | Container runtime | Apache‑2.0 |
| [systemd](https://github.com/systemd/systemd) | Per‑agent service supervision | LGPL‑2.1‑or‑later |
| [Node.js](https://github.com/nodejs/node) | `matrix-voip-agent` runtime | MIT (core; bundled deps vary) |
| [Element](https://github.com/element-hq/element-web) | Matrix client used to place calls | Apache‑2.0 |

## Inference & models

| Project | Role here | License |
|---|---|---|
| [vLLM](https://github.com/vllm-project/vllm) | LLM + ASR serving | Apache‑2.0 |
| [Qwen3](https://huggingface.co/collections/Qwen/qwen3) LLM (Alibaba Qwen) | The persona's reasoning | Apache‑2.0 |
| [Qwen3‑TTS‑VoiceDesign](https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign) (Alibaba Qwen) | Voice clone / design | Apache‑2.0 |
| [Qwen3‑ASR](https://huggingface.co/Qwen/Qwen3-ASR-0.6B) (Alibaba Qwen) | Speech‑to‑text | Apache‑2.0 |
| [whisper.cpp](https://github.com/ggml-org/whisper.cpp) / [Whisper](https://github.com/openai/whisper) (OpenAI) | Optional fallback STT | MIT / MIT |
| local embedding model (your choice) | Corpus/RAG vectors | per model card |

> **Quantized / abliterated / fine‑tuned derivatives** (e.g. NVFP4 builds) may carry
> different terms than the base weights — check the specific model card you deploy.

## Orchestration & reference implementations

| Project | Role here | License |
|---|---|---|
| [OpenClaw](https://github.com/openclaw/openclaw) | The multi‑agent gateway this guide targets (chat hosting, skills, agent management) | MIT |
| [qwen3‑tts‑server](https://github.com/AEON-7/qwen3-tts-server) | Reference Qwen3‑TTS OpenAI‑compatible server | MIT |
| [qwen3‑asr‑server](https://github.com/AEON-7/qwen3-asr-server) | Reference Qwen3‑ASR OpenAI‑compatible server | MIT |
| [matrix‑voip‑agent](https://github.com/AEON-7/matrix-voip-agent) | The shared WebRTC voice‑agent engine each persona runs | MIT |
| [Obsidian](https://obsidian.md) | The "vault of small markdown notes" convention for corpora — a pattern, not a dependency | — |

## Models, voices, and data are *your* responsibility

The guide makes it easy to compose powerful models. The obligations stay with you:

- **Model weights** carry their own licenses and acceptable‑use policies — read each
  model card before commercial use or redistribution.
- **Voice cloning** requires consent, rights, or a public‑domain source. Use voice
  *design* when you have neither. Never clone a real person's voice to impersonate or
  deceive. See [`SECURITY.md`](SECURITY.md).
- **Corpora** must be public‑domain or properly licensed — no scraping copyrighted or
  living‑person material.
- The example persona **Ada Lovelace** is a public‑domain historical figure, used
  purely to illustrate the workflow.

## This repository

The guide, `scripts/`, `templates/`, and the `create-agentic-persona` skill are
released under the [MIT License](LICENSE). If you build something with it, a link back
is appreciated but not required.
