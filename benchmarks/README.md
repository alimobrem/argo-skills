# Benchmarks — methodology and caveats

Measured 2026-10-21 against a live OpenShift cluster (OpenShift GitOps 1.21.3, Argo CD
v3.4.5). **572 expectations per condition, graded twice — once with the skills, once
without.** 1,144 verdicts, each carrying an evidence string, in [`results/`](results/).

| Skill | with-skill | baseline | delta | per-eval detail |
|-------|-----------:|---------:|------:|---|
| `argo-performance-tuning` | **94.2%** | 66.8% | **+27.4** | [↗](argo-performance-tuning.md) |
| `argo-repo-audit` | **97.5%** | 81.2% | **+16.2** | [↗](argo-repo-audit.md) |
| `argo-operations` | **93.8%** | 84.4% | **+9.4** | [↗](argo-operations.md) |
| `argo-knowledge` | **98.5%** | 93.9% | +4.5 | [↗](argo-knowledge.md) |
| `argo-team-onboard` | 84.5% | 84.5% | **0.0** | [↗](argo-team-onboard.md) |
| `argo-cluster-debug` | **94.1%** | 84.7% | **+9.3** | [↗](argo-cluster-debug.md) |
| **Weighted overall** | **93.6%** | **83.7%** | **+9.9** | |

## Method

- **Blind A/B.** Graders saw "Condition A" and "Condition B" with a seeded flip, were
  never told which was which, and could not read `skills/`. Flips came out mixed.
- **Per expectation, not per eval**, with partial credit and a required evidence string.
- **Strong baselines, deliberately.** Each baseline agent was an experienced OpenShift
  GitOps engineer with the same prompts, CLIs, live cluster and read-only limits — just
  no `skills/`. A hobbled baseline produces a flattering number and tells you nothing.
  Several baselines beat their with-skill counterpart on specific items.
- **Integrity-checked before publication:** every expectation graded exactly once, every
  verdict's text joined verbatim against the eval definition, every blind input
  md5-verified complete against its source. Run 1 shipped a truncated input; that last
  check exists because of it.
- **Reproduce:** `make score` · `make score-compare PRIOR=results-run1-2026-10-20`.

## How much of this is grader noise? We measured it.

Four baselines were reused unchanged from run 1 and regraded by a fresh grader. Same
answer text, same expectations — so any difference is the grader, not the skill:

| Reused baseline | n | grader agreement | drift |
|---|--:|--:|--:|
| `argo-knowledge` | 131 | 98% | −0.8 |
| `argo-performance-tuning` | 101 | 92% | −2.0 |
| `argo-cluster-debug` | 57 | 88% | +0.9 |
| `argo-repo-audit` | 80 | 86% | **−6.9** |
| **pooled** | **369** | **92%** | — |

Disagreements are almost entirely one-directional (`pass` → `partial`): the second grader
is stricter at that boundary, not randomly different. Two consequences, both cutting
against the headline numbers:

1. **Absolute scores are not comparable across grading passes.** A score can move ~7
   points with no change to the skill at all.
2. **A stricter grader *widens* deltas when the with-skill arm is near ceiling.**
   `argo-repo-audit` is the clean case: its with-skill score was 97.5% in both runs, but
   the regraded baseline fell 88.1% → 81.2%, so the delta grew +9.4 → +16.2 without the
   skill improving. Read that one as "somewhere in +9 to +16".

Within a run both conditions share one grader and one bar, so **direction and
rank-ordering** are the trustworthy part. Treat anything under ~5 points as
indistinguishable from zero.

## What the numbers say

**The delta tracks how product-specific the skill is.** Performance tuning gains most —
the baseline there was confidently wrong rather than vague: it called an experimental
sharding algorithm "GA, supported… the sane default", never named
`ARGOCD_APPLICATION_TREE_SHARD_SIZE` for a resource-tree problem, and applied patches
with no dry-run and no confirmation. The lesson: *encode what is version- and
product-specific; do not re-encode what the model already knows.*

**`argo-operations` went from −3.6 to +9.4.** Run 1 lost to its own baseline on one
category — no post-action verification. The skill stopped at the confirmation gate and
never said "now check it worked". Adding a Step 4: Verify closed it; all four failing
expectations flipped to pass. Roughly a third of the swing is that fix, the rest a
baseline that is no longer contaminated.

**Two skills tie their baselines** — `argo-team-onboard` (87/103 each) and
`argo-cluster-debug` (52.5/57 each). They split rather than dominate: the skill arm
reliably ends at a "commit this?" Git gate and honors "don't re-create what exists",
while the baseline writes more complete literal YAML.

## The cluster-debug re-run, and what it exposed about the evals

Four `argo-cluster-debug` scenarios named resources that did not exist on the cluster,
capping both arms. We deployed real fixtures — an Application driven OutOfSync *and*
Degraded by live image drift with `selfHeal: false`, a paused blue-green Rollout
reporting health `Suspended`, a multi-source Application failing with
`ComparisonError: failed to generate manifest for source 1 of 2` — re-ran both arms, and
tore the fixtures down. Both rose ~4 points (87.7→92.1, 88.6→92.1), matching the
predicted headroom. **The gap did not move.**

