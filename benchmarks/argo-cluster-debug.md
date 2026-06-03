# argo-cluster-debug

## v0.0.2 (2026-06-03)

Model: `claude-opus-4-6`

**Results**

| Eval | Score |
|------|-------|
| Argo CD installation check | 8/8 (100%) |
| **Overall** | **8/8 (100%)** |

**Checks performed:**
- Found argoproj.io CRDs on the cluster
- Identified the Argo CD namespace (openshift-gitops)
- Listed all pods and their status
- Verified core component health (server, repo-server, application-controller)
- Reported Argo CD version from image tags / operator
- Inspected ArgoCD CR and ConfigMap configuration
- Confirmed all components healthy (or reported unhealthy ones with diagnostics)
- Produced structured status report with Summary and Recommendations

Tested on a live OpenShift cluster with `oc` CLI (kubectl-compatible).

Remaining evals (Application debug, Rollout stuck, Workflow failing, EventSource issues)
require those specific resources to exist on the cluster. Run them in environments with
deployed Argo workloads.
