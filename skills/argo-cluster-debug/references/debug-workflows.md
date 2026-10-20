<!-- Loaded on demand by skills/argo-cluster-debug/SKILL.md. Load only the workflow(s)
     matching the reported symptom; each is self-contained. -->

# Debugging Workflows

Execute the workflow that matches the user's problem. Each workflow is self-contained.
Work through the steps in order — each step builds context for the next.

---

## Workflow 1: Argo CD Installation Check

Use when: user asks if Argo CD is installed, reports general Argo CD failures, or as a prerequisite before Application debugging.

**Steps:**

1. Check for Argo CD CRDs:
   ```bash
   kubectl get crd | grep argoproj.io
   ```
   Expected CRDs: `applications.argoproj.io`, `appprojects.argoproj.io`, `applicationsets.argoproj.io`. If missing, Argo CD is not installed.

2. Identify every Argo CD instance and its namespace. **Do not rely on the
   `part-of=argocd` label alone** — Operator-managed installs (OpenShift GitOps) do not
   set it on pods, so the label selector reports nothing on a cluster running several
   instances, and this step wrongly concludes "Argo CD is not installed":

   ```bash
   # Operator-managed (OpenShift GitOps / argocd-operator): the ArgoCD CR is authoritative
   if kubectl get crd argocds.argoproj.io >/dev/null 2>&1; then
     kubectl get argocd -A --no-headers 2>/dev/null | awk '{print $1"\t"$2"\t(operator)"}'
   fi
   # Helm / plain-manifest installs do carry the label
   kubectl get pods -A -l app.kubernetes.io/part-of=argocd --no-headers 2>/dev/null \
     | awk '{print $1}' | sort -u | sed 's/$/\t-\t(helm)/'
   ```

   Set `NS` to the instance you are debugging and use it for every command below. **There
   is frequently more than one instance** — if so, confirm with the user which one before
   continuing, and note that an ArgoCD CR *named* `argocd` may live in a namespace that is
   not `argocd`.

   ```bash
   NS=<argo-cd-namespace>    # e.g. openshift-gitops, argocd, team-x-gitops
   ```

3. Check all pods in that namespace:
   ```bash
   kubectl get pods -n "$NS" -o wide
   ```
   Operator-managed components are named `<cr-name>-server`, `<cr-name>-repo-server`,
   `<cr-name>-application-controller` — not `argocd-*`. Match on suffix, not prefix.

4. Verify core components are running. All required components must be `Running` with
   `READY` containers:

   | Component | Required |
   |-----------|----------|
   | server | Yes |
   | repo-server | Yes |
   | application-controller | Yes |
   | applicationset-controller | Yes |
   | redis | Yes |
   | dex-server | Yes (when SSO is configured) |
   | notifications-controller | No (optional) |

   **The `app.kubernetes.io/name=argocd-<component>` selectors do not work on
   Operator-managed installs.** The Operator sets `app.kubernetes.io/name=<cr-name>-<component>`,
   so a hardcoded `argocd-` prefix silently matches nothing and every component looks
   absent. Enumerate instead of guessing the label:

   ```bash
   kubectl get deploy,sts -n "$NS" -o custom-columns=NAME:.metadata.name,READY:.status.readyReplicas,WANT:.spec.replicas
   ```

   Then match components by **suffix** (`-server`, `-repo-server`,
   `-application-controller`, …). To target one component's pods, read its selector off
   the workload rather than assuming a label:

   ```bash
   kubectl get deploy -n "$NS" <cr-name>-repo-server -o jsonpath='{.spec.selector.matchLabels}'
   ```

   **Note:** `notifications-controller` is not deployed in all installations. Its absence
   should not be treated as a failure. On OpenShift you will also see non-Argo-CD
   workloads in the namespace (`gitops-plugin`, `argo-rollouts`) — not components of the
   Argo CD instance itself.

5. If argocd CLI is available, check version compatibility:
   ```bash
   argocd version
   ```
   Compare client and server versions. Mismatches beyond minor version can cause issues.

