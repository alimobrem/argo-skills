# Changelog

All notable changes to this project will be documented in this file.

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
