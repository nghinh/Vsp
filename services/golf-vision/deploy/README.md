# Wiring the API to the model

Two machines that cannot see each other, and the two systemd units that fix it
without opening anything new to the internet.

```
  mobile app                                    A100 box (public, 14.225.68.28)
      │                                                    │
      ▼                                          golfseg-service.service
  vps-api.vnteki.com                             uvicorn 127.0.0.1:8100
      │  (cloudflare tunnel)                              ▲
      ▼                                                   │ ssh -L, restricted key
  vsp-api container ──► 172.18.0.1:18100 ──────► golfseg-tunnel.service
  (LAN 192.168.1.37, behind NAT)                 (runs on the API host)
```

The vision service binds `127.0.0.1`. Nothing on the GPU box listens for the
outside world, even though the machine has a public address. The only way in is
the forward the API host opens, and the key it opens it with is restricted on
the far side to exactly that:

```
restrict,port-forwarding,permitopen="127.0.0.1:8100" ssh-ed25519 AAAA…
```

`restrict` turns everything off; `port-forwarding` turns one thing back on;
`permitopen` names the single destination. That key cannot run a command, cannot
open a shell, and cannot forward anywhere else.

The tunnel's local end is bound to `172.18.0.1` — the gateway of the `vsp`
docker network — rather than to `0.0.0.0`. The API container reaches it. Nothing
else on the office LAN does.

## Installing

On the GPU box:

```bash
printf 'GOLF_VISION_API_KEY=%s\n' "$(head -c 32 /dev/urandom | base64 | tr -d '\n/+=')" \
  > /root/golfseg/.vision-api-key.env
chmod 600 /root/golfseg/.vision-api-key.env
cp golfseg-service.service /etc/systemd/system/
systemctl enable --now golfseg-service
```

On the API host:

```bash
ssh-keygen -t ed25519 -N '' -f ~/.ssh/id_ed25519_golfseg
# add the public key to the GPU box's authorized_keys with the restriction above
cp golfseg-tunnel.service /etc/systemd/system/    # check User= and the home path
systemctl enable --now golfseg-tunnel
```

Then in `~/vsp/.env`, with the same key:

```
VSP_GOLFSEG_BASE_URL=http://172.18.0.1:18100
VSP_GOLFSEG_API_KEY=…
```

and `docker compose up -d vsp-api`.

## Checking it

```bash
systemctl is-active golfseg-service                     # on the GPU box
systemctl is-active golfseg-tunnel                      # on the API host
curl -s http://172.18.0.1:18100/health                  # on the API host
```

`/health` reports which checkpoint is loaded, how many input channels it
expects, and — the field worth reading before anything is sold — the lineage of
imagery licences behind it and whether the result may ship.

End to end, the thing a golfer actually triggers:

```bash
curl -X POST https://vps-api.vnteki.com/courses/1352/holes/8/features/request \
  -H "Authorization: Bearer $TOKEN"
# {"featuresDetected":20,"tracedNow":true,"perLayer":{...},"status":"READY"}
```

A hole that already has geometry answers `alreadyTraced` and does not call the
model. To exercise the trace path, clear that hole's rows first.

## When it breaks

**Everything answers, nothing gets traced.** The service refuses every request
when `GOLF_VISION_API_KEY` is unset — including on its own side. It was found
running that way, which meant every trace had been failing closed since the key
was introduced. `/health` stays open on purpose, so a service in that state
looks healthy: check that a `/trace/hole` actually returns features.

**`pkill -f` kills the ssh session that ran it.** The pattern matches the
session's own arguments. Both restart scripts here are files for that reason,
and it cost two debugging detours to learn twice.