That re-run exposed a limitation in the evals themselves. On the two scenarios where the
arms reached *different* root causes, the skill arm was right both times and the baseline
wrong both times — and they scored **identically**:

| eval | with-skill | baseline | verified truth |
|---|---|---|---|
| 3 | zero-length conversion-webhook `caBundle` | "the operator pod is down" | `caBundle` length **0**; operator pods all **1/1 Running**; InstallPlan `install-fzm4w` Failed on exactly that webhook |
| 8 | `CrashLoopBackOff` from a probe/port mismatch | "the pause landed mid-bringup" | pod **CrashLoopBackOff, 13 restarts**; `containerPort: 80` while the image binds **:8443** |

Expectations phrased "identifies the root cause" are satisfied by naming a *plausible*
cause, not the *correct* one. Until they discriminate on correctness, this suite cannot
resolve the difference it exists to measure. **Read `0.0` as "not resolved by this
instrument", not "no difference".** This is the next change to the suite.

## The suite changed after these numbers were measured

The `argo-cluster-debug` expectations were rewritten after run 3 to test whether a
stated root cause is **correct and grounded**, not merely plausible — the limitation
described above. Expectations that said "produces a report with root cause and
recommendations" now add: *every root cause asserted must be backed by the specific
observation that establishes it, and a cause contradicted by output shown elsewhere in
the same answer fails even if it is plausible and well written.* Evals 3 and 8 also
gained expectations naming the specific finding each must land.

The rewrite was validated rather than assumed. Re-grading the **same two stored
answers** from run 3 blind, against old and new expectations:

| | with-skill | baseline | gap |
|---|---:|---:|---:|
| old expectations | 96.2% | 96.2% | **+0.0** |
| new expectations | 100.0% | 86.7% | **+13.3** |

The old wording scored a correct diagnosis and a factually wrong one identically. The
new wording separates them, in the direction the independently verified cluster state
supports. The baseline lost exactly where it should: it explained `Available=False` by
asserting a Service-selector problem with no output shown, while the other answer showed
the pod in `CrashLoopBackOff` with zero Service endpoints.

**Re-run against the corrected suite (run 5, 2026-10-22):** `argo-cluster-debug` scores
**94.1% vs 84.7% (+9.3)** over 59 expectations, where the old suite showed 92.1% vs
92.1% (+0.0) on the same skill. The instrument now resolves a difference it previously
could not. The other five skills were not re-run; their rows predate the change.

Consequence: **the other numbers on this page predate that change.** They were measured
against the older, more permissive suite (572 expectations; the suite is now 574), so
a future run is not directly comparable to them and should be reported as a new
baseline rather than a delta against these.

## Caveats — read these before quoting the numbers

1. **Four of the six baselines are run-1 answers, reused.** Only `argo-operations` and
   `argo-team-onboard` baselines were re-run. Reuse is sound — baselines never see
   `skills/`, and the eval prompts were verified byte-identical between runs — but those
   four were regraded, with the drift quantified above.
2. **Run 1's two contaminated baselines are fixed.** To protect a live cluster, the
   `argo-operations` and `argo-team-onboard` baselines had been told to stop before
   writing — which is part of what those evals measure. Both were re-run with the write
   ban stated purely as an environment constraint. That is why `team-onboard` dropped
   from an apparent +4.4 to 0.0: the earlier gap was largely the contamination.
3. **Expectations that cannot discriminate.** The correctness problem above, plus
   `argo-team-onboard` eval 13, which asks the agent to detect that Argo CD is absent
   when it is installed. Both compress deltas toward zero — eval-design bugs, not results.
4. **Fixes made in response to a run are not reflected in it.** Each skill's files were
   verified unchanged during its own run, but defects the run surfaced — notably two
   `argo-repo-audit` credential/TLS scans that returned zero on their own fixtures — were
   fixed afterward. Those numbers describe the pre-fix skill.
5. **Single run, single model, no confidence intervals.** With the measured grader
   variance, treat small deltas as unresolved rather than real.

## Run history

`benchmarks/history.jsonl` is the append-only record of every scored run. Each row
carries a **`suite_fp`** — a hash of the exact expectation texts that were graded,
taken from the stored verdicts rather than from the current `evals.json`.

That field answers the question directory names could not: *is this score comparable
to that one?* Two scores are comparable **only** if their `suite_fp` match. Four of the
six suites have been reworded at some point, so comparing numbers without checking is
wrong more often than it is right.

```sh
make history        # the table, with stale suites flagged
make history-check  # fails if a result file was never recorded (also runs in CI)
```

Known wrinkle: the archived `argo-repo-audit` verdicts were mechanically edited when a
test-fixture credential literal was redacted. No verdict changed, but their `suite_fp`
now reflects the post-redaction text, so it matches the current suite for a reason
unrelated to grading.

## Archived runs

| Directory | What it holds |
|---|---|
| [`results/`](results/) | Current verdicts (run 2; `argo-cluster-debug` is run 3) |
| [`results-run1-2026-10-20/`](results-run1-2026-10-20/) | Run-1 verdicts — makes the grader-drift table reproducible |
| [`results-run2-fixturecapped/`](results-run2-fixturecapped/) | `argo-cluster-debug` run 2, before fixtures were deployed |

Cluster-dependent suites need a real cluster — run them locally with `make eval-*`; CI
can only run the two that do not.
