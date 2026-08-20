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

## What is deliberately missing

`gemma-run.original.sh` and `gemma-run.reduced.sh` — the `runlike` backup of the
production vLLM container, and the reduced-memory variant used to free ~8 GB for
training (FINDINGS §9). They are the record of how the GPU gets shared without
taking the 26B model down, and they are **not in this repo** because both carry
a live HuggingFace token and the vLLM API key inline. `SECRETS_POLICY.md` is
zero-tolerance, and a redacted `docker run` backup is worse than none: it looks
restorable and is not. They stay on the box.
