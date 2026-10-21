#!/usr/bin/env bash
# Install the repo's local git hooks. Currently: a pre-commit secret scan.
#
#   make hooks            install
#   make hooks-uninstall  remove (restores any backup)
#
# Why a plain .git/hooks script rather than a .pre-commit-config.yaml:
# this repository is PUBLIC. Red Hat's rh-pre-commit lives on internal GitLab and
# can only be installed over the VPN, so referencing it from a committed
# pre-commit config would break `pre-commit install` for outside contributors.
# Red Hat InfoSec's own docs say as much and recommend keeping that configuration
# local. This hook therefore uses whichever scanner is available and never
# requires internal access.
set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK="$REPO_ROOT/.git/hooks/pre-commit"
MARKER="argo-skills-secret-scan"

if [[ "${1:-}" == "--uninstall" ]]; then
  if [[ -f "$HOOK" ]] && grep -q "$MARKER" "$HOOK" 2>/dev/null; then
    rm -f "$HOOK"
    if [[ -f "$HOOK.pre-argo-skills" ]]; then
      mv "$HOOK.pre-argo-skills" "$HOOK"
      echo "removed; restored your previous pre-commit hook"
    else
      echo "removed"
    fi
  else
    echo "nothing to remove (hook absent, or not installed by this script)"
  fi
  exit 0
fi

mkdir -p "$REPO_ROOT/.git/hooks"

# Never silently clobber someone else's hook -- notably rh-multi-pre-commit, which
# the rh-pre-commit quickstart installs across every repo under $HOME with --force.
if [[ -f "$HOOK" ]] && ! grep -q "$MARKER" "$HOOK" 2>/dev/null; then
  cp "$HOOK" "$HOOK.pre-argo-skills"
  echo "note: existing pre-commit hook backed up to .git/hooks/pre-commit.pre-argo-skills"
  echo "      it will be chained, not replaced"
fi

cat > "$HOOK" <<'HOOK_EOF'
#!/usr/bin/env bash
# argo-skills-secret-scan — installed by scripts/install-git-hooks.sh
set -uo pipefail
ROOT="$(git rev-parse --show-toplevel)"

# Chain any hook that was here first (e.g. rh-multi-pre-commit).
PREV="$ROOT/.git/hooks/pre-commit.pre-argo-skills"
if [[ -x "$PREV" ]]; then
  "$PREV" "$@" || exit $?
fi

if [[ -x "$ROOT/scripts/scan-secrets.sh" ]]; then
  "$ROOT/scripts/scan-secrets.sh" || {
    echo ""
    echo "Commit aborted. To bypass for a change you are certain about:"
    echo "    git commit --no-verify"
    exit 1
  }
fi
HOOK_EOF

chmod +x "$HOOK"
echo "installed: .git/hooks/pre-commit  (secret scan)"
echo "verify with: make scan-secrets"
