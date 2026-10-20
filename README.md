<p align="center">
  <img src="assets/banner.svg" alt="Argo Agent Skills" width="900"/>
</p>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-blue.svg" alt="License"></a>
  <a href="CONTRIBUTING.md"><img src="https://img.shields.io/badge/PRs-welcome-brightgreen.svg" alt="PRs Welcome"></a>
  <img src="https://img.shields.io/badge/Argo%20CD-v2.14+-EF7B4D.svg" alt="Argo CD">
  <img src="https://img.shields.io/badge/Rollouts-v1.8+-EF7B4D.svg" alt="Argo Rollouts">
  <img src="https://img.shields.io/badge/OpenShift%20GitOps-1.19+-EE0000.svg" alt="OpenShift GitOps">
</p>

<p align="center">
  <b>Give your AI agent deep expertise in Red Hat OpenShift GitOps.</b><br>
  Argo CD and Argo Rollouts as the operator ships them — generate manifests, audit repos,
  debug clusters, tune performance, onboard teams, and manage operations from your terminal.
</p>

---

> **Scope — Red Hat OpenShift GitOps.** These skills cover Argo CD and Argo Rollouts as
> shipped and supported by the OpenShift GitOps operator, including the operator-managed
> CRDs (`ArgoCD`, `RolloutManager`, `NotificationsConfiguration`, `NamespaceManagement`,
> `ImageUpdater`). They work against vanilla Argo CD too, but OpenShift GitOps is the
> target.
>
> **Argo Workflows and Argo Events are deliberately out of scope** — they are separate
> upstream projects the operator does not ship, and on OpenShift pipelines are normally
> [OpenShift Pipelines](https://docs.redhat.com/en/documentation/openshift_pipelines)
> (Tekton). For those, see the [Argo Workflows](https://argo-workflows.readthedocs.io/)
> and [Argo Events](https://argoproj.github.io/argo-events/) docs.
>
> [GitOps Promoter](https://github.com/argoproj-labs/gitops-promoter) **is** covered for
> environment promotion, but is installed separately — it is argoproj-labs, not
> operator-owned.

<details>
<summary><b>Quick Start</b></summary>

```shell
# Claude Code
/plugin marketplace add alimobrem/argo-skills
/plugin install argo-skills@argocd

# Then try:
# "Audit the current repo for GitOps best practices"
# "Check if Argo CD is healthy on my cluster"
# "Generate an ApplicationSet with git directory generator"
```

</details>

## Install

<details>
<summary><b>Claude Code</b></summary>

```shell
/plugin marketplace add alimobrem/argo-skills
/plugin install argo-skills@argocd
```

After install, the `argocd` agent appears in `/agents` and the 6 skills auto-trigger
based on context. Run `/reload-plugins` if they don't appear immediately.

</details>

<details>
<summary><b>Codex</b></summary>

Add to `$REPO_ROOT/.agents/plugins/marketplace.json` or `~/.agents/plugins/marketplace.json`:

```json
{
  "name": "argo-skills",
  "category": "Developer Tools",
  "source": {
    "source": "url",
    "url": "https://github.com/alimobrem/argo-skills.git",
    "ref": "main"
  },
  "policy": {
    "installation": "AVAILABLE",
    "authentication": "ON_INSTALL"
  }
}
```

</details>

<details>
<summary><b>GitHub Copilot</b></summary>

Copy the agent file to your repository:

```shell
mkdir -p .github/copilot
cp agents/github-copilot/argocd.agent.md .github/copilot/
```

</details>

<details>
<summary><b>Prerequisites</b></summary>

Required:
- `kubectl` or `oc` for Kubernetes/OpenShift cluster interaction

Optional (enhances capabilities):
- `kustomize` — Kustomize overlay builds
- `kubeconform` — schema validation against Argo CRDs
- `yq` — YAML parsing
- `argocd` — richer Application debugging and sync operations
- `kubectl-argo-rollouts` — Rollout status and promotion

Install all on macOS:
```shell
brew bundle
```

</details>

## Usage Guide

> **Full guide with all example prompts:** [docs/USER_GUIDE.md](docs/USER_GUIDE.md)

### How the Skills Work Together

The agent automatically selects the right skill based on what you ask:

```
 Ask a question ────► argo-knowledge           "How do I...?"
 Audit a repo ──────► argo-repo-audit          "Audit this repo"
 Debug a cluster ───► argo-cluster-debug       "Why is X failing?"
 Make a change ─────► argo-operations          "Install / create / promote / upgrade..."
 Tune performance ──► argo-performance-tuning  "Why is this slow at scale?"
 Onboard a team ────► argo-team-onboard        "Set up a new team on Argo CD"
```

You don't need to invoke skills manually — just describe what you need.

### Knowledge — Ask Questions & Generate YAML

Use when you need to understand Argo concepts or generate manifests.

```text
# Generate manifests
Generate a multi-source Application that combines a Helm chart from
oci://registry.example.com/myapp with values from a Git repo.

# Architecture guidance
What's the best way to structure a multi-cluster GitOps repo?
Should I use app-of-apps or ApplicationSet?

# Newer features
How do I set up argocd-agent for 200 edge clusters behind firewalls?
How do I run Applications in any namespace for multi-tenancy?

# OpenShift-specific
Generate an ArgoCD CR for the OpenShift GitOps operator with OAuth and Routes.
```

<details>
<summary>Reference docs included</summary>

| Topic | Reference |
|-------|-----------|
| Application spec, sync policies, health checks, multi-cluster | `applications.md` |
| ApplicationSet generators, progressive syncs, templates | `applicationsets.md` |
| AppProject RBAC, source/destination restrictions, sync windows | `app-projects.md` |
| Rollout canary/blue-green, traffic management, AnalysisTemplate | `rollouts.md` |
| Notification services, templates, triggers, subscriptions | `notifications.md` |
| Image updater annotations, strategies, write-back | `image-updater.md` |
| Repository patterns (app-of-apps, ApplicationSet, monorepo) | `repo-patterns.md` |
| Best practices (sync, RBAC, health, secrets) | `best-practices.md` |
| argocd-agent hub-and-spoke architecture | `agent-mode.md` |
| Multi-tenancy, apps-in-any-namespace, Autopilot | `multi-tenancy.md` |
| OpenShift GitOps Operator, ArgoCD CRD, Routes, SCCs, OAuth | `openshift.md` |
| GitOps Promoter, PromotionStrategy, branch-per-env promotion, commit status gating | `gitops-promoter.md` |

</details>

### Repo Audit — Security & Best Practice Review

<p align="center">
  <img src="assets/screenshots/audit-preview.svg" alt="Audit Report Preview" width="820"/>
</p>

Use when you want to validate a GitOps repo before deploying or during a review.

```text
# Full audit
Audit the current repo and provide a GitOps report.

# Targeted checks
Check for security issues in my AppProject configurations.
Are there any hardcoded secrets in Helm values?
Do my Applications have proper sync retry configuration?

# Validation only
Just validate YAML syntax and schemas, don't do a full audit.
```

**What it catches:**

| Severity | Examples |
|----------|---------|
| Critical | Wildcard `*` in AppProject sourceRepos/destinations, plain-text Secrets, hardcoded passwords in Helm values, `clusterResourceWhitelist: */*` |
| Warning | Missing syncPolicy, `targetRevision: HEAD` in production, no retry/backoff, missing `ignoreDifferences` for controller-managed fields |
| Info | Missing `ignoreDifferences` for HPA-managed replicas, no progressive sync on multi-cluster ApplicationSets |

### Cluster Debug — Troubleshoot Live Issues

<p align="center">
  <img src="assets/screenshots/debug-preview.svg" alt="Debug Report Preview" width="820"/>
</p>

Use when something is broken or you want a health check.

```text
# Health check
Check if Argo CD is properly installed on my cluster.

# Application issues
Why is my Application podinfo stuck in OutOfSync?
Debug the degraded Application in the production namespace.

# Rollout issues
The canary rollout for frontend is stuck at step 2. Why?
Are my AnalysisTemplates actually testing anything meaningful?

# Multi-tenant review
Compare all ArgoCD instances on this cluster and check for security gaps.

# Deep investigation
Inspect all Rollouts on this cluster and give me a health report.
Review the Argo CD configuration for security concerns.
```

### Operations — Install, Deploy, Promote, Maintain

<p align="center">
  <img src="assets/screenshots/operations-preview.svg" alt="Operations Preview" width="820"/>
</p>

Use when you want to make changes. Every write follows a safety model:
**Generate** YAML → **Preview** with dry-run → **Confirm** before applying.

```text
# Setup
Install Argo CD on my OpenShift cluster using the GitOps operator.
Create an AppProject for the frontend team with restricted access.
Add the staging cluster to Argo CD.

# Deploy
Create an Application for my Helm chart with automated sync.
Create an ApplicationSet with git directory generator and progressive syncs.
Set up Slack notifications for sync failures.

# Promote
Promote the canary rollout frontend in production.
Sync the Application with server-side apply.
Abort the failing rollout and retry.

# Maintain
Upgrade Argo CD to the latest version.
Back up all my Applications and AppProjects to YAML files.
Rotate the Git credentials for the infra repo.
```

<details>
<summary>Safety model details</summary>

| Step | What happens |
|------|-------------|
| Generate | Produces YAML manifest or CLI command, shows it in a code block |
| Preview | Runs `--dry-run=client`, `kubectl diff`, or `argocd app diff` to show what changes |
| Confirm | Asks "Apply this? (yes/no)" — does NOT proceed without explicit approval |

Read-only operations (backup, status checks) skip confirmation.

Destructive operations (delete, prune, rollback) require typing the resource name to confirm.

</details>

### Performance Tuning — Diagnose & Fix Slowness at Scale

Use when Argo CD/OpenShift GitOps is slow, resource-hungry, or struggling at scale.

```text
# Repo-server under pressure
Our argocd-repo-server keeps getting OOMKilled every time we push to our
  500-application monorepo.

# UI/controller sluggishness
The Argo CD UI feels sluggish and drift detection takes forever with 2,000 apps.

# Multi-cluster scaling
We have 20 clusters registered but only one application-controller pod and
  it's maxed out on CPU.

# Timeout errors
Users see "context deadline exceeded" opening an Application with a huge Helm chart.

# Git provider limits
Our GitHub org is rate-limiting us — 500 apps all point at the same repo and branch.

# Reconciliation churn (no real drift)
Our controller CPU is constantly high even though every Application shows
  Synced/Healthy — nothing in Git has changed.
```

Diagnoses the bottleneck first — including whether the controller is reconciling for the
right reasons at all (`resource.ignoreResourceUpdatesEnabled`, `resource.exclusions`,
per-Application `manifest-generate-paths` cache scoping for monorepos) before reaching for
repo-server concurrency, controller processors, sharding (static or Dynamic Cluster
Distribution), or Git rate-limits — then applies the same **Generate → Preview → Confirm**
safety model as Operations before changing anything live.

<details>
<summary>Reference docs included</summary>

| Topic | Reference |
|-------|-----------|
| Full settings table, per-setting fixes, sharding algorithms, standalone vs. OpenShift GitOps Operator YAML, common mistakes, tuning order of leverage | `tuning-settings.md` |

</details>

### Team Onboarding — Set Up New Teams on Argo CD

<p align="center">
  <img src="assets/screenshots/onboarding-preview.svg" alt="Onboarding Preview" width="820"/>
</p>

Use when you need to onboard app teams onto Argo CD. The skill discovers what
each team already has (CI, registry, source type) and generates only the Argo CD
pieces — no assumptions about your stack.

**Onboarding output is a commit, not a `kubectl apply`.** The tenant boundary —
AppProject, RBAC, namespace, quotas, NetworkPolicies — is GitOps config like anything
else, so the skill writes it to your GitOps repo and hands off to Argo CD to reconcile.
Applying it directly would put the boundary outside Git: invisible in review, missing
from the audit trail, and reverted the next time anything reconciles. The only exception
is a one-time bootstrap when no control loop exists yet, and the skill names it as such.

The recommended model follows Thomas Jungbauer's
[project onboarding with GitOps and Helm](https://www.redhat.com/en/blog/project-onboarding-using-gitops-and-helm):
onboarding a tenant means adding one small `values.yaml`, which a shared onboarding chart
renders and an ApplicationSet discovers. Committing rendered manifests or Kustomize
overlays is also supported.

```text
# Single team onboarding
Onboard the payments team. They use Kustomize, deploy from
https://github.com/acme/payments.git, need dev/staging/prod namespaces.

# Helm-based team
Onboard analytics — they deploy a Helm chart from OCI registry
oci://registry.acme.com/charts/analytics with values in a separate config repo.

# Self-service at scale
Set up self-service onboarding so teams can add themselves via PR.

# Multi-environment with promotion
Onboard the checkout team with gitops-promoter gating dev → staging → prod.
Production should require manual approval.
```

**What it generates:**

| Resource | When | Why |
|----------|------|-----|
| AppProject | Always | Security boundary — scoped sourceRepos, destinations, RBAC |
| Application | Always | Points to team's repo with correct source type (Helm/Kustomize/directory) |
| RBAC role | Always | Project-scoped permissions for team's SSO group |
| Namespace | Always | With Pod Security Standards (`enforce: restricted`) and monitoring labels |
| NetworkPolicies | Always | Default-deny egress (with DNS allowed) plus router, monitoring, and same-namespace ingress — without these the namespace is open to every pod on the cluster |
| ResourceQuota + LimitRange | If needed | Capacity limits, via t-shirt size or explicit values |
| PromotionStrategy | If multi-env | Branch-per-environment promotion with health gates |
| ApplicationSet | If self-service | Per-tenant values discovered by a `**/values.yaml` git generator |

**What it refuses:**

| Request | Response |
|---------|----------|
| `sourceRepos: '*'` | Lists repos explicitly — wildcards defeat multi-tenancy |
| `clusterResourceWhitelist: '*/*'` | Scopes to specific CRD groups needed |
| `exec` permission | Redirects to kubectl exec with scoped RBAC |
| Hardcoded secrets | References ExternalSecret or SealedSecret patterns |
| "Just apply it to the cluster" | Explains the drift cost and offers the commit path; proceeds only if it's a genuine bootstrap, and commits the same manifests alongside |

<details>
<summary>Reference docs included</summary>

| Topic | Reference |
|-------|-----------|
| **Recommended model** — per-tenant values + onboarding chart, discovery ApplicationSet, t-shirt sizes, default NetworkPolicies, Pod Security Standards, two-instance split | `gitops-onboarding.md` |
| What gets created, AppProject/Application/RBAC templates, validation checklist | `onboarding-guide.md` |
| Self-service via ApplicationSet, PR workflow, guard rails | `self-service-pattern.md` |
| Helm/Kustomize/directory variants, Rollouts, notifications, sync windows, promoter | `onboarding-variants.md` |

</details>

## Benchmarks

Evals test **outcomes** (issues found, report quality), not process (which tools were used).
Tested on real repos and a live OpenShift cluster.

<table>
<thead>
<tr>
<th width="200">Skill</th>
<th width="80">Score</th>
<th>Highlights</th>
</tr>
</thead>
<tbody>
<tr>
<td><a href="benchmarks/argo-knowledge.md"><b>argo-knowledge</b></a></td>
<td><b>98%</b><br><sub>vs 86% baseline</sub></td>
<td>+70% on argocd-agent, +17% on gitops-promoter, +8% on multi-tenant RBAC. Skill differentiates on newer features not saturated in training data.</td>
</tr>
<tr>
<td><a href="benchmarks/argo-repo-audit.md"><b>argo-repo-audit</b></a></td>
<td><b>94–98%</b><br><sub>vs 84% baseline</sub></td>
<td>Catches all Critical issues (wildcard AppProjects, plain-text Secrets, hardcoded passwords) in every condition, with or without the skill — this draws on general security judgment both models already have. The skill's real gap-closing is on comprehensiveness: ApplicationSet-specific checklist items (<code>goTemplateOptions</code>, <code>preserveResourcesOnDeletion</code>) that baseline reliably skips on open-ended audits.</td>
</tr>
<tr>
<td><a href="benchmarks/argo-cluster-debug.md"><b>argo-cluster-debug</b></a></td>
<td><b>99–100%</b><br><sub>vs 93% baseline</sub></td>
<td>97.5% on the original live-OpenShift advanced evals (multi-tenant audit, ApplicationSet deep dive, Rollout analysis). On the expanded 13-eval cross-model run, narrowest with-skill/baseline gap of any skill (+6–7%) — Argo troubleshooting patterns are well-represented in general training data; the skill's edge is committing to a specific root cause instead of a generic checklist.</td>
</tr>
<tr>
<td><a href="benchmarks/argo-operations.md"><b>argo-operations</b></a></td>
<td><b>99–100%</b><br><sub>vs 74–89% baseline</sub></td>
<td>Safety model fully compliant: dry-run preview + confirmation on every write. Cross-model run shows the gap is mostly the confirmation gate itself — baseline Opus skipped it 74% of the time, baseline Sonnet adopted it unprompted 89% of the time, closed to 100% for both once the skill enforces it explicitly.</td>
</tr>
<tr>
<td><a href="benchmarks/argo-performance-tuning.md"><b>argo-performance-tuning</b></a></td>
<td><b>99–100%</b><br><sub>vs 47–56% baseline</sub></td>
<td>+52% (Opus-tier) / +44% (Sonnet-tier) vs. unaided baseline, 14 evals × 2 models × with-skill/baseline. Biggest deltas: catches the <code>spec.extraConfig</code> processors misconfiguration baseline Opus validated outright (+100%), timeout-chain alignment (+100% Opus), Git <code>ls-remote</code> rate-limit setting unknown to both baselines (+100% Sonnet). Zero delta on reasoning derivable without Argo-specific knowledge (single-cluster sharding, cache-TTL-vs-image-freshness).</td>
</tr>
<tr>
<td><a href="benchmarks/argo-team-onboard.md"><b>argo-team-onboard</b></a></td>
<td><b>100%</b><br><sub>vs 72–76% baseline</sub></td>
<td>Discovery-first onboarding, Opus and Sonnet both 100% with skill. Sharpest finding in this repo: asked for wildcard <code>sourceRepos</code>/<code>clusterResourceWhitelist</code>/<code>exec</code>, both baseline models <i>generated the overprivileged config exactly as asked</i> with a caveat attached — neither refused. Both skill-equipped runs refused and substituted the scoped alternative, as the skill's hard rules require.</td>
</tr>
</tbody>
</table>

### Cross-Model: Sonnet with skill beats Opus without

<table>
<thead>
<tr>
<th width="220"></th>
<th width="120">Opus + Skill</th>
<th width="120">Opus Baseline</th>
<th width="120">Sonnet + Skill</th>
<th width="120">Sonnet Baseline</th>
</tr>
</thead>
<tbody>
<tr>
<td><b>argo-knowledge</b> (8 evals)</td>
<td><b>98%</b></td>
<td>86%</td>
<td><b>95%</b></td>
<td>88%<sup>†</sup></td>
</tr>
<tr>
<td><b>argo-repo-audit</b> (13 evals)</td>
<td><b>98%</b></td>
<td>84%</td>
<td><b>94%</b></td>
<td>84%</td>
</tr>
<tr>
<td><b>argo-cluster-debug</b> (13 evals)</td>
<td><b>99%</b></td>
<td>93%</td>
<td><b>100%</b></td>
<td>93%</td>
</tr>
<tr>
<td><b>argo-operations</b> (13 evals)</td>
<td><b>99%</b></td>
<td>74%</td>
<td><b>100%</b></td>
<td>89%</td>
</tr>
<tr>
<td><b>argo-performance-tuning</b> (14 evals<sup>‡</sup>)</td>
<td><b>99%</b></td>
<td>47%</td>
<td><b>100%</b></td>
<td>56%</td>
</tr>
<tr>
<td><b>argo-team-onboard</b> (13 evals)</td>
<td><b>100%</b></td>
<td>72%</td>
<td><b>100%</b></td>
<td>76%</td>
</tr>
</tbody>
</table>

Every cell above is a real score — no skill has an unrun condition left. See each skill's
`benchmarks/*.md` for the full per-eval breakdown and methodology notes (in particular, `argo-team-onboard`'s
baseline runs were not given the same "simulate a committed outcome" instruction as the
with-skill runs, which affects one eval; `argo-repo-audit` is a static-file-audit skill, so its
baseline runs had real read access to the same fixture files as the with-skill runs, differing
only in whether `SKILL.md`/`references/` were loaded).

<sup>†</sup> `argo-knowledge`'s Sonnet Baseline was scored against a slightly expanded
`evals.json` (88 checks) than the Opus columns in this row were originally scored against (86
checks) — see `benchmarks/argo-knowledge.md` for the exact delta. Directionally comparable, not
a perfectly controlled identical-rubric diff.

<sup>‡</sup> `argo-performance-tuning`'s `evals.json` now has 21 scenarios after a web-research
pass added 7 covering settings this skill didn't previously document (`resource.exclusions`,
`manifest-generate-paths`, Dynamic Cluster Distribution, and others — see
`references/tuning-settings.md`). The 99%/47%/100%/56% scores above are the real, unmodified
result of the original 14-eval benchmark and have not been re-run against the new 21; treat
them as the pre-expansion baseline, not a current full-coverage score.

> **Sonnet + skill (94–100%) beats Opus without skill (47–93%) on every skill — but the size of
> that gap varies enormously by skill.** It's widest on `argo-performance-tuning` (100% vs.
> 47%, +53 points) and `argo-team-onboard` (100% vs. 72%, +28 points) — skills whose baseline
> evals include an adversarial trap (an Operator misconfiguration both models' baselines
> validated outright; an overprivileged-RBAC request both baselines generated as asked instead
> of refusing). It's narrowest on `argo-cluster-debug` (100% vs. 93%, +7 points) and
> `argo-repo-audit` (94–98% vs. 84%, +10–14 points) — tasks where the underlying judgment (common
> troubleshooting patterns; "wildcard RBAC and plaintext secrets are bad") is common enough that
> baseline models already handle most of it correctly without any skill-specific knowledge. The
> skill's real, measurable value is concentrated in the specific settings, CRD-field names,
> checklist comprehensiveness, and hard safety rules that aren't common knowledge — not a flat
> tax on every task.

<sub>Run locally with <code>make eval</code> or via GitHub Actions (<code>evals</code> workflow).
Full results per model in <a href="benchmarks/">benchmarks/</a>.</sub>

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

<details>
<summary><b>Development</b></summary>

```shell
# Install prerequisites (macOS)
brew bundle

# Download Argo CRD schemas for validation
make download-schemas

# Run tests
make test-discover
make test-validate

# Run evals
make eval
```

See [AGENTS.md](AGENTS.md) for the repo layout, skill conventions, and eval runner instructions.

</details>

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).

## Security

See [SECURITY.md](SECURITY.md) for reporting vulnerabilities.

## License

[MIT License](LICENSE)
