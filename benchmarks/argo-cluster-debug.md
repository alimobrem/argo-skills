# argo-cluster-debug

## Run 6 — 2026-10-23, live cluster + fixtures, corrected suite

**92.6% with the skill vs 86.1% baseline (+6.6) over 61 expectations.**

| run | suite | with-skill | baseline | delta |
|---|---|---:|---:|---:|
| 3 | original | 92.1% | 92.1% | +0.0 |
| 4 | correctness-discriminating, eval-9 defective | 94.1% | 90.7% | +3.4 |
| 5 | eval-9 fixed | 94.1% | 84.7% | +9.3 |
| 6 | fixtures deployed, prompts unchanged | **92.6%** | 86.1% | **+6.6** |

Run 3 could not separate a correct diagnosis from a plausible one. Rewriting the
expectations to require a grounded, self-consistent root cause (run 4), then fixing the
eval-9 defect those runs exposed (run 5), progressively sharpened the instrument. **The
skill arm scored 94.1% in both runs 4 and 5; the movement is almost entirely the
baseline.** Treat that baseline swing (90.7 → 84.7) as run-to-run variance in a single
unaided agent, not as evidence the suite got harder — 58 of the 59 expectations are
identical between those runs.

Run 6 is the first with **fixtures actually deployed**, so the four evals that previously
named resources the cluster did not have could finally be answered rather than capped at
`partial` for both arms. The delta settles at +6.6 — above the ~5-point noise floor, and
lower than run 5's +9.3. Reading the sequence +0.0 → +3.4 → +9.3 → +6.6 as a trend would
be a mistake: three of those four runs scored different suites, and only run 6 had the
cluster state the prompts assume.

Fixtures are reproducible and are torn down after each run:
[`tests/argo-cluster-debug/fixtures/`](../tests/argo-cluster-debug/fixtures/).

| # | Eval | n | with-skill | baseline | delta |
|---|------|--:|-----------:|---------:|------:|
| 1 | Application OutOfSync and Degraded | 9 | 100% | 89% | +11 |
| 2 | Canary Rollout stuck at step 2 | 8 | 56% | 44% | +12 |
| 3 | Argo CD installation health check | 9 | 94% | 83% | +11 |
| 4 | ApplicationSet not generating expected Applications | 6 | 100% | 92% | +8 |
| 5 | ApplicationSet RollingSync stuck on production step | 7 | 100% | 93% | +7 |
| 6 | Blue-green rollout stuck at preview, never promotes | 6 | 92% | 92% | +0 |
| 7 | Ambiguous debug request with multiple Argo CD instances | 5 | 100% | 100% | +0 |
| 8 | Suspended Application reported as broken | 6 | 100% | 100% | +0 |
| 9 | Multi-source Application with one failing source | 5 | 100% | 100% | +0 |
| | **total** | **61** | **92.6%** | **86.1%** | **+6.6** |

The sharpest split is eval 3, and it is a depth-of-diagnosis split rather than a
right-versus-wrong one. Both arms found the operator upgrade stalled. One stopped at the
CSV reporting `RequirementsNotMet` and olm-operator logging `no owned roles found`; the
other produced the object that actually failed — `InstallPlan install-fzm4w`, whose
condition names the `argocds.argoproj.io` conversion webhook, a zero-length `caBundle`,
and a serving certificate whose SANs do not cover the Service the CRD dials. The first is
a true statement about a downstream symptom; the second is the cause, and only the second
tells you what to fix. The expectation asks for "the specific blocking object and field",
which is what separates them.

Eval 8 is worth noting as a *non*-split. In earlier runs it was the clearest divergence;
here both arms identified the `Suspended` state as an intentional `spec.paused: true` and
both then found the genuinely broken workload underneath — pod not ready, probes on port
80 against an image binding 8080, both Services with no endpoints. An expectation that
discriminated once does not necessarily discriminate again.

### Caveats specific to this suite

- **Evals 2, 4 and 6 still name resources that do not exist on this cluster** —
  `frontend`/`production`, `team-apps`/`argocd`, and `checkout-api`/`prod` were all
  verified absent at run time. The fixtures cover evals 1, 5, 8 and 9 only. Both arms
  correctly established absence and demonstrated on clearly-labelled comparable
  resources, but those verdicts rest on a substitute object and are the least robust in
  the set. Grading absence-handling is deliberate and legitimate; grading a *diagnosis*
  through a substitute is weaker, and these three should get fixtures next.
- **Eval 5's `maxUpdate` expectation presumes a field the ApplicationSet lacks.** This one
  is our own doing: the fixture declares `rollingSync.steps` without `maxUpdate`, so the
  expectation cannot be fully satisfied. Fix the fixture, not the expectation.
- **Eval 2's "traffic routing if configured" is unresolvable** — the substitute Rollout has
  none — and failed in both arms identically.
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
