SCHEMAS_DIR := skills/argo-repo-audit/assets/schemas

DISCOVER_SCRIPT := skills/argo-repo-audit/scripts/discover.sh
VALIDATE_SCRIPT := skills/argo-repo-audit/scripts/validate.sh
TEST_DIR := tests/argo-repo-audit

ARGOCD_VERSION := v2.14.14
ROLLOUTS_VERSION := v1.8.2
WORKFLOWS_VERSION := v3.6.5
EVENTS_VERSION := v1.10.1

.PHONY: help download-schemas clean-schemas test-discover test-validate eval eval-knowledge eval-repo-audit eval-cluster-debug

download-schemas: clean-schemas ## Download Argo CRD schemas for kubeconform validation
	@mkdir -p $(SCHEMAS_DIR)
	@echo "Downloading Argo CD CRDs..."
	@curl -sL "https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/crds/application-crd.yaml" | \
		yq e -o=json '.spec.versions[0].schema.openAPIV3Schema' > $(SCHEMAS_DIR)/application-argoproj-v1alpha1.json || true
	@curl -sL "https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/crds/appproject-crd.yaml" | \
		yq e -o=json '.spec.versions[0].schema.openAPIV3Schema' > $(SCHEMAS_DIR)/appproject-argoproj-v1alpha1.json || true
	@curl -sL "https://raw.githubusercontent.com/argoproj/argo-cd/$(ARGOCD_VERSION)/manifests/crds/applicationset-crd.yaml" | \
		yq e -o=json '.spec.versions[0].schema.openAPIV3Schema' > $(SCHEMAS_DIR)/applicationset-argoproj-v1alpha1.json || true
	@echo "Downloading Argo Rollouts CRDs..."
	@curl -sL "https://raw.githubusercontent.com/argoproj/argo-rollouts/$(ROLLOUTS_VERSION)/manifests/crds/rollout-crd.yaml" | \
		yq e -o=json '.spec.versions[0].schema.openAPIV3Schema' > $(SCHEMAS_DIR)/rollout-argoproj-v1alpha1.json || true
	@curl -sL "https://raw.githubusercontent.com/argoproj/argo-rollouts/$(ROLLOUTS_VERSION)/manifests/crds/analysis-template-crd.yaml" | \
		yq e -o=json '.spec.versions[0].schema.openAPIV3Schema' > $(SCHEMAS_DIR)/analysistemplate-argoproj-v1alpha1.json || true
	@curl -sL "https://raw.githubusercontent.com/argoproj/argo-rollouts/$(ROLLOUTS_VERSION)/manifests/crds/analysis-run-crd.yaml" | \
		yq e -o=json '.spec.versions[0].schema.openAPIV3Schema' > $(SCHEMAS_DIR)/analysisrun-argoproj-v1alpha1.json || true
	@curl -sL "https://raw.githubusercontent.com/argoproj/argo-rollouts/$(ROLLOUTS_VERSION)/manifests/crds/experiment-crd.yaml" | \
		yq e -o=json '.spec.versions[0].schema.openAPIV3Schema' > $(SCHEMAS_DIR)/experiment-argoproj-v1alpha1.json || true
	@echo "Done"

clean-schemas: ## Remove downloaded schemas
	@rm -rf $(SCHEMAS_DIR)

test-discover: ## Run discovery script on test fixtures
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/app-of-apps
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/applicationset
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/mixed-issues

test-validate: ## Run validation script on test fixtures
	$(VALIDATE_SCRIPT) -d $(TEST_DIR)/app-of-apps
	$(VALIDATE_SCRIPT) -d $(TEST_DIR)/applicationset

eval: eval-knowledge eval-repo-audit eval-cluster-debug ## Run all skill evals

eval-knowledge: ## Run argo-knowledge evals
	@echo "Running argo-knowledge evals..."
	@claude --print --dangerously-skip-permissions \
		"Read skills/argo-knowledge/evals/evals.json. For each eval: \
		1. Spawn a sub-agent that reads skills/argo-knowledge/SKILL.md first, then answers the eval prompt following the skill workflow. \
		2. Score the output against the expectations array. \
		Report a scorecard table: eval id, passed/total, and list any failed expectations."

eval-repo-audit: ## Run argo-repo-audit evals
	@echo "Running argo-repo-audit evals..."
	@claude --print --dangerously-skip-permissions \
		"Read skills/argo-repo-audit/evals/evals.json. For each eval: \
		1. Spawn a sub-agent that reads skills/argo-repo-audit/SKILL.md first, then follows the audit workflow on the specified test fixture directory. \
		2. Score the output against the expectations array. \
		Report a scorecard table: eval name, passed/total, and list any failed expectations."

eval-cluster-debug: ## Run argo-cluster-debug evals (requires live cluster)
	@echo "Running argo-cluster-debug evals (requires kubectl access)..."
	@claude --print --dangerously-skip-permissions \
		"Read skills/argo-cluster-debug/evals/evals.json. For each eval: \
		1. Spawn a sub-agent that reads skills/argo-cluster-debug/SKILL.md first, then follows the debug workflow. \
		2. Score the output against the expectations array. \
		Report a scorecard table: eval id, passed/total, and list any failed expectations."

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-20s %s\n", $$1, $$2}'
