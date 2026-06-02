# Argo Agent Skills

[![license](https://img.shields.io/github/license/your-org/argo-skills.svg)](https://github.com/your-org/argo-skills/blob/main/LICENSE)

A collection of reusable skills that give AI Agents expertise in the Argo ecosystem —
Argo CD, Argo Rollouts, Argo Workflows, and Argo Events — for generating manifests,
answering questions, auditing repository structure and security, and debugging live
cluster installations.

## Install

### Using Claude Code

Add the marketplace and install the skills:

```shell
/plugin marketplace add your-org/argo-skills
/plugin install argo-skills@argocd
```

### Using Codex

Add to `$REPO_ROOT/.agents/plugins/marketplace.json` or `~/.agents/plugins/marketplace.json`:

```json
{
  "name": "argo-skills",
  "category": "Developer Tools",
  "source": {
    "source": "url",
    "url": "https://github.com/your-org/argo-skills.git",
    "ref": "main"
  },
  "policy": {
    "installation": "AVAILABLE",
    "authentication": "ON_INSTALL"
  }
}
```

### Using GitHub Copilot

Copy the agent file to your repository:

```shell
mkdir -p .github/copilot
cp agents/github-copilot/argocd.agent.md .github/copilot/
```

## Prerequisites

The skills rely on the following tools being available in the environment:

- `kubectl` for Kubernetes cluster interaction
- `kustomize` for building kustomize overlays
- `kubeconform` for validating Kubernetes manifests against OpenAPI schemas
- `yq` for YAML parsing and validation
- `argocd` for Argo CD CLI operations (optional, enhances cluster debugging)
- `argo` for Argo Workflows CLI operations (optional)
- `kubectl-argo-rollouts` for Argo Rollouts CLI operations (optional)

A [Brewfile](Brewfile) is provided for easy installation on macOS:

```shell
brew bundle
```

## Available Skills

The skills are designed to work together and the agent automatically selects the right one
based on context: `argo-knowledge` for answering questions and generating manifests,
`argo-repo-audit` for validating and auditing repository contents,
and `argo-cluster-debug` for troubleshooting live clusters.

### argo-knowledge

Answers questions about the full Argo ecosystem and generates correct YAML manifests
for all Argo custom resources. Bundled with reference documentation covering Applications,
ApplicationSets, AppProjects, Rollouts, Workflows, Events, notifications, image updater,
repository patterns, and best practices.

Example prompts:

```text
How do I set up an ApplicationSet with a git directory generator and progressive syncs?
```

```text
Generate a Rollout with canary strategy, Istio traffic management,
and a Prometheus-based AnalysisTemplate.
```

```text
What's the best way to structure a multi-cluster GitOps repo with Argo CD?
```

### argo-repo-audit

Audits Argo GitOps repositories for structure, security, and operational best practices.
Validates manifests against schemas, reviews AppProject restrictions, RBAC configuration,
sync policies, secrets management, and generates a structured report with prioritized
recommendations.

Example prompts:

```text
Audit the current repo and provide a GitOps report.
```

```text
Validate my repo without auditing it.
```

```text
Check for security issues in my AppProject configurations.
```

### argo-cluster-debug

Debugs and troubleshoots the Argo ecosystem on live Kubernetes clusters. Inspects
Application sync status, diagnoses Rollout failures, traces Workflow step errors,
and debugs EventSource/Sensor connectivity. Prefers `argocd`/`argo` CLIs when available,
falls back to `kubectl` for CRD inspection.

Example prompts:

```text
Check the Argo CD installation on my cluster.
```

```text
Debug the Application podinfo that's stuck in OutOfSync.
```

```text
Why is my canary Rollout stuck at step 2?
```

```text
My Argo Workflow build-pipeline keeps failing. Debug it.
```
