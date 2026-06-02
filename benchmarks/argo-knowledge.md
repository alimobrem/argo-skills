# argo-knowledge

## v0.0.1 (2026-06-02)

Model: `claude-opus-4-6`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Multi-source Application | 10/10 (100%) | 10/10 (100%) | 0% |
| Merge generator + goTemplateOptions | 9/10 (90%) | 9/10 (90%) | 0% |
| Blue-green + Job AnalysisTemplate | 10/10 (100%) | 10/10 (100%) | 0% |
| Slack Block Kit + GitHub App status | 10/10 (100%) | 10/10 (100%) | 0% |
| GitLab + Kafka EventBus + CEL filter | 12/12 (100%) | 11/12 (92%) | +8% |
| Multi-tenant apps-in-any-namespace | 12/12 (100%) | 10/12 (83%) | +17% |
| Edge fleet with argocd-agent | 10/10 (100%) | 7/10 (70%) | +30% |
| **Overall** | **73/74 (99%)** | **67/74 (91%)** | **+8%** |

The skill shows strongest differentiation on newer features not well-covered in training data:
- **argocd-agent** (hub-and-spoke architecture for edge/air-gapped clusters) — baseline doesn't know the component names
- **Applications in any namespace** — baseline misses the three-part RBAC syntax and annotation-based tracking requirement
- **GitLab EventSource** — baseline omits `merge_request` event type

Core Argo CD concepts (Applications, Rollouts, Workflows) are well-known to the base model.
The skill adds most value for post-2024 features, niche configurations, and gotcha avoidance.
