---
name: argo-knowledge
description: >
  Comprehensive knowledge base for the Argo ecosystem including Argo CD, Argo Rollouts,
  Argo Workflows, and Argo Events. Use this skill when generating, reviewing, debugging,
  or explaining Argo CRDs (Application, ApplicationSet, AppProject, Rollout, AnalysisTemplate,
  Workflow, WorkflowTemplate, CronWorkflow, EventSource, Sensor, EventBus), configuring
  notifications, image updater, sync policies, progressive delivery strategies, or
  designing GitOps repository patterns. Also use when the user asks about Argo best practices,
  common mistakes, or needs to choose between Argo approaches (e.g., app-of-apps vs
  ApplicationSet, canary vs blue-green, steps vs DAG workflows).
license: MIT
---

# Argo Knowledge Base

## Rules

1. **Always use correct apiVersion and kind.** Most Argo CRDs use `apiVersion: argoproj.io/v1alpha1` — see the CRD Table below — but **not all of them**, and assuming otherwise produces a manifest the API server rejects. The exceptions:
   - **`argoproj.io/v1beta1`** — the OpenShift GitOps / Argo CD Operator `ArgoCD` CR (`references/openshift.md`). `v1alpha1` is deprecated for this kind.
   - **`promoter.argoproj.io/v1alpha1`** — all GitOps Promoter kinds: `PromotionStrategy`, `GitRepository`, `ScmProvider`, `ArgocdCommitStatus` (`references/gitops-promoter.md`). Note the different API *group*, not just version.

   Never invent CRDs or apiVersions that do not exist. When in doubt, check the reference file for that topic rather than defaulting to `argoproj.io/v1alpha1`.
2. **Load references on-demand.** Only read reference files when the user's question requires detailed field-level knowledge. Do not preload all references.
3. **Max 1-2 topic reference files per question** (`references/patterns.md` does not count toward that budget — load it whenever a manifest is requested). Keep context focused. If a question spans more than two reference areas, answer the primary question first and offer to elaborate.
4. **Validate YAML before presenting.** Every YAML example must be syntactically valid and use real field names from the Argo CRD schemas.
5. **Prefer canonical patterns.** When the user needs a manifest, load `references/patterns.md` and start from the matching numbered pattern. Adapt it to the user's specifics rather than writing YAML from memory or inventing from scratch.
6. **State trade-offs.** When recommending an approach, briefly note what you give up.

## What is Argo

The Argo project is a set of Kubernetes-native tools for running and managing jobs and applications on Kubernetes.

- **Argo CD** — Declarative GitOps continuous delivery. Watches Git repos and syncs Kubernetes resources to match the desired state. Supports Helm, Kustomize, plain YAML, Jsonnet, and plugin-based config management tools. Provides a UI, CLI, and API for managing applications across multiple clusters.

- **Argo Rollouts** — Progressive delivery controller. Extends Kubernetes Deployments with canary releases, blue-green deployments, experimentation, and automated analysis-driven promotion/rollback. Integrates with service meshes and ingress controllers for traffic management.

- **Argo Workflows** — Container-native workflow engine for Kubernetes. Runs DAG and step-based workflows where each step is a container. Used for CI/CD pipelines, data processing, ML pipelines, and infrastructure automation.

- **Argo Events** — Event-driven workflow automation. Connects external event sources (webhooks, message queues, cloud events, cron schedules) to triggers that create Argo Workflows or any Kubernetes resource.

**How they relate:** Argo CD deploys your applications via GitOps. Argo Rollouts handles the progressive delivery strategy during those deployments. Argo Workflows orchestrates complex multi-step jobs. Argo Events wires external events to trigger Workflows or other actions. Together they form a complete GitOps + progressive delivery + automation platform.

## CRD Table

