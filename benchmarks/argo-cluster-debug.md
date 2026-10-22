# argo-cluster-debug

## Run 4 — 2026-10-22, live cluster + fixtures, correctness-discriminating suite

**94.1% with the skill vs 90.7% baseline (+3.4) over 59 expectations.**

Run 3 scored 92.1% vs 92.1% (+0.0) on this same skill against the same fixtures. The
difference is the suite: expectations were rewritten so that a stated root cause must be
**correct and grounded**, not merely plausible — a cause asserted with no supporting
output, or contradicted by output elsewhere in the same answer, now fails. See
[the methodology notes](README.md).

Fixtures are reproducible: [`tests/argo-cluster-debug/fixtures/`](../tests/argo-cluster-debug/fixtures/)
(`setup.sh` deploys and arms, `teardown.sh` removes and verifies). They were torn down
after this run.

| # | Eval | n | with-skill | baseline | delta |
|---|------|--:|-----------:|---------:|------:|
| 1 | Application OutOfSync and Degraded | 8 | 100% | 94% | +6 |
| 2 | Canary Rollout stuck at step 2 | 8 | 75% | 94% | -19 |
| 3 | Argo CD installation health check | 9 | 100% | 83% | +17 |
| 4 | ApplicationSet not generating expected Applications | 6 | 100% | 100% | +0 |
| 5 | ApplicationSet RollingSync stuck on production step | 6 | 92% | 92% | +0 |
| 6 | Blue-green rollout stuck at preview, never promotes | 6 | 100% | 83% | +17 |
| 7 | Ambiguous debug request with multiple Argo CD instances | 5 | 100% | 100% | +0 |
| 8 | Suspended Application reported as broken | 6 | 92% | 83% | +8 |
| 9 | Multi-source Application with one failing source | 5 | 90% | 90% | +0 |
| | **total** | **59** | **94.1%** | **90.7%** | **+3.4** |

The largest split is eval 3, the expectation added for exactly this purpose: one arm
named the failing InstallPlan and the zero-length conversion-webhook `caBundle`; the
other asserted the Subscription and all InstallPlans had been deleted — a false negative
from a bare `oc get subscription`, which on an ACM cluster resolves to a different API
group entirely.

**Known defect in eval 9.** Its final expectation says the report "must not attribute the
failure to the other" source when the error names one. The live error names source 1 while
the missing values file is reached through the `ref` source, and both arms correctly
explained that discrepancy — so the clause penalises the better answer. It is a fixture
flaw as much as a wording one: both sources point at the same repo, making "which source
is failing" ill-posed. It cost both arms equally, so the delta is unaffected.

Prior runs of this skill, graded against the older and more permissive suite, are in
[`results-run3-oldsuite/`](results-run3-oldsuite/) and
[`results-run2-fixturecapped/`](results-run2-fixturecapped/). Use `make history` to see
which scores are comparable.

---

<details>
<summary>Superseded: v0.2.0 (2026-10-14) — simulated outcomes, no live cluster</summary>

## v0.2.0 (2026-10-14) — Cross-model, with-skill vs. baseline

**Methodology:** 13 evals (expanded from 5) × 2 models (Opus-tier, Sonnet-tier) × with-skill/baseline,
via Cursor subagents instructed to simulate plausible cluster outcomes where no live cluster
was attached (same convention as `argo-performance-tuning`'s benchmark). Scored by the
orchestrating agent against `evals/evals.json`.

| Condition | Score |
|---|---|
| Opus-tier + skill | 82/83 (99%) |
| Opus-tier baseline | 77/83 (93%) |
| Sonnet-tier + skill | 83/83 (100%) |
| Sonnet-tier baseline | 77/83 (93%) |

**Key findings:**

- **Smallest with-skill/baseline gap of any benchmarked skill so far** (+6–7 points, vs.
  +44–52 on `argo-performance-tuning`). Argo CD/Rollouts/Workflows/Events troubleshooting
  patterns (sync vs. health status, canary pause reasons, EventSource→EventBus→Sensor
  pipeline tracing) are well-represented in general training data — both baselines produced
  methodologically sound investigation plans for most scenarios.
- **The gap concentrates in two places:** (1) scenarios requiring a *committed, specific*
  root-cause finding rather than a generic "check A, B, or C" checklist — e.g. the
  multi-instance eval and the Suspended-Application eval, where the skill's plausible-outcome
  simulation produces a concrete diagnosis and baseline produces investigative advice without
  landing on one; and (2) the ApplicationSet eval set (zero coverage existed before this
  expansion) and ambiguous multi-instance detection, where baseline's generic "sweep all
  namespaces" guidance scores lower against expectations written for a resolved finding.
- **Multi-source Application and blue-green-vs-canary distinctions were handled well by both
  baselines** — these are documented, common patterns, not the kind of obscure setting that
  differentiated other skills.


Model: `claude-opus-4-6`

**Results — Basic Evals**

| Eval | Score |
|------|-------|
| Argo CD installation check | 8/8 (100%) |

**Results — Advanced Evals (live OpenShift cluster)**

| Eval | Score | Key Findings |
|------|-------|--------------|
| Multi-tenant ArgoCD audit | 7/8 (88%) | Found both instances, RBAC cross-namespace tests, flagged team-b wildcard AppProject |
| ApplicationSet deep dive | 8/8 (100%) | Found deleted apps, flagged missing goTemplate/rollingSync/preserveResourcesOnDeletion |
| Rollout analysis | 8/8 (100%) | Flagged trivial AnalysisTemplate conditions, caught Degraded rollout |
| Cross-cutting config review | 8/8 (100%) | Compared both instances, flagged admin enabled, insecureCA, notifications disabled |
| Sync waves and hooks | 8/8 (100%) | Traced wave ordering, hook deletion policies, Helm hook mappings |
| **Overall** | **39/40 (97.5%)** | |

**Notable agent behaviors:**
- 187 tool calls across 5 evals — deep, thorough investigations
- Rollout eval inspected AnalysisTemplate Prometheus queries and identified that
  `success-rate` checks CPU usage (always >= 0), making it effectively a no-op
- Multi-tenant eval ran `oc auth can-i` tests across namespaces to verify RBAC boundaries
- ApplicationSet eval traced controller logs to discover apps were created then deleted externally
- Config review compared both ArgoCD instances side-by-side with gap analysis

Tested on live OpenShift cluster (OpenShift GitOps operator) with `oc` CLI.


</details>
