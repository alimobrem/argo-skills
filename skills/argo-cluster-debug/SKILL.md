---
name: argo-cluster-debug
description: >
  Debug and troubleshoot the Argo ecosystem on live Kubernetes clusters — inspects
  Argo CD Application sync status, health checks, and controller logs; diagnoses
  Argo Rollouts canary/blue-green failures and AnalysisRun results; traces Argo
  Workflow step failures and artifact issues; and debugs Argo Events EventSource
  and Sensor connectivity. Prefers argocd/argo CLIs when available, falls back to
  kubectl for CRD inspection. Use when users report failing, stuck, or degraded
  Argo resources on a cluster.
license: MIT
compatibility: Requires kubectl; optionally argocd, argo (workflows CLI), kubectl-argo-rollouts
---

# Argo Cluster Debug

Debug and troubleshoot the full Argo ecosystem on live Kubernetes clusters.

## Prerequisites

| Tool | Required | Purpose |
|------|----------|---------|
| `kubectl` **or** `oc` | Yes | CRD inspection, pod logs, resource status |
| argocd | No | Richer Application output, diff, sync operations |
| argo | No | Workflow logs, node inspection |
| kubectl-argo-rollouts | No | Rollout status, step details, promotion |

**Resolve the CLI before any workflow. On OpenShift, `oc` is the default.**

```bash
# Detect the platform and pick the CLI — on OpenShift, oc is the default.
if command -v oc >/dev/null 2>&1 && oc api-resources --api-group=route.openshift.io 2>/dev/null | grep -q routes; then
  KCTL=oc; PLATFORM=OpenShift
elif command -v kubectl >/dev/null 2>&1; then
  KCTL=kubectl
  PLATFORM=$(kubectl api-resources --api-group=route.openshift.io 2>/dev/null | grep -q routes && echo OpenShift || echo Kubernetes)
elif command -v oc >/dev/null 2>&1; then
  KCTL=oc; PLATFORM=Kubernetes
else
  echo "ERROR: no cluster CLI found — install kubectl or oc" >&2; exit 1
fi
echo "Platform: $PLATFORM — using '$KCTL'"
```

Every `kubectl` in the workflows below means `$KCTL`. `oc` accepts all of them verbatim,
so substituting is always safe. Prefer `oc` on OpenShift — `Route`, `project`,
`SecurityContextConstraints`, and `oc adm` have no `kubectl` equivalent, and they are
exactly what you need when the Argo CD UI is unreachable (Route) or a pod will not start
(SCC). Only report a missing prerequisite when **neither** binary exists.

When `$PLATFORM` is OpenShift, also expect the Argo CD namespace to be
`openshift-gitops` rather than `argocd`, and instances to be Operator-managed `ArgoCD`
CRs (`argoproj.io/v1beta1`) — check `$KCTL get argocd -A`.

## How This Skill Works

The debug skill provides **systematic workflows** — each is a sequence of checks that
traces the problem from surface symptoms to root cause. The value is in the completeness
of the investigation, not just finding the first error.

**Before starting any workflow:**
1. Check which CLIs are available (argocd, argo, kubectl-argo-rollouts, kubectl)
2. Confirm the current cluster context
3. Pick the matching workflow from the table below and load `references/debug-workflows.md`
4. Load `references/troubleshooting.md` — it maps symptoms to causes and saves time

**General rules:**
- Prefer specialized CLIs when available (richer output), fall back to `kubectl get -o yaml`
- Read-only by default — never sync, promote, or delete unless explicitly asked
- Analyze `.status.conditions` as the primary diagnostic signal for every Argo CRD
- Complete the full workflow — don't stop after finding one issue, cascading problems are common

## Cluster Context

- If the user specifies a cluster context, switch to it:
  ```bash
  kubectl config use-context <context-name>
  ```
  If using argocd CLI with a remote server:
  ```bash
  argocd context <context-name>
  ```
- If no cluster is specified, use the current context. Confirm it:
  ```bash
  kubectl config current-context
  ```
- Always verify Argo CD installation before Application/ApplicationSet debugging. Check for the argocd namespace and CRDs.

## Debugging Workflows

Seven self-contained workflows live in `references/debug-workflows.md`. Match the reported
symptom to a workflow below, **load that file, and work its steps in order** — each step
builds context for the next. The value is in completing the investigation, not in stopping
at the first error.

