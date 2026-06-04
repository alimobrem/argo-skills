# Argo CD Cluster Debug Report

## Summary

| Field | Value |
|-------|-------|
| Cluster | `aws-jb-acsacm-1.dev05.red-chesterfield.com` (OCP 4.21.16) |
| Operator | Red Hat OpenShift GitOps **v1.20.4** |
| Namespace | `openshift-gitops` |
| Components | 7 pods running (6 core + 1 rollouts controller) |

## Component Status

| Component | Status | Ready | Restarts |
|-----------|--------|-------|----------|
| application-controller | Running | Yes | 0 |
| applicationset-controller | Running | Yes | 0 |
| server | Running | Yes | 0 |
| repo-server | Running | Yes | 0 |
| redis | Running | Yes | 0 |
| dex-server (SSO) | Running | Yes | 0 |
| argo-rollouts | Running | Yes | **4** |

## Findings

1. **MEDIUM** -- `argo-rollouts` pod has **4 restarts**. Investigate previous container logs (`oc logs -n openshift-gitops argo-rollouts-765df4fc64-txnjg --previous --tail=100`) to identify the crash cause (likely OOM or leader-election churn).
2. **LOW** -- The only Application on the cluster (`stackrox/stackrox`) reports `<none>` for both sync and health status, indicating it was never synced or its controller has not reconciled it.
3. **LOW** -- No Kubernetes events found in `openshift-gitops` namespace. This is normal for a stable installation but limits post-incident forensics.
