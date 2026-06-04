# argo-knowledge

## v0.1.0 (2026-06-04)

### claude-opus-4-6

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Multi-source Application | 10/10 (100%) | 10/10 (100%) | 0% |
| Merge generator + goTemplateOptions | 9/10 (90%) | 9/10 (90%) | 0% |
| Blue-green + Job AnalysisTemplate | 9/10 (90%) | 9/10 (90%) | 0% |
| Slack Block Kit + GitHub App status | 10/10 (100%) | 10/10 (100%) | 0% |
| OpenShift GitOps Operator | 12/12 (100%) | 12/12 (100%) | 0% |
| Multi-tenant apps-in-any-namespace | 12/12 (100%) | 11/12 (92%) | +8% |
| Edge fleet with argocd-agent | 10/10 (100%) | 3/10 (30%) | **+70%** |
| gitops-promoter setup | 12/12 (100%) | 10/12 (83%) | **+17%** |
| **Overall** | **84/86 (98%)** | **74/86 (86%)** | **+12%** |

### claude-sonnet-4-6

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Multi-source Application | 10/10 (100%) | 10/10 (100%) | 0% |
| Merge generator + goTemplateOptions | 9/10 (90%) | 10/10 (100%) | -10% |
| Blue-green + Job AnalysisTemplate | 10/10 (100%) | ~10/10 (100%) | 0% |
| Slack Block Kit + GitHub App status | 10/10 (100%) | — | — |
| OpenShift GitOps Operator | 9/10 (90%) | — | — |
| Multi-tenant apps-in-any-namespace | 10/12 (83%) | — | — |
| Edge fleet with argocd-agent | 10/10 (100%) | — | — |
| gitops-promoter setup | 11/11 (100%) | — | — |
| **Overall** | **79/83 (95%)** | — | — |

### Cross-Model Summary

| Model | With Skill | Baseline | Delta |
|-------|-----------|----------|-------|
| Opus 4.6 | 98% | 86% | +12% |
| Sonnet 4.6 | 95% | — | — |

**Key findings:**
- **Sonnet performs nearly as well as Opus with the skill loaded** (95% vs 98%) — the skill
  compensates for model capability differences
- **argocd-agent** — biggest delta on Opus (+70%). Baseline doesn't know the project.
- **gitops-promoter** — +17% on Opus. Baseline gets structure right but misses field-level
  details (wrong commit status key name, wrong reference type on ArgocdCommitStatus)
- **Multi-tenancy** — +8% on Opus. Baseline misses three-part RBAC syntax and annotation tracking.
- **Core Argo CD** — no delta on well-established APIs. Both models know these well.
- **Sonnet with skill matches or beats Opus baseline** on newer features — the skill
  effectively upgrades Sonnet to Opus-level accuracy for Argo-specific tasks.
