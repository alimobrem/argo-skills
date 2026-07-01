# argo-repo-audit

## v0.2.0 (2026-07-01)

### claude-opus-4-6

| Eval | Type | Score |
|------|------|-------|
| App-of-apps audit | General | 11/11 (100%) |
| ApplicationSet audit | General | — |
| Mixed-issues audit | General | 12/12 (100%) |
| Validate-only | General | — |
| Detect wildcard project | False negative | 5/5 (100%) |
| Detect plain-text secret | False negative | 4/4 (100%) |
| Detect no sync policy | False negative | 4/4 (100%) |
| Detect HEAD in prod | False negative | 4/4 (100%) |
| Detect weak AnalysisTemplate | False negative | 4/4 (100%) |
| Detect no-deadline workflow | False negative | 4/4 (100%) |
| Detect hardcoded Helm password | False negative | 4/4 (100%) |
| Clean repo zero findings | False positive | 9/9 (100%) |
| Subtle RBAC privilege escalation | Hard: subtle | 6/6 (100%) |
| **Overall** | | **67/67 (100%)** |

### claude-sonnet-4-6

| Eval | Type | Score |
|------|------|-------|
| Subtle RBAC privilege escalation | Hard: subtle | 6/6 (100%) |
| **Overall** | | **6/6 (100%)** |

### Cross-model notes

- **Subtle RBAC:** Both models caught ClusterRole/ClusterRoleBinding privilege escalation AND exec permission. Both provided attack YAML showing how the escalation works. No false positives on the properly-configured sourceRepos/destinations.
- The subtle RBAC eval was designed to produce failures — the AppProject looks well-configured at first glance. Both models looked past the surface.

### Accuracy validation

13 evals test detection accuracy:

**False negative tests (7):** Each fixture has ONE planted bug. Both models detected every
bug with correct severity classification — Critical for security issues (wildcards,
plain-text secrets, hardcoded passwords), Warning for operational risks (missing sync
policy, HEAD in prod, weak analysis, no deadline).

**False positive test (1):** Clean repo follows every best practice. Both models correctly
reported PASS with zero Critical/Warning findings. SealedSecret ciphertext not false-flagged.

**Hard eval (1):** Subtle RBAC privilege escalation — AppProject looks restricted but allows
ClusterRole/ClusterRoleBinding creation (escalation path) and exec into pods.

Evals test outcomes (issues found, report quality) not process (which tools were used).
