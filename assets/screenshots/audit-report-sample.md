# Argo GitOps Audit Report — `mixed-issues`

| Field | Value |
|-------|-------|
| Pattern | Multi-Repo |
| Clusters | `kubernetes.default.svc`, `staging.k8s.example.com` |
| Argo Resources | 5 Applications, 2 AppProjects, 2 Rollouts, 1 AnalysisTemplate, 2 Workflows, 1 WorkflowTemplate, 1 CronWorkflow |
| K8s Resources | 3 Secrets |
| Overall Status | **FAIL** |

## Top Findings

| # | Severity | File | Finding |
|---|----------|------|---------|
| 1 | ![CRITICAL](https://img.shields.io/badge/-CRITICAL-red) | `apps/backend-app.yaml:26` | Plain-text database credentials in `stringData` — password and connection string exposed |
| 2 | ![CRITICAL](https://img.shields.io/badge/-CRITICAL-red) | `apps/cluster-secret.yaml:13` | Cluster bearer token committed in plain text with `insecure: true` TLS |
| 3 | ![CRITICAL](https://img.shields.io/badge/-CRITICAL-red) | `projects/default-override.yaml` | Default AppProject permits `*` sourceRepos, `*/*` destinations, and `*/*` clusterResourceWhitelist |
| 4 | ![HIGH](https://img.shields.io/badge/-HIGH-orange) | `apps/redis.yaml:15` | Hard-coded password in Helm values (`auth.password`) |
| 5 | ![HIGH](https://img.shields.io/badge/-HIGH-orange) | `apps/api-server.yaml`, `apps/frontend-app.yaml` | No `syncPolicy` defined — manual sync only, no selfHeal or prune |

## Recommendations

1. **Eliminate all plain-text secrets.** Replace `Secret` resources and inline passwords with `SealedSecret`, `ExternalSecret`, or SOPS-encrypted files. Rotate every credential currently in the repo — they are compromised by commit history.
2. **Lock down AppProjects.** Replace wildcard `sourceRepos`, `destinations`, and `clusterResourceWhitelist` with explicit allow-lists scoped per team. Neither `default` nor `team-insecure` enforces any restriction.
3. **Add `syncPolicy.automated` with `selfHeal: true` and `prune: true`** to all Applications, and set `activeDeadlineSeconds` + `podGC` on both Workflows (`build-pipeline`, `data-pipeline`) to prevent resource leaks.
