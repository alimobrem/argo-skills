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
| OpenShift GitOps Operator + ArgoCD CRD | 12/12 (100%) | 12/12 (100%) | 0% |
| Multi-tenant apps-in-any-namespace | 12/12 (100%) | 11/12 (92%) | +8% |
| Edge fleet with argocd-agent | 10/10 (100%) | 3/10 (30%) | **+70%** |
| **Overall** | **72/74 (97%)** | **64/74 (86%)** | **+11%** |

**Where the skill adds value:**

- **argocd-agent** (+70%) — baseline doesn't know the project, can't name principal/agent
  components, doesn't know about autonomous mode, mTLS, or agent-initiated connections.
  This is a post-2024 project with limited training data coverage.
- **Multi-tenancy RBAC** (+8%) — baseline misses the three-part `project/namespace/app`
  RBAC syntax and the annotation-based resource tracking requirement for composite names.

**Where baseline already matches:**

Core Argo CD, Rollouts, Workflows, Events, and OpenShift GitOps are well-established
projects (2017–2021) with extensive documentation in training data. The skill matches
but doesn't exceed baseline on these topics.

**Primary skill value is not knowledge generation — it's the structured workflows:**

The `argo-repo-audit` skill (phased discovery → validation → best practices → security → report)
and `argo-cluster-debug` skill (systematic debugging workflows with fallback CLI strategies)
provide process and tooling that baseline cannot replicate without scripts and reference checklists.
These skills are evaluated by their workflow quality, not by knowledge delta.