| Kind | apiVersion | Project | Purpose |
|------|-----------|---------|---------|
| Application | argoproj.io/v1alpha1 | Argo CD | Defines a single application to sync from Git to a cluster |
| AppProject | argoproj.io/v1alpha1 | Argo CD | RBAC boundary: restricts sources, destinations, and resources |
| ApplicationSet | argoproj.io/v1alpha1 | Argo CD | Generates multiple Applications from templates + generators |
| Rollout | argoproj.io/v1alpha1 | Rollouts | Progressive delivery replacement for Deployment |
| AnalysisTemplate | argoproj.io/v1alpha1 | Rollouts | Defines metric queries for automated rollout analysis |
| ClusterAnalysisTemplate | argoproj.io/v1alpha1 | Rollouts | Cluster-scoped AnalysisTemplate |
| AnalysisRun | argoproj.io/v1alpha1 | Rollouts | Instance of an AnalysisTemplate execution (auto-created) |
| Experiment | argoproj.io/v1alpha1 | Rollouts | Runs multiple ReplicaSet versions simultaneously for comparison |
| Workflow | argoproj.io/v1alpha1 | Workflows | A single workflow execution |
| WorkflowTemplate | argoproj.io/v1alpha1 | Workflows | Reusable workflow definition (namespace-scoped) |
| ClusterWorkflowTemplate | argoproj.io/v1alpha1 | Workflows | Reusable workflow definition (cluster-scoped) |
| CronWorkflow | argoproj.io/v1alpha1 | Workflows | Scheduled workflow execution |
| EventSource | argoproj.io/v1alpha1 | Events | Defines external event sources to consume |
| EventBus | argoproj.io/v1alpha1 | Events | Message transport layer between EventSources and Sensors |
| Sensor | argoproj.io/v1alpha1 | Events | Listens to EventBus, applies filters, fires triggers |
| ArgoCD | **argoproj.io/v1beta1** | OpenShift GitOps / Argo CD Operator | Operator-managed Argo CD instance (`v1alpha1` is deprecated for this kind) |
| PromotionStrategy | **promoter.argoproj.io/v1alpha1** | GitOps Promoter | Environment promotion across branches with gating |
| GitRepository | **promoter.argoproj.io/v1alpha1** | GitOps Promoter | Git repo reference for the promoter |
| ScmProvider | **promoter.argoproj.io/v1alpha1** | GitOps Promoter | SCM credentials/endpoint used by the promoter |
| ArgocdCommitStatus | **promoter.argoproj.io/v1alpha1** | GitOps Promoter | Surfaces Argo CD health/sync as a promotion gate |

## How Argo CD Works

### Sync Loop

1. **Desired state:** Argo CD reads manifests from a Git repo (source). The source can be Helm charts, Kustomize overlays, plain YAML directories, Jsonnet, or custom config management plugins.
2. **Live state:** Argo CD queries the target Kubernetes cluster (destination) for the current state of resources it manages.
3. **Diff:** Argo CD compares desired vs live state. Resources that differ are marked `OutOfSync`.
4. **Sync:** When triggered (manually or via automated sync policy), Argo CD applies the desired state to the cluster using `kubectl apply`, server-side apply, or `kubectl create/replace` depending on sync options.
5. **Health assessment:** After sync, Argo CD evaluates resource health using built-in health checks (Deployments, StatefulSets, Services, Ingresses, etc.) and custom health checks (Lua scripts in `argocd-cm`). Resources are marked Healthy, Progressing, Degraded, Suspended, or Missing.

### Resource Tracking

Argo CD tracks which resources belong to an Application using one of three methods:

- **`label`** — Adds `app.kubernetes.io/instance: <app-name>` label. Simple but can conflict with other tools using this label.
- **`annotation`** — Adds `argocd.argoproj.io/tracking-id` annotation. Avoids label conflicts. Default in modern Argo CD.
- **`annotation+label`** — Uses both. Maximum compatibility.

Configured via `resource.trackingMethod` in `argocd-cm` ConfigMap.

### Multi-Cluster

Argo CD manages applications across multiple clusters from a single control plane:

