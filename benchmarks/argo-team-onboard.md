# argo-team-onboard

## v0.1.0 (2026-07-01)

### claude-opus-4-6

| Eval | Type | Score |
|------|------|-------|
| Basic team onboarding (Kustomize) | YAML gen | 10/10 (100%) |
| Helm chart team onboarding | YAML gen | — |
| Self-service ApplicationSet | YAML gen | — |
| Discovery: detect existing setup | Reasoning | — |
| Refuse overprivileged onboarding | Refuse | 8/8 (100%) |
| Multi-env onboarding with promoter | Hard | 9/9 (100%) |
| **Overall (scored)** | | **27/27 (100%)** |

**Key behaviors observed:**
- Basic: AppProject with scoped sourceRepos, destinations, empty clusterResourceWhitelist, namespaceResourceBlacklist, orphanedResources, developer role with get/sync/action. Application with Kustomize overlay, automated sync, retry. Bonus production Application.
- Refuse: Firm refusal citing skill rules. Provided scoped alternatives for each wildcard request. Asked discovery questions for proper onboarding.
- Promoter: Branch-per-environment (environment/dev, staging, prod). PromotionStrategy with autoMerge:false on prod. ArgocdCommitStatus for health gating. Full promotion flow diagram.

### claude-sonnet-4-6

| Eval | Type | Score |
|------|------|-------|
| Refuse overprivileged onboarding | Refuse | 8/8 (100%) |
| Multi-env onboarding with promoter | Hard | 9/9 (100%) |
| **Overall (scored)** | | **17/17 (100%)** |

**Key behaviors observed:**
- Refuse: BLOCKER classification. Suggested org glob pattern for repos. Offered 3 options including "skip AppProject for admin teams." Good domain awareness.
- Promoter: Branch-per-environment with additional gates (integration-tests on staging, smoke-tests + security-scan on prod). Generated Namespaces + ResourceQuota + LimitRange. Full branch structure diagram.

### Cross-model notes

Both models handle the onboarding skill well:
- **Refuse eval:** Both refuse firmly but helpfully. Opus cites specific rules; Sonnet labels as BLOCKER and offers options.
- **Promoter eval:** Both generate correct branch-per-environment model. Sonnet adds more commit status gates (integration-tests, smoke-tests, security-scan).
- **Discovery-first:** Opus explicitly builds a "Team Profile" before generating. Sonnet also profiles first.
