# argo-knowledge

## v0.0.2 (2026-06-02)

Model: `claude-opus-4-6`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Multi-source Application | 10/10 (100%) | 10/10 (100%) | 0% |
| Merge generator + goTemplateOptions | 9/10 (90%) | 9/10 (90%) | 0% |
| Blue-green + Job AnalysisTemplate | 9/10 (90%) | 9/10 (90%) | 0% |
| Slack Block Kit + GitHub App status | 10/10 (100%) | 10/10 (100%) | 0% |
| GitLab + Kafka EventBus + CEL filter | 12/12 (100%) | 12/12 (100%) | 0% |
| Multi-tenant apps-in-any-namespace | 12/12 (100%) | 11/12 (92%) | +8% |
| Edge fleet with argocd-agent | 10/10 (100%) | 3/10 (30%) | **+70%** |
| **Overall** | **72/74 (97%)** | **64/74 (86%)** | **+11%** |

**Key findings:**
- **argocd-agent** — biggest delta (+70%). Baseline doesn't know the project exists, can't name
  principal/agent components, doesn't recommend autonomous mode, doesn't know about mTLS
  or agent-initiated outbound connections. Skill has full reference doc.
- **Multi-tenancy** — baseline misses annotation-based resource tracking requirement for
  apps-in-any-namespace (composite names exceed 63-char label limit)
- **Core Argo CD** — no delta on well-established APIs (Applications, Rollouts, Events).
  The base model knows these well from extensive training data coverage.
- **Shared failures** — both skill and baseline struggle with git file generator Go template
  path syntax (use glob wildcard instead of `{{.name}}`) and Job-based AnalysisTemplate
  preview service references.

The skill adds most value for post-2024 features (argocd-agent, apps-in-any-namespace RBAC),
OpenShift GitOps patterns, and niche configurations not saturated in training data.
