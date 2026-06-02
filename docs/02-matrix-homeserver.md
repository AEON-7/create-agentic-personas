# 02 — Matrix homeserver (Dendrite + Postgres + Caddy)

Every persona needs a Matrix identity (`@ada:matrix.example.com`). You host the
homeserver yourself so you can mint accounts freely and own the data. The reference
stack is **Dendrite** (lightweight, Go) on **Postgres**, fronted by **Caddy** for TLS.

```
Internet ──443──▶ Caddy (TLS, .well-known) ──▶ Dendrite :8008 ──▶ Postgres
                    │
                    └── also fronts TURN/Jitsi (docs/03)
```

You can run this on `AGENT_HOST`, or on a small VPS if you want calls reachable from
outside your LAN. Either way the agents reach it at `http://127.0.0.1:8008` locally.

---

## 1. Compose

Use [`templates/compose/docker-compose.calls.yml`](../templates/compose/docker-compose.calls.yml)
(it includes the call infra from [docs/03](03-turn-and-webrtc.md) too). The homeserver
core:

```yaml
postgres:                      # dendrite_pgdata volume; POSTGRES_PASSWORD from your .env
  image: postgres:16-alpine
dendrite:
  image: matrixdotorg/dendrite-monolith:latest
  volumes: [./config:/etc/dendrite:ro, dendrite_media:/var/dendrite/media, …]
  ports: ["127.0.0.1:8008:8008"]      # only localhost; Caddy terminates TLS
caddy:
  image: caddy:2-alpine
  ports: ["0.0.0.0:443:443", …]
```

Dendrite binds to **127.0.0.1 only** — never expose `:8008` directly; Caddy is the
edge. Generate the Postgres password and Dendrite signing key yourself (don't commit
them).

## 2. Caddyfile (TLS + federation discovery)

```caddyfile
matrix.example.com:443 {
    tls /certs/origin.pem /certs/origin-key.pem

    header /.well-known/matrix/* { Content-Type application/json; Access-Control-Allow-Origin * }
    respond /.well-known/matrix/server `{"m.server":"matrix.example.com:443"}`
    respond /.well-known/matrix/client `{"m.homeserver":{"base_url":"https://matrix.example.com"}}`

    reverse_proxy /_matrix/*  dendrite:8008
    reverse_proxy /_synapse/* dendrite:8008
}
```

- The two `.well-known` responses are what let other servers and clients **find** your
  homeserver — don't skip them.
- If you front with a CDN (e.g. Cloudflare), add its IP ranges as `trusted_proxies`
  and read `CF-Connecting-IP`, so Dendrite sees real client IPs. **But** note the TURN
  caveat in [docs/03](03-turn-and-webrtc.md): media must not go through the CDN.

## 3. Dendrite config essentials (`config/dendrite.yaml`)

- `registration_disabled: true` after you've created your accounts (mint them via the
  admin API or `create-account`, not open signup).
- Set the `client_api.turn` block so Dendrite hands clients your TURN server — covered
  in [docs/03](03-turn-and-webrtc.md).
- Keep `server_name: matrix.example.com` consistent with the `.well-known`.

## 4. Bring it up

```bash
cd ~/dendrite
docker compose -f docker-compose.calls.yml up -d postgres dendrite caddy
curl -s https://matrix.example.com/_matrix/client/versions | python3 -m json.tool
curl -s http://127.0.0.1:8008/_matrix/client/versions        # local path the agents use
```

## 5. Minting persona accounts

Each persona gets one account. Create it, then capture an **access token** (used by
both the chat binding and the voice agent). The mechanics — admin API vs
`create-account`, getting a token via `/login`, and where the token is stored — are in
[docs/08](08-register-bind-gate.md). Accounts you'll want:

- `@you:matrix.example.com` — your human account.
- `@ada:…`, `@tesla:…`, … — one per persona.
- optionally a **bridge** account (`BRIDGE_USER_ID`) the voice agents use for signaling.

> **E2EE:** if you run encrypted rooms, each persona's device must cross‑sign and keep
> a crypto‑store. That's per‑agent state under `~/voip-<name>/crypto-store/` — see
> [docs/07](07-voip-profile.md) and [docs/08](08-register-bind-gate.md).

Next: [docs/03 — TURN & WebRTC](03-turn-and-webrtc.md).
