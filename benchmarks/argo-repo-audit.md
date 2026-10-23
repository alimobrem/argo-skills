# argo-repo-audit

## Run 6 — 2026-10-23, live cluster, blind A/B

**97.0% with the skill vs 85.4% baseline (+11.6) over 82 expectations.**

Measured against a live OpenShift cluster (OpenShift GitOps 1.21.3, Argo CD v3.4.5).
Graders saw "Condition A"/"Condition B" without knowing which was which and could not
read `skills/`. Partial credit; every verdict carries an evidence string. Raw verdicts:
[`results/argo-repo-audit.with-skill.results.json`](results/argo-repo-audit.with-skill.results.json) and
[`results/argo-repo-audit.baseline.results.json`](results/argo-repo-audit.baseline.results.json).

| # | Eval | n | with-skill | baseline | delta |
|---|------|--:|-----------:|---------:|------:|
| 1 | app-of-apps-audit | 13 | 100% | 73% | +27 |
| 2 | applicationset-audit | 11 | 100% | 95% | +5 |
| 3 | mixed-issues-audit | 12 | 100% | 96% | +4 |
| 4 | validate-only | 6 | 100% | 92% | +8 |
| 5 | detect-wildcard-project | 5 | 90% | 80% | +10 |
| 6 | detect-plain-secret | 4 | 88% | 62% | +25 |
| 7 | detect-no-sync-policy | 4 | 100% | 100% | +0 |
| 8 | detect-head-in-prod | 4 | 100% | 100% | +0 |
| 9 | detect-weak-analysis | 4 | 100% | 50% | +50 |
| 10 | detect-hardcoded-helm-password | 4 | 75% | 75% | +0 |
| 11 | clean-repo-zero-findings | 9 | 100% | 100% | +0 |
| 12 | Subtle RBAC: looks restricted but has privilege escalation | 6 | 92% | 75% | +17 |
| | **total** | **82** | **97.0%** | **85.4%** | **+11.6** |

**Largest gains:** #9 detect-weak-analysis (+50); #1 app-of-apps-audit (+27); #6 detect-plain-secret (+25).