- The cluster running Argo CD is the **in-cluster** target (referenced as `https://kubernetes.default.svc`).
- External clusters are added via `argocd cluster add <context-name>`, which creates a ServiceAccount + ClusterRoleBinding on the target cluster and stores credentials as a Secret in the Argo CD namespace.
- Cluster Secrets have label `argocd.argoproj.io/secret-type: cluster` and contain `server`, `name`, `config` (with `bearerToken`, `tlsClientConfig`).

## Decision Trees

### Application vs ApplicationSet

Use **Application** when:
- You have a single application or a small, fixed number of applications
- Each application has unique configuration that doesn't follow a pattern
- You want direct, explicit control over each application

Use **ApplicationSet** when:
- You need to generate many Applications from a pattern (e.g., per-directory, per-cluster, per-team)
- Applications share a common template with parameterized differences
- You want Applications auto-created/deleted when directories or clusters appear/disappear
- You need progressive rollout across environments (rollingSync)

### Rollout vs Deployment

Use **Deployment** when:
- You want simple rolling updates
- You don't need traffic shaping, analysis, or manual promotion gates
- The application is non-critical or internal-only

Use **Rollout** when:
- You need canary or blue-green deployment strategies
- You want automated analysis (metrics-based promotion/rollback)
- You need traffic percentage control via service mesh or ingress
- You need manual approval gates between rollout steps
- You want experiment-based A/B testing

### Which ApplicationSet Generator

- **Git directory** — One Application per directory in a monorepo. Best for: environments or services organized as directories.
- **Git file** — One Application per JSON/YAML config file in a repo. Best for: externalized app configs with arbitrary fields.
- **List** — Explicitly enumerated Applications. Best for: small, fixed sets with no dynamic discovery.
- **Cluster** — One Application per registered Argo CD cluster. Best for: deploying the same app to all clusters matching a selector.
- **Matrix** — Cartesian product of two generators. Best for: deploy N apps to M clusters.
- **Merge** — Combine generator outputs, overriding fields from a secondary generator. Best for: cluster-specific overrides on top of a base config.
- **Pull request** — One Application per open PR. Best for: PR preview environments.
- **SCM provider** — One Application per repo in a GitHub org or GitLab group. Best for: auto-onboarding repos.
## Canonical YAML Patterns

Ten validated starting points live in `references/patterns.md`. **Load that file when the
user needs a manifest** — do not reproduce these from memory.

| # | Pattern | Use when |
|---|---------|----------|
| 1 | Application with Helm source | Deploying a chart from a Helm or OCI registry |
| 2 | Application with Kustomize source | Deploying an overlay directory from Git |
| 3 | ApplicationSet with git directory generator | One Application per directory in a monorepo |
| 4 | ApplicationSet with cluster generator + matrix | N apps across M registered clusters |
| 5 | Rollout with canary + AnalysisTemplate | Metric-gated progressive delivery |
| 6 | Rollout with blue-green strategy | Preview/active cutover with promotion gates |
| 7 | Workflow DAG pattern | Multi-step CI/CD or data pipelines |
| 8 | EventSource + Sensor triggering a Workflow | Event-driven automation from webhooks |
| 9 | Notifications config (`argocd-notifications-cm`) | Slack/email alerts on sync or health events |
| 10 | Image updater annotations | Automated image bumps written back to Git |

## Common Mistakes

1. **Missing `namespace: argocd` on Application metadata.** Applications must live in the Argo CD namespace (or a namespace explicitly allowed via `--application-namespaces`). Omitting this causes Argo CD to never see the Application.

2. **Using `helm.values` (string) instead of `helm.valuesObject` (map).** `helm.values` is a multiline YAML string which is error-prone. `helm.valuesObject` is a structured map and should be preferred.

3. **Setting `automated.prune: true` without understanding consequences.** This deletes resources from the cluster that are no longer in Git. If you accidentally remove a manifest from Git, prune will delete the live resource. Use `prune: false` until you trust the workflow, or use `preserveResourcesOnDeletion` on ApplicationSets.

