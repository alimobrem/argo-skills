# argo-cluster-debug

## Run 3 — 2026-10-21, live cluster **with deployed fixtures**, blind A/B

**92.1% with the skill vs 92.1% baseline (+0.0) over 57 expectations.**

Run 2 scored 87.7% vs 88.6%, but four scenarios named resources that did not exist on the
cluster, so both arms were capped at `partial` on any expectation requiring a real
finding. For this run we deployed genuine fixtures — an Application driven both OutOfSync
and Degraded via live image drift with `selfHeal: false`, a paused blue-green Rollout
reporting health `Suspended`, and a multi-source Application whose `$values` path does not
exist (`ComparisonError: failed to generate manifest for source 1 of 2`) — then re-ran
both arms and tore the fixtures down.

Both arms rose ~4 points, matching the predicted fixture headroom almost exactly. **The
gap did not move.**

| # | Eval | n | with-skill | baseline | delta |
|---|------|--:|-----------:|---------:|------:|
| 1 | Application OutOfSync and Degraded | 8 | 100% | 88% | +12 |
| 2 | Canary Rollout stuck at step 2 | 8 | 56% | 81% | -25 |
| 3 | Argo CD installation health check | 8 | 94% | 94% | +0 |
| 4 | ApplicationSet not generating expected Applications | 6 | 100% | 100% | +0 |
| 5 | ApplicationSet RollingSync stuck on production step | 6 | 92% | 100% | -8 |
| 6 | Blue-green rollout stuck at preview, never promotes | 6 | 100% | 75% | +25 |
| 7 | Ambiguous debug request with multiple Argo CD instances | 5 | 100% | 100% | +0 |
| 8 | Suspended Application reported as broken | 5 | 100% | 100% | +0 |
| 9 | Multi-source Application with one failing source | 5 | 100% | 100% | +0 |
| | **total** | **57** | **92.1%** | **92.1%** | **+0.0** |

### The evals do not discriminate on correctness

On the two scenarios where the arms reached *different* root causes, the skill arm was
right both times and the baseline wrong both times — yet they scored the same:

| eval | with-skill | baseline | verified truth |
|---|---|---|---|
| 3 | zero-length conversion-webhook `caBundle` | "the operator pod is down" | `caBundle` length **0**; operator pods all **1/1 Running**. InstallPlan `install-fzm4w` Failed on exactly that webhook |
| 8 | `CrashLoopBackOff`, probe/port mismatch | "pause landed mid-bringup" | pod **CrashLoopBackOff, 13 restarts**; `containerPort: 80` while the image binds **:8443** |

Expectations phrased "identifies the root cause" are satisfied by naming a *plausible*
cause, not the *correct* one. Until they discriminate, this suite cannot resolve the
difference it exists to measure. Read `0.0` as "not resolved by this instrument".

Fixture-capped run-2 verdicts kept in
[`results-run2-fixturecapped/`](results-run2-fixturecapped/).

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