> **Run 6 used a freshly generated baseline**, not the reused-and-regraded run-1 baseline
> that earlier revisions of this page described. It also used a corrected expectation
> suite: nine of the twelve evals had expectations rewritten because the originals could
> be satisfied by naming any plausible cause, and so scored a correct root cause and a
> confident wrong one identically.
>
> **The correction lowered the published delta, from +16.2 to +11.6.** The skill arm
> barely moved; the baseline rose from 81.2% to 85.4% because the sharper wording credited
> work the vague wording had been failing. Expect that direction when you fix your own
> rubric — if rewriting expectations only ever improves your numbers, the rewrite is the
> thing to distrust. See the grader-drift table in the
> [root README](../README.md#benchmarks): absolute scores move with the grader, so read
> the direction, not the decimal.

---

<details>
<summary>Superseded: v0.2.0 (2026-10-14) — simulated outcomes, no live cluster</summary>

## v0.3.0 (2026-10-14) — Cross-model, with-skill vs. baseline (real file audits)

Unlike the other five skills in this repo, `argo-repo-audit` has no live cluster to simulate —
it audits real YAML files already on disk under `tests/argo-repo-audit/`. That makes this the
most rigorous of the six cross-model runs: **both** the with-skill and baseline subagents were
given identical, real file-read access to the actual fixture directories for all 13 evals. The
only variable between conditions was whether `SKILL.md` + `references/*.md` were loaded first.
No cluster state, API responses, or outcomes were simulated or asserted — every finding below
is grounded in literal fixture content, scored against each eval's real `expectations` array in
`skills/gitops/argo-repo-audit/evals/evals.json`.

4 subagents were dispatched — Opus-tier and Sonnet-tier, each in with-skill and baseline
conditions — each covering all 13 real eval scenarios in a single batched run (not the
Makefile's literal one-subagent-per-eval convention; see the other `v0.2.0` sections in this
repo for the same disclosed deviation). Each subagent was instructed to read every YAML file in
each target directory before producing findings — not guess contents.

| # | Eval | Max | Opus + Skill | Opus Baseline | Sonnet + Skill | Sonnet Baseline |
|---|------|-----|-------------|----------------|-----------------|-------------------|
| 1 | App-of-apps audit | 12 | 12 (100%) | 6 (50%) | 11 (92%) | 6 (50%) |
| 2 | ApplicationSet audit | 11 | 11 (100%) | 8 (73%) | 8 (73%) | 6 (55%) |
| 3 | Mixed-issues audit | 13 | 13 (100%) | 10 (77%) | 12 (92%) | 11 (85%) |
| 4 | Validate-only | 6 | 5 (83%) | 6 (100%) | 6 (100%) | 6 (100%) |
| 5 | Detect wildcard project | 5 | 5 (100%) | 5 (100%) | 5 (100%) | 5 (100%) |
| 6 | Detect plain-text secret | 4 | 4 (100%) | 4 (100%) | 4 (100%) | 4 (100%) |
| 7 | Detect no sync policy | 4 | 4 (100%) | 4 (100%) | 4 (100%) | 4 (100%) |
| 8 | Detect HEAD in prod | 4 | 3 (75%) | 3 (75%) | 4 (100%) | 3 (75%) |
| 9 | Detect weak AnalysisTemplate | 4 | 4 (100%) | 3 (75%) | 4 (100%) | 4 (100%) |
| 10 | Detect no-deadline workflow | 4 | 4 (100%) | 4 (100%) | 4 (100%) | 4 (100%) |
| 11 | Detect hardcoded Helm password | 4 | 4 (100%) | 4 (100%) | 4 (100%) | 4 (100%) |
| 12 | Clean repo zero findings | 9 | 9 (100%) | 9 (100%) | 9 (100%) | 9 (100%) |
| 13 | Subtle RBAC privilege escalation | 6 | 6 (100%) | 6 (100%) | 6 (100%) | 6 (100%) |
| | **Overall** | **86** | **84 (98%)** | **72 (84%)** | **81 (94%)** | **72 (84%)** |

### Key findings

- **Baseline does much better here than on any other skill in this repo (84% vs. the 47–76%
  range seen on `argo-performance-tuning`/`argo-team-onboard`/`argo-operations`).** GitOps
  security auditing — "wildcard RBAC is bad," "plaintext secrets in Git are bad," "`HEAD` in
  prod is risky," "missing `syncPolicy` breaks reconciliation" — draws on general
  Kubernetes/DevSecOps judgment both frontier models already have well-internalized. This isn't
  obscure, Argo-specific trivia the way `argo-performance-tuning`'s sharding algorithms or
  `argo-team-onboard`'s hard refusal rules are.
- **The skill's real value-add here is comprehensiveness, not detection of things baseline
  models can't reason about at all.** The two evals with the widest with-skill-vs-baseline gaps
  — App-of-apps audit (+50 Opus / +42 Sonnet points) and ApplicationSet audit (+27 Opus / +18
  Sonnet points) — are the two general, open-ended, "audit everything" scenarios with the
  longest checklists (sync waves, `ignoreDifferences`, `goTemplateOptions`, `goTemplate` vs.
  `fasttemplate`, `preserveResourcesOnDeletion`, generated-Application `prune` settings). All
  four conditions found the obvious security issues; what baseline runs reliably skipped was
  the long tail of ApplicationSet-specific and report-structure checklist items the skill
  enumerates explicitly. On the eight single-bug "targeted" fixtures (evals 5–11) — one planted
  issue each — baseline and with-skill are statistically indistinguishable.
- **Surprising miss: Opus with the skill loaded did not catch the `AppProject` name collision**
  in the `app-of-apps` fixture (both `projects/platform.yaml` and `projects/team-platform.yaml`
  declare `metadata.name: platform` — a real defect that makes roughly half the repo's
  Applications fail to sync depending on apply order). This wasn't a scored expectation for
  eval 1, but all **three other** conditions — Sonnet with the skill, and *both* unaided
  baselines — caught it independently just by reading the files closely. It's a reminder that
  loading a skill doesn't substitute for careful reading, and that this particular defect is
  detectable by general diligence alone, not special Argo-CD-specific knowledge.
- **Severity-calibration miss on "HEAD in prod" (eval 8), including the skill-equipped Opus
  run.** The eval expects this to be classified as a Warning/best-practice violation, not a
  Critical security vulnerability (per the skill's own severity rubric). Three of four
  conditions — Opus+skill, Opus baseline, and Sonnet baseline — labeled it "Critical" anyway;
  only Sonnet+skill kept it at "High"/non-Critical. This suggests the intuitive pull of "any
  commit auto-deploys to production" toward the highest severity bucket is strong enough that
  even having the skill's calibration guidance loaded doesn't reliably override it — a real,
  reproducible finding, not a fabricated one.
- **Both baselines tied exactly (72/86, 84%)** despite being different model tiers — on this
  skill, with real file access and no skill-specific checklist, Opus-tier and Sonnet-tier
  unaided judgment converged on the same overall score, even though they missed different
  individual items (Opus baseline was stronger on the obscure ApplicationSet best-practice
  items like `missingkey=error`; Sonnet baseline caught the `AppProject` name collision Opus
  baseline described differently).

### Methodology note

This run differs from the `v0.2.0` scores below in two ways: (1) all 13 evals were scored for
every condition (the `v0.2.0` run never scored Sonnet on 12 of the 13 evals, and never scored
either model on "ApplicationSet audit" or "Validate-only"), and (2) this run adds, for the first
time, unaided baseline conditions for both models — `argo-repo-audit` previously had no
baseline comparison at all. The `v0.2.0` scores remain below for history; they are not
superseded, just superseded in *coverage* by this run.

---

## v0.2.0 (2026-07-01)

### claude-opus-4-6

| Eval | Type | Score |
|------|------|-------|
| App-of-apps audit | General | 11/11 (100%) |
| ApplicationSet audit | General | — |
| Mixed-issues audit | General | 12/12 (100%) |
| Validate-only | General | — |
| Detect wildcard project | False negative | 5/5 (100%) |
| Detect plain-text secret | False negative | 4/4 (100%) |
| Detect no sync policy | False negative | 4/4 (100%) |
| Detect HEAD in prod | False negative | 4/4 (100%) |
| Detect weak AnalysisTemplate | False negative | 4/4 (100%) |
| Detect no-deadline workflow | False negative | 4/4 (100%) |
| Detect hardcoded Helm password | False negative | 4/4 (100%) |
| Clean repo zero findings | False positive | 9/9 (100%) |
| Subtle RBAC privilege escalation | Hard: subtle | 6/6 (100%) |
| **Overall** | | **67/67 (100%)** |

### claude-sonnet-4-6

| Eval | Type | Score |
|------|------|-------|
| Subtle RBAC privilege escalation | Hard: subtle | 6/6 (100%) |
| **Overall** | | **6/6 (100%)** |

### Cross-model notes

- **Subtle RBAC:** Both models caught ClusterRole/ClusterRoleBinding privilege escalation AND exec permission. Both provided attack YAML showing how the escalation works. No false positives on the properly-configured sourceRepos/destinations.
- The subtle RBAC eval was designed to produce failures — the AppProject looks well-configured at first glance. Both models looked past the surface.

### Accuracy validation

13 evals test detection accuracy:

**False negative tests (7):** Each fixture has ONE planted bug. Both models detected every
bug with correct severity classification — Critical for security issues (wildcards,
plain-text secrets, hardcoded passwords), Warning for operational risks (missing sync
policy, HEAD in prod, weak analysis, no deadline).

**False positive test (1):** Clean repo follows every best practice. Both models correctly
reported PASS with zero Critical/Warning findings. SealedSecret ciphertext not false-flagged.

**Hard eval (1):** Subtle RBAC privilege escalation — AppProject looks restricted but allows
ClusterRole/ClusterRoleBinding creation (escalation path) and exec into pods.

Evals test outcomes (issues found, report quality) not process (which tools were used).


</details>
