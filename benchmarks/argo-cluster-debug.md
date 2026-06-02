# argo-cluster-debug

## v0.0.1 (2026-06-02)

Model: `claude-opus-4-6`

**Results**

| Eval | With Skill | Baseline | Delta |
|------|-----------|----------|-------|
| Application OutOfSync + Degraded | -/12 | -/12 | - |
| Canary Rollout stuck at step 2 | -/12 | -/12 | - |
| Argo CD installation check | -/12 | -/12 | - |
| Workflow build-pipeline failing | -/10 | -/10 | - |
| EventSource not receiving events | -/10 | -/10 | - |
| **Overall** | **-/56** | **-/56** | **-** |

**Costs**

| Metric | With Skill | Baseline |
|--------|-----------|----------|
| Mean duration | - | - |
| Mean tokens | - | - |

> Run evals to populate: see `AGENTS.md` for eval runner instructions.
