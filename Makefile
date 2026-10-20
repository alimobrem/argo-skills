SCHEMAS_DIR := skills/argo-repo-audit/assets/schemas
SCHEMAS_TMP := $(SCHEMAS_DIR).tmp

DISCOVER_SCRIPT := skills/argo-repo-audit/scripts/discover.sh
VALIDATE_SCRIPT := skills/argo-repo-audit/scripts/validate.sh
TEST_DIR := tests/argo-repo-audit

ARGOCD_VERSION := v2.14.14
ROLLOUTS_VERSION := v1.8.2
WORKFLOWS_VERSION := v3.6.5
EVENTS_VERSION := v1.10.1

.PHONY: help download-schemas clean-schemas test-discover test-validate test-registration eval eval-knowledge eval-repo-audit eval-cluster-debug eval-operations eval-performance-tuning eval-team-onboard

# Download one CRD schema into the staging dir, failing loudly if upstream moved it.
# $(1)=repo $(2)=version $(3)=upstream CRD filename $(4)=output basename
define fetch_schema
	@echo "  $(4)"
	@curl -fsSL "https://raw.githubusercontent.com/argoproj/$(1)/$(2)/manifests/crds/$(3)" \
		| yq e -o=json '.spec.versions[0].schema.openAPIV3Schema' > "$(SCHEMAS_TMP)/$(4).json" \
		|| { echo "ERROR: failed to fetch $(3) from $(1)@$(2)"; exit 1; }
	@test -s "$(SCHEMAS_TMP)/$(4).json" \
		|| { echo "ERROR: $(4).json is empty — upstream path likely moved ($(3) @ $(1) $(2))"; exit 1; }
	@python3 -m json.tool "$(SCHEMAS_TMP)/$(4).json" > /dev/null \
		|| { echo "ERROR: $(4).json is not valid JSON"; exit 1; }
endef

# Downloads into a staging dir and only swaps it in once every schema is verified, so a
# network blip or an upstream rename can never leave the committed schemas empty/deleted.
download-schemas: ## Download Argo CRD schemas for kubeconform validation
	@rm -rf $(SCHEMAS_TMP) && mkdir -p $(SCHEMAS_TMP)
	@echo "Downloading Argo CD CRDs ($(ARGOCD_VERSION))..."
	$(call fetch_schema,argo-cd,$(ARGOCD_VERSION),application-crd.yaml,application-argoproj-v1alpha1)
	$(call fetch_schema,argo-cd,$(ARGOCD_VERSION),appproject-crd.yaml,appproject-argoproj-v1alpha1)
	$(call fetch_schema,argo-cd,$(ARGOCD_VERSION),applicationset-crd.yaml,applicationset-argoproj-v1alpha1)
	@echo "Downloading Argo Rollouts CRDs ($(ROLLOUTS_VERSION))..."
	$(call fetch_schema,argo-rollouts,$(ROLLOUTS_VERSION),rollout-crd.yaml,rollout-argoproj-v1alpha1)
	$(call fetch_schema,argo-rollouts,$(ROLLOUTS_VERSION),analysis-template-crd.yaml,analysistemplate-argoproj-v1alpha1)
	$(call fetch_schema,argo-rollouts,$(ROLLOUTS_VERSION),analysis-run-crd.yaml,analysisrun-argoproj-v1alpha1)
	$(call fetch_schema,argo-rollouts,$(ROLLOUTS_VERSION),experiment-crd.yaml,experiment-argoproj-v1alpha1)
	@rm -rf $(SCHEMAS_DIR) && mv $(SCHEMAS_TMP) $(SCHEMAS_DIR)
	@echo "Done — $$(ls -1 $(SCHEMAS_DIR) | wc -l | tr -d ' ') schemas in $(SCHEMAS_DIR)"

clean-schemas: ## Remove downloaded schemas
	@rm -rf $(SCHEMAS_DIR) $(SCHEMAS_TMP)

test-discover: ## Run discovery script on test fixtures
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/app-of-apps
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/applicationset
	$(DISCOVER_SCRIPT) -d $(TEST_DIR)/mixed-issues

test-registration: ## Check every skill is registered in manifests, agent, Makefile, banner, docs
	@bash scripts/check-skill-registration.sh

test-validate: ## Run validation script on test fixtures
	$(VALIDATE_SCRIPT) -d $(TEST_DIR)/app-of-apps
	$(VALIDATE_SCRIPT) -d $(TEST_DIR)/applicationset

eval: eval-knowledge eval-repo-audit eval-cluster-debug eval-operations eval-performance-tuning eval-team-onboard ## Run all skill evals

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

eval-operations: ## Run argo-operations evals (requires live cluster)
	@echo "Running argo-operations evals (requires kubectl access)..."
	@claude --print --dangerously-skip-permissions \
		"Read skills/argo-operations/evals/evals.json. For each eval: \
		1. Spawn a sub-agent that reads skills/argo-operations/SKILL.md first, then follows the generate/preview/confirm workflow. \
		2. Score the output against the expectations array. \
		Report a scorecard table: eval id, passed/total, and list any failed expectations."

eval-performance-tuning: ## Run argo-performance-tuning evals (requires live cluster)
	@echo "Running argo-performance-tuning evals (requires kubectl access)..."
	@claude --print --dangerously-skip-permissions \
		"Read skills/argo-performance-tuning/evals/evals.json. For each eval: \
		1. Spawn a sub-agent that reads skills/argo-performance-tuning/SKILL.md first, then follows the assess/diagnose/tune workflow. \
		2. Score the output against the expectations array. \
		Report a scorecard table: eval id, passed/total, and list any failed expectations."

eval-team-onboard: ## Run argo-team-onboard evals (requires live cluster)
	@echo "Running argo-team-onboard evals (requires kubectl access)..."
	@claude --print --dangerously-skip-permissions \
		"Read skills/argo-team-onboard/evals/evals.json. For each eval: \
		1. Spawn a sub-agent that reads skills/argo-team-onboard/SKILL.md first, then follows the discovery-first onboarding workflow. \
		2. Score the output against the expectations array. \
		Report a scorecard table: eval id, passed/total, and list any failed expectations."

help: ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-20s %s\n", $$1, $$2}'
