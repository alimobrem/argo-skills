---
name: argo-repo-audit
description: >
  Audit and validate Argo CD GitOps repositories by scanning local repo files (not live clusters) —
  runs Kubernetes schema validation, reviews AppProject RBAC and security restrictions, checks sync
  policies and operational best practices, and produces a prioritized GitOps report. Use when users
  ask to audit, analyze, validate, review, or security-check an Argo CD GitOps repo.
license: MIT
compatibility: Requires awk, yq, kustomize, kubeconform
---

# Argo Repo Audit

Audit and validate Argo CD GitOps repositories by scanning local files — no live cluster required.

## Prerequisites

| Tool | Minimum Version | Purpose |
|------|----------------|---------|
| awk | any | Discovery script (no yq needed) |
| yq | 4.50+ | YAML syntax validation |
| kustomize | 5.8+ | Kustomize overlay builds |
| kubeconform | 0.7+ | Kubernetes schema validation |

## Workflow

Execute phases sequentially. Each phase builds on the previous.

### Phase 1: Discovery

Run the discovery script to inventory all resources in the repository:

```bash
skills/argo-repo-audit/scripts/discover.sh -d <repo-root>
```

With the JSON output:

1. **Classify the repo pattern** by reading `references/repo-patterns.md` and matching heuristics:
   - **App of Apps**: Application resources whose `spec.source.path` points to directories containing other Application YAMLs
   - **ApplicationSet**: Presence of ApplicationSet resources with generators
   - **Monorepo**: Single repo with path-based Applications and multiple environment overlays
   - **Multi-Repo**: Applications referencing different `repoURL` values
   - **Environment Branch**: Applications with same `repoURL` but different `targetRevision` per environment

2. **Detect clusters and environments** from:
   - Directory naming (`clusters/`, `envs/`, `environments/`)
   - Application `spec.destination.server` and `spec.destination.name` values
   - ApplicationSet generator parameters
   - Overlay directory names (`staging/`, `production/`, `dev/`)

3. **Note mixed tooling** — Terraform directories, Flux resources, or Helm-only charts co-existing with Argo resources.

### Phase 2: Manifest Validation

Run the validation script:

```bash
skills/argo-repo-audit/scripts/validate.sh -d <repo-root>
```

This performs three validation passes:
1. **YAML syntax** — parse every YAML file with `yq`
2. **Kubernetes schema** — validate manifests against schemas with `kubeconform` (uses Argo CRD schemas from `assets/schemas/`)
3. **Kustomize builds** — build each overlay and pipe through `kubeconform`

The script auto-skips SOPS-encrypted Secrets, Terraform directories, and Helm chart directories.

### Phase 3: Best Practices Assessment

Read `references/best-practices.md` **in full** and assess the repository against each applicable category:

- **Sync policies** — automated sync, selfHeal, prune, retry configuration
- **ApplicationSet configuration** — progressive syncs (rollingSync), generators, preserveResourcesOnDeletion
- **Resource tracking method** — annotation vs label-based tracking
- **Health checks** — custom health checks for CRDs
- **Ignore differences** — fields managed by controllers (HPA replicas, mutating webhooks)
- **Sync waves and hooks** — ordering via `argocd.argoproj.io/sync-wave` and PreSync/PostSync hooks
- **Rollout configurations** — if Argo Rollouts resources are present, check AnalysisTemplates, canary steps, traffic management
- **Workflow resource limits** — if Argo Workflows resources are present, check activeDeadlineSeconds, retry strategies, pod GC

Skip categories that have zero matching resources in the discovery output.

### Phase 4: Security Review

Read `references/security-audit.md` **in full** and audit the repository:

- **AppProject restrictions** — sourceRepos, destinations, clusterResourceWhitelist, namespaceResourceBlacklist, orphaned resource monitoring
- **RBAC** — SSO integration, project roles, default policy, admin access restrictions
- **Secrets management** — check for plain-text Secrets (should be sealed-secrets, external-secrets, SOPS, or Vault)
- **Cluster credentials** — ensure argocd-cluster-secret is not in plain text
- **Source repo allowlisting** — wildcards (`*`) in sourceRepos
- **Destination restrictions** — wildcards (`*`) in destinations
- **Network policies** — ingress TLS, GRPC configuration

