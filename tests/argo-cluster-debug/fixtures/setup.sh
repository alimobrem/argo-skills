#!/usr/bin/env bash
# Deploy the argo-cluster-debug eval fixtures to a live cluster, and arm their
# symptoms. Teardown: ./teardown.sh
#
# Why this exists: four argo-cluster-debug evals name resources that do not exist
# on a stock cluster, so both the skill and the baseline arm get capped at
# `partial` on every expectation that needs a real finding — the suite cannot
# measure what it claims to. These fixtures create the real conditions.
#
# WRITES TO THE CLUSTER. Everything carries argo-skills-eval-fixture=true and is
# removed by teardown.sh. Do not run against a cluster you care about.
#
#   eval 1  podinfo          OutOfSync AND Degraded   (live image drift, selfHeal off)
#   eval 8  billing-service  health Suspended         (paused blue-green Rollout)
#   eval 9  platform-ui      ComparisonError          (multi-source, bad $values path)
#   eval 5  eval-rollingsync RollingSync declared     (see the note at the end)
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
KCTL="$(command -v oc >/dev/null 2>&1 && echo oc || echo kubectl)"
NS_ARGOCD="${NS_ARGOCD:-openshift-gitops}"

echo "==> applying manifests (server dry-run first)"
$KCTL apply -f "$HERE/manifests.yaml" --dry-run=server --validate=strict >/dev/null
$KCTL apply -f "$HERE/manifests.yaml"

echo "==> waiting for the initial sync"
for _ in $(seq 1 30); do
  ready=$($KCTL get applications.argoproj.io -n "$NS_ARGOCD" \
            -o jsonpath='{range .items[*]}{.metadata.name}={.status.sync.status}{"\n"}{end}' 2>/dev/null \
          | grep -c '=Synced' || true)
  [ "${ready:-0}" -ge 3 ] && break
  sleep 10
done

echo "==> arming eval 1: drift podinfo's live image so it is OutOfSync AND Degraded"
# One action produces both symptoms: the live spec diverges from git (OutOfSync)
# and the tag is unpullable (ImagePullBackOff -> Degraded). selfHeal is off in the
# Application, so Argo CD will not revert it.
dep=$($KCTL get deploy -n apps -o jsonpath='{.items[0].metadata.name}')
container=$($KCTL get deploy "$dep" -n apps -o jsonpath='{.spec.template.spec.containers[0].name}')
$KCTL set image -n apps "deploy/$dep" \
  "$container=registry.access.redhat.com/ubi8/nonexistent-eval:9.9.9"
# Default progressDeadlineSeconds is 600; shorten it so Degraded appears in ~1min
# rather than 10. Without this the eval sees Progressing, not Degraded.
$KCTL patch deploy "$dep" -n apps --type=merge -p '{"spec":{"progressDeadlineSeconds":60}}'

echo "==> arming eval 8: pause the blue-green Rollout so health reports Suspended"
ro=$($KCTL get rollout -n finance -o jsonpath='{.items[0].metadata.name}')
$KCTL patch rollout "$ro" -n finance --type=merge -p '{"spec":{"paused":true}}'

echo "==> arming eval 9: hard-refresh platform-ui so the ComparisonError is populated"
# The manifest-generation error is cached by repo-server; a soft refresh will not
# surface it. Note the FULL resource name: on a cluster running Open Cluster
# Management, `get application` resolves to applications.app.k8s.io instead.
$KCTL annotate applications.argoproj.io platform-ui -n "$NS_ARGOCD" \
  argocd.argoproj.io/refresh=hard --overwrite >/dev/null

echo "==> settling"
sleep 90

echo
echo "==> state (expected: podinfo OutOfSync/Degraded, billing-service Suspended,"
echo "           platform-ui Unknown with a ComparisonError)"
$KCTL get applications.argoproj.io -A \
  -o custom-columns='NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status' --no-headers

echo
echo "NOTE on eval 5: RollingSync is declared on the ApplicationSet but is INERT on"
echo "OpenShift GitOps unless the applicationset controller runs with"
echo "--enable-progressive-syncs, which the operator does not set by default. Enabling"
echo "it means editing the shared ArgoCD CR, so this script deliberately does not."
echo "Eval 5 therefore still measures the inert case — which is itself the realistic"
echo "OpenShift GitOps failure mode, and what the skill documents."