| # | Workflow | Use when |
|---|----------|----------|
| 1 | Argo CD Installation Check | User asks if Argo CD is installed, reports general Argo CD failures — **or as a prerequisite before any Application/ApplicationSet debugging** |
| 2 | Application Debugging | Application sync failure, health degradation, `OutOfSync`, or `Unknown` status |
| 3 | ApplicationSet Debugging | ApplicationSet not generating Applications, generating the wrong ones, or reporting errors |
| 4 | Rollout Debugging | Canary or blue-green Rollout stuck, aborted, or degraded |
| 5 | Workflow Debugging | Argo Workflow failure, stuck steps, or artifact errors |
| 6 | EventSource / Sensor Debugging | Events not flowing, Sensor not triggering, EventSource failures |
| 7 | Log Analysis | Cross-component log correlation when the failing component is not yet known |

Run **Workflow 1 first** whenever Argo CD's own health is unverified — a broken controller
or repo-server explains most Application-level symptoms, and skipping it leads to
misdiagnosing a healthy Application as broken.

If a workflow is inconclusive, `references/troubleshooting.md` maps symptoms to causes.

## Report Format

Every debugging session must conclude with a structured report.

### 1. Summary

| Field | Value |
|-------|-------|
| Cluster Context | `<context-name>` |
| Argo Component | CD / Rollouts / Workflows / Events |
| Component Versions | e.g., Argo CD v2.14.2 |
| Resource | `<kind>/<namespace>/<name>` |
| Current Status | Sync/Health/Phase status |

### 2. Resource Analysis

- **Spec**: key configuration details (source, strategy, template)
- **Status Conditions**: each condition with type, status, message, timestamp
- **Events**: relevant Kubernetes events

### 3. Dependency Chain

Map the full dependency chain relevant to the problem:
- Argo CD: `Git Repo -> Repo Server -> Application -> Managed Resources -> Pods`
- Rollouts: `Rollout -> ReplicaSets -> Pods`, `Rollout -> AnalysisRun -> Metric Provider`
- Workflows: `Workflow -> DAG/Steps -> Pods -> Artifacts`
- Events: `EventSource -> EventBus -> Sensor -> Trigger Target`

### 4. Root Cause

State the identified root cause with supporting evidence:
- The specific error message or condition
- The resource and field where the failure originates
- The chain of causation from root cause to observed symptom

### 5. Recommendations

Prioritized list of actions:
- **BLOCKER** — must fix to restore functionality
- **HIGH** — significant risk if not addressed
- **MEDIUM** — best practice violation contributing to the issue
- **LOW** — improvement for reliability or observability

---

## Edge Cases

Handle these scenarios explicitly:

| Scenario | Behavior |
|----------|----------|
| Argo CD not installed (no argocd namespace or CRDs) | Report "Argo CD is not installed on this cluster" and stop Application/AppSet workflows |
| argocd CLI not logged in | Detect `FATAL: Argo CD server address unspecified` and suggest `argocd login <server>` |
| Multiple Argo CD instances | If multiple namespaces found, list them and ask user to specify |
| Application in Progressing state | Note that the resource is actively reconciling — wait 60s and re-check before diagnosing |
| Suspended Application or Rollout | Report as intentional suspension, do not treat as error unless user says otherwise |
| Unknown health status | Check for custom health check Lua scripts in `argocd-cm` under `resource.customizations.health.<group_kind>` |
| Rollout without traffic management | Note that canary is replica-based only — weight percentages are approximated by replica ratio |
| Workflow pods cleaned up by GC | Report that logs are unavailable due to pod GC — suggest increasing `spec.podGC.strategy` or checking archived workflows |
| CronWorkflow not firing | Check `spec.timezone`, `spec.concurrencyPolicy`, `spec.startingDeadlineSeconds`, and whether previous run is still active |
| Argo Events NATS cluster split | Check NATS pod logs for cluster connectivity, check PDB and pod anti-affinity |
| Helm source with missing values files | Check `spec.source.helm.valueFiles` paths relative to the chart, not the repo root |
| Multi-source Application | Iterate all entries in `spec.sources[]` — each source can fail independently |

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
| Workflow | Argo Workflows | DAG/step-based job execution (`argoproj.io/v1alpha1`) |
| WorkflowTemplate | Argo Workflows | Reusable workflow definition |
| ClusterWorkflowTemplate | Argo Workflows | Cluster-scoped WorkflowTemplate |
| CronWorkflow | Argo Workflows | Scheduled workflow execution |
| EventSource | Argo Events | Event ingestion (webhooks, SNS, SQS, etc.) |
| EventBus | Argo Events | Event transport (NATS, JetStream, Kafka) |
| Sensor | Argo Events | Event-driven trigger execution |

## Reference Index

| Topic | Reference File | When to Load |
|-------|---------------|-------------|
| The seven step-by-step debugging workflows (installation, Application, ApplicationSet, Rollout, Workflow, Events, log analysis) | `references/debug-workflows.md` | **Every debugging session** — load the workflow matching the symptom |
| Symptom → cause → fix tables across all four Argo projects | `references/troubleshooting.md` | Alongside a workflow, or when a workflow is inconclusive |
