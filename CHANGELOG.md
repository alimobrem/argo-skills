# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Fixed (`preserveResourcesOnDeletion` was documented at the wrong path everywhere)

Surfaced by an eval run and confirmed against the repo's own committed CRD schema
(`skills/argo-repo-audit/assets/schemas/applicationset-argoproj-v1alpha1.json`): the field
exists **only** at `spec.syncPolicy.preserveResourcesOnDeletion`. There is no
`spec.preserveResourcesOnDeletion`. Because the ApplicationSet CRD is a structural schema,
the API server silently prunes the misplaced key — the manifest applies cleanly, review
looks correct, and the cluster has no deletion protection at all.

Every occurrence in the repo had it at spec level:

- `argo-knowledge/references/patterns.md` — patterns 3 and 4
- `argo-knowledge/references/applicationsets.md` — the spec overview block and the
  dedicated `## preserveResourcesOnDeletion` section (which contradicted the correct
  usage shown in the same file's Sync Policy section)
- `argo-operations/references/deployment.md` — ApplicationSet example
- `argo-repo-audit/references/best-practices.md` — the audit checklist, which meant the
  auditor **passed** repos with the broken key and would have flagged correct ones. Now
  reports the spec-level form as a finding.
- `argo-knowledge/evals/evals.json` — eval 2 explicitly instructed "Set
  preserveResourcesOnDeletion at the spec level" and asserted it in the expectations, so
  the benchmark was rewarding the broken output. Prompt and expectation corrected.

Note this slightly changes the argo-knowledge eval set, so the recorded 98% is not a
like-for-like comparison with future runs of eval 2.

### Fixed (argo-knowledge Rule 1 was factually wrong)

Rule 1 asserted "Every Argo CRD uses `apiVersion: argoproj.io/v1alpha1`", which the
skill's own references contradict: the OpenShift GitOps `ArgoCD` CR is
`argoproj.io/v1beta1`, and every GitOps Promoter kind is in a different API *group*
(`promoter.argoproj.io/v1alpha1`). A model following Rule 1 literally emits a rejected
manifest on those topics. Rule 1 now names the exceptions, and the CRD Table lists
`ArgoCD`, `PromotionStrategy`, `GitRepository`, `ScmProvider`, and `ArgocdCommitStatus`.

### Changed (argo-team-onboard is now GitOps-first) — BREAKING for existing users

Review feedback: *"I'm not a fan of argo-team-onboard if it's directly updating the Argo
CD config, this should be handled in git and managed by GitOps."* Correct, and it was a
design flaw — a GitOps onboarding skill whose write path was `kubectl apply` put the
tenant boundary outside Git: invisible in review, absent from the audit trail, and liable
to be reverted the next time anything reconciled.

- **The write is now a commit**, not an apply. The safety model changed from
  Generate → dry-run → apply to **Generate → `git diff` → confirm → commit/PR**, and the
  skill states that the tenant is not onboarded until Argo CD syncs.
- **`kubectl apply` is now the documented exception**, allowed only to bootstrap the first
  control loop, and the skill must label it as such and commit the same manifests.
- **Phase 1 Discovery now locates the GitOps repo first** and matches the existing tenant
  layout instead of inventing one. New Phase 3 covers the commit and handoff.
- **`git` is now the only hard requirement**; `kubectl`/`argocd` are optional and
  read-only. Onboarding works with no cluster access at all.
- New *Choosing the Onboarding Model* section: per-tenant values + chart (recommended),
  rendered manifests, or Kustomize overlay.

### Added (argo-team-onboard — security baseline and recommended model)

- `references/gitops-onboarding.md` — the recommended model, following Thomas Jungbauer's
  [project onboarding with GitOps and Helm](https://www.redhat.com/en/blog/project-onboarding-using-gitops-and-helm):
  per-tenant `values.yaml` rendered by a shared onboarding chart and discovered by an
  ApplicationSet with a `**/values.yaml` git generator. Includes t-shirt sizing with
  per-tenant override, and the two-Argo-CD-instance platform/tenant split.
- **Default NetworkPolicies are now generated for every tenant namespace.** The skill
  previously blacklisted `NetworkPolicy` via `namespaceResourceBlacklist` but never
  created any — so tenant namespaces shipped fully open to lateral traffic *and* teams
  were blocked from fixing it. Adds default-deny egress (with the DNS exception that
  makes it survivable), same-namespace, router ingress, and monitoring ingress.
- **Pod Security Standards labels on the Namespace template** —
  `pod-security.kubernetes.io/enforce: restricted` plus audit/warn and cluster monitoring.
  Previously absent entirely, so a tenant could run privileged pods regardless of how
  carefully the AppProject was scoped.

### Fixed (six-skill consistency)

- `assets/banner.svg` now shows a pill for all six skills; `performance-tuning` and
  `team-onboard` were missing.
- `make eval` ran only four of six skills — added `eval-operations` and
  `eval-team-onboard` (both skills already had `evals.json` and a benchmarks page).
- `.github/workflows/evals.yml` knew only three skills, and offered stale model IDs.
- `.codex-plugin/plugin.json` had placeholder `your-org` URLs and a three-capability
  description.
- `docs/USER_GUIDE.md` had no Team Onboarding section.
- README was missing the `gitops-promoter.md` reference row, and still explained a `—`
  placeholder that no longer appears in the benchmarks table.
- `make download-schemas` deleted the committed schemas first and had `|| true` on every
  download, so a network blip or an upstream CRD rename silently produced empty schema
  files — and `update-schemas.yml` would open a weekly PR deleting them. Downloads are now
  staged, verified non-empty and valid JSON, and only then swapped in.
- `argo-repo-audit` invoked its scripts at a CWD-relative path that does not resolve once
  the skill is installed as a plugin.
- `argo-knowledge` Pattern 10 combined Helm image-updater annotations with
  `write-back-target: kustomization` on a Kustomize source; each half is ignored by the
  other's source type.
- `argo-team-onboard` Phase 2/3 carried inline templates that contradicted `references/`:
  a different AppProject naming convention, snake_case vs camelCase `teams.yaml` fields,
  and a `teams:` array feeding a per-file generator's `{{ .team.name }}` (which cannot
  resolve, and hard-fails under `missingkey=error`).

### Added

- `scripts/check-skill-registration.sh`, wired into CI and `make test-registration`: a new
  skill cannot be added without being registered in the marketplace manifest, agent
  definition, Makefile eval targets, banner, README, and eval workflow. Verified it fails
  against the old four-pill banner.

### Changed (progressive disclosure)

Large always-loaded `SKILL.md` files now route to references, following the structure
`argo-performance-tuning` already used. No content was dropped — verified by comparing
every code block before and after.

- `argo-knowledge`: 822 → 189 lines; the 10 canonical YAML patterns moved to
  `references/patterns.md`, replaced by an index table.
- `argo-cluster-debug`: 695 → 176 lines; the 7 debugging workflows moved to
  `references/debug-workflows.md`, replaced by a symptom → workflow routing table.
- `argo-team-onboard`: 609 → 421 lines; Phase 2/3 inline manifests removed in favour of
  the existing `references/`, which are now the single source of truth for templates.

Evals should be re-run to confirm no regression, since answering now requires following a
reference pointer rather than reading everything up front.

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
