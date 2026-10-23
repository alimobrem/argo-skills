#!/usr/bin/env python3
"""Append a benchmark run to benchmarks/history.jsonl, and report the history.

    scripts/record-run.py <results-dir> --run <id> --date YYYY-MM-DD [--note "..."]
    scripts/record-run.py --report          # print the history table
    scripts/record-run.py --check           # exit 1 if any run is unrecorded

Why this exists: scores were previously tracked only as directory names
("results-run1-2026-10-20") plus prose in the README. That could not answer the
question that actually matters — *is this score comparable to that one?* — because
nothing recorded WHICH expectations produced it. Four of the six suites have been
reworded at some point, so comparing two numbers blindly is wrong more often than
it is right.

Each record therefore carries a `suite_fp`: a hash of the exact expectation texts
that were graded, taken from the stored verdicts themselves rather than from the
current evals.json. Two scores are comparable if and only if their suite_fp match.
"""
import argparse
import hashlib
import json
import pathlib
import subprocess
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
HISTORY = ROOT / "benchmarks" / "history.jsonl"
WEIGHT = {"pass": 1.0, "partial": 0.5, "fail": 0.0}


def suite_fingerprint(evals):
    """Hash the graded expectation texts. Identical fp == identical suite."""
    texts = sorted(f"{e.get('id')}|{x.get('text','')}" for e in evals
                   for x in e.get("expectations", []))
    return hashlib.sha256("\n".join(texts).encode()).hexdigest()[:12], len(texts)


def score(evals):
    earned = total = 0.0
    for e in evals:
        for x in e.get("expectations", []):
            earned += WEIGHT.get(str(x.get("verdict", "fail")).lower(), 0.0)
            total += 1.0
    return earned, total


def _evals_on_disk(skill):
    matches = sorted(ROOT.glob(f"skills/*/{skill}/evals/evals.json"))
    if not matches:
        return None
    d = json.loads(matches[0].read_text())
    return d if isinstance(d, list) else d.get("evals", d.get("cases", []))


def prompt_fp(skill):
    """Hash the eval PROMPTS as they exist on disk right now.

    suite_fp covers expectation texts only, because that is all a results file
    records. But changing a prompt changes what the agent was asked, which can
    change the answer completely — and that moved nothing in suite_fp. Eval 6 of
    argo-cluster-debug had a fabricated "for an hour" claim removed and the
    staleness check stayed silent, which is exactly the kind of quiet
    non-comparability this file exists to prevent.

    Recorded alongside the run. Rows written before this existed have no
    prompt_fp and are reported as unknown rather than stale — guessing either
    way would be worse than saying so.
    """
    evs = _evals_on_disk(skill)
    if evs is None:
        return None
    texts = sorted(f"{e.get('id')}|{e.get('prompt', '')}" for e in evs)
    return hashlib.sha256("\n".join(texts).encode()).hexdigest()[:12]


def current_fp(skill):
    """Fingerprint of the expectations as they exist on disk right now.

    Skills live at skills/<product>/<skill>/. This used a flat
    skills/<skill>/evals/evals.json and silently returned None after the
    multi-product move, which made `make history` report EVERY skill as stale —
    including ones whose expectations had not changed. A wrong "needs a re-run"
    is costly: it is ten agent runs per skill.
    """
    matches = sorted(ROOT.glob(f"skills/*/{skill}/evals/evals.json"))
    if not matches:
        return None
    f = matches[0]
    d = json.loads(f.read_text())
    evs = d if isinstance(d, list) else d.get("evals", d.get("cases", []))
    texts = sorted(f"{e.get('id')}|{x}" for e in evs for x in e.get("expectations", []))
    return hashlib.sha256("\n".join(texts).encode()).hexdigest()[:12]


def load_history():
    if not HISTORY.exists():
        return []
    return [json.loads(l) for l in HISTORY.read_text().splitlines() if l.strip()]


def record(results_dir, run, date, note, commit):
    rows = []
    for f in sorted(pathlib.Path(results_dir).glob("*.results.json")):
        d = json.loads(f.read_text())
        evals = d.get("evals", [])
        fp, n_fp = suite_fingerprint(evals)
        earned, total = score(evals)
        rows.append({
            "run": run,
            "date": date,
            "skill": d.get("skill", f.name.split(".")[0]),
            "condition": d.get("condition", "?"),
            "pct": round(100 * earned / total, 1) if total else 0.0,
            "earned": round(earned, 1),
            "n": int(total),
            "suite_fp": fp,
            "suite_n": n_fp,
            "prompt_fp": prompt_fp(d.get("skill", f.name.split(".")[0])),
            "model": d.get("model", "unknown"),
            "skills_commit": commit,
            "note": note,
        })
    existing = {(r["run"], r["skill"], r["condition"]) for r in load_history()}
    new = [r for r in rows if (r["run"], r["skill"], r["condition"]) not in existing]
    with HISTORY.open("a") as fh:
        for r in new:
            fh.write(json.dumps(r, sort_keys=True) + "\n")
    print(f"recorded {len(new)} row(s) from {results_dir}"
          + (f" ({len(rows)-len(new)} already present)" if len(rows) != len(new) else ""))
    return len(new)


