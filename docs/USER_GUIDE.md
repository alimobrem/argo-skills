# User Guide — Argo Agent Skills

## Quick Start

```shell
# Install the plugin
/plugin marketplace add alimobrem/argo-skills
/plugin install argo-skills@argocd

# Verify it loaded
/agents    # should show 'argocd'

# Start using
Audit the current repo for GitOps best practices.
```

## What You Can Ask

The agent automatically picks the right skill based on your prompt. You don't need to specify which skill to use.

### Knowledge — Learn & Generate

```text
# Concepts
What's the difference between app-of-apps and ApplicationSet?
When should I use canary vs blue-green rollouts?
How does argocd-agent work for edge clusters?

# Generate YAML
Generate an Application for my Helm chart at oci://ghcr.io/org/app version 2.x
  with automated sync, prune, selfHeal, and CreateNamespace.

Create an ApplicationSet with git directory generator and progressive syncs
  deploying to staging first, then production at 25%.

Generate a Rollout with canary strategy, Istio traffic management, and a
  Prometheus-based AnalysisTemplate checking error rate < 1%.

# Multi-source
Generate a multi-source Application combining a Helm chart from OCI with
  values from a separate Git repo.

# Notifications
Set up Slack notifications for sync failures with Block Kit formatting
  and GitHub commit status via GitHub App.

# Events
Create an EventSource + Sensor that triggers a Workflow on GitHub push to main.

# OpenShift
Generate an ArgoCD CR for the OpenShift GitOps operator with OAuth, Routes,
  and resource exclusions for Tekton.

# Promoter
Set up gitops-promoter for environment promotion with commit status gating
  across dev → staging → production.

# Multi-tenancy
Set up apps-in-any-namespace for 3 teams with separate AppProjects, RBAC,
  and namespace-scoped Applications.
```

### Repo Audit — Review & Validate

```text
# Full audit
Audit the current repo and provide a GitOps report.

# Targeted
Check for security issues in my AppProject configurations.
Are there any hardcoded secrets in Helm values?
Do my Applications have proper sync retry configuration?
Are any Applications using targetRevision: HEAD?

# Validation only
Just validate YAML syntax and schemas, don't do a full audit.

# Changed files only
Audit only the files changed in this PR.
```

### Cluster Debug — Troubleshoot

```text
# Health check
Check if Argo CD is properly installed on my cluster.

# Application issues
Why is my Application podinfo stuck in OutOfSync?
Debug the degraded Application in the production namespace.

# Rollout issues
The canary rollout for frontend is stuck at step 2. Why?
Are my AnalysisTemplates actually testing anything meaningful?

# Multi-tenant
Compare all ArgoCD instances on this cluster and check for security gaps.

# Deep investigation
Inspect all Rollouts on this cluster and give me a health report.
Review the Argo CD configuration and RBAC for security concerns.
Analyze the sync wave ordering across my Applications.
```

### Operations — Install, Deploy, Promote, Maintain

Every write operation follows the safety model: **Generate → Preview → Confirm**.

```text
# Setup
Install Argo CD on my OpenShift cluster using the GitOps operator.
Create an AppProject for the frontend team with restricted access.
Add the staging cluster to Argo CD.

# Deploy
Create an Application for this Helm chart with automated sync.
Create an ApplicationSet with git directory generator and progressive syncs.
Set up Slack notifications for sync failures.
Configure the image updater to watch for new tags on my registry.

# Promote
Promote the canary rollout frontend in production.
Sync the Application with server-side apply.
Abort the failing rollout and retry.

# Maintain
Upgrade Argo CD to the latest version.
Back up all my Applications and AppProjects to YAML files.
Rotate the Git credentials for the infra repo.
Migrate deprecated APIs to the latest versions.

# Promoter
Set up gitops-promoter for environment promotion of our payments app.
```

## Make Commands (Developer)

```shell
# Show all targets
make help

# Download Argo CRD schemas (for kubeconform validation)
make download-schemas

# Run discovery script on test fixtures
make test-discover

# Run validation script on test fixtures
make test-validate

# Run all skill evals
make eval

# Run evals per skill
make eval-knowledge
make eval-repo-audit
make eval-cluster-debug

# Clean schemas
make clean-schemas
```

## GitHub Actions

| Workflow | Trigger | What it does |
|----------|---------|-------------|
| `ci.yml` | Push/PR to main | Validates JSON, YAML syntax, SKILL.md frontmatter |
| `release.yml` | Tag push `v*` | Packages skills as tar.gz/zip, creates GitHub release |
| `evals.yml` | Manual dispatch | Runs evals with model selection (Opus/Sonnet/Haiku) |
| `update-schemas.yml` | Weekly (Monday 9am) | Downloads latest Argo CRD schemas, opens PR if changed |

## Tips

- **Use `oc` or `kubectl`** — the skills work with either. If on OpenShift, `oc` is preferred.
- **Cluster context matters** — the debug and operations skills use your current kubeconfig context. Switch context before asking about a specific cluster.
- **Reference docs load on demand** — the agent loads at most 2 reference files per question. If you need deeper coverage on a topic, ask a follow-up.
- **Safety model** — operations skill always shows what it will change before applying. Say "yes" to apply, anything else to cancel.
- **Argo CD questions redirect** — the platform-engineering skill (openshift-platform-skills) redirects Argo CD questions to argo-skills if both are installed.