6. Check the argocd-cm ConfigMap for server configuration:
   ```bash
   kubectl get configmap argocd-cm -n argocd -o yaml
   ```
   Look for: `url` (server URL), `repositories` (legacy repo config), `resource.customizations` (custom health checks), `kustomize.buildOptions`, `configManagementPlugins`.

7. Check argocd-rbac-cm for RBAC configuration:
   ```bash
   kubectl get configmap argocd-rbac-cm -n argocd -o yaml
   ```
   Look for: `policy.default`, `policy.csv`, `scopes`.

8. If any component is CrashLoopBackOff or not ready, get its logs:
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=<component-name> --tail=100 --previous
   kubectl logs -n argocd -l app.kubernetes.io/name=<component-name> --tail=100
   ```

9. Check Argo CD events:
   ```bash
   kubectl get events -n argocd --sort-by='.lastTimestamp' | tail -30
   ```

---

## Workflow 2: Application Debugging

Use when: user reports Application sync failure, health degradation, OutOfSync, or unknown status.

**Steps:**

1. Get the Application resource:
   - argocd CLI:
     ```bash
     argocd app get <name> -o yaml
     ```
   - kubectl:
     ```bash
     kubectl get applications.argoproj.io <name> -n argocd -o yaml
     ```
   If the Application is in a non-default namespace, the user must specify it or check:
   ```bash
   kubectl get applications.argoproj.io --all-namespaces | grep <name>
   ```

2. Extract and assess sync status from `.status.sync.status`:
   | Status | Meaning |
   |--------|---------|
   | Synced | Live state matches desired state |
   | OutOfSync | Live state differs from desired state |
   | Unknown | Comparison could not be performed |

3. Extract and assess health status from `.status.health.status`:
   | Status | Meaning |
   |--------|---------|
   | Healthy | All resources healthy |
   | Degraded | One or more resources failed |
   | Progressing | Resources are being rolled out |
   | Suspended | Resource is paused (e.g., suspended CronJob, paused Rollout) |
   | Missing | Resource does not exist in the cluster |
   | Unknown | Health assessment not available |

4. Check `.status.conditions` for error messages. Common conditions:
   - `ComparisonError` — manifest generation failed
   - `SyncError` — sync operation failed
   - `InvalidSpecError` — Application spec is invalid
   - `OrphanedResourceWarning` — resources exist outside the Application's management

5. Check `.status.operationState` for the last sync operation:
   - `.status.operationState.phase` — Succeeded, Failed, Error, Running
   - `.status.operationState.message` — error detail
   - `.status.operationState.syncResult.resources` — per-resource sync results

6. If OutOfSync, analyze the diff:
   - argocd CLI:
     ```bash
     argocd app diff <name>
     ```
   - kubectl: inspect `.status.resources` and compare `status` field per resource. Look for resources with `status: OutOfSync`.

7. Check the source configuration. Applications may use either `spec.source` (single-source) or `spec.sources[]` (multi-source, GA since v2.6). Check both:
   ```bash
   # Check if multi-source
   kubectl get applications.argoproj.io <name> -n argocd -o jsonpath='{.spec.sources}' 2>/dev/null | grep -q '\[' && echo "multi-source" || echo "single-source"

   # Single-source
   kubectl get applications.argoproj.io <name> -n argocd -o jsonpath='{.spec.source}' | python3 -m json.tool

   # Multi-source — iterate all sources
   kubectl get applications.argoproj.io <name> -n argocd -o jsonpath='{range .spec.sources[*]}repoURL={.repoURL} targetRevision={.targetRevision} path={.path} chart={.chart}{"\n"}{end}'
   ```
   For multi-source Applications, each source can fail independently — verify `repoURL`, `targetRevision`, `path`, and Helm `valueFiles` for every entry in `spec.sources[]`.

8. If repo-server is failing to render manifests, check repo-server logs:
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-repo-server --tail=100
   ```