Use the grep/awk scanning commands from `security-audit.md` to find specific issues.

If the repo targets **OpenShift** (presence of `Route`, `ArgoCD` CRD, `DeploymentConfig`,
or `SecurityContextConstraints` resources), also check the OpenShift-specific security
section in `security-audit.md` — covers ArgoCD CRD version, Route TLS, OAuth, SCCs,
managed-by labels, and namespace-scoped instance elevation risks.

### Phase 5: Report

Produce a structured markdown report with these sections:

#### 1. Summary

| Field | Value |
|-------|-------|
| Repository | `<name>` |
| Pattern | App of Apps / ApplicationSet / Monorepo / Multi-Repo / Environment Branch |
| Clusters | list of detected clusters |
| Argo Resources | count by kind |
| Kubernetes Resources | count by kind |
| Overall Status | PASS / WARN / FAIL |

#### 2. Directory Structure

Show the relevant directory tree with annotations for what each section contains.

#### 3. Validation Results

Table of validation findings:
- File path
- Kind
- Issue
- Severity (Error / Warning)

#### 4. Best Practices

For each applicable category from Phase 3:
- Status (Pass / Fail / N/A)
- Findings with file paths and line references
- Recommendation if failing

#### 5. Security

For each applicable check from Phase 4:
- Status (Pass / Fail / N/A)
- Evidence (file path, line, value)
- Risk level (Critical / High / Medium / Low)

#### 6. Recommendations

Prioritized list:

- **Critical** — Security vulnerabilities, plain-text secrets, wildcard permissions in production
- **Warning** — Missing best practices that increase operational risk
- **Info** — Suggestions for improved maintainability or performance

## Edge Cases

Handle these scenarios gracefully:

| Scenario | Behavior |
|----------|----------|
| Not an Argo repo (no `argoproj.io` CRDs found) | Report as "No Argo resources detected" and skip Phases 3-4 |
| Mixed tooling (Argo + Terraform, Argo + Flux) | Note in summary, audit only Argo resources, flag potential conflicts |
| SOPS-encrypted secrets | Skip from validation (detect by `.sops.yaml` or `sops:` metadata), note as "encrypted — OK" |
| Helm chart directories | Auto-skip directories containing `Chart.yaml` — they are rendered by Argo CD at sync time |
| postBuild substitution variables | Note that `${VAR}` patterns in Kustomize overlays may cause kubeconform failures — report as info, not error |
| Third-party CRDs | Silently skipped by kubeconform (`-ignore-missing-schemas`) — not an error |

## Argo CRD Reference

All CRDs use `apiVersion: argoproj.io/v1alpha1` unless noted:

| Kind | Project | Description |
|------|---------|-------------|
| Application | Argo CD | Defines a deployed application |
| AppProject | Argo CD | Groups applications with RBAC and restrictions |
| ApplicationSet | Argo CD | Templated multi-cluster/multi-env application generation |
| Rollout | Argo Rollouts | Advanced deployment with canary/blue-green |
| AnalysisTemplate | Argo Rollouts | Metrics-based promotion criteria |
| ClusterAnalysisTemplate | Argo Rollouts | Cluster-scoped AnalysisTemplate |
| AnalysisRun | Argo Rollouts | Instance of an analysis execution |
| Experiment | Argo Rollouts | Temporary ReplicaSet for A/B testing |
| Workflow | Argo Workflows | DAG/step-based job execution |
| WorkflowTemplate | Argo Workflows | Reusable workflow definition |
| ClusterWorkflowTemplate | Argo Workflows | Cluster-scoped WorkflowTemplate |
| CronWorkflow | Argo Workflows | Scheduled workflow execution |
| EventSource | Argo Events | Event ingestion (webhooks, SNS, SQS, etc.) |
| EventBus | Argo Events | Event transport (NATS, Jetstream, Kafka) |
| Sensor | Argo Events | Event-driven trigger execution |
