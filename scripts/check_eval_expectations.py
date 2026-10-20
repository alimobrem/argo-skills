#!/usr/bin/env python3
"""Validate field paths asserted in eval expectations against the committed Argo CRD schemas.

Three expectations were found grading FOR output the API server rejects or silently
prunes. Nothing checked the expectations themselves. This does.

Only flags paths rooted at `spec.` that resolve in NO available schema — conservative by
design, because expectations are prose and a false positive is worse than a miss here.
"""
import json
import pathlib
import re
import sys

SCHEMA_DIR = pathlib.Path("skills/argo-repo-audit/assets/schemas")
EVAL_GLOB = "skills/*/evals/evals.json"

# Paths that are legitimately not in a CRD schema: other projects' CRDs we don't ship
# schemas for, or non-Argo kinds.
IGNORE_PREFIXES = (
    "spec.template.spec.",   # pod spec — core/v1, not in the Argo schemas
    "spec.strategy.canary.steps",  # list items, resolved positionally
)


def load_schemas():
    out = {}
    if not SCHEMA_DIR.is_dir():
        return out
    for f in sorted(SCHEMA_DIR.glob("*.json")):
        try:
            out[f.stem] = json.loads(f.read_text())
        except Exception as exc:  # pragma: no cover
            print(f"  warn: could not parse {f.name}: {exc}", file=sys.stderr)
    return out


def resolve(schema, path):
    """True if dotted `path` resolves inside this schema's properties tree."""
    node = schema
    for part in path.split("."):
        props = node.get("properties")
        if not isinstance(props, dict):
            # arrays: step into items and retry this part
            items = node.get("items")
            if isinstance(items, dict):
                props = items.get("properties")
            if not isinstance(props, dict):
                return False
        if part not in props:
            return False
        node = props[part]
    return True


def main():
    schemas = load_schemas()
    if not schemas:
        print("No CRD schemas found — run `make download-schemas` first. Skipping.")
        return 0

    path_re = re.compile(r"\bspec(?:\.[a-zA-Z][a-zA-Z0-9]*){1,6}\b")
    findings = []
    checked = 0

    for ef in sorted(pathlib.Path(".").glob(EVAL_GLOB)):
        data = json.loads(ef.read_text())
        for ev in data.get("evals", []):
            blob = " ".join(ev.get("expectations", [])) + " " + str(ev.get("expected_output", ""))
            for raw in set(path_re.findall(blob)):
                if raw.startswith(IGNORE_PREFIXES):
                    continue
                # An expectation may name a wrong path precisely to forbid it.
                # Skip those: look for a negation within a short window either side.
                esc = re.escape(raw)
                negated = re.search(
                    r"(?:NOT|not|never|rather than|instead of|no longer)\W+(?:\w+\W+){0,3}" + esc
                    + r"|" + esc + r"\W+(?:\w+\W+){0,4}(?:is not|does not|was removed|is removed|no longer|deprecated|is silently)",
                    blob)
                if negated:
                    continue
                checked += 1
                if not any(resolve(s, raw) for s in schemas.values()):
                    findings.append((str(ef), ev.get("id", "?"), raw))

    print(f"Checked {checked} distinct spec.* paths across eval expectations "
          f"against {len(schemas)} CRD schemas.\n")

    if not findings:
        print("All asserted spec.* paths resolve in at least one Argo CRD schema.")
        return 0

    print("Paths that resolve in NO available schema — verify each before trusting it:\n")
    for f, eid, p in sorted(findings):
        print(f"  \033[0;33m{p}\033[0m")
        print(f"      {f} (eval {eid})")
    print("\nA path may be legitimate if it belongs to a CRD whose schema isn't shipped")
    print("(Workflows, Events, GitOps Promoter). Confirm with `kubectl explain <kind>.<path>`")
    print("and either fix the expectation or add the schema to `make download-schemas`.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
