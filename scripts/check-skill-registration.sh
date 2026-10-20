#!/usr/bin/env bash
# Every skill under skills/ must be registered everywhere it needs to appear.
# Adding a skill without wiring it up is how the banner, the Codex manifest, and the
# `make eval` target all silently drifted to a stale 3-4 skill list.
set -euo pipefail

cd "$(dirname "$0")/.."

FAIL=0
note() { printf '  \033[0;31mMISSING\033[0m  %s\n' "$1"; FAIL=1; }

SKILLS=$(find skills -mindepth 1 -maxdepth 1 -type d -exec basename {} \; | sort)
echo "Skills found: $(echo "$SKILLS" | tr '\n' ' ')"
echo

for skill in $SKILLS; do
  echo "$skill"
  short="${skill#argo-}"

  [ -f "skills/$skill/SKILL.md" ]      || note "skills/$skill/SKILL.md"
  [ -f "skills/$skill/evals/evals.json" ] || note "skills/$skill/evals/evals.json"
  [ -f "benchmarks/$skill.md" ]        || note "benchmarks/$skill.md"

  grep -q "\"./skills/$skill\""        .claude-plugin/marketplace.json || note ".claude-plugin/marketplace.json entry"
  grep -q "^  - $skill\$"              agents/claude-code/argocd.md    || note "agents/claude-code/argocd.md skills: list"
  grep -q "^eval-$short:"              Makefile                        || note "Makefile target eval-$short"
  grep -qE "^eval:.*[[:space:]]eval-$short([[:space:]]|\$)" Makefile    || note "Makefile 'eval' aggregate does not include eval-$short"
  grep -q ">$short<"                   assets/banner.svg               || note "assets/banner.svg pill for '$short'"
  grep -q "$skill"                     README.md                       || note "README.md mention"
  grep -qe "^ *- $skill\$"             .github/workflows/evals.yml     || note ".github/workflows/evals.yml choice option"
  grep -qe "^ *- skill: $skill\$"      .github/workflows/evals.yml     || note ".github/workflows/evals.yml matrix entry"
done

# The README badge and the Benchmarks notice cite an eval count. The banner drifted two
# skills behind before anyone noticed; don't let the same happen to a number.
EVAL_TOTAL=$(python3 -c "
import json,glob
print(sum(len(json.load(open(f))['evals']) for f in glob.glob('skills/*/evals/evals.json')))")
if ! grep -q "evals-${EVAL_TOTAL}-" README.md; then
  printf '  \033[0;31mSTALE\033[0m    README eval badge does not match the actual total (%s)\n' "$EVAL_TOTAL"
  FAIL=1
fi

echo
if [ "$FAIL" -ne 0 ]; then
  echo "Skill registration check FAILED — see MISSING lines above."
  exit 1
fi
echo "Skill registration check passed — all skills registered everywhere."
