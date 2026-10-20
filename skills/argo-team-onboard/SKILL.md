---
name: argo-team-onboard
description: >
  Onboard app teams onto Argo CD with discovery-first workflows. Generates
  AppProject, Application, and RBAC configuration tailored to the team's
  existing stack (Helm, Kustomize, or plain YAML). Supports manual single-team
  onboarding and self-service scaling via ApplicationSet + teams.yaml.
  Does NOT generate CI pipelines, registry config, or secrets backends —
  focuses on Argo CD resources only. Use when users ask about onboarding
  teams, adding tenants, setting up new teams, bootstrapping first apps,
  or self-service onboarding patterns.
license: MIT
compatibility: Requires kubectl; optionally argocd CLI
---

# Argo Team Onboard

Onboard application teams onto Argo CD with discovery-first workflows.

This is a **write** skill focused on multi-tenancy setup. It generates AppProjects,
Applications, and RBAC resources tailored to each team's existing stack. The read-only
skills (`argo-knowledge`, `argo-repo-audit`, `argo-cluster-debug`) answer questions,
audit repos, and diagnose problems without changes. This skill **acts**.

**Scope boundary:** This skill generates Argo CD resources only — AppProject, Application,
ApplicationSet, RBAC ConfigMap entries, and optionally Namespace/ResourceQuota/LimitRange.
It does NOT generate CI pipelines, container registry configuration, or secrets backend
setup. It references how to wire those in but delegates the actual config to the
appropriate tools.

## Rules

1. **Always discover before generating.** Never assume the team's stack. Ask what CI
   system, container registry, source type (Helm/Kustomize/directory), and secrets
   management they use. The discovery phase is non-negotiable — skipping it produces
   generic output that will need rework.

2. **AppProject is the security boundary — get it right.** Scope `sourceRepos` to exact
   repo URLs, `destinations` to exact namespace/cluster pairs, and `clusterResourceWhitelist`
   to only what the team needs. Never use wildcards (`*`). This is the single most
   important resource in the onboarding output.

