# argo-repo-audit

## v0.1.0 (2026-07-01)

Model: `claude-opus-4-6`

**Results**

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
| **Overall** | | **61/61 (100%)** |

### Accuracy validation

8 new evals test detection accuracy in isolation:

**False negative tests (7):** Each fixture has ONE planted bug. The skill detected every
bug with correct severity classification — Critical for security issues (wildcards,
plain-text secrets, hardcoded passwords), Warning for operational risks (missing sync
policy, HEAD in prod, weak analysis, no deadline).

**False positive test (1):** Clean repo follows every best practice — restricted AppProject,
pinned tags, SealedSecret, AnalysisTemplate with failureCondition+failureLimit, Istio
traffic routing. The skill correctly reported PASS with zero Critical/Warning findings.
Notably, the SealedSecret's encrypted `password:` field was correctly identified as
ciphertext, not a false positive.

### Prior results (v0.0.2)

| Eval | Score |
|------|-------|
| App-of-apps audit | 11/11 (100%) |
| Mixed-issues audit | 12/12 (100%) |
| **Overall** | **23/23 (100%)** |

Evals test outcomes (issues found, report quality) not process (which tools were used).
The skill's value is in the comprehensive checklists from `references/best-practices.md`
and `references/security-audit.md` — the model works through them against the repo files.
