# argo-cluster-debug

## v0.0.2 (2026-06-03)

Model: `claude-opus-4-6`

**Results**

| Eval | Score | Notes |
|------|-------|-------|
| Argo CD installation check | 4/8 (50%) | Cluster auth was blocked — agent correctly diagnosed auth failure as root cause |

**Notes:**
- The 4 failures are infrastructure-gated (auth expired), not skill failures
- Agent correctly: identified CRDs, found the namespace, attempted pod listing, produced structured report
- Agent couldn't: check component health, version, ConfigMaps, events — all blocked by same auth issue
- When auth is available, expect higher scores — the skill's troubleshooting reference covers all these checks

Remaining evals (Application debug, Rollout stuck, Workflow failing, EventSource issues)
require those specific resources to exist on the cluster. Run them in environments with
deployed Argo workloads.