3. **Generate only Argo CD resources.** Do not generate CI pipelines, registry setup, or
   secrets backend config. When the team's answers reveal they need those, reference how
   to wire them into the Argo CD config (e.g., "add your registry credentials as an
   `argocd-image-updater` annotation") but do not create the external resource itself.

4. **Use the team's existing source type.** If they use Helm, generate a Helm Application.
   If Kustomize, Kustomize. If plain YAML, directory. Do not convert between source types
   unless the user explicitly asks.

5. **Redirect non-Argo questions.** CI/pipeline questions go to `argo-knowledge` or
   platform-skills. Secrets backend setup goes to the relevant tool's docs. Cluster setup
   questions go to `argo-operations`. Be explicit about the redirect.

6. **Follow the safety model.** Generate -> preview (dry-run) -> confirm for all write
   operations. Read-only discovery operations do not need confirmation.

## Safety Model

**Every write operation follows a 3-step protocol: Generate, Preview, Confirm.**

**Read-only operations** (cluster detection, namespace listing, version queries, RBAC
checks) do NOT require confirmation — just execute them and report results. The safety
model applies only to operations that modify cluster or repo state.

### Step 1: Generate

Produce the YAML manifests for the requested onboarding resources. Show them to the
user in fenced code blocks, grouped by resource type. Do not execute anything yet.

### Step 2: Preview

Show what the operation would change on the cluster before applying:

| Operation | Preview Command |
|-----------|----------------|
| Create AppProject | `kubectl apply --dry-run=server -f appproject.yaml -o yaml` |
| Create Application | `kubectl apply --dry-run=server -f application.yaml -o yaml` |
| Create Namespace/Quota | `kubectl apply --dry-run=server -f namespace.yaml -o yaml` |
| Update RBAC ConfigMap | `kubectl diff -f argocd-rbac-cm.yaml` |
| Update existing AppProject | `kubectl diff -f appproject.yaml` |

Show the preview output to the user. Explain what will change in plain language.

### Step 3: Confirm

Ask the user explicitly: **"Apply this? (yes/no)"**

Do not proceed without an affirmative response. Acceptable confirmations: "yes", "y",
"apply", "do it", "go ahead", "ship it". Anything else is a no.

### Safety Rules

1. **NEVER apply without showing the user what will change first.**
2. **NEVER use wildcards in AppProject sourceRepos or destinations.** This is the
   entire point of scoped onboarding.
3. **NEVER modify an existing AppProject without showing the diff first.** If a project
   with the same name exists, show the current state and the proposed changes.
4. **NEVER create cluster-admin-equivalent RBAC.** Team roles should be scoped to their
   project's resources.
5. **Log every applied change.** After each successful apply, report:
   `[APPLIED] <timestamp> <kind>/<namespace>/<name> -- <action>`
6. **If a command fails, show the error and suggest recovery.** Do not retry automatically.

## Prerequisites

Before any onboarding operation, check the environment:

```bash
# Required
command -v kubectl >/dev/null && echo "kubectl: $(kubectl version --client -o json 2>/dev/null | grep gitVersion)" || echo "kubectl: MISSING"

# Optional — enhances capabilities
command -v argocd >/dev/null && echo "argocd: $(argocd version --client -o json 2>/dev/null | grep Version)" || echo "argocd: not installed"

# Cluster context
kubectl config current-context
kubectl cluster-info --request-timeout=5s 2>/dev/null || echo "WARN: cluster not reachable"
```

Then verify Argo CD is installed:

```bash
# Check for Argo CD
kubectl get crd applications.argoproj.io 2>/dev/null && echo "Argo CD CRDs: installed" || echo "Argo CD CRDs: NOT FOUND"

# Find Argo CD namespace
kubectl get pods -A -l app.kubernetes.io/part-of=argocd --no-headers 2>/dev/null | awk '{print $1}' | sort -u

# Check for OpenShift GitOps operator
kubectl get crd argocds.argoproj.io 2>/dev/null && echo "OpenShift GitOps: installed" || echo "OpenShift GitOps: not detected"

# Argo CD version
kubectl get pods -n argocd -l app.kubernetes.io/name=argocd-server -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null || \
  kubectl get pods -n openshift-gitops -l app.kubernetes.io/name=openshift-gitops-server -o jsonpath='{.items[0].spec.containers[0].image}' 2>/dev/null
```

If Argo CD is not installed, stop and redirect to `argo-operations` for setup.

## Workflow Phases

### How to Route Requests

| User says | Phase | Reference |
|-----------|-------|-----------|
| "Onboard team X" / "Add a new team" | Phase 1 + 2 | `references/onboarding-guide.md` |
| "Set up self-service onboarding" | Phase 3 | `references/self-service-pattern.md` |
| "Bootstrap first app for team" | Phase 1 + 2 | `references/onboarding-guide.md` + `references/onboarding-variants.md` |
| "Generate AppProject for team" | Phase 2 (skip discovery if info given) | `references/onboarding-guide.md` |
| "Scale onboarding to many teams" | Phase 3 | `references/self-service-pattern.md` |
| "Install Argo CD" | Redirect to `argo-operations` | -- |
| "How do AppProjects work?" | Redirect to `argo-knowledge` | -- |
| "Set up CI pipeline" | Redirect: out of scope | -- |
| "Set up secrets management" | Redirect: out of scope | -- |

Load the matching reference file before starting. Max 1-2 reference files per request.

---

### Phase 1: Discovery

**This phase is mandatory.** Do not skip it even if the user provides partial information.

#### Step 1: Cluster Check

Run read-only checks (no confirmation needed):

```bash
# Platform detection
kubectl api-resources --api-group=route.openshift.io 2>/dev/null && echo "Platform: OpenShift" || echo "Platform: Kubernetes"

# Argo CD installation
kubectl get pods -A -l app.kubernetes.io/part-of=argocd --no-headers 2>/dev/null

# Existing AppProjects (to avoid conflicts)
kubectl get appprojects -A --no-headers 2>/dev/null

# Existing namespaces (to check if team namespaces exist)
kubectl get namespaces --no-headers 2>/dev/null | awk '{print $1}'
```

If Argo CD is not installed, stop: "Argo CD is not installed on this cluster.
Use `argo-operations` to set it up first."

#### Step 2: Team Profile Questions

Ask the user about the team. Do not assume answers. If the user provides all info
up front, acknowledge and confirm rather than re-asking.

**Required:**
- Team name (used for AppProject name, namespace prefix, RBAC group)
- Git repository URL(s) for the team's application manifests
- Target namespace(s) and cluster(s)
- SSO group name for RBAC binding (e.g., LDAP group, OIDC claim)

**Required — Source Type:**
- What source type does the team use? (Helm / Kustomize / plain YAML directory)
- If Helm: chart repo URL or OCI registry? In-repo chart or remote?
- If Kustomize: base + overlays structure?

**Optional (ask if relevant, don't interrogate):**
- Environments (dev/staging/prod) — affects whether to generate multiple Applications
- CI system (GitHub Actions, GitLab CI, Tekton, Jenkins) — noted but NOT generated
- Container registry — noted but NOT generated
- Secrets management (Sealed Secrets, ESO, Vault) — noted but NOT generated
- Need progressive delivery? (Rollouts) — generates scaffold if yes
- Notification preferences (Slack, email) — generates annotations if yes

#### Step 3: Build Team Profile

Summarize the gathered information as a profile block:

```yaml
# Team Profile
team: frontend
sso_group: team-frontend
source_type: helm
repos:
  - https://github.com/org/frontend-app.git
namespaces:
  - frontend-dev
  - frontend-staging
  - frontend-prod
cluster: in-cluster
environments: [dev, staging, prod]
notes:
  ci: github-actions  # not generated, for reference
  registry: ghcr.io   # not generated, for reference
  secrets: sealed-secrets  # not generated, for reference
```

Show this profile to the user and confirm before proceeding to generation.

---

### Phase 2: Generate

Generate Argo CD resources from the team profile, grouped by resource type.

**`references/onboarding-guide.md` holds the authoritative templates — load it and
fill in the team profile. Do not write these manifests from memory.** This section
covers *what* to generate and the decisions behind it; the guide has the YAML.

#### Always Generated

| # | Resource | Template section in `onboarding-guide.md` |
|---|----------|-------------------------------------------|
| 1 | AppProject — the security boundary, the most important resource | *AppProject Template* |
| 2 | Application — one per environment, matching the team's source type | *Application Templates* (Kustomize / Helm / Multi-Source Helm / Directory) |
| 3 | RBAC — `argocd-rbac-cm` entry binding the team's SSO group to the project role | *RBAC Template* |

**AppProject constraints** — these are what make onboarding safe:
- `sourceRepos`: exact URLs, never `*`
- `destinations`: exact namespace/server pairs, never `*`
- `clusterResourceWhitelist`: empty by default; add only the specific CRD groups the team needs
- `namespaceResourceBlacklist`: block ResourceQuota, LimitRange, and NetworkPolicy — the
  platform team owns those
- `orphanedResources.warn: true`: always enable drift detection
- `roles`: scoped to this project's Applications only

**Application decisions:**
- `CreateNamespace=false` by default — the platform team manages namespaces
- `automated.selfHeal: true` + `prune: true` for non-production environments
- For production: consider manual sync, or add `syncWindows` for change control
- Always include `retry` with backoff
- `targetRevision`: environment-specific branches or tags, never `HEAD`

**RBAC is a patch, not a replacement.** Read the live ConfigMap first and show the user
the existing content alongside the lines being added:

```bash
kubectl get cm argocd-rbac-cm -n <argocd-namespace> -o yaml
```

#### Conditionally Generated

Generate these only when discovery indicates they are needed:

| Resource | When to Generate | Template section |
|----------|-----------------|------------------|
| Namespace + ResourceQuota + LimitRange | Team namespaces do not exist yet | *Conditional Resources* |
| RoleBinding | Team needs `kubectl` access beyond the Argo CD UI | *RoleBinding (kubectl Access)* |
| Notification annotations | Team requested Slack/email notifications | *Notification Subscriptions* |
| Rollout scaffold | Team wants progressive delivery | `references/onboarding-variants.md` |
| SyncWindow | Production environment needs change control | *Sync Windows* |

The guide's ResourceQuota tiers are reasonable defaults, not universal — ask the user to
confirm or adjust the values for their team.

---

### Phase 3: Self-Service (if requested)

Use when the platform team wants to scale onboarding beyond manual generation: teams
submit a PR adding their own config, and an ApplicationSet generates their resources.

**Load `references/self-service-pattern.md` — it holds the authoritative `teams.yaml`
schema, both ApplicationSet approaches, and the PR workflow. Do not improvise the file
schema or the generator; the two must agree or the ApplicationSet fails to render.**

Two approaches, both in the reference:

| Approach | Use when |
|----------|----------|
| Per-team AppProject + Applications via git **file** generator (recommended) | One `teams/<name>/config.yaml` per team; platform team reviews each PR |
| Kustomize overlay with an immutable platform base | Platform team needs to enforce non-negotiable settings teams cannot override |

**Schema and generator must match.** The recommended pattern uses one file per team at
`teams/*/config.yaml`, each with a top-level `team:` key, which is what makes
`{{ .team.name }}` resolve. A single central file containing a `teams:` *array* is a
different shape and will not populate those template variables — with
`goTemplateOptions: [missingkey=error]` set, it fails loudly rather than silently.

#### Onboarding Workflow

1. New team forks the GitOps config repo
2. Adds their `teams/<team-name>/config.yaml`
3. Opens a PR — platform team reviews AppProject scope and quotas
4. PR merges — ApplicationSet auto-generates all resources
5. Team's Applications appear in Argo CD within the sync interval

See *Guard Rails: Platform vs Team* in the reference for what teams may and may not
change, and *PR Validation Script* for automated scope checks on incoming PRs.

---

### Phase 4: Validate

After applying resources, verify the onboarding was successful.

```bash
# Verify AppProject was created with correct restrictions
kubectl get appproject <team-name> -n <argocd-namespace> -o yaml

# Verify Application syncs successfully
argocd app get <team-app-name> 2>/dev/null || \
  kubectl get application <team-app-name> -n <argocd-namespace> -o jsonpath='sync={.status.sync.status} health={.status.health.status}'

# Verify RBAC — team member can see their apps
argocd account can-i get applications '<team-name>/*' --auth-token <token> 2>/dev/null

# Verify RBAC — team member CANNOT see other projects
argocd account can-i get applications 'other-project/*' --auth-token <token> 2>/dev/null

# Verify namespace-level access
kubectl auth can-i create deployments -n <team-ns> --as=<user> 2>/dev/null

# Verify AppProject restrictions hold
kubectl auth can-i create resourcequotas -n <team-ns> --as=<user> 2>/dev/null  # should be "no"
```

Report results as a checklist:

```
Onboarding Validation:
  [PASS] AppProject <name> created with scoped sourceRepos
  [PASS] AppProject <name> has orphanedResources.warn enabled
  [PASS] Application <name> synced successfully (Synced/Healthy)
  [PASS] RBAC: team can access their project
  [PASS] RBAC: team cannot access other projects
  [FAIL] Namespace <name> ResourceQuota not yet applied
```

## CRD Reference

Only AppProject, Application, and ApplicationSet are directly generated by this skill.
Cross-reference `argo-knowledge` for full CRD documentation.

| Kind | apiVersion | Purpose in Onboarding |
|------|-----------|----------------------|
| AppProject | argoproj.io/v1alpha1 | Security boundary — scopes repos, destinations, RBAC |
| Application | argoproj.io/v1alpha1 | Deploys the team's app from Git to cluster |
| ApplicationSet | argoproj.io/v1alpha1 | Self-service: generates Applications from teams.yaml |

## Common Mistakes

1. **Wildcard AppProject.** `sourceRepos: ['*']` or `destinations: [{namespace: '*'}]`
   defeats the entire purpose of multi-tenant onboarding. Every team gets access to
   every repo and namespace. Always use exact values.

2. **Missing namespaceResourceBlacklist.** Without it, teams can create their own
   ResourceQuotas, LimitRanges, and NetworkPolicies — overriding platform constraints.
   Always blacklist resources the platform team owns.

3. **Missing orphanedResources.warn.** Without orphan detection, resources manually
   created in the team's namespace go unnoticed. Drift accumulates silently. Always
   enable `orphanedResources.warn: true`.

4. **All environments on the same branch.** Using `targetRevision: main` for dev,
   staging, and prod means every commit deploys everywhere simultaneously. Use
   environment-specific branches or tags for promotion gating.

5. **Overprivileged project roles.** Using `action: '*'` or granting `exec` access
   in AppProject roles gives teams more power than they need. Scope to `get`, `sync`,
   and `override` at most. Never grant `delete` or `exec` without explicit justification.

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Argo CD not installed | Stop immediately. Redirect to `argo-operations` for setup. |
| Single-tenant cluster | Generate a simpler AppProject — less restrictive destinations OK, but still scope sourceRepos. Note that `namespaceResourceBlacklist` may not be needed. |
| Existing AppProject with same name | Run `kubectl get appproject <name> -n <ns> -o yaml`. Show the current state. Ask the user whether to update or use a different name. Show diff before applying. |
| Multiple Argo CD instances | Detect by checking for ArgoCD CRs or argocd-labeled pods in multiple namespaces. Ask which instance to target. |
| OpenShift with GitOps operator | Check for `ArgoCD` CR (`kubectl get argocd -A`). Use the operator-managed namespace (typically `openshift-gitops` or a namespace-scoped instance). Adjust RBAC to use OpenShift groups. |
| Team namespaces already exist | Skip Namespace creation. Still offer ResourceQuota and LimitRange if missing. |
| Team already has partial onboarding | Inventory existing resources (`kubectl get appproject,application -A`). Show what exists, ask what to add or update. |
| User provides all info up front | Skip interactive discovery. Parse the info, build the team profile, confirm, and proceed to generation. |

## Reference Index

These files hold the **authoritative manifests** for this skill. Phase 2 and Phase 3 above
describe what to generate and why; the YAML itself lives here. Load the relevant file
rather than writing manifests from memory.

| Topic | Reference File | When to Load |
|-------|---------------|-------------|
| AppProject / Application / RBAC templates, conditional resources (Namespace, quota tiers, LimitRange, RoleBinding, notifications, sync windows), validation checklist | `references/onboarding-guide.md` | **Every onboarding request** — Phase 2 |
| `teams.yaml` schema, both ApplicationSet approaches, PR workflow, platform-vs-team guard rails | `references/self-service-pattern.md` | Phase 3 — scaling or self-service requests |
| Source type variants (Helm / Kustomize / directory), Rollouts, notifications, sync windows, gitops-promoter | `references/onboarding-variants.md` | When adapting to a specific stack |
