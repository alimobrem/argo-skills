#!/usr/bin/env bash
# Scan for secrets — and for things that merely LOOK like secrets — before they
# reach a commit. Perceived secrets matter as much as real ones here: a plausible
# -looking string in a test fixture is what triggers an InfoSec alert email.
#
#   scripts/scan-secrets.sh            # staged changes only (what the hook runs)
#   scripts/scan-secrets.sh --all      # whole working tree
#
# Scanner preference, best first:
#   1. rh-gitleaks        — Red Hat internal patterns; what PwnedAlert actually runs
#   2. leaktk gitleaks7   — the same engine (7.6.1) with the PUBLIC leaktk patterns
#   3. gitleaks           — whatever upstream build is on PATH
# If none is available the script warns and exits 0: a contributor without the
# tooling should not be blocked from committing, but must not be told they are safe.
set -uo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || { echo "not a git repo" >&2; exit 1; }
cd "$REPO_ROOT"

MODE="staged"
[[ "${1:-}" == "--all" ]] && MODE="all"

ALLOWLIST="$REPO_ROOT/.gitleaks.toml"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/argo-skills"
PATTERNS="$CACHE_DIR/leaktk-patterns-7.6.1.toml"
PATTERNS_URL="https://raw.githubusercontent.com/leaktk/patterns/main/target/patterns/gitleaks/7.6.1"
# InfoSec recommends ~12h caching with fallback to stale patterns if the source is
# unavailable, so a network blip never blocks a commit.
PATTERNS_TTL_MIN=720

say() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

# ---------------------------------------------------------------- scanner pick
GITLEAKS=""; CONFIG_ARGS=(); SCANNER=""

if command -v rh-gitleaks >/dev/null 2>&1 && rh-gitleaks --version >/dev/null 2>&1; then
  SCANNER="rh-gitleaks"
else
  CACHED_BIN="$(ls -1 "$HOME/.cache/rh-gitleaks/"*gitleaks7* 2>/dev/null | head -1)"
  if [[ -n "$CACHED_BIN" && -x "$CACHED_BIN" ]]; then
    GITLEAKS="$CACHED_BIN"; SCANNER="leaktk-gitleaks7 + public patterns"
  elif command -v gitleaks >/dev/null 2>&1; then
    GITLEAKS="$(command -v gitleaks)"; SCANNER="gitleaks (upstream)"
  fi
fi

if [[ -z "$SCANNER" ]]; then
  say "secret scan SKIPPED — no scanner found."
  say "  Install one of:"
  say "    rh-gitleaks (Red Hat internal patterns) — see CONTRIBUTING.md"
  say "    gitleaks                                 — brew install gitleaks"
  say "  Your commit is NOT verified clean."
  exit 0
fi

# Public patterns are only needed for the non-rh fallbacks; rh-gitleaks fetches
# its own (internal) set.
if [[ "$SCANNER" != "rh-gitleaks" ]]; then
  mkdir -p "$CACHE_DIR"
  if [[ -z "$(find "$PATTERNS" -mmin "-$PATTERNS_TTL_MIN" 2>/dev/null)" ]]; then
    if curl -sfL --max-time 20 "$PATTERNS_URL" -o "$PATTERNS.tmp" && [[ -s "$PATTERNS.tmp" ]]; then
      mv "$PATTERNS.tmp" "$PATTERNS"
    else
      rm -f "$PATTERNS.tmp"
      [[ -s "$PATTERNS" ]] || die "could not fetch leak patterns and no cached copy exists"
      say "note: using cached patterns (refresh failed)"
    fi
  fi
  CONFIG_ARGS=(--config-path="$PATTERNS")
fi
[[ -f "$ALLOWLIST" ]] && CONFIG_ARGS+=(--additional-config="$ALLOWLIST")

