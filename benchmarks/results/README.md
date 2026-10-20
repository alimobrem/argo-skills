# Eval results

One `<skill>.results.json` per skill per run, in the shape documented at the top of
`scripts/score_evals.py`. Scoring is per **expectation**, not per eval, so a partially
correct answer is visible rather than rounded to pass/fail.

```shell
make score                                    # scorecard
make score-json                               # machine-readable
make score-compare PRIOR=benchmarks/results-2026-10-20/   # regression diff
```

Keep a dated copy of a run you want to compare against later — `make score-compare`
exists so a regression shows up as a number rather than as someone noticing prose changed.
