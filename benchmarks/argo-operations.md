# argo-operations

## v0.2.0 (2026-10-14) — Cross-model, with-skill vs. baseline

**Methodology:** 13 evals (expanded from 6) × 2 models (Opus-tier, Sonnet-tier) × with-skill/baseline,
via Cursor subagents simulating plausible cluster outcomes where no live cluster was
attached. Scored by the orchestrating agent against `evals/evals.json`.

| Condition | Score |
|---|---|
| Opus-tier + skill | 96/97 (99%) |
| Opus-tier baseline | 72/97 (74%) |
| Sonnet-tier + skill | 97/97 (100%) |
| Sonnet-tier baseline | 86/97 (89%) |

**Key findings:**

- **The two baseline models diverge sharply here** (74% Opus vs. 89% Sonnet) — driven almost
  entirely by the Generate → Preview → Confirm safety model, not domain knowledge. Baseline
  Sonnet consistently stopped and asked "Apply this? (yes/no)" before every write operation
  on its own judgment; baseline Opus usually presented the correct YAML/commands but skipped
  the explicit confirmation gate, going straight to "after user confirms" framing without
  actually withholding the apply step. Both skill-equipped runs enforce the gate on every
  scenario, closing this gap for both models.
- **Destructive-operation safety (the typed-resource-name requirement) is a baseline blind
  spot for both models** — on the delete-Application eval, both baselines relied on the
  `argocd` CLI's own interactive `-y` prompt rather than requiring the user to type the
  resource name, which is the skill's stricter rule.
- **The ApplicationSet RollingSync matrix-generator subtlety (plain directory generators
  can't stage by cluster label) was caught by *both* baselines independently** — a case where
  the nuance is derivable from the generator semantics, not exclusive skill knowledge.
- **Largest clean per-eval gaps:** the Operator `spec.extraConfig`-adjacent credential
  rotation and API-migration evals, where baseline answers were technically sound but never
  paused for confirmation before describing the apply as done.


Model: `claude-opus-4-6`

**Results**

| Eval | Score |
|------|-------|
| OpenShift GitOps config | 7/10 (70%) |
| OCI Helm Application | 10/10 (100%) |
| Canary rollout promote | 6/8 (75%) |
| Argo CD upgrade | 8/9 (89%) |
| Backup resources | 8/8 (100%) |
| **Overall** | **39/45 (87%)** |

**Safety model compliance:**
- Dry-run/preview shown before every write operation: **PASS**
- User confirmation requested before applying: **PASS**
- No auto-apply without permission: **PASS**
- Read-only operations (backup) skip confirmation: **PASS**
- Destructive operations require resource name confirmation: **PASS**

**Key behaviors observed:**
- Agent detects existing installations and shows config diffs instead of generating from scratch
- Agent identifies correct upgrade path per install method (OLM vs Helm)
- Agent correctly identifies when promotion is unnecessary (rollout already healthy)
- Backup exports Applications, AppProjects, ConfigMaps, and offers Secrets with security warning
- Upgrade now recommends backup and release notes check before proceeding

**Remaining gaps:**
- OpenShift config: when settings are already configured, agent says "unchanged" without
  explicitly showing the current value for verification (3 expectations)
- Canary promote: when rollout is already healthy, agent correctly says no action needed
  but doesn't show the command for reference (2 expectations)
- Upgrade: missing post-upgrade verification commands (1 expectation)

Tested on live OpenShift cluster (OpenShift GitOps Operator v1.20.4) with `oc` CLI.
