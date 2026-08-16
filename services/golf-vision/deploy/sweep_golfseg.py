"""Trace every hole that has coordinates and nothing drawn on it.

One pass over the database, hole by hole, through the admin endpoint that
already knows the filing rules — the area bounds golf actually has, the course
boundary, the place below anything a person drew. Nothing here decides what is
worth keeping; it decides only what to ask about, and it writes down what it
was told.

<strong>What it deliberately does not touch, and how that went wrong once.</strong>
Holes whose coordinates are the seed's invention are skipped: a neat lattice,
every tee and green on one longitude, evenly spaced. Pointing a segmentation
model at those does not produce a bad map of the course, it produces a
confident map of whatever farmland is at the fake coordinates. 108 holes on
six courses are in that state, Yên Dũng among them, and what they need is a
survey rather than a trace.

The filter for that was `source NOT LIKE 'synthetic:seed-arithmetic%'`, and it
was wrong, because 63 further holes carry a source that begins the same way and
means the opposite:

    synthetic:seed-arithmetic par; osm:way/1017346962 geometry

Those are holes whose *par* is invented and whose *coordinates* were measured
and imported from OpenStreetMap — a dual label added precisely so a row could
stop claiming provenance it did not have. Reading only the prefix threw away
the good half of the sentence. 45 of the 63 sit on courses retired on
2026-08-14 and are no loss; the other 18 are Vinpearl Golf Hải Phòng, a live
course with real positions, and this sweep skipped it for a reason that was not
true of it.

So the test is on the geometry alone: `source = 'synthetic:seed-arithmetic'`,
exactly, no wildcard. A prefix match on a field that carries two facts matches
the fact you were not asking about.

Holes with no coordinates at all are skipped for the plainer reason that there
is no box to photograph.

Run it from the API host, where the endpoint is on localhost and the tunnel to
the GPU box is already up:

    python3 sweep_golfseg.py --worklist /tmp/golfseg-worklist.txt \
        --log /tmp/golfseg-sweep.log --workers 4

It is safe to re-run: filing replaces a hole's untouched proposals rather than
adding to them, and the worklist is regenerated from what is actually missing.
Written to a file and run from one because `pkill -f` on the pattern of a
sweep kills the ssh session that started it — learned twice.
"""

from __future__ import annotations

import argparse
import json
import queue
import threading
import time
import urllib.error
import urllib.request

TOKEN_LOCK = threading.Lock()


class Session:
    """An admin token, refreshed when the server stops accepting it.

    A sweep outlives its own login. Rather than time the expiry — which is a
    number this script would have to be told and would then be wrong about —
    it asks again the first time a call comes back 401, once, under a lock so
    four workers hitting the wall together produce one new token.
    """

    def __init__(self, base: str, identifier: str, password: str):
        self.base = base.rstrip("/")
        self.identifier = identifier
        self.password = password
        self.token = self._login()

    def _login(self) -> str:
        body = json.dumps({"identifier": self.identifier,
                           "password": self.password}).encode()
        request = urllib.request.Request(
            f"{self.base}/auth/login", data=body,
            headers={"Content-Type": "application/json"})
        with urllib.request.urlopen(request, timeout=30) as answer:
            return json.load(answer)["accessToken"]

    def refresh(self, stale: str) -> None:
        with TOKEN_LOCK:
            if self.token == stale:
                self.token = self._login()

    def post(self, path: str, timeout: int = 180):
        """Returns (status, body). Never raises for an HTTP status."""
        for attempt in range(2):
            held = self.token
            request = urllib.request.Request(
                f"{self.base}{path}", data=b"",
                headers={"Authorization": f"Bearer {held}",
                         "Content-Type": "application/json"})
            try:
                with urllib.request.urlopen(request, timeout=timeout) as answer:
                    return answer.status, json.load(answer)
            except urllib.error.HTTPError as refused:
                if refused.code in (401, 403) and attempt == 0:
                    self.refresh(held)
                    continue
                try:
                    return refused.code, json.loads(refused.read())
                except Exception:                       # noqa: BLE001
                    return refused.code, {}
            except Exception as broken:                 # noqa: BLE001
                return 0, {"error": str(broken)}
        return 0, {"error": "unreachable"}


def classify(status: int, body: dict) -> tuple[str, int]:
    """What happened to one hole, and how many shapes came of it.

    Three outcomes worth telling apart, because they need different work
    afterwards. `filed` is the model answering. `empty` is the model answering
    with nothing, which on this pipeline almost always means the imagery was
    a blank placeholder and the fetcher refused it — that hole needs imagery,
    not another trace. `failed` is everything else, and it names itself.
    """
    if status != 200:
        detail = body.get("message") or body.get("error") or f"HTTP {status}"
        return f"failed:{detail}"[:120], 0
    filed = body.get("filed") or {}
    total = sum(filed.values())
    return ("filed" if total else "empty"), total


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="http://localhost:18081")
    parser.add_argument("--worklist", required=True)
    parser.add_argument("--log", required=True)
    parser.add_argument("--workers", type=int, default=4)
    parser.add_argument("--identifier", default="admin@vsp.local")
    parser.add_argument("--password", required=True)
    args = parser.parse_args()

    holes: queue.Queue = queue.Queue()
    with open(args.worklist) as source:
        for line in source:
            parts = line.split()
            if len(parts) == 2:
                holes.put((int(parts[0]), int(parts[1])))
    total = holes.qsize()

    session = Session(args.base, args.identifier, args.password)
    log = open(args.log, "a", buffering=1)
    counts: dict[str, int] = {}
    shapes = 0
    done = 0
    started = time.time()
    lock = threading.Lock()

    def work() -> None:
        nonlocal shapes, done
        while True:
            try:
                course, hole = holes.get_nowait()
            except queue.Empty:
                return
            status, body = session.post(
                f"/admin/courses/{course}/holes/{hole}/geometry/golfseg")
            outcome, filed = classify(status, body)
            with lock:
                kind = outcome.split(":")[0]
                counts[kind] = counts.get(kind, 0) + 1
                shapes += filed
                done += 1
                elapsed = time.time() - started
                rate = done / elapsed if elapsed else 0
                left = (total - done) / rate if rate else 0
                log.write(f"{course} {hole} {outcome} {filed} "
                          f"{json.dumps(body.get('filed') or {})}\n")
                if done % 20 == 0 or done == total:
                    print(f"[{done}/{total}] {shapes} shapes, "
                          f"{dict(sorted(counts.items()))}, "
                          f"~{left/60:.0f} min left", flush=True)

    threads = [threading.Thread(target=work, daemon=True)
               for _ in range(args.workers)]
    for thread in threads:
        thread.start()
    for thread in threads:
        thread.join()

    print(f"done: {done} holes, {shapes} shapes, {dict(sorted(counts.items()))}",
          flush=True)
    log.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
