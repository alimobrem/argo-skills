#!/usr/bin/env bash
# Find hardcoded credentials in a GitOps repo WITHOUT printing their values.
#
# Why this is a script and not a documented grep: the obvious
#   grep -rn -iE "(password|token|secret):" .
# prints the whole matching line, so running it puts the credential straight
# into the agent transcript. An audit that leaks the thing it is auditing for
# is worse than no audit — the finding is the LOCATION, never the value.
#
# This reports file, line, key name and value length. That is enough to triage
# severity and to find the string yourself; it is not enough to use the
# credential. Nothing here writes, and nothing here echoes a secret value.
#
# usage: scan-credentials.sh [repo-root]
# exit:  0 always when it ran (this is a reporting tool, not a gate)
#        2 bad usage
set -uo pipefail

ROOT="${1:-.}"
[[ -d "$ROOT" ]] || { echo "usage: $(basename "$0") [repo-root]" >&2; exit 2; }

# Keys worth flagging. secretName/secretKeyRef/valueFrom are REFERENCES, not
# values, and are filtered out below — flagging them is the noise that makes
# people stop reading credential scans.
KEYS='password|passwd|token|secret|apikey|api_key|accesskey|access_key|sshPrivateKey|bearer|credential'

plain=0; enc=0; synth=0; keys=0

emit() { printf '    %-58s %-16s %s\n' "$1" "$2" "$3"; }

echo "CREDENTIAL SCAN: $ROOT"
echo "  Values are never printed — location, key and length only."
echo

tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT

# -I skips binaries. The grep prints whole lines, but nothing downstream of
# here emits the value portion: awk splits on the first colon after the key
# and keeps only its length.
grep -rnIE "^[[:space:]]*[\"']?($KEYS)[\"']?[[:space:]]*:" "$ROOT" \
  --include='*.yaml' --include='*.yml' --include='*.json' 2>/dev/null \
  | grep -vE 'secretName|secretKeyRef|valueFrom|configMapKeyRef|^[^:]*:[0-9]+:[[:space:]]*#' \
  > "$tmp" || true

while IFS= read -r line; do
  [[ -z "$line" ]] && continue
  file="${line%%:*}"; rest="${line#*:}"
  lineno="${rest%%:*}"; content="${rest#*:}"

  key="$(printf '%s' "$content" | sed -E "s/^[[:space:]]*[\"']?($KEYS)[\"']?[[:space:]]*:.*/\1/I")"
  val="$(printf '%s' "$content" | sed -E 's/^[^:]*:[[:space:]]*//')"
  # Strip a trailing comment before measuring, so "# notsecret" does not
  # inflate the reported length.
  bare="$(printf '%s' "$val" | sed -E 's/[[:space:]]+#.*$//; s/^["'"'"']//; s/["'"'"']$//')"
  n=${#bare}

  loc="${file#./}:$lineno"

  if printf '%s' "$content" | grep -qiE '# *notsecret|EXAMPLE-|CHANGEME|<[a-z-]+>|\$\{|\{\{'; then
    synth=$((synth+1)); emit "$loc" "key=$key" "marked synthetic / templated"
    continue
  fi
  # SOPS and SealedSecrets store ciphertext in these same keys. Flagging them
  # as plaintext is a false positive that trains people to ignore the scanner.
  if grep -qiE 'kind:[[:space:]]*SealedSecret|sops:|ENC\[' "$file" 2>/dev/null; then
    enc=$((enc+1)); emit "$loc" "key=$key" "encrypted at rest — not a finding"
    continue
  fi
  if [[ "$key" == "sshPrivateKey" ]]; then
    keys=$((keys+1)); emit "$loc" "key=$key" "SSH private key, ${n} chars"
    continue
  fi
  plain=$((plain+1)); emit "$loc" "key=$key" "PLAINTEXT, ${n} chars"
done < "$tmp"

# PEM blocks: report the file only. Never the body, and never the first line,
# which for some formats already carries key material.
pem=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  pem=$((pem+1)); emit "${f#./}" "PEM block" "private key material in file"
done < <(grep -rlIE 'BEGIN ([A-Z ]+ )?PRIVATE KEY' "$ROOT" 2>/dev/null || true)

echo
echo "  plaintext: $plain   ssh keys: $keys   PEM files: $pem   synthetic: $synth   encrypted: $enc"
if [[ $((plain + keys + pem)) -gt 0 ]]; then
  echo
  echo "  Treat every plaintext hit as COMPROMISED: it is in git history, so removing it"
  echo "  from HEAD is not sufficient. Rotate first, then purge."
fi
exit 0
