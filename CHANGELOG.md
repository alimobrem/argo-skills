# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added (argo-performance-tuning — web research delta)

- `references/tuning-settings.md` expanded with 11 settings/features verified against official
  Argo CD docs, upstream source, and benchmarked engineering blogs (the skill's reference was
  previously sourced from a single blog post). New coverage, roughly in order of impact:
  - `resource.ignoreResourceUpdatesEnabled` and the default `/status` ignore rule — the actual
    mechanism behind "high controller CPU with no real drift," which the skill previously only
    addressed indirectly via `timeout.reconciliation`.
  - `resource.exclusions` (ships with defaults since Argo CD 3.0) — stops watching known
    high-churn, non-GitOps kinds entirely.
  - `argocd.argoproj.io/manifest-generate-paths` annotation — the official fix for "one commit
    to a monorepo invalidates the cache for every Application in it," which the skill previously
    only worked around via shallow-clone depth / cache TTL advice. Documented with its known
    cache-coherency bugs (fixed as recently as mid-2026) as an explicit caveat.
  - `ARGOCD_K8S_CLIENT_QPS`/`BURST` (+ related TCP/TLS client family) — controller→managed-cluster
    API client tuning, with real AWS benchmark numbers (42min→11min sync time at 200/400).
  - Controller self-heal pacing (`controller.self.heal.timeout/backoff.*`).
  - `ARGOCD_APPLICATION_TREE_SHARD_SIZE` — Redis resource-tree sharding, distinct from cluster
    sharding.
  - Dynamic Cluster Distribution (alpha, v2.9+) — shard rebalancing without controller restarts,
    documented alongside two open 2025 upstream bugs on scale-down/scale-up
    (argoproj/argo-cd#24147, #24520).
  - Real consistent-hashing vs. round-robin benchmark data (CNOE blog) replacing the previous
    unsupported assertion that consistent-hashing "can improve balance"; also added the
    round-robin-is-still-experimental caveat the skill didn't carry before.
  - `controller.sync.timeout.seconds`, `controller.sync.wave.delay.seconds`,
    `controller.resource.health.persist` (new 3.0 default), and `controller.app.state.cache.expiration`
    (distinct from the repo-server's `ARGOCD_REPO_CACHE_EXPIRATION`, which the skill already covered).
- `SKILL.md` Phase 1 (Assess) gathers the new signals; Phase 2 (Diagnose) gained 6 new
  symptom→setting rows; Edge Cases gained 5 new entries for the above.
- 7 new eval scenarios (ids 15-21, bringing the total to 21) covering the high-impact new
  gaps — not yet benchmarked; see `benchmarks/argo-performance-tuning.md` for the existing
  14-eval / 99% vs. 47% result, which predates this expansion.
- All findings sourced and linked in a research canvas; one claim (exact Redis-compression /
  batch-event-processing setting names in 3.0) was left out of the skill because it could not be
  independently verified beyond the release changelog's entry titles.

### Added

- Expanded evals from 5/6/6 to 13 each for `argo-cluster-debug`, `argo-operations`, and
  `argo-team-onboard` — new scenarios target real gaps found by re-reading each skill's own
  `SKILL.md` (ApplicationSet debugging had zero prior coverage in `argo-cluster-debug`;
  `argo-operations` only ever tested the OpenShift Operator path, never Helm; `argo-team-onboard`
  never tested the plain-directory source type, the Phase 4 validation checklist, or the
  "Argo CD not installed" stop-and-redirect edge case).
- Real cross-model with-skill-vs-baseline benchmarks for all three expanded skills (Opus-tier
  + Sonnet-tier, same subagent methodology as `argo-performance-tuning`). See each skill's
  `benchmarks/*.md` for full per-eval breakdowns.

### Benchmark highlights

- `argo-team-onboard`: 100% with skill (both models) vs. 72–76% baseline. On the
  overprivileged-access eval, **both baseline models generated the requested wildcard
  `sourceRepos`/`clusterResourceWhitelist`/`exec` config as asked**, only adding a caveat
  afterward — neither refused. Both skill-equipped runs refused and substituted the scoped
  alternative per the skill's hard safety rules.
- `argo-operations`: 99–100% with skill vs. 74% (Opus baseline) / 89% (Sonnet baseline). The
  gap is driven almost entirely by the Generate → Preview → Confirm gate itself — baseline
  Sonnet adopted explicit confirmation prompts unprompted far more often than baseline Opus.
- `argo-cluster-debug`: 99–100% with skill vs. 93% baseline (both models) — the narrowest
  gap of any skill in this repo, since Argo troubleshooting patterns are common enough that
  baseline models already handle most of it; the skill's edge here is committing to one
  concrete root cause instead of a generic "check A, B, or C" list.

### Changed

- README Cross-Model comparison table expanded from `argo-knowledge` only to all 6 skills,
  with a new Sonnet Baseline column. Every cell is now a real, run score — no placeholder
  dashes remain anywhere in the table.

### Benchmark highlights (round 2)

- `argo-repo-audit`: first-ever baseline comparison for this skill (previously had none —
  it's a static local-file audit skill, not a live-cluster simulation). 98% (Opus+skill) /
  94% (Sonnet+skill) vs. 84% (both baselines, tied exactly) across all 13 real fixture-audit
  evals. The narrowest baseline gap of any skill in this repo besides `argo-cluster-debug`:
  GitOps security judgment ("wildcard RBAC is bad," "plaintext secrets are bad") is common
  DevSecOps knowledge both models already have. The skill's value here is comprehensiveness
  (ApplicationSet-specific checklist items like `goTemplateOptions`/`preserveResourcesOnDeletion`
  that baseline reliably skips) rather than teaching facts the models don't know. Also surfaced
  a real miss: Opus **with** the skill loaded failed to catch a duplicate-`AppProject`-name
  defect that both unaided baselines and Sonnet-with-skill all caught independently — and a
  severity-calibration miss on "HEAD in prod" (3 of 4 conditions, including skill-equipped
  Opus, over-escalated it to Critical when the skill's own rubric calls for Warning).
- `argo-knowledge`: added the one remaining untested condition (Sonnet unaided baseline),
  closing out the Cross-Model table completely. Sonnet's baseline scored 88% (77/88) —
  notably, it nailed the `argocd-agent` edge-fleet-architecture eval unaided (10/10), a sharp
  contrast with Opus's historical 30% baseline on the same eval. Weakest area unaided:
  `gitops-promoter` (58%) — branch-naming convention, `activeCommitStatuses` placement, and
  wrong parent-resource reference on `ArgocdCommitStatus` were all missed, consistent with the
  pattern that gitops-promoter (a newer, smaller project) is where unaided knowledge is least
  reliable across both models.

### Added

- **argo-performance-tuning** skill — diagnoses and tunes Argo CD / OpenShift GitOps
  performance and scalability. Maps symptoms (OOMKilled repo-server, sluggish UI/drift
  detection, Git rate-limiting, `context deadline exceeded`, high baseline polling load) to
  the specific repo-server, controller, or sharding setting that fixes them, for both
  standalone Argo CD and the OpenShift GitOps Operator `ArgoCD` CR. Reuses the
  generate/preview/confirm safety model from `argo-operations` for any live-cluster change.
  Distilled from [Tuning OpenShift GitOps for performance at scale](https://blog.stderr.at/gitopscollection/2026-03-27-openshift-gitops-performance-tuning/).
- `references/tuning-settings.md` — full settings reference (defaults, recommended values,
  standalone vs. Operator CR placement, common misconfigurations, tuning order of leverage)
- 14 eval scenarios for `argo-performance-tuning`, covering core symptom diagnosis plus
  edge cases (single-cluster sharding refusal, Operator misconfiguration correction,
  floating-tag cache pushback, unsupported sharding algorithm, multi-symptom prioritization,
  safety-model compliance, standalone vs. Operator placement)
- Routing entries for the new skill in the `argocd` agent, `argo-operations` redirect table,
  README, and USER_GUIDE

### Benchmarks

- argo-performance-tuning: 99% (Opus-tier) / 100% (Sonnet-tier) with skill vs. 47% / 56%
  unaided baseline — +52% / +44% delta across all 14 evals on both models. Largest deltas on
  the Operator `spec.extraConfig` processors misconfiguration (baseline Opus validated the
  broken request outright, 0/5), the three-way timeout alignment (0/5 baseline Opus), and the
  Git `ls-remote` rate-limit setting (unknown to both unaided baselines). See
  `benchmarks/argo-performance-tuning.md`.

## [0.1.0] - 2026-06-04

### Added

- **argo-knowledge** skill — answers questions about the full Argo ecosystem and generates
  validated YAML for all Argo CRDs (Application, ApplicationSet, AppProject, Rollout,
  AnalysisTemplate, Workflow, EventSource, Sensor, and more)
- **argo-repo-audit** skill — audits GitOps repositories for security issues, best practice
  violations, and operational gaps with structured prioritized reports
- **argo-cluster-debug** skill — debugs Argo resources on live Kubernetes/OpenShift clusters
  with systematic workflows for Applications, Rollouts, Workflows, and Events
- **argo-operations** skill — installs, deploys, promotes, and maintains Argo resources with
  a 3-step safety model (generate → preview → confirm)
- 15 reference docs covering Applications, ApplicationSets, AppProjects, Rollouts, Workflows,
  Events, notifications, image updater, repo patterns, best practices, argocd-agent, multi-tenancy,
  OpenShift GitOps, gitops-promoter
- 7 bundled Argo CRD schemas for offline kubeconform validation
- 3 test fixtures (app-of-apps, applicationset, mixed-issues) with 37 YAML files
- 19 eval scenarios across all 4 skills with benchmarks
- Agent configs for Claude Code, GitHub Copilot, and Codex
- CI workflows for validation, releases, evals, and weekly schema updates
- Pre-commit hook for PII/secret scanning
- SVG banner and terminal-style preview screenshots in README

### Benchmarks

- argo-knowledge: 97% with skill vs 86% baseline (+11%), +70% on argocd-agent
- argo-repo-audit: 100% — catches all Critical security issues
- argo-cluster-debug: 97.5% on advanced live cluster evals
- argo-operations: 87% — safety model fully compliant