# ------------------------------------------------------------------ scan input
# Materialise the INDEX, not the working tree: those differ, and the commit will
# contain the index. Relative paths are preserved so .gitleaks.toml path
# allowlists (e.g. ^tests/argo-repo-audit/) still match.
TMP=""
cleanup() { [[ -n "$TMP" && -d "$TMP" ]] && rm -rf "$TMP"; }
trap cleanup EXIT

if [[ "$MODE" == "staged" ]]; then
  # NOT `mapfile -d ''` — macOS ships bash 3.2 where that silently yields zero
  # items instead of failing, which would make this check pass by scanning nothing.
  FILES=()
  while IFS= read -r -d '' f; do FILES+=("$f"); done \
    < <(git diff --cached --name-only --diff-filter=ACMR -z)
  if [[ ${#FILES[@]} -eq 0 ]]; then
    say "secret scan: nothing staged."
    exit 0
  fi
  TMP="$(mktemp -d)"
  for f in "${FILES[@]}"; do
    mkdir -p "$TMP/$(dirname "$f")"
    git show ":$f" > "$TMP/$f" 2>/dev/null || true
  done
  SCAN_PATH="$TMP"
  LABEL="${#FILES[@]} staged file(s)"
else
  # Materialise TRACKED files only. Scanning $REPO_ROOT directly also walks .git/,
  # which surfaces COMMIT_EDITMSG and packed objects as "findings" -- a commit
  # message that merely quotes a key header would fail the scan.
  FILES=()
  while IFS= read -r -d '' f; do FILES+=("$f"); done < <(git ls-files -z)
  TMP="$(mktemp -d)"
  for f in "${FILES[@]}"; do
    mkdir -p "$TMP/$(dirname "$f")"
    cp "$f" "$TMP/$f" 2>/dev/null || true
  done
  SCAN_PATH="$TMP"
  LABEL="${#FILES[@]} tracked file(s)"
fi

# ----------------------------------------------------------------------- scan
REPORT="$(mktemp -u /tmp/scan-secrets-XXXXXX.json)"
if [[ "$SCANNER" == "rh-gitleaks" ]]; then
  rh-gitleaks --path="$SCAN_PATH" --no-git --quiet \
    ${ALLOWLIST:+--additional-config="$ALLOWLIST"} --report="$REPORT" >/dev/null 2>&1
else
  "$GITLEAKS" --path="$SCAN_PATH" "${CONFIG_ARGS[@]}" --no-git --quiet \
    --report="$REPORT" >/dev/null 2>&1
fi

# gitleaks v7 does NOT write the report when a scan is clean, so absence of the
# file means zero findings. Never infer "clean" from a stale report.
if [[ ! -s "$REPORT" ]]; then
  say "secret scan: clean — $LABEL, via $SCANNER"
  exit 0
fi

COUNT="$(python3 -c "import json;print(len(json.load(open('$REPORT'))))" 2>/dev/null || echo "?")"
say ""
say "SECRET SCAN FAILED — $COUNT finding(s) in $LABEL (via $SCANNER)"
say ""
python3 - "$REPORT" <<'PY' 2>/dev/null || cat "$REPORT"
import json,sys
for f in json.load(open(sys.argv[1])):
    print(f"  {f.get('file')}:{f.get('lineNumber')}")
    print(f"    rule    : {f.get('rule')}")
    print(f"    match   : {str(f.get('offender'))[:80]}")
    print()
PY
cat <<'EOT'
If this is a REAL secret:
  Do not commit it. Rotate it if it ever existed anywhere, then remove it.

If this is a false positive (test fixture, placeholder, documentation):
  1. Prefer making it obviously fake   — prefix the value with EXAMPLE-
  2. Add a trailing  # notsecret  comment on that line
  3. Or allowlist it narrowly in .gitleaks.toml (match the VALUE over the path)
  Red Hat InfoSec deliberately does NOT tune out secret-shaped strings in tests,
  so fixtures must be handled here rather than reported upstream.

Re-run manually with:  make scan-secrets
EOT
rm -f "$REPORT"
exit 1
