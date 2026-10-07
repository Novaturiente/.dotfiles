#!/usr/bin/env python3
"""Audit prompt-cache misses.

Part 1: all Pi session logs (~/.pi/agent/sessions), misses grouped by likely cause.
Part 2: ~/.pi/agent/cache-trace.jsonl (written by the cache-trace extension),
        each miss with the first transcript message that changed before it.

A miss = cacheRead drops >2000 tokens and >10% below previous cacheRead+cacheWrite.
"""

import collections
import glob
import json
import os
from datetime import datetime

HOME = os.path.expanduser("~/.pi/agent")


def ts(s):
    return datetime.fromisoformat(s.replace("Z", "+00:00"))


def records(path):
    """Yield parsed JSONL lines, skipping unreadable files and bad lines."""
    try:
        with open(path) as fh:
            for line in fh:
                try:
                    yield json.loads(line)
                except ValueError:
                    continue
    except OSError:
        return


def is_miss(prev, read):
    expect = prev[0] + prev[1]
    return expect - read > 2000 and read < expect * 0.9, expect - read


def cause(cur, prev, events, gap):
    if cur[3] != prev[3] or "model_change" in events:
        return "model change"
    if "compaction" in events:
        return "compaction"
    if gap > 3600:
        return "idle >1h (TTL)"
    if gap > 300:
        return "idle 5m-1h"
    if cur[0] == 0:
        return "full miss, no gap"
    return "partial miss, no gap (earlier context changed)"


def sessions():
    causes, wasted = collections.Counter(), collections.Counter()
    for f in glob.glob(f"{HOME}/sessions/*/*.jsonl"):
        prev, events = None, []
        for d in records(f):
            m = d.get("message") if isinstance(d.get("message"), dict) else {}
            u = m.get("usage")
            if not (u and m.get("role") == "assistant"):
                events.append(d.get("type"))
                continue
            if not (u.get("cacheRead") or u.get("cacheWrite")):
                continue
            cur = (u["cacheRead"], u["cacheWrite"], ts(d["timestamp"]), m.get("model"))
            if prev:
                miss, lost = is_miss(prev, cur[0])
                if miss:
                    c = cause(cur, prev, events, (cur[2] - prev[2]).total_seconds())
                    causes[c] += 1
                    wasted[c] += lost
            prev, events = cur, []
    print("== Session logs ==\ncause | misses | tokens re-written")
    for c, n in causes.most_common():
        print(f"{c} | {n} | {wasted[c]:,}")


def trace():
    path = f"{HOME}/cache-trace.jsonl"
    if not os.path.exists(path):
        print("\n(no cache-trace.jsonl yet: cache-trace extension has not run)")
        return
    last_req, prev = {}, {}
    firsts = collections.Counter()
    print("\n== Trace: misses and what changed ==")
    for r in records(path):
        s = r.get("session")
        if r.get("kind") == "request":
            last_req[s] = r
            continue
        cur = (r.get("cacheRead") or 0, r.get("cacheWrite") or 0)
        if s in prev:
            miss, lost = is_miss(prev[s], cur[0])
            if miss:
                req = last_req.get(s, {})
                fd = req.get("firstDiff")
                key = (
                    f"msg #{fd} ({req.get('role')})"
                    if fd is not None
                    else "no transcript change (TTL/system/tools?)"
                )
                firsts[key] += 1
                print(f"\n{r['ts']} {s[:8]} lost {lost:,} tokens; first changed msg: {fd} role={req.get('role')}")
                if fd is not None:
                    print(f"  before: {req.get('before')!r}\n  after:  {req.get('after')!r}")
        prev[s] = cur
    print("\nmisses by first changed message:")
    for k, n in firsts.most_common():
        print(f"  {k}: {n}")


if __name__ == "__main__":
    sessions()
    trace()
