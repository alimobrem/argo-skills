---
name: argo-performance-tuning
description: >
  Diagnoses and tunes OpenShift GitOps / Argo CD performance and scalability — repo-server
  Git and caching behavior, application-controller sharding and concurrency, API-server
  timeouts, and reconciliation/webhook tuning. Maps symptoms (slow or stuck UI, OOMKilled
  repo-server, backed-up sync queue, Git provider rate-limiting, sluggish drift detection,
  "context deadline exceeded" errors) to the specific setting that fixes them, for both
  standalone Argo CD (ConfigMaps + env vars) and the OpenShift GitOps Operator (ArgoCD CR).
  Use when users report Argo CD or OpenShift GitOps running slowly at scale, hitting OOM,
  timing out, or ask how to tune, scale, speed up, or reduce resource usage of GitOps
  reconciliation.
license: MIT
compatibility: Requires kubectl or oc; optionally argocd CLI, yq
---

# Argo Performance Tuning

Diagnose and tune Argo CD / OpenShift GitOps performance and scalability — from a single
sluggish instance to multi-cluster, thousands-of-Applications deployments.

This skill complements `argo-cluster-debug` (diagnoses *broken* resources) and `argo-operations`
(installs/deploys/maintains). It owns the "it works but it's slow / resource-hungry / falling
over at scale" problem space, and reuses the **Generate → Preview → Confirm** safety model from
`argo-operations` for any change that touches a live cluster.

## How This Skill Works

1. **Assess** — gather scale signals and current settings from the live cluster.
2. **Diagnose** — map the reported symptom(s) to the specific bottleneck and setting(s).
3. **Tune** — generate the exact config change for the user's install type, preview it, confirm,
   apply, and state what to monitor afterward.

Load `references/tuning-settings.md` once per session — it is the full settings reference
(defaults, recommended values, standalone vs. OpenShift GitOps Operator locations, and the
common-mistakes list) and the source of truth for every recommendation this skill makes.

## Prerequisites

| Tool | Required | Purpose |
|------|----------|---------|
| kubectl or oc | Yes | Read current config, apply tuning changes |
| argocd | No | Richer Application/version inspection |
| yq | No | Parsing `argocd-cm`/`argocd-cmd-params-cm` YAML |

## Phase 1: Assess

Confirm the cluster context and install type first:

```bash
kubectl config current-context
kubectl get argocd -A -o name 2>/dev/null  # Operator-managed (OpenShift GitOps / Argo CD Operator)
kubectl get deployment -n argocd argocd-server 2>/dev/null || \
  kubectl get deployment -n openshift-gitops argocd-server 2>/dev/null  # standalone / detect namespace
```

Gather scale signals:

```bash
NS=<argocd-namespace>   # argocd or openshift-gitops

# Application and cluster count — the two numbers that matter most for sharding decisions
kubectl get applications -A --no-headers | wc -l
kubectl get secrets -n "$NS" -l argocd.argoproj.io/secret-type=cluster --no-headers | wc -l   # external clusters (+1 for in-cluster)
kubectl get secrets -n "$NS" -l argocd.argoproj.io/secret-type=repository --no-headers | wc -l

# Current replica counts
kubectl get deploy,statefulset -n "$NS" -l app.kubernetes.io/name=argocd-application-controller -o wide
kubectl get deploy -n "$NS" -l app.kubernetes.io/name=argocd-repo-server -o wide
kubectl get deploy -n "$NS" -l app.kubernetes.io/name=argocd-server -o wide

# OOM / restart history — strong signal for parallelism-limit tuning
kubectl get pods -n "$NS" -l app.kubernetes.io/name=argocd-repo-server -o json | \
  python3 -c "import json,sys; [print(p['metadata']['name'], c['restartCount'], c.get('lastState',{}).get('terminated',{}).get('reason')) for p in json.load(sys.stdin)['items'] for c in p['status']['containerStatuses']]"
kubectl get pods -n "$NS" -l app.kubernetes.io/name=argocd-application-controller -o json | \
  python3 -c "import json,sys; [print(p['metadata']['name'], c['restartCount'], c.get('lastState',{}).get('terminated',{}).get('reason')) for p in json.load(sys.stdin)['items'] for c in p['status']['containerStatuses']]"

# Current tuning-relevant settings
kubectl get configmap argocd-cm -n "$NS" -o jsonpath='{.data.timeout\.reconciliation}{"\n"}{.data.timeout\.reconciliation\.jitter}{"\n"}' 2>/dev/null
kubectl get configmap argocd-cmd-params-cm -n "$NS" -o yaml 2>/dev/null
kubectl get argocd -n "$NS" -o yaml 2>/dev/null   # Operator-managed: spec.repo.env / spec.controller.* / spec.extraConfig
```

Check whether Git webhooks are configured (relevant to `timeout.reconciliation` decisions) —
look for a webhook Route/Ingress/Service in front of `argocd-server`, or ask the user directly.

## Phase 2: Diagnose

Map the reported symptom to the bottleneck using this table, then read the matching section of
`references/tuning-settings.md` for the exact setting, default, recommended value, and placement.

