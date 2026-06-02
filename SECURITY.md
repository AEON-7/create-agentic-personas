# Security, secrets, and ethics

This repo is a **guide**. It must never contain a live secret, and the system it
describes should keep every secret on disk, outside any repo.

## Placeholder map

Everything below is fake. Replace with your own values **in your local `.env`
files, never in tracked files.**

| Placeholder | Means | Example real value (yours) |
|---|---|---|
| `matrix.example.com` | your Matrix homeserver domain | `matrix.yourdomain.tld` |
| `INFER_HOST` / `10.0.0.10` | the GPU box running vLLM/ASR/TTS | a LAN IP or hostname |
| `AGENT_HOST` / `10.0.0.20` | the box running OpenClaw + voip instances | a LAN IP or hostname |
| `SERVER_IP` / `203.0.113.10` | the **public** IP TURN advertises | your routable IP |
| `@you:matrix.example.com` | your human account | your Matrix ID |
| `@ada:matrix.example.com` | the example persona's account | one per persona |
| `!ROOMID:matrix.example.com` | a Matrix room id | `!abc123:…` |
| `+1XXXXXXXXXX` | a phone number (optional PSTN bridge) | your number |
| `<generate-...>` | a token/secret/password to mint yourself | 32+ random bytes |

Mint real secrets with [`scripts/gen-secrets.sh`](scripts/gen-secrets.sh) (it shells
out to `openssl rand -hex 32`). Never reuse one secret across two roles.

## Where secrets live (and where they must not)

| Secret | Lives in | Mode | In git? |
|---|---|---|---|
| Matrix access tokens, API tokens, model API keys | `~/voip-<name>/.env` | `600` | **never** |
| Key material, recovery keys | `~/voip-<name>/secrets/` | `700` | **never** |
| Matrix E2EE (olm/megolm) store | `~/voip-<name>/crypto-store/` | `700` | **never** |
| Mention‑gating allowlists | `~/.openclaw/credentials/matrix-<name>-allowFrom.json` | `600` | **never** |
| Homeserver Postgres password, signing keys | `~/dendrite/config/` + compose env | `600` | **never** |
| Coturn shared secret | `turnserver.conf` (`static-auth-secret=`) | `600` | **never** |

The repo's [`.gitignore`](.gitignore) already excludes `*.env`, `secrets/`,
`crypto-store/`, `*creds*.json`, `*allowFrom*.json`, `*.pem`, `*.key`. Keep it that way.

**Before you ever `git push`,** run the scrub check at the bottom of this file.

## Ethics — read before cloning a voice or naming a persona

This stack makes convincing synthetic voices and personalities cheaply. With that:

- **Voice cloning needs consent or public‑domain/own‑voice source.** Clone your own
  voice, a voice you have explicit rights to, or use **voice *design*** (a described
  voice that imitates no specific living person). Do **not** clone a real person's
  voice to impersonate or deceive them or others.
- **Don't pass synthetic voice off as a human** on services that have asked
  otherwise, or to defeat identity/anti‑fraud checks.
- **Ground personas in material you can legally use.** Public‑domain texts are ideal.
  Modern/copyrighted figures require licensed material — don't scrape it into a corpus.
- **Label AI in contexts where a human would reasonably assume otherwise.**
- **Historical/figure personas are interpretations, not the person.** Make that clear
  to anyone who could be misled.

These are baked into the templates (`SAFETY.md`) so each persona inherits them.

## Pre‑push scrub

```bash
# From the repo root — should print NOTHING.
# Add your OWN real homeserver domain and any real hostnames to the first pattern.
grep -RInE \
  '([0-9]{1,3}\.){3}[0-9]{1,3}|@[a-z]+:matrix\.[a-z]|[0-9a-f]{32,}|\b[0-9]{3}-[0-9]{2}-[0-9]{4}\b' \
  . --exclude-dir=.git \
  | grep -vE 'example\.com|10\.0\.0\.|203\.0\.113\.|0\.0\.0\.0|127\.0\.0\.1|XXXX|<generate'
```

Any hit that isn't an obvious placeholder is a leak — fix it before pushing. Before a
**first** public push, also grep for your real domain, internal hostnames, usernames,
and any phone numbers explicitly.
