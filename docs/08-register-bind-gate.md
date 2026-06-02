# 08 — Register, bind, gate (+ where secrets live)

The wiring that connects the three identities a persona actually has — its **OpenClaw
agent**, its **Matrix account**, and its **voice‑call profile** — and the access
control that decides **who may summon it**. Plus the canonical map of where every
secret lives on disk.

```
 OpenClaw agent "ada" ──bind──▶ Matrix @ada:matrix.example.com ──token──▶ voip-ada/.env
        │                              │
        └── mention-gating ────────────┘
            (allowFrom: who may invoke ada)
```

---

## 1. Create the Matrix account

On the homeserver ([docs/02](02-matrix-homeserver.md)), create one account per persona
and get an **access token**.

```bash
# create (admin API or dendrite's create-account; registration otherwise disabled)
# then log in to mint a token for the agent to use:
curl -s -XPOST http://127.0.0.1:8008/_matrix/client/v3/login \
  -d '{"type":"m.login.password","identifier":{"type":"m.id.user","user":"ada"},"password":"<ada-password>","initial_device_display_name":"ada-voip"}' \
  | python3 -c 'import sys,json;d=json.load(sys.stdin);print("token:",d["access_token"]);print("device:",d["device_id"])'
```

Store the token + device id in `~/voip-ada/.env` (`MATRIX_ACCESS_TOKEN`,
`MATRIX_DEVICE_ID`). Optionally keep a copy in `~/.openclaw_ada_creds.json` (mode 600)
as a recovery record. **Never** put the token in the workspace or this repo.

## 2. Register the OpenClaw agent

```bash
openclaw agents add ada \
  --workspace ~/.openclaw/workspace-ada \
  --model vllm/qwen36-deep \
  --identity-name "Ada Lovelace" \
  --identity-emoji "♾️"
```

This creates `~/.openclaw/agents/ada/` (session state, model pin). Confirm:

```bash
openclaw agents list --json | python3 -c '
import sys,json
for a in json.load(sys.stdin):
    if a["id"]=="ada": print(a["id"], a["identityName"], a["model"], a["workspace"])'
```

## 3. Bind the Matrix account to the agent

Binding tells the gateway "messages to/from `@ada` are agent `ada`." The agent object
carries a `bindings` field linking it to the Matrix account; the account credentials
live in the gateway's account store (`~/.openclaw/matrix/accounts`) and/or the voip
`.env`. After binding:

```bash
openclaw gateway restart
```

## 4. Gate who may summon it (mention‑gating)

So random homeserver users can't drive your persona, restrict who it responds to.
Per‑agent allowlist:

```
~/.openclaw/credentials/matrix-ada-allowFrom.json
```

```json
{ "allowFrom": ["@you:matrix.example.com"] }
```

- Start with **just you**. Add others deliberately.
- For voice, the parallel control is `AUTHORIZED_USERS` in `~/voip-ada/.env` — only
  those IDs get auto‑answered.
- Mention‑gating in shared rooms means the persona only acts when **@‑mentioned** by an
  allowed user (so 30 personas in one room don't all answer at once).

Restart the gateway after editing gating, then verify:

```bash
# @-mention @ada from an allowed account → replies.  From a non-allowed account → silent.
```

## 5. E2EE first‑run (encrypted rooms only)

If your rooms are encrypted, the persona's device must cross‑sign and persist keys:

```ini
# in ~/voip-ada/.env
MATRIX_E2EE_ENABLED=true
MATRIX_E2EE_REQUIRED=false
MATRIX_AUTO_CROSS_SIGN=true
MATRIX_RESTORE_KEY_BACKUP_ON_START=true
CRYPTO_STORE_PATH=/home/USER/voip-ada/crypto-store
MATRIX_RECOVERY_KEY_FILE=/home/USER/voip-ada/secrets/recovery-key.txt
MATRIX_CRYPTO_STORE_PASSWORD=<secret>
```

On first start the agent self‑verifies and writes its crypto‑store. If you later see
"unable to decrypt," the store lost its cross‑signing — re‑verify / restore the key
backup. Each persona keeps its **own** crypto‑store; don't share one across agents.

---

## Where secrets live

The canonical map — **all of these are git‑ignored and host‑local:**

| Secret | Path | Mode |
|---|---|---|
| Matrix access token, API token, model keys, crypto‑store password | `~/voip-<name>/.env` | `600` |
| Recovery key, other key material | `~/voip-<name>/secrets/` | `700` |
| Matrix E2EE store | `~/voip-<name>/crypto-store/` | `700` |
| Credentials backup (optional) | `~/.openclaw_<name>_creds.json` | `600` |
| Mention‑gating allowlist | `~/.openclaw/credentials/matrix-<name>-allowFrom.json` | `600` |
| Gateway account store | `~/.openclaw/matrix/accounts` | `700` |
| Homeserver Postgres password, signing key | `~/dendrite/config/`, compose env | `600` |
| Coturn shared secret | `turnserver.conf` (`static-auth-secret=`) | `600` |

Mint new secrets with [`scripts/gen-secrets.sh`](../scripts/gen-secrets.sh). One secret
per role; never reuse. Run the pre‑push scrub in [`SECURITY.md`](../SECURITY.md) before
publishing anything.

---

## The whole loop, condensed

```bash
# (infra already up: docs/01-03)
./scripts/new-persona.sh ada --port 8210                 # scaffold (§ AGENTS.md)
$EDITOR ~/.openclaw/workspace-ada/{SOUL,IDENTITY}.md     # personality (docs/04)
# corpus (docs/05) + voice (docs/06) as desired
# create Matrix account + token (above §1) → ~/voip-ada/.env
openclaw agents add ada --workspace ~/.openclaw/workspace-ada --model vllm/qwen36-deep
echo '{"allowFrom":["@you:matrix.example.com"]}' > ~/.openclaw/credentials/matrix-ada-allowFrom.json
openclaw gateway restart
systemctl --user enable --now ada-voip-stt ada-voip-tts matrix-voip-agent-ada
# → @-mention @ada in chat, then call @ada from Element.
```

Back to the [master runbook](../AGENTS.md) · or hand it to the
[agent skill](../skills/create-agentic-persona/SKILL.md).
