# argo-cluster-debug

## Run 7 — 2026-10-23, live cluster + fixtures, corrected suite

**97.5% with the skill vs 92.6% baseline (+4.9) over 61 expectations.**

| run | suite | with-skill | baseline | delta |
|---|---|---:|---:|---:|
| 3 | original | 92.1% | 92.1% | +0.0 |
| 4 | correctness-discriminating, eval-9 defective | 94.1% | 90.7% | +3.4 |
| 5 | eval-9 fixed | 94.1% | 84.7% | +9.3 |
| 6 | fixtures for evals 1, 5, 8, 9 | 92.6% | 86.1% | +6.6 |
| 7 | fixtures for evals 2, 4, 6 too | **97.5%** | 92.6% | **+4.9** |

Run 3 could not separate a correct diagnosis from a plausible one. Rewriting the
expectations to require a grounded, self-consistent root cause (run 4), then fixing the
eval-9 defect those runs exposed (run 5), progressively sharpened the instrument. **The
skill arm scored 94.1% in both runs 4 and 5; the movement is almost entirely the
baseline.** Treat that baseline swing (90.7 → 84.7) as run-to-run variance in a single
unaided agent, not as evidence the suite got harder — 58 of the 59 expectations are
identical between those runs.

Run 6 was the first with **fixtures actually deployed** (evals 1, 5, 8, 9). Run 7 added
the rest — a canary parked at step 2 by a live AnalysisRun, an ApplicationSet whose
directory pattern matches nothing, and a blue-green held at preview — so for the first
time every eval but 3 and 7 describes something that genuinely exists.

**The result is the most useful thing this suite has produced, and it is not flattering.**
Giving both arms real objects to debug raised the skill arm 92.6% → 97.5% and the baseline
86.1% → 92.6%. The baseline gained more, so the delta *fell* from +6.6 to +4.9 — below the
~5-point grader-noise floor. This skill is no longer claimed as a measured win.

The honest reading: a substantial part of what looked like skill advantage in run 6 was the
skill handling *absent* resources more gracefully — checking before asserting, refusing to
invent a cause, naming the right namespace. Those are real behaviours and they still show
up in the per-eval table. But when the resource is actually there, a competent unaided
agent reaches the same diagnosis most of the time, and the gap narrows to noise.

Reading the sequence +0.0 → +3.4 → +9.3 → +6.6 → +4.9 as a trend would be a mistake.
Four different suites and three different cluster states are represented; only runs 6 and
7 had fixtures at all, and only run 7 has most of them.

Fixtures are reproducible and are torn down after each run:
[`tests/argo-cluster-debug/fixtures/`](../tests/argo-cluster-debug/fixtures/).

| # | Eval | n | with-skill | baseline | delta |
|---|------|--:|-----------:|---------:|------:|
| 1 | Application OutOfSync and Degraded | 9 | 100% | 89% | +11 |
| 2 | Canary Rollout stuck at step 2 | 8 | 100% | 81% | +19 |
| 3 | Argo CD installation health check | 9 | 100% | 94% | +6 |
| 4 | ApplicationSet not generating expected Applications | 6 | 100% | 100% | +0 |
| 5 | ApplicationSet RollingSync stuck on production step | 7 | 93% | 93% | +0 |
| 6 | Blue-green rollout stuck at preview, never promotes | 6 | 100% | 92% | +8 |
| 7 | Ambiguous debug request with multiple Argo CD instances | 5 | 100% | 100% | +0 |
| 8 | Suspended Application reported as broken | 6 | 92% | 92% | +0 |
| 9 | Multi-source Application with one failing source | 5 | 90% | 100% | -10 **←** |
| | **total** | **61** | **97.5%** | **92.6%** | **+4.9** |

Eval 2 is the widest gap (+19) and it is the new fixture earning its keep. Both arms saw
the canary held at step index 1. Only one checked
`spec.strategy.canary.trafficRouting`, found none, and drew the consequence: with no mesh
or ingress wired in, `setWeight: 20` is approximated by replica count — 1 pod of 5, not
20% of requests. The other never looked. That expectation had previously failed *both*
arms for not describing a configuration that did not exist; rewording it to grade
reporting-the-absence is what made it discriminate.

Eval 3 is the deepest split even though both arms pass it. Both found the operator
upgrade stalled. One stopped at the CSV reporting `RequirementsNotMet`; the other produced
the object that actually failed — `InstallPlan install-fzm4w`, whose condition names the
`argocds.argoproj.io` conversion webhook, a zero-length `caBundle`, and a serving
certificate whose SANs do not cover the Service the CRD dials, proven by forcing a
v1alpha1 read. The first is a true statement about a downstream symptom; only the second
tells you what to fix.

Eval 9 is the one the baseline won (-10): it showed `targetRevision` for both sources
where the skill arm's per-source table omitted the values its own command had queried.

Evals 4, 7 and 8 split not at all. Eval 8 was the clearest divergence in earlier runs;
here both arms identified the `Suspended` state as an intentional `spec.paused: true` and
both found the broken workload underneath it. An expectation that discriminated once does
not necessarily discriminate again — which is the argument for re-running a suite rather
than trusting a number.

### Caveats specific to this suite

- **Eval 6's prompt claims the rollout has been stuck "for an hour"; the fixture is
  minutes old.** Both arms caught the discrepancy and said so with timestamps, which is
  correct behaviour — but it is a false premise we manufactured, not a real condition, so
  it rewards spotting a fixture artefact. Fix by dropping the duration from the prompt or
  by ageing the fixture before the run. Not changed mid-run, because that would have
  desynced the two arms.
- **Eval 4's prompt was moved from the `argocd` namespace to `openshift-gitops`.** The
  applicationset controller runs without `--applicationset-namespaces` and so reconciles
  only its own namespace; an ApplicationSet in `argocd` would sit inert and the eval would
  measure nothing. The alternative was editing the shared `ArgoCD` CR, which these
  fixtures never do. The prompt is now less faithful to the upstream default and more
  faithful to how OpenShift GitOps actually behaves.
- **Eval 5's `maxUpdate` is now set, and both arms still only partially satisfy the
  expectation** — neither evaluated whether the staging step's `maxUpdate` requirement was
  met, only the health gate. That is now a real shared gap rather than an unsatisfiable
  expectation, which is the state an eval should be in when both arms miss something.
- **Evals 3 and 7 have no fixtures and need none** — they ask about the cluster's own
  Argo CD installation, which is real by construction.
- **Eval 5 measures the inert case.** RollingSync is declared but the applicationset
  controller runs without `--enable-progressive-syncs`, so it never engages. That is a
  real and common OpenShift GitOps failure mode and both arms identified it, but it means
  the suite does not exercise a working progressive sync. Enabling the flag requires
  editing the shared `ArgoCD` CR, which the fixtures deliberately do not touch.

Earlier runs of this skill are archived: [`results-run4-eval9defect/`](results-run4-eval9defect/),
[`results-run3-oldsuite/`](results-run3-oldsuite/), [`results-run2-fixturecapped/`](results-run2-fixturecapped/).
Use `make history` to see which are comparable.

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