4. **Forgetting `CreateNamespace=true` sync option.** Argo CD does not create namespaces by default. Without this option, syncing to a non-existent namespace fails.

5. **Using `targetRevision: HEAD` in production.** This follows the default branch and makes deployments unpredictable. Pin to a specific tag, commit SHA, or semver range.

6. **Rollout without matching Services.** Canary and blue-green strategies require correctly configured `stableService` and `canaryService`/`previewService`. Forgetting these Services causes traffic routing failures.

7. **AnalysisTemplate with no `count` or `interval`.** Without these, the analysis runs once and completes immediately, which is rarely useful. Set `count` and `interval` for continuous monitoring during rollout.

8. **ApplicationSet with `goTemplate: true` but using `{{name}}` syntax.** Go templates use `{{.name}}`, not `{{name}}` (which is fasttemplate syntax). Mixing them produces empty strings silently.

9. **EventSource and Sensor in different namespaces without cross-namespace EventBus config.** They must reference the same EventBus. By default, they look for an EventBus named `default` in their own namespace.

10. **Workflow `activeDeadlineSeconds` not set.** Without a deadline, stuck workflows run forever, consuming cluster resources. Always set a reasonable deadline.

11. **Notification trigger `when` expression referencing wrong fields.** Common mistake: `app.status.sync.status` vs `app.status.operationState.phase`. Sync status is Synced/OutOfSync. Operation phase is Succeeded/Failed/Error/Running.

12. **Image updater `write-back-method: git` without write access.** The image updater needs push access to the Git repo. Without it, updates silently fail. Check the image updater logs.

## Reference Index

| Topic | Reference File | When to Load |
|-------|---------------|-------------|
| 10 canonical YAML patterns (Application, ApplicationSet, Rollout, Workflow, Events, notifications, image updater) | `references/patterns.md` | **Any request to generate or review a manifest** |
| Application spec, sync policies, sync waves, health checks, ignore differences, multi-cluster | `references/applications.md` | Questions about Application configuration, sync behavior, health, or multi-cluster |
| ApplicationSet generators, templates, progressive syncs | `references/applicationsets.md` | Questions about ApplicationSet generators, templating, or progressive rollout |
| AppProject RBAC, source/destination restrictions, sync windows | `references/app-projects.md` | Questions about RBAC, project policies, sync windows |
| Rollout canary/blue-green, traffic management, AnalysisTemplate, experiments | `references/rollouts.md` | Questions about progressive delivery, canary/blue-green, analysis metrics |
| Workflow DAG/steps, parameters, artifacts, CronWorkflow | `references/workflows.md` | Questions about workflow orchestration, scheduling, parameters |
| EventSource types, EventBus, Sensor triggers, filters | `references/events.md` | Questions about event-driven automation |
| Notification services, templates, triggers, subscriptions | `references/notifications.md` | Questions about alerting and notifications |
| Image updater annotations, strategies, write-back | `references/image-updater.md` | Questions about automated image updates |
| App-of-apps, monorepo, multi-repo patterns | `references/repo-patterns.md` | Questions about repository structure and GitOps patterns |
| Sync policy, RBAC, health checks, secret management | `references/best-practices.md` | General architecture and operational best practices |
| Agent mode, principal/agent architecture, managed/autonomous modes, hub-and-spoke | `references/agent-mode.md` | Questions about argocd-agent, multi-cluster at scale, air-gapped, edge deployments |
| Applications in any namespace, multi-instance, multi-tenancy, Autopilot | `references/multi-tenancy.md` | Questions about multi-tenancy, team isolation, --application-namespaces, Autopilot bootstrap |
| OpenShift GitOps Operator, ArgoCD CRD, Routes, SCCs, OAuth, managed namespaces | `references/openshift.md` | Questions about running Argo on OpenShift, operator-managed instances, OpenShift-specific patterns |
| GitOps Promoter, PromotionStrategy, environment promotion, commit status gating | `references/gitops-promoter.md` | Questions about environment promotion, PR-based gating, branch-per-environment, gitops-promoter CRDs |
