# argo-repo-audit

## v0.0.2 (2026-06-03)

Model: `claude-opus-4-6`

**Results**

| Eval | Score |
|------|-------|
| App-of-apps audit | 11/11 (100%) |
| Mixed-issues audit | 12/12 (100%) |
| **Overall** | **23/23 (100%)** |

**Findings caught in mixed-issues audit:**
- Wildcard `*` in AppProject sourceRepos (Critical)
- Wildcard `*` in AppProject destinations (Critical)
- Wildcard `*/*` in clusterResourceWhitelist (Critical)
- Plain-text Secret in Git (Critical)
- Hardcoded password in Helm values (Critical)
- Missing syncPolicy on Applications (Warning)
- `targetRevision: HEAD` in production (Warning)
- Missing activeDeadlineSeconds on Workflows (Warning)
- Rollout AnalysisTemplate condition checks (Info)

Evals test outcomes (issues found, report quality) not process (which tools were used).
The skill's value is in the comprehensive checklists from `references/best-practices.md`
and `references/security-audit.md` — the model works through them against the repo files.