| Symptom | Likely bottleneck | Setting(s) |
|---|---|---|
| repo-server `OOMKilled` / CrashLoopBackOff during a mass sync or large push | Unbounded concurrent manifest generation | `ARGOCD_REPO_SERVER_PARALLELISM_LIMIT` |
| Git provider rate-limiting / 429s / org-wide block | Unbounded concurrent `git ls-remote` | `ARGOCD_GIT_LS_REMOTE_PARALLELISM_LIMIT` |
| `context deadline exceeded` in UI/CLI viewing a complex Application | API server timeout shorter than actual render time | `ARGOCD_SERVER_REPO_SERVER_TIMEOUT_SECONDS` (align with `ARGOCD_EXEC_TIMEOUT`) |
| Sync/comparison errors on large Helm charts or Kustomize overlays | Repo-server child-process timeout too low | `ARGOCD_EXEC_TIMEOUT` |
| Large monorepo is slow to fetch/clone | Full-history clone | Git shallow clone `depth` (repository Secret) |
| Sync failures on flaky/throttled Git connections | No retry | `ARGOCD_GIT_ATTEMPTS_COUNT` |
| CPU spikes when many apps share one commit | Cache stampede — lock timeout too short for a slow chart | `ARGOCD_REVISION_CACHE_LOCK_TIMEOUT` |
| UI/CLI sluggish, slow drift detection at 1,000+ apps | Status comparison concurrency too low | `controller.status.processors` |
| Mass sync leaves apps `Pending`/`Waiting` | Operation concurrency too low | `controller.operation.processors` |
| Raised `operation.processors` but syncs still queue | `kubectl` process-slot limit unchanged | `ARGOCD_APPLICATION_CONTROLLER_KUBECTL_PARALLELISM_LIMIT` |
| Controller `context deadline exceeded` cancelling slow manifest RPCs | Controller→repo-server timeout too low | `ARGOCD_APPLICATION_CONTROLLER_REPO_SERVER_TIMEOUT_SECONDS` |
| Sustained high baseline CPU/network, no code changes | Aggressive blind polling, no webhooks | `timeout.reconciliation` (+ set up webhooks) |
| Periodic load spikes at a fixed cadence | No jitter spreading polls | `timeout.reconciliation.jitter` |
| One controller maxed out across many registered clusters | No horizontal scaling | Application Controller **sharding** |

If multiple symptoms are present, work through **Tuning order of leverage** in
`references/tuning-settings.md`: reduce unnecessary work first, then align timeouts, then bound
concurrency, then scale out with sharding.

## Phase 3: Tune — Generate, Preview, Confirm

Every change that touches the live cluster follows the same 3-step protocol as
`argo-operations`:

1. **Generate** — produce the exact YAML patch or env var change, in a fenced code block. For
   the OpenShift GitOps Operator, show the correct `spec` path (`spec.repo.env`,
   `spec.controller.env`, `spec.controller.processors`, `spec.controller.sharding`, or
   `spec.extraConfig`) — get this wrong and the change silently does nothing. Check the
   **Common mistakes** list in `references/tuning-settings.md` before presenting the patch.
2. **Preview**:
   ```bash
   kubectl patch argocd <name> -n <ns> --type merge -p '<patch>' --dry-run=server -o yaml
   # or, for standalone ConfigMap/env changes:
   kubectl diff -f <file>.yaml
   ```
3. **Confirm** — ask "Apply this? (yes/no)" and wait for explicit approval before applying.
   Read-only assessment (Phase 1) never requires confirmation.

After applying, state what to watch to confirm the fix worked and catch regressions:
controller/repo-server CPU & memory, reconcile duration, kube-apiserver request rate/latency,
and Git provider rate-limit headers. Recommend changing **one** major setting at a time.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Only one cluster registered | Sharding will not help — say so explicitly and point to repo-server/controller concurrency settings instead |
| No Git webhook configured | Do not recommend lowering `timeout.reconciliation` much, and caution that raising it delays commit detection by up to the full interval; recommend configuring a webhook first |
| OpenShift GitOps Operator in use | `processors` go under `spec.controller.processors`, **not** `spec.extraConfig`; controller repo-server timeout goes under `spec.controller.env`, **not** `spec.extraConfig` |
| Floating tags / mutable Helm chart versions in use | Do not recommend lowering `ARGOCD_REPO_CACHE_EXPIRATION` to chase freshness — recommend webhooks or version pinning instead |
| Public repository with no Repository Secret yet | Must create the Secret object first — shallow-clone `depth` cannot be set without it |
| User asks for `consistent-hashing` sharding on OpenShift GitOps | Note it is not documented/officially supported there; verify against the installed operator version before relying on it in production |
| Repo-server/controller already restarting with `OOMKilled` | Treat as urgent — recommend the relevant parallelism/processor limit immediately, not just resource-limit increases that mask the root cause |
| Cluster not reachable | Report the error and stop; do not generate apply commands for a cluster you cannot validate against |

## Reference Index

| Topic | Reference File | When to Load |
|-------|---------------|-------------|
| Full settings table, per-setting Problem→Fix detail, sharding algorithms, standalone vs. Operator YAML, common mistakes, tuning order of leverage | `references/tuning-settings.md` | Every request — this is the primary source of truth for this skill |

## Related Skills

- **Resource broken, not just slow?** → `argo-cluster-debug`
- **Installing, deploying, or general day-2 ops?** → `argo-operations` (its `day2-operations.md`
  covers basic replica/resource scaling; this skill covers the deeper env-var/ConfigMap tuning)
- **"What is X" / generate manifests?** → `argo-knowledge`
