#!/usr/bin/env bash
# Remove everything setup.sh created, and verify nothing is left behind.
set -euo pipefail

KCTL="$(command -v oc >/dev/null 2>&1 && echo oc || echo kubectl)"
NS_ARGOCD="${NS_ARGOCD:-openshift-gitops}"
LABEL="argo-skills-eval-fixture=true"

echo "==> deleting fixture Applications and ApplicationSets"
# Delete the Argo CD objects first: removing the namespaces while an Application
# still manages them leaves the Application reconciling against a terminating
# namespace, which can hang the delete.
$KCTL delete applicationset,applications.argoproj.io -n "$NS_ARGOCD" -l "$LABEL" --ignore-not-found
sleep 20

echo "==> deleting fixture namespaces"
$KCTL delete ns apps finance eval-staging eval-production --ignore-not-found --wait=false
for _ in $(seq 1 18); do
  left=0
  for ns in apps finance eval-staging eval-production; do
    $KCTL get ns "$ns" >/dev/null 2>&1 && left=$((left+1))
  done
  [ "$left" -eq 0 ] && break
  sleep 10
done

echo
echo "==> verification"
fail=0
for ns in apps finance eval-staging eval-production; do
  if $KCTL get ns "$ns" >/dev/null 2>&1; then
    echo "  STILL PRESENT: namespace/$ns ($($KCTL get ns "$ns" -o jsonpath='{.status.phase}'))"; fail=1
  fi
done
remaining=$($KCTL get applications.argoproj.io,applicationsets.argoproj.io -A -l "$LABEL" \
            --no-headers 2>/dev/null | wc -l | tr -d ' ')
[ "$remaining" != "0" ] && { echo "  STILL PRESENT: $remaining labelled Argo object(s)"; fail=1; }

if [ "$fail" -eq 0 ]; then
  echo "  clean — no fixture namespaces, no labelled Argo objects"
  echo
  echo "  remaining Applications on the cluster (should be yours only):"
  $KCTL get applications.argoproj.io -A --no-headers 2>/dev/null | sed 's/^/    /'
else
  echo
  echo "  teardown INCOMPLETE — investigate before leaving the cluster."
  exit 1
fi
