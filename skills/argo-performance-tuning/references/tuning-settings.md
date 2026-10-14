# Performance & Scale Tuning Settings Reference

Source: [Tuning OpenShift GitOps for performance at scale](https://blog.stderr.at/gitopscollection/2026-03-27-openshift-gitops-performance-tuning/) (Thomas Jungbauer).
Defaults and recommendations below are indicative — always validate in your own environment and
change one setting at a time.

**Standalone Argo CD** reads `argocd-cm` / `argocd-cmd-params-cm` ConfigMaps and env vars on the
upstream Deployments/StatefulSet. **OpenShift GitOps** maps the same settings into the `ArgoCD`
custom resource (`metadata.name`/`namespace` typically `openshift-gitops`); the same `spec`
fragments work for a community **Argo CD Operator** install under `metadata.name`/`namespace`
`argocd`. Repository shallow-clone depth is always a repository `Secret`, never a CR field.

## Quick lookup table

| Setting | Default | Recommended | Standalone location | Operator (ArgoCD CR) location |
|---|---|---|---|---|
| Git shallow clone `depth` | full history | `1` | Repository `Secret` `stringData.depth` | Same — always a Secret, not the CR |
| `ARGOCD_REPO_SERVER_PARALLELISM_LIMIT` | `0` (unlimited) | `20`, then tune | env on `argocd-repo-server` or `argocd-cmd-params-cm` `reposerver.parallelism.limit` | `spec.repo.env` |
| `ARGOCD_GIT_LS_REMOTE_PARALLELISM_LIMIT` | `0` (unlimited) | `20` when Git rate-limits | env on `argocd-repo-server` | `spec.repo.env` |
| `ARGOCD_EXEC_TIMEOUT` | `90s` | `180s`+ for heavy Helm/Kustomize | env on `argocd-repo-server` | `spec.repo.env` |
| `ARGOCD_EXEC_FATAL_TIMEOUT` | `10s` | leave default unless you know why | env on `argocd-repo-server` | `spec.repo.env` |
| `ARGOCD_GIT_ATTEMPTS_COUNT` | `1` | `3`–`5` on flaky networks | env on `argocd-repo-server` | `spec.repo.env` |
| `ARGOCD_REPO_CACHE_EXPIRATION` | `24h` | keep `24h` unless you know why | env on `argocd-repo-server` | `spec.repo.env` |
| `ARGOCD_REVISION_CACHE_LOCK_TIMEOUT` | `10s` | raise (e.g. `30s`) for large charts | env on `argocd-repo-server` | `spec.repo.env` |
| `ARGOCD_SERVER_REPO_SERVER_TIMEOUT_SECONDS` | `60` | match repo render time (e.g. `180`) | env on `argocd-server` | `spec.server.env` |
| Application Controller sharding | disabled / 1 replica | enabled; algorithm + replicas | HA StatefulSet, `argocd-cmd-params-cm` `controller.sharding.algorithm`, `ARGOCD_CONTROLLER_REPLICAS`/`ARGOCD_CONTROLLER_SHARD` | `spec.controller.sharding` + `spec.controller.env` (algorithm) |
| `timeout.reconciliation` | `3m` | `600s`–`3600s` **with webhooks** | `argocd-cm` key | `spec.extraConfig` |
| `timeout.reconciliation.jitter` | `60s` | non-zero fraction of the interval | `argocd-cm` key | `spec.extraConfig` |
| `controller.status.processors` | `20` | `50`–`100` at large scale | `argocd-cmd-params-cm` | `spec.controller.processors.status` |
| `controller.operation.processors` | `10` | raise when sync queue backs up | `argocd-cmd-params-cm` | `spec.controller.processors.operation` |
| `ARGOCD_APPLICATION_CONTROLLER_REPO_SERVER_TIMEOUT_SECONDS` | `60` | `120`–`300` for slow manifest RPCs | `argocd-cmd-params-cm` `controller.repo.server.timeout.seconds` | `spec.controller.env` (**not** `extraConfig`) |
| `ARGOCD_APPLICATION_CONTROLLER_KUBECTL_PARALLELISM_LIMIT` | `20` | match or sit slightly below `operation.processors` | `argocd-cmd-params-cm` `controller.kubectl.parallelism.limit` | `spec.controller.env` |

## Repo-Server: Git shallow cloning

**Fixes:** slow fetch/clone on large or long-lived monorepos.

By default the repo-server clones full history. Set `depth` on the repository `Secret` to fetch
only the last N commits:

```yaml
kind: Secret
apiVersion: v1
metadata:
  name: repo-2960947011
  namespace: openshift-gitops
  labels:
    argocd.argoproj.io/secret-type: repository
  annotations:
    managed-by: argocd.argoproj.io
stringData:
  depth: "1"
  type: git
  url: https://github.com/org/repo.git
type: Opaque
```

For public repositories you may need to create this Secret manually — it does not exist by
default. Verify in repo-server logs: `git fetch origin <rev> --depth 1 --force --prune` should
replace a full `git fetch origin --tags --force --prune`.

## Repo-Server: env vars

Set under `spec.repo.env` on the `ArgoCD` CR (OpenShift GitOps / Argo CD Operator):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  name: openshift-gitops
  namespace: openshift-gitops
spec:
  repo:
    env:
      - name: ARGOCD_REPO_SERVER_PARALLELISM_LIMIT
        value: "20"
```

### `ARGOCD_REPO_SERVER_PARALLELISM_LIMIT` (default `0`)

**Fixes:** repo-server `OOMKilled` / crash-looping during mass manifest generation.

Unbounded concurrent `helm template`/`kustomize build` runs (e.g. a push that touches 500
Applications at once) spike CPU and memory. Setting a value > 0 (e.g. `20`) creates a worker-pool
semaphore — the rest queue instead of running concurrently. Trade-off: large bursts take a little
longer to sync, but the repo-server stays up. Start at `20` and watch memory.

### `ARGOCD_GIT_LS_REMOTE_PARALLELISM_LIMIT` (default `0`)

**Fixes:** Git provider rate-limiting / 429s / org-wide blocks when many Applications share one
repo+branch — each reconciliation runs `git ls-remote` per Application concurrently.

Set > 0 (e.g. `20`) to cap concurrent connections to the Git provider. Don't set it too low (e.g.
`2`) — that can itself cause controller-side timeouts while requests wait in queue.

### `ARGOCD_EXEC_TIMEOUT` (default `90s`)

**Fixes:** timeouts/render errors for large or slow Helm charts and Kustomize overlays.

Max time for a repo-server child process (helm/kustomize/plugin). Raise to `180s`+ for heavy
charts. Don't set excessively high — that delays failing fast on a truly hung process.

### `ARGOCD_EXEC_FATAL_TIMEOUT` (default `10s`)

**Fixes:** zombie child processes after `ARGOCD_EXEC_TIMEOUT` fires (SIGTERM ignored).

Hard SIGKILL deadline after `ARGOCD_EXEC_TIMEOUT` sends SIGTERM. Leave at default unless you have
evidence of hung processes surviving SIGTERM.

### `ARGOCD_GIT_ATTEMPTS_COUNT` (default `1`)

**Fixes:** sync/reconciliation failing outright on transient Git network blips (connection reset,
SSH handshake failures, provider throttling).

Raise to `3`–`5` for resilience. Avoid very high values (e.g. `50`) — a genuinely down provider or
expired credentials will tie up the repo-server retrying for minutes, and you'll still hit
`ARGOCD_EXEC_TIMEOUT` eventually.

## Repo-Server: caching

### `ARGOCD_REPO_CACHE_EXPIRATION` (default `24h`)

**Fixes/protects against:** redundant re-clone + re-render of unchanged commits (expensive).

TTL for cached repo state and generated manifests in Redis. `24h` is a good default for most
environments. **Do not lower this** (e.g. to `5m`) just to pick up floating tags (`latest`, `main`)
or mutable Helm chart versions sooner — that forces constant re-rendering and tanks performance.
If you need faster propagation for floating tags, use webhooks or pin versions instead.

### `ARGOCD_REVISION_CACHE_LOCK_TIMEOUT` (default `10s`)

**Fixes:** "cache stampede" — many Applications on the same commit all render independently and
spike CPU when the first renderer doesn't finish within the lock timeout.

One worker locks the cache key for a revision while rendering; others wait instead of duplicating
work. Raise (e.g. `30s`) if your slowest chart/overlay takes longer than the default to render.
Trade-off: if the first worker hangs without releasing the lock, others wait the full timeout.

### `ARGOCD_SERVER_REPO_SERVER_TIMEOUT_SECONDS` (default `60`, on `argocd-server`)

**Fixes:** UI/CLI showing `context deadline exceeded` for a complex Application even though the
repo-server is still successfully rendering it in the background.

This is the API server's client-side timeout waiting on the repo-server's manifest-generation RPC.
**Align it with `ARGOCD_EXEC_TIMEOUT`** — if the repo-server may legitimately take 180s to render a
chart but this stays at 60s, the UI fails even on success.

## Application Controller: Sharding

**Fixes:** a single controller reconciling too many Applications across too many clusters —
high CPU/memory, long reconcile queues, API-server throttling, repo-server pressure.

Only useful with **more than one registered cluster** — sharding distributes *clusters* (not
individual apps) across controller replicas; each replica only reconciles Applications whose
destination cluster maps to its shard.

**Distribution algorithms** (`ARGOCD_CONTROLLER_SHARDING_ALGORITHM` / `controller.sharding.algorithm`):

| Algorithm | Behavior |
|---|---|
| `legacy` | Stable hash from cluster ID. Simple, can be unbalanced. Default for compatibility. |
| `round-robin` | Spreads clusters more evenly. Good default when scaling out. |
| `consistent-hashing` | Can improve balance further at large scale; cluster placement reshuffles when shard count changes. **Not documented for OpenShift GitOps** — verify support against your installed operator version before relying on it in production. |

OpenShift GitOps (`ArgoCD` CR):

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ArgoCD
metadata:
  name: openshift-gitops
  namespace: openshift-gitops
spec:
  controller:
    env:
      - name: ARGOCD_CONTROLLER_SHARDING_ALGORITHM
        value: round-robin
    sharding:
      enabled: true
      replicas: 3
      minShards: 2
      maxShards: 5
```

Standalone Argo CD: run the application controller as an HA StatefulSet, set `replicas` = shard
count, set `controller.sharding.algorithm` in `argocd-cmd-params-cm`, and ensure each pod gets
`ARGOCD_CONTROLLER_REPLICAS` (total shards) and `ARGOCD_CONTROLLER_SHARD` (this pod's index).

Sharding applies **only** to the application controller — repo-server, Redis, and argocd-server
scale and are sized independently.

## Controller: ConfigMap settings (`argocd-cm` / `spec.extraConfig`)

```yaml
# Operator — merges into argocd-cm
spec:
  extraConfig:
    timeout.reconciliation: 600s
    timeout.reconciliation.jitter: 60s
```

### `timeout.reconciliation` (default `3m`)

**Fixes:** sustained baseline CPU/memory/network load from blind polling at scale (thousands of
Applications checking Git every 3 minutes even when nothing changed).

Raise to `600s`–`3600s` — but **only if Git webhooks are configured**. Without webhooks, new
commits are detected up to one full interval later; with webhooks the controller doesn't need to
poll aggressively, so a longer interval is safe. This is one of the single highest-leverage
settings when combined with webhooks.

### `timeout.reconciliation.jitter` (default `60s`)

**Fixes:** periodic load spikes when thousands of Applications' polls align to the same instant.

Random delay (0 to this max) added per-Application poll so refreshes spread out instead of
synchronizing. Keep **non-zero** — a reasonable fraction of `timeout.reconciliation`. If you raise
the base interval for performance, raise jitter proportionally too.

## Controller: command-line parameters (`argocd-cmd-params-cm` / `spec.controller.*`)

These are passed as container command-line flags by the Operator, **not** read from
`argocd-cm`/`extraConfig` — a common source of misconfiguration.

```yaml
# Operator
spec:
  controller:
    processors:
      status: 50
      operation: 25
    env:
      - name: ARGOCD_APPLICATION_CONTROLLER_REPO_SERVER_TIMEOUT_SECONDS
        value: "180"
      - name: ARGOCD_APPLICATION_CONTROLLER_KUBECTL_PARALLELISM_LIMIT
        value: "50"
```

### `controller.status.processors` (default `20`)

**Fixes:** slow drift detection / sluggish status refresh in the UI at scale.

Number of concurrent status comparisons (desired vs. live state). With 500+ Applications and only
20 processors, most queue during a mass reconciliation. Raise to `50`–`100` above ~1,000
Applications. Trade-off: more controller CPU/memory.

### `controller.operation.processors` (default `10`)

**Fixes:** mass syncs leaving many Applications `Pending`/`Waiting` while only 10 run at a time.

Number of concurrent sync/operation runs. Independent of `status.processors` — tune separately
based on refresh load vs. sync load.

### `ARGOCD_APPLICATION_CONTROLLER_REPO_SERVER_TIMEOUT_SECONDS` (default `60`)

**Fixes:** controller-side `context deadline exceeded` cancelling a legitimately slow
`GenerateManifests` RPC before the repo-server finishes.

**Must go under `spec.controller.env` on the Operator CR, not `spec.extraConfig`.** Raise (e.g.
`180`) so it's at least as long as the worst-case repo-server render time you expect. This is the
controller→repo-server gRPC client timeout — it does not replace `ARGOCD_EXEC_TIMEOUT` (child
process timeout) or `ARGOCD_REPO_SERVER_PARALLELISM_LIMIT` (concurrency cap).

### `ARGOCD_APPLICATION_CONTROLLER_KUBECTL_PARALLELISM_LIMIT` (default `20`)

**Fixes:** raising `operation.processors` without raising this just moves the bottleneck — extra
operation processors wait on a `kubectl` process slot.

Max concurrent `kubectl` child processes the controller may spawn. Raise to match or sit slightly
below `operation.processors` (e.g. `50`). Raise in steps and watch kube-apiserver request
rate/latency, etcd, and controller CPU/memory after each change — don't set it far above
`operation.processors`, extra headroom wastes memory without raising throughput.

## Common mistakes (OpenShift GitOps Operator)

1. **Putting `controller.status.processors` / `controller.operation.processors` under
   `spec.extraConfig`.** They belong under `spec.controller.processors.status` /
   `spec.controller.processors.operation` — the Operator sets these as container command-line
   flags, not ConfigMap data.
2. **Putting `ARGOCD_APPLICATION_CONTROLLER_REPO_SERVER_TIMEOUT_SECONDS` under
   `spec.extraConfig`.** It's an env var — belongs under `spec.controller.env`.
3. **Lowering `timeout.reconciliation` without webhooks**, or raising it far without webhooks —
   either hurts. Pair a longer interval with a configured Git webhook.
4. **Relying on `consistent-hashing` sharding on OpenShift GitOps** — the operator still passes
   through whatever value you set, but it isn't documented/officially supported there. Verify
   against your installed version before depending on it in production.
5. **Lowering `ARGOCD_REPO_CACHE_EXPIRATION`** to chase floating tags — use webhooks or pin
   versions instead; a short TTL forces constant re-rendering.
6. **Raising `ARGOCD_EXEC_TIMEOUT` without raising `ARGOCD_SERVER_REPO_SERVER_TIMEOUT_SECONDS` and
   `ARGOCD_APPLICATION_CONTROLLER_REPO_SERVER_TIMEOUT_SECONDS` to match.** The repo-server will
   keep working past the point the server/controller already gave up and surfaced an error.

## Tuning order of leverage

1. **Reduce unnecessary Git/render work** — shallow clone depth, sane cache TTLs, Git webhooks
   instead of blind polling.
2. **Align related timeouts** — `ARGOCD_EXEC_TIMEOUT`, controller repo-server timeout, API server
   repo-server timeout should all be consistent with the slowest chart you expect to render.
3. **Bound concurrency** — repo-server parallelism limit, `git ls-remote` parallelism limit,
   status/operation processors, kubectl parallelism.
4. **Scale out** — sharding and replicas, once the above no longer helps.

Treat tuning as evidence-led: change one major setting at a time and watch controller/repo-server
memory, reconcile duration, API rate, and Git rate-limit headers before changing the next.

## References

- [Tuning OpenShift GitOps for performance at scale](https://blog.stderr.at/gitopscollection/2026-03-27-openshift-gitops-performance-tuning/)
- Argo CD: Reconcile optimization, High availability / scaling, Repo server deployment, Command line parameters
- Red Hat OpenShift GitOps — Managing resource use, Argo CD instance / CR properties