9. Inspect managed resources. List resources from `.status.resources` with non-Healthy or non-Synced status:
   ```bash
   kubectl get applications.argoproj.io <name> -n argocd -o jsonpath='{range .status.resources[*]}{.kind}/{.namespace}/{.name}: sync={.status}, health={.health.status}{"\n"}{end}'
   ```

10. For each unhealthy managed resource, inspect it:
    ```bash
    kubectl get <kind> <name> -n <namespace> -o yaml
    kubectl describe <kind> <name> -n <namespace>
    kubectl get events -n <namespace> --field-selector involvedObject.name=<name>
    ```

11. If managed resource is a Deployment/StatefulSet with failing pods:
    ```bash
    kubectl get pods -n <namespace> -l <label-selector> --sort-by='.status.startTime'
    kubectl logs -n <namespace> <pod-name> --tail=100
    kubectl logs -n <namespace> <pod-name> --previous --tail=100
    ```

12. Produce a root cause analysis report (see Report Format).

---

## Workflow 3: ApplicationSet Debugging

Use when: user reports ApplicationSet not generating Applications, generating wrong Applications, or ApplicationSet errors.

**Steps:**

1. Get the ApplicationSet:
   ```bash
   kubectl get applicationset <name> -n argocd -o yaml
   ```

2. Check `.status.conditions` for errors. Key conditions:
   - `ErrorOccurred` — generator or template rendering failed
   - `ParametersGenerated` — generator output status
   - `ResourcesUpToDate` — template application status

3. Identify the generator type and check its configuration:
   | Generator | Common Issues |
   |-----------|--------------|
   | list | Empty `elements` array |
   | git (directories) | `repoURL` inaccessible, `directories` path pattern wrong |
   | git (files) | File format invalid, path pattern wrong |
   | cluster | No matching clusters, label selector wrong |
   | pull request | API credentials missing/expired, no open PRs matching filter |
   | scmProvider | API credentials missing, org/owner wrong |
   | matrix/merge | Inner generator errors, key conflicts |
   | plugin | Plugin ConfigMap missing, generator RPC error |

4. List generated Applications:
   ```bash
   kubectl get applications.argoproj.io -n argocd -l 'app.kubernetes.io/managed-by=applicationset-controller' --show-labels
   ```
   Cross-reference with expected output from the generator.

5. If no Applications generated, check the applicationset-controller logs:
   ```bash
   kubectl logs -n argocd -l app.kubernetes.io/name=argocd-applicationset-controller --tail=200
   ```

6. If some Applications are generated but failing, debug each one using Workflow 2.

7. For progressive sync issues, check `spec.strategy`:
   ```bash
   kubectl get applicationset <name> -n argocd -o jsonpath='{.spec.strategy}' | python3 -m json.tool
   ```
   Check `rollingSync.steps`, `maxUpdate` values, and whether unhealthy apps are blocking progression.

---

## Workflow 4: Rollout Debugging

Use when: user reports canary/blue-green rollout stuck, aborted, or degraded.

**Steps:**

1. Get the Rollout status:
   - kubectl-argo-rollouts:
     ```bash
     kubectl argo rollouts get rollout <name> -n <namespace>
     ```
   - kubectl:
     ```bash
     kubectl get rollout <name> -n <namespace> -o yaml
     ```

2. Check the phase from `.status.phase`:
   | Phase | Meaning |
   |-------|---------|
   | Healthy | Rollout completed successfully |
   | Paused | Waiting for manual promotion or analysis |
   | Progressing | Actively rolling out |
   | Degraded | Rollout encountered errors |
   | Aborting | Rollback in progress |
   | Aborted | Rollback completed |

3. For canary rollouts, check current step and step index:
   ```bash
   kubectl get rollout <name> -n <namespace> -o jsonpath='{.status.currentStepIndex}'
   kubectl get rollout <name> -n <namespace> -o jsonpath='{.spec.strategy.canary.steps}'
   ```
   Identify which step the rollout is paused/stuck at.

