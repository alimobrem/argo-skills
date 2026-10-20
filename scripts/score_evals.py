#!/usr/bin/env python3
"""Aggregate per-expectation eval results into a comparable scorecard.

Why this exists: scoring used to be a model reading free text and reporting a
percentage in prose. Nothing was stored, so runs could not be compared and a
regression was invisible. Scorers now emit one JSON file per skill in a fixed shape;
this turns those into a scorecard and a machine-diffable summary.

Expected input — results/<skill>.results.json:

    {
      "skill": "argo-knowledge",
      "model": "claude-opus-5",
      "condition": "with-skill",          # or "baseline"
      "evals": [
        {"id": 1, "name": "...",
         "expectations": [
            {"text": "...", "verdict": "pass"|"fail"|"partial", "evidence": "..."}
         ]}
      ]
    }

Usage:
    python3 scripts/score_evals.py results/            # scorecard to stdout
    python3 scripts/score_evals.py results/ --json     # machine-readable
    python3 scripts/score_evals.py results/ --compare prior/   # regression diff
"""
import argparse
import json
import pathlib
import sys

WEIGHT = {"pass": 1.0, "partial": 0.5, "fail": 0.0}


def load(d):
    out = {}
    for f in sorted(pathlib.Path(d).glob("*.results.json")):
        try:
            data = json.loads(f.read_text())
        except json.JSONDecodeError as exc:
            print(f"warn: {f.name} is not valid JSON ({exc})", file=sys.stderr)
            continue
        out[data["skill"]] = data
    return out


def score(data):
    """Return (earned, total, per_eval list)."""
    earned = total = 0.0
    per = []
    for ev in data.get("evals", []):
        e = t = 0.0
        for x in ev.get("expectations", []):
            v = x.get("verdict", "fail").lower()
            if v not in WEIGHT:
                v = "fail"
            e += WEIGHT[v]
            t += 1.0
        earned += e
        total += t
        per.append({"id": ev.get("id"), "name": ev.get("name", ""),
                    "earned": e, "total": t,
                    "pct": (100 * e / t) if t else 0.0,
                    "failed": [x["text"] for x in ev.get("expectations", [])
                               if x.get("verdict", "fail").lower() == "fail"]})
    return earned, total, per


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("results_dir")
    ap.add_argument("--json", action="store_true")
    ap.add_argument("--compare", help="a prior results dir, to show regressions")
    ap.add_argument("--fail-under", type=float, default=None,
                    help="exit 1 if any skill scores below this percentage")
    a = ap.parse_args()

    cur = load(a.results_dir)
    if not cur:
        print(f"No *.results.json found in {a.results_dir}", file=sys.stderr)
        return 2
    prior = load(a.compare) if a.compare else {}

    summary, worst = {}, 100.0
    for skill in sorted(cur):
        e, t, per = score(cur[skill])
        pct = (100 * e / t) if t else 0.0
        worst = min(worst, pct)
        entry = {"evals": len(per), "expectations": int(t),
                 "earned": round(e, 1), "pct": round(pct, 1),
                 "model": cur[skill].get("model"),
                 "condition": cur[skill].get("condition"),
                 "weakest": sorted(per, key=lambda x: x["pct"])[:3]}
        if skill in prior:
            pe, pt, _ = score(prior[skill])
            entry["prior_pct"] = round((100 * pe / pt) if pt else 0.0, 1)
            entry["delta"] = round(pct - entry["prior_pct"], 1)
        summary[skill] = entry

    if a.json:
        print(json.dumps(summary, indent=2))
    else:
        print(f"{'skill':<26}{'evals':>6}{'expect':>8}{'score':>8}" +
              ("  delta" if prior else ""))
        print("-" * (48 + (7 if prior else 0)))
        for s, v in summary.items():
            line = f"{s:<26}{v['evals']:>6}{v['expectations']:>8}{v['pct']:>7.1f}%"
            if "delta" in v:
                d = v["delta"]
                line += f"  {d:+.1f}" + ("  REGRESSION" if d < -2 else "")
            print(line)
        tot_e = sum(v["earned"] for v in summary.values())
        tot_t = sum(v["expectations"] for v in summary.values())
        print("-" * (48 + (7 if prior else 0)))
        print(f"{'OVERALL':<26}{sum(v['evals'] for v in summary.values()):>6}"
              f"{tot_t:>8}{(100*tot_e/tot_t if tot_t else 0):>7.1f}%")
        print("\nWeakest evals per skill:")
        for s, v in summary.items():
            for w in v["weakest"]:
                if w["pct"] < 100:
                    print(f"  {s} #{w['id']} {w['name'][:40]:<42}{w['pct']:.0f}%")
                    for f in w["failed"][:2]:
                        print(f"      miss: {f[:95]}")

    if a.fail_under is not None and worst < a.fail_under:
        print(f"\nFAIL: a skill scored below {a.fail_under}%", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
