# argo-knowledge

## v0.2.0 (2026-10-14) — Sonnet baseline added

The only remaining untested cell for this skill's cross-model table was Sonnet's unaided
baseline. Dispatched one Sonnet-tier subagent, explicitly instructed not to read any skill
files, to answer all 8 prompts from trained knowledge alone (this skill is pure
manifest-generation/architecture-explanation — no fixture files to read, unlike
`argo-repo-audit`).

Note: the current `evals/evals.json` has slightly more granular expectations than the file used
for the original `v0.1.0` run below (88 total checks across 8 evals now vs. 86 then — eval 1
picked up 2 additional checks). The Sonnet Baseline score below is computed against the current
88-point rubric; the `v0.1.0` Opus/Sonnet-with-skill percentages were computed against the
slightly smaller original rubric, so treat the comparison as directionally accurate, not a
perfectly controlled apples-to-apples diff.

| Eval | Max | Sonnet Baseline |
|------|-----|-------------------|
| Multi-source Application | 12 | 11 (92%) |
| Merge generator + goTemplateOptions | 10 | 9 (90%) |
| Blue-green + Job AnalysisTemplate | 10 | 10 (100%) |
| Slack Block Kit + GitHub App status | 10 | 9 (90%) |
| OpenShift GitOps Operator | 12 | 12 (100%) |
| Multi-tenant apps-in-any-namespace | 12 | 9 (75%) |
| Edge fleet with argocd-agent | 10 | 10 (100%) |
| gitops-promoter setup | 12 | 7 (58%) |
| **Overall** | **88** | **77 (88%)** |

**Key findings:**
- **Edge fleet with argocd-agent (eval 7): unaided Sonnet nailed it (10/10)** — a sharp contrast
  with the historical Opus baseline's 30% on the same topic in the `v0.1.0` run below (the
  single biggest with-skill delta Opus ever showed on this skill, +70 points). This doesn't mean
  the skill has stopped mattering here; it's more likely that argocd-agent's documentation
  matured and propagated into more recent training data between the two runs, or this is
  model-specific variance. Either way, it's a real, reproducible data point: Sonnet's unaided
  recommendation correctly named the principal/agent architecture, autonomous mode, the
  mTLS outbound-only connection model, and explicitly avoided the "store cluster credentials
  centrally" anti-pattern.
- **gitops-promoter (eval 8): weakest unaided score (58%)** — consistent with the historical
  pattern (Opus baseline scored 83% here too, its second-weakest eval). Sonnet's baseline
  explicitly flagged its own uncertainty ("a considerably newer, smaller, faster-moving project
  ... real schema-drift risk") before answering — reasonable epistemic humility — but still got
  several structural details wrong: branch naming convention, placing `activeCommitStatuses` at
  the per-environment level instead of a strategy-level default, and referencing the wrong
  parent resource from `ArgocdCommitStatus`. gitops-promoter remains the one Argo-ecosystem
  project where unaided model knowledge is least reliable.
- **Multi-tenant RBAC (eval 6): missed the three-part `project/namespace/app` RBAC syntax**
  specifically introduced for Applications-in-any-namespace — used the older two-part
  `project/app` pattern instead, and reasoned (plausibly, but incorrectly for what was asked)
  that AppProject-level scoping alone was sufficient. Also didn't mention the
  annotation/annotation+label resource-tracking switch needed for long composite names — the
  same gap the `v0.1.0` run documented for Opus's baseline (its only non-100% item in that
  category: 92%).
- **Core, well-established APIs (multi-source Applications, merge generators, blue-green
  Rollouts, notifications, OpenShift Operator CRs) are all 90–100% even unaided** — consistent
  with the `v0.1.0` finding that both models already know mainstream Argo CD/Rollouts surface
  area well; the skill's marginal value concentrates in newer or more obscure projects
  (argocd-agent historically, gitops-promoter consistently) and specific schema-placement
  details (`preserveResourcesOnDeletion`'s exact nesting, three-part RBAC syntax).

---

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
