# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- **argo-performance-tuning** skill — diagnoses and tunes Argo CD / OpenShift GitOps
  performance and scalability. Maps symptoms (OOMKilled repo-server, sluggish UI/drift
  detection, Git rate-limiting, `context deadline exceeded`, high baseline polling load) to
  the specific repo-server, controller, or sharding setting that fixes them, for both
  standalone Argo CD and the OpenShift GitOps Operator `ArgoCD` CR. Reuses the
  generate/preview/confirm safety model from `argo-operations` for any live-cluster change.
  Distilled from [Tuning OpenShift GitOps for performance at scale](https://blog.stderr.at/gitopscollection/2026-03-27-openshift-gitops-performance-tuning/).
- `references/tuning-settings.md` — full settings reference (defaults, recommended values,
  standalone vs. Operator CR placement, common misconfigurations, tuning order of leverage)
- 14 eval scenarios for `argo-performance-tuning`, covering core symptom diagnosis plus
  edge cases (single-cluster sharding refusal, Operator misconfiguration correction,
  floating-tag cache pushback, unsupported sharding algorithm, multi-symptom prioritization,
  safety-model compliance, standalone vs. Operator placement)
- Routing entries for the new skill in the `argocd` agent, `argo-operations` redirect table,
  README, and USER_GUIDE

### Benchmarks

- argo-performance-tuning: 99% (Opus-tier) / 100% (Sonnet-tier) with skill vs. 47% / 56%
  unaided baseline — +52% / +44% delta across all 14 evals on both models. Largest deltas on
  the Operator `spec.extraConfig` processors misconfiguration (baseline Opus validated the
  broken request outright, 0/5), the three-way timeout alignment (0/5 baseline Opus), and the
  Git `ls-remote` rate-limit setting (unknown to both unaided baselines). See
  `benchmarks/argo-performance-tuning.md`.

## [0.1.0] - 2026-06-04

### Added

- **argo-knowledge** skill — answers questions about the full Argo ecosystem and generates
  validated YAML for all Argo CRDs (Application, ApplicationSet, AppProject, Rollout,
  AnalysisTemplate, Workflow, EventSource, Sensor, and more)
- **argo-repo-audit** skill — audits GitOps repositories for security issues, best practice
  violations, and operational gaps with structured prioritized reports
- **argo-cluster-debug** skill — debugs Argo resources on live Kubernetes/OpenShift clusters
  with systematic workflows for Applications, Rollouts, Workflows, and Events
- **argo-operations** skill — installs, deploys, promotes, and maintains Argo resources with
  a 3-step safety model (generate → preview → confirm)
- 15 reference docs covering Applications, ApplicationSets, AppProjects, Rollouts, Workflows,
  Events, notifications, image updater, repo patterns, best practices, argocd-agent, multi-tenancy,
  OpenShift GitOps, gitops-promoter
- 7 bundled Argo CRD schemas for offline kubeconform validation
- 3 test fixtures (app-of-apps, applicationset, mixed-issues) with 37 YAML files
- 19 eval scenarios across all 4 skills with benchmarks
- Agent configs for Claude Code, GitHub Copilot, and Codex
- CI workflows for validation, releases, evals, and weekly schema updates
- Pre-commit hook for PII/secret scanning
- SVG banner and terminal-style preview screenshots in README

### Benchmarks

- argo-knowledge: 97% with skill vs 86% baseline (+11%), +70% on argocd-agent
- argo-repo-audit: 100% — catches all Critical security issues
- argo-cluster-debug: 97.5% on advanced live cluster evals
- argo-operations: 87% — safety model fully compliant
