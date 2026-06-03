# argo-cluster-debug

## v0.0.3 (2026-06-03)

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
