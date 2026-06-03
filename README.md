# Argo Agent Skills

[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

A collection of reusable skills that give AI Agents expertise in the Argo ecosystem —
Argo CD, Argo Rollouts, Argo Workflows, and Argo Events — for generating manifests,
answering questions, auditing repository structure and security, and debugging live
cluster installations.

## Install

### Using Claude Code

Add the marketplace and install the skills:

```shell
/plugin marketplace add alimobrem/argo-skills
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
    "url": "https://github.com/alimobrem/argo-skills.git",
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

### argo-operations

Installs, deploys, promotes, and maintains Argo resources on live clusters.
Every write operation follows a 3-step safety model: **generate** YAML,
**preview** with dry-run, **confirm** before applying. Covers Argo CD installation
(Helm, OpenShift GitOps Operator, Autopilot), Application/ApplicationSet lifecycle,
Rollout promotion, and day-2 operations (upgrades, API migration, backup/restore).

Example prompts:

```text
Install Argo CD on my OpenShift cluster using the GitOps operator.
```

```text
Create an Application for my Helm chart with automated sync.
```

```text
Promote the canary rollout frontend in production.
```

```text
Upgrade Argo CD from 2.12 to 2.14.
```

```text
Back up all my Applications and AppProjects to YAML files.
```

## Benchmarks

Eval results for each skill on `claude-opus-4-6`. Knowledge evals compare with-skill vs baseline (no skill loaded). Audit and debug evals test outcome quality on real repos and live clusters.

<table>
<tr>
<td>

**argo-knowledge** — [full results](benchmarks/argo-knowledge.md)

| Eval | Skill | Base | Delta |
|------|-------|------|-------|
| Multi-source App | 100% | 100% | — |
| Merge generator | 90% | 90% | — |
| Blue-green + Job | 90% | 90% | — |
| Slack + GitHub App | 100% | 100% | — |
| OpenShift GitOps | 100% | 100% | — |
| Multi-tenant RBAC | 100% | 92% | **+8%** |
| argocd-agent | 100% | 30% | **+70%** |
| **Overall** | **97%** | **86%** | **+11%** |

</td>
<td>

**argo-repo-audit** — [full results](benchmarks/argo-repo-audit.md)

| Eval | Score |
|------|-------|
| App-of-apps audit | 100% |
| Mixed-issues audit | 100% |
| **Overall** | **100%** |

Catches: wildcard AppProjects, plain-text
secrets, hardcoded passwords, missing sync
policies, HEAD revisions, weak AnalysisTemplates

</td>
<td>

**argo-cluster-debug** — [full results](benchmarks/argo-cluster-debug.md)

| Eval | Score |
|------|-------|
| Install check | 100% |
| Multi-tenant audit | 88% |
| ApplicationSet dive | 100% |
| Rollout analysis | 100% |
| Config review | 100% |
| Sync waves/hooks | 100% |
| **Overall** | **97.5%** |

</td>
</tr>
<tr>
<td colspan="3">

**argo-operations** — [full results](benchmarks/argo-operations.md)

| Eval | Score |
|------|-------|
| OpenShift GitOps config | 70% |
| OCI Helm Application | 100% |
| Canary rollout promote | 75% |
| Argo CD upgrade | 89% |
| Backup resources | 100% |
| **Overall** | **87%** |

Safety model: dry-run preview + user confirmation on every write. Read-only ops skip confirmation.

</td>
</tr>
</table>

> Evals test **outcomes** (issues found, report quality), not process (which tools were used).
> Run evals locally with `make eval` or via GitHub Actions (`evals` workflow).

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

By submitting a pull request, you agree that your contributions will be licensed
under the [MIT License](LICENSE).

### Development

```shell
# Install prerequisites (macOS)
brew bundle

# Download Argo CRD schemas for validation
make download-schemas

# Run discovery script tests
make test-discover

# Run validation script tests
make test-validate
```

### Adding a New Skill

See [AGENTS.md](AGENTS.md) for the repo layout, skill conventions, and eval runner instructions.

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code.

## Security

If you discover a security vulnerability, please report it responsibly.
See [SECURITY.md](SECURITY.md) for details.

## License

This project is licensed under the [MIT License](LICENSE).
