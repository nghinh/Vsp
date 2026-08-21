# What actually runs on the GPU box

The training in FINDINGS §9–10 does not run from this repository. It runs from
`/root/golfseg/` on the A100 (`si-ai-a100-hni`), a machine this repo has never
been checked out on, and until now those scripts existed in exactly one place:
that disk. A box that dies takes the pipeline with it, and a script edited at
2 a.m. leaves no trace anybody can read afterwards. These are copies, so that
`git log` has something to say about them.

## The chain

```
golfseg-autopilot.service  oneshot systemd unit, logs to /data/golfseg/autopilot.log
  └── autopilot.sh         wait out the corpus → train → score → deploy on a win → clean up
        ├── corpus-large.sh   Geofabrik PBF → courses → NAIP patches, 6 fetch shards, merge
        ├── disk-guard.sh     under 12 GB free on /data: stop the build, leave DISK-STOP
        ├── train-large.sh    pretrain on the US corpus, then 3 seeds × Lovász {0, 0.5} on VN
        └── pick_winner.py    the deploy gate: beat mean 0.573 AND green 0.5554, or ship nothing

golfseg-service.service    the vision service the API calls through the tunnel
tier0-eval.sh              the TTA/ensemble measurement matrix behind FINDINGS §10
```

## These are copies, and the server holds the original

Nothing here is wired into a deploy. The paths are absolute and belong to that
one machine on purpose — `/data/golfseg` is its 442 GB volume, and rewriting
them into repo-relative paths would produce a file that reads better and runs
nowhere.

So the two can drift, and only a human closes the gap: after editing anything
under `/root/golfseg/`, copy it back here and commit. Route in, since the
GPU box is behind the jump host:

```bash
scp thing.sh ubuntu-docker:/tmp/
ssh ubuntu-docker "scp -i ~/.ssh/id_ed25519_golfseg /tmp/thing.sh root@<a100>:/root/golfseg/"
```

## The vLLM scripts, and where their secrets went

`gemma-run.original.sh` and `gemma-run.reduced.sh` — the `runlike` backup of the
production vLLM container, and the reduced-memory variant used to free ~8 GB for
training (FINDINGS §9) — used to carry a live HuggingFace token and the vLLM
API key inline, which kept them out of this repo. On 2026-08-20 both secrets
moved to `/root/golfseg/.gemma.env` (root-only, 600) and the scripts now source
it; what is committed here is byte-identical to what runs, and restorable on a
box that has the env file.

The keys themselves are still the keys. The vLLM API key is consumed by the
vnpt-iplace fleet on the same GPU box (eight containers plus
`/opt/litellm/config.yaml`), so rotating it is a coordination with that team,
not a solo act. The HuggingFace token can only be reissued by its account
owner.

## Rotating the vLLM key

`rotate-vllm-key.sh` does the whole turn in one pass: new key into every file
that holds the old one, vLLM rebuilt on it, consumers restarted, old key
checked to be dead. Install it the way this file describes above, then look
before you leap:

```bash
bash /root/golfseg/rotate-vllm-key.sh --dry-run   # lists the files, touches nothing
bash /root/golfseg/rotate-vllm-key.sh             # ~6 minutes of iplace LLM downtime
```

Two things this script will not do for you. It cannot avoid the outage —
vLLM reloads a 26B model to pick up a new key, and every iplace LLM call
fails while it does, so run it when that team can afford six minutes. And it
finds the files by searching for the old key rather than from a list: the
first version of it carried a hardcoded list that named
`docker-compose.override.example.yaml` but not `docker-compose.override.yaml`,
which is the file `up -d` actually loads. That rotation would have brought the
fleet back up on a key that had just been retired.