def report():
    h = load_history()
    if not h:
        print("no history recorded yet")
        return 0
    runs = sorted({r["run"] for r in h})
    skills = sorted({r["skill"] for r in h})
    print(f"{'skill':<26}" + "".join(f"{r:>24}" for r in runs))
    print("-" * (26 + 24 * len(runs)))
    for s in skills:
        line = f"{s:<26}"
        for run in runs:
            w = next((x for x in h if x["run"] == run and x["skill"] == s
                      and x["condition"] == "with-skill"), None)
            b = next((x for x in h if x["run"] == run and x["skill"] == s
                      and x["condition"] == "baseline"), None)
            if not (w and b):
                line += f"{'-':>24}"
            else:
                # Compare against the suite that is CURRENTLY on disk, not the last
                # one recorded. Comparing to the latest *record* silently marks a
                # stale run as current whenever every recorded run predates an edit.
                if w["suite_fp"] != current_fp(s):
                    mark = "*"
                elif w.get("prompt_fp") and w["prompt_fp"] != prompt_fp(s):
                    mark = "p"     # expectations unchanged, PROMPTS changed
                elif not w.get("prompt_fp"):
                    mark = "?"     # recorded before prompts were fingerprinted
                else:
                    mark = " "
                line += f"{w['pct']:>10.1f}/{b['pct']:<6.1f}{w['pct']-b['pct']:>+6.1f}{mark}"
        print(line)
    print("\n* = graded against an expectation suite that is NO LONGER the one on disk;")
    print("    those scores are not comparable to a run of the current suite.")
    print("p = same expectations, but one or more PROMPTS have changed since; the agent")
    print("    was asked something different, so the score is not comparable either.")
    print("? = recorded before prompts were fingerprinted — comparability unverifiable.")
    # A skill needs a re-run only if NO recorded run used the current suite --
    # not merely if some older run used a different one.
    # A skill whose evals.json cannot be located is a BUG, not a stale suite. Reporting
    # it as "needs a re-run" costs ten agent runs chasing a path problem. This is how the
    # multi-product move went unnoticed: current_fp() returned None for every skill and
    # the report looked plausible.
    drifted = [s for s in skills
               if current_fp(s) is not None
               and any(r["skill"] == s and r["suite_fp"] == current_fp(s)
                       and r.get("prompt_fp") and r["prompt_fp"] != prompt_fp(s)
                       for r in h)
               and not any(r["skill"] == s and r["suite_fp"] == current_fp(s)
                           and r.get("prompt_fp") == prompt_fp(s) for r in h)]
    if drifted:
        print("\nPROMPTS CHANGED since the last comparable run (expectations are "
              "unchanged, so the\n* marker above does not catch these): "
              + ", ".join(drifted))
        print("Re-run these; the recorded answers were produced from different prompts.")

    unresolved = [s for s in skills if current_fp(s) is None]
    if unresolved:
        print("\nERROR: could not locate evals.json for: " + ", ".join(unresolved),
              file=sys.stderr)
        print("Expected skills/<product>/<skill>/evals/evals.json — fix the path, do not "
              "re-run on the strength of this report.", file=sys.stderr)
        return 1

    stale = sorted(s for s in skills
                   if current_fp(s) not in {r["suite_fp"] for r in h if r["skill"] == s})
    if stale:
        print(f"\n{len(stale)} skill(s) need a re-run to produce current-suite numbers:")
        for s in stale:
            print(f"  {s:<26}recorded {sorted({r['suite_fp'] for r in h if r['skill']==s})} "
                  f"-> on disk {current_fp(s)}")
    print("\nSuite fingerprints seen per skill:")
    for s in skills:
        fps = []
        for r in h:
            if r["skill"] == s and (r["suite_fp"], r["run"]) not in fps:
                fps.append((r["suite_fp"], r["run"]))
        uniq = {}
        for fp, run in fps:
            uniq.setdefault(fp, []).append(run)
        print(f"  {s:<26}" + "  ".join(f"{fp}({'/'.join(sorted(set(r)))})" for fp, r in uniq.items()))
    return 0


def check():
    """Fail if benchmarks/results/ holds a run that was never recorded."""
    h = load_history()
    known = {(r["skill"], r["condition"], r["suite_fp"], r["pct"]) for r in h}
    missing = []
    for f in sorted((ROOT / "benchmarks" / "results").glob("*.results.json")):
        d = json.loads(f.read_text())
        fp, _ = suite_fingerprint(d.get("evals", []))
        earned, total = score(d.get("evals", []))
        key = (d.get("skill"), d.get("condition"), fp,
               round(100 * earned / total, 1) if total else 0.0)
        if key not in known:
            missing.append(f.name)
    if missing:
        print("These results are not in benchmarks/history.jsonl:", file=sys.stderr)
        for m in missing:
            print("   ", m, file=sys.stderr)
        print("\nRecord them with: scripts/record-run.py benchmarks/results "
              "--run <id> --date <YYYY-MM-DD>", file=sys.stderr)
        return 1
    print(f"history is current — all {len(list((ROOT/'benchmarks'/'results').glob('*.results.json')))} "
          f"result files are recorded")
    return 0


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("results_dir", nargs="?")
    ap.add_argument("--run")
    ap.add_argument("--date")
    ap.add_argument("--note", default="")
    ap.add_argument("--commit", default=None)
    ap.add_argument("--report", action="store_true")
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()

    if a.report:
        return report()
    if a.check:
        return check()
    if not (a.results_dir and a.run and a.date):
        ap.error("need <results-dir> --run <id> --date <YYYY-MM-DD>, or --report / --check")
    commit = a.commit or subprocess.run(
        ["git", "rev-parse", "--short", "HEAD"], capture_output=True, text=True).stdout.strip()
    record(a.results_dir, a.run, a.date, a.note, commit)
    return 0


if __name__ == "__main__":
    sys.exit(main())