4. If paused, determine the reason:
   - `pause` step: manual approval required. Check `.status.pauseConditions`.
   - `analysis` step: AnalysisRun in progress. Proceed to step 5.
   - `setWeight` step: traffic shift issue. Proceed to step 8.

5. Get AnalysisRuns for this Rollout:
   ```bash
   kubectl get analysisrun -n <namespace> --sort-by='.metadata.creationTimestamp'
   ```
   Filter by Rollout ownership:
   ```bash
   kubectl get analysisrun -n <namespace> -o yaml | grep -A5 'ownerReferences' | grep '<rollout-name>'
   ```
   Or use the revision label:
   ```bash
   kubectl get analysisrun -n <namespace> -l rollouts-pod-template-hash=<hash>
   ```

6. Inspect the AnalysisRun:
   ```bash
   kubectl get analysisrun <analysisrun-name> -n <namespace> -o yaml
   ```
   Check:
   - `.status.phase` — Running, Successful, Failed, Error, Inconclusive
   - `.status.metricResults[*].phase` — per-metric status
   - `.status.metricResults[*].measurements` — individual measurement values
   - `.status.metricResults[*].message` — error messages from the provider

7. If analysis failed, check the AnalysisTemplate:
   ```bash
   kubectl get analysistemplate <template-name> -n <namespace> -o yaml
   ```
   Verify:
   - `successCondition` / `failureCondition` expressions
   - `provider` configuration (Prometheus URL, Datadog API key, web query, etc.)
   - `interval`, `count`, `failureLimit`, `inconclusiveLimit`

8. Check traffic management configuration:
   - Istio:
     ```bash
     kubectl get virtualservice -n <namespace> -o yaml
     kubectl get destinationrule -n <namespace> -o yaml
     ```
   - NGINX Ingress:
     ```bash
     kubectl get ingress -n <namespace> -o yaml
     ```
     Check `canary-*` annotations.
   - ALB:
     ```bash
     kubectl get ingress -n <namespace> -o yaml
     ```
     Check `alb.ingress.kubernetes.io/*` annotations.
   - Traefik:
     ```bash
     kubectl get traefikservice -n <namespace> -o yaml
     ```

9. Check ReplicaSets — compare stable vs canary:
   ```bash
   kubectl get replicaset -n <namespace> -l app=<app-label> -o wide
   ```
   The stable RS has the `rollouts-pod-template-hash` matching `.status.stableRS`, canary RS matches `.status.currentPodHash`.

10. Check pod status for the canary ReplicaSet:
    ```bash
    kubectl get pods -n <namespace> -l rollouts-pod-template-hash=<canary-hash>
    kubectl describe pods -n <namespace> -l rollouts-pod-template-hash=<canary-hash>
    ```

11. Produce a root cause analysis report.

---

## Workflow 5: Log Analysis

Use for any Argo component when logs are needed.

**Steps:**

1. Identify the Deployment managing the target pods:
   ```bash
   kubectl get deployment -n <namespace> -l <label-selector>
   ```

2. Extract the label selector and container name:
   ```bash
   kubectl get deployment <deployment-name> -n <namespace> -o jsonpath='{.spec.selector.matchLabels}' | python3 -m json.tool
   kubectl get deployment <deployment-name> -n <namespace> -o jsonpath='{.spec.template.spec.containers[*].name}'
   ```

3. List pods with matching labels:
   ```bash
   kubectl get pods -n <namespace> -l <key=value> --sort-by='.status.startTime'
   ```

4. Get logs — prefer `--tail` to limit output:
   ```bash
   kubectl logs <pod-name> -n <namespace> -c <container> --tail=200
   ```
   For previous instance (after crash):
   ```bash
   kubectl logs <pod-name> -n <namespace> -c <container> --previous --tail=200
   ```

5. Analyze logs for:
   - `level=error` or `"error"` entries
   - Stack traces
   - Connection refused / timeout patterns
   - RBAC denied messages
   - OOM or resource pressure signals
   - Repeated restart patterns (check timestamps)

---
