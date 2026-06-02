# 03 — Matrix TURN & WebRTC

For a persona to hold a **live voice call**, two clients (your Element and the
persona's voice agent) must exchange real‑time media. That's WebRTC, and on anything
but a flat LAN it needs a **TURN** server to relay media through NAT. This is the
piece people most often get subtly wrong, so it gets its own doc.

```
Element ⇄  ICE/STUN (find paths)  ⇄  voice agent
   ╲          if direct fails        ╱
    ╲──────▶  Coturn (TURN relay) ◀─╱        media relayed here when P2P is blocked
                  3478/udp+tcp, 4443/tls, 10000-10100/udp
```

---

## 1. Coturn (TURN/STUN)

Runs as a container alongside the homeserver. Config —
[`templates/turn/turnserver.conf`](../templates/turn/turnserver.conf):

```ini
listening-port=3478
tls-listening-port=4443
realm=matrix.example.com

min-port=10000
max-port=10100
external-ip=SERVER_IP            # ◀ the PUBLIC, routable IP. The #1 mistake is wrong/missing this.

use-auth-secret
static-auth-secret=<generate-with-gen-secrets.sh>   # shared with Dendrite (below)

fingerprint
no-loopback-peers
no-multicast-peers
cert=/certs/origin.pem
pkey=/certs/origin-key.pem
```

Compose service (in [`templates/compose/docker-compose.calls.yml`](../templates/compose/docker-compose.calls.yml)):

```yaml
coturn:
  image: coturn/coturn
  ports:
    - "3478:3478"
    - "3478:3478/udp"
    - "4443:4443"
    - "4443:4443/udp"
    - "10000-10100:10000-10100/udp"   # the media relay range — MUST be open end-to-end
  volumes: [./jitsi/turn/turnserver.conf:/etc/turnserver.conf:ro]
```

**Open the relay UDP range** (`10000–10100/udp`) on the host firewall *and* any
upstream NAT/router. If only `3478` is open, calls connect then go silent.

## 2. Wire TURN into Dendrite

Dendrite hands its clients the TURN server via the `client_api.turn` config, using the
**same** `static-auth-secret`:

```yaml
client_api:
  turn:
    turn_uris:
      - "turn:SERVER_IP:3478?transport=udp"
      - "turn:SERVER_IP:3478?transport=tcp"
      - "turns:SERVER_IP:4443?transport=tcp"
    turn_shared_secret: "<same static-auth-secret as Coturn>"
    turn_user_lifetime: "24h"
```

> **The golden rule:** `turn_uris` must point at the **server's real IP**
> (`SERVER_IP`), **not** a domain that resolves to a CDN/Cloudflare. Signaling can go
> through the CDN; **media cannot.** A domain‑fronted TURN URI is the classic cause of
> "call connects, then one‑way or dead audio."

Verify a client actually receives TURN creds:

```bash
curl -s http://127.0.0.1:8008/_matrix/client/v3/voip/turnServer \
  -H "Authorization: Bearer $YOUR_MATRIX_TOKEN" | python3 -m json.tool
# → uris[] should list your SERVER_IP, with a username + short-lived password.
```

## 3. Jitsi (optional — group/video)

The reference compose also brings up **Jitsi Videobridge + Jitsi Meet** for
multi‑party/video rooms. 1:1 persona voice calls don't need Jitsi (they're direct
WebRTC relayed by Coturn), so you can omit it for a voice‑only setup. If you keep it,
set `JVB_ADVERTISE_IPS=SERVER_IP` and expose `4443` + the `10000-10100/udp` range
(shared with Coturn's relay).

## 4. Test the path

```bash
# STUN/TURN reachable?
nc -vzu SERVER_IP 3478 ; nc -vz SERVER_IP 4443
# From Element: place a voice call into a room with the persona. Watch the voice agent:
journalctl --user -u matrix-voip-agent-ada -f | grep -iE 'invite|ice|turn|audio bridge'
```

You want to see the invite accepted, ICE succeed, and an "audio bridge started" line.
If ICE fails, it's almost always (a) the relay UDP range not open, or (b) `external-ip`
/ `turn_uris` pointing somewhere that isn't the real public IP.

## 5. Firewall summary

| Port | Proto | Who | Purpose |
|---|---|---|---|
| 443 | tcp | public | Matrix client/federation (Caddy) |
| 3478 | udp+tcp | public | STUN/TURN control |
| 4443 | udp+tcp | public | TURN over TLS (and Jitsi if used) |
| 10000–10100 | udp | public | **TURN media relay** (do not forget) |
| 8000/8001/8002 | tcp | LAN only | inference — never public |
| 8008 | tcp | localhost | Dendrite behind Caddy — never public |
| 8210+ | tcp | localhost | per‑agent voice‑call API — never public |

Next: [docs/04 — Persona files](04-persona-files.md).
