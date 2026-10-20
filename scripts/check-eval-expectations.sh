#!/usr/bin/env bash
# Validate that field paths asserted in eval expectations actually exist in the Argo CRDs.
#
# Why this exists: three eval expectations were found grading FOR invalid output —
# `preserveResourcesOnDeletion` at spec level (not in the CRD), `repoURL: oci://...`
# (docs say omit the scheme), and ArgoCDCommitStatus's `gitRepositoryRef` (not a field on
# that kind). Nothing validated the expectations themselves, so the benchmark rewarded
# manifests the API server would reject or silently prune.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 -I scripts/check_eval_expectations.py "$@"
