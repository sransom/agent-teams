#!/usr/bin/env python3
"""Validate mol-*.formula.json files (stdlib only).

Four checks: (a) JSON validity + required top-level keys, (b) filename
`mol-*.formula.json` and `formula` field matches stem, (c) dep-type trap:
step with `waits_for: all-children` AND non-empty `needs` (see
commands/spawn.md), (d) reference integrity: every `{{var}}` in
title/description/labels declared in `vars`; every `needs` entry references
a step id.

Usage: python3 scripts/validate-formulas.py [DIR ...]
Exits 0 if clean, 1 on any failures.
"""

import argparse
import json
import os
import re
import sys

REQUIRED_KEYS = ("formula", "version", "type", "vars", "steps")
SPAWN_TRAP_HINT = (
    "see commands/spawn.md (dep-type-trap section): a step that uses "
    "`waits_for: \"all-children\"` MUST have an empty `needs` array — "
    "otherwise beads applies both a child-bond AND a hard dep, deadlocking."
)
VAR_RE = re.compile(r"\{\{\s*([a-zA-Z0-9_-]+)\s*\}\}")


def find_formulas(dirs):
    out = []
    for d in dirs:
        if not os.path.isdir(d):
            continue
        for name in sorted(os.listdir(d)):
            if name.endswith(".formula.json"):
                out.append(os.path.join(d, name))
    return out


def check_required_keys(data):
    missing = [k for k in REQUIRED_KEYS if k not in data]
    return [f"missing required top-level key(s): {', '.join(missing)}"] if missing else []


def check_filename(path, data):
    base = os.path.basename(path)
    errs = []
    if not base.startswith("mol-"):
        errs.append(f"filename {base!r} must start with 'mol-'")
    expected = base[: -len(".formula.json")] if base.endswith(".formula.json") else base
    actual = data.get("formula")
    if actual != expected:
        errs.append(
            f"`formula` field {actual!r} does not match filename stem {expected!r}"
        )
    return errs


def check_dep_trap(data):
    errs = []
    for step in data.get("steps", []) or []:
        if not isinstance(step, dict):
            continue
        needs = step.get("needs") or []
        waits = step.get("waits_for")
        if waits == "all-children" and isinstance(needs, list) and len(needs) > 0:
            errs.append(
                f"step {step.get('id')!r}: has `waits_for: \"all-children\"` AND "
                f"non-empty `needs` {needs}. {SPAWN_TRAP_HINT}"
            )
    return errs


def _scan_vars(text, declared, errs, ctx):
    if not isinstance(text, str):
        return
    for ref in VAR_RE.findall(text):
        if ref not in declared:
            errs.append(f"{ctx}: {{{{{ref}}}}} not declared in `vars`")


def check_references(data):
    errs = []
    declared_vars = set((data.get("vars") or {}).keys())
    steps = data.get("steps") or []
    step_ids = {s.get("id") for s in steps if isinstance(s, dict)}
    for step in steps:
        if not isinstance(step, dict):
            continue
        sid = step.get("id", "<unknown>")
        _scan_vars(step.get("title"), declared_vars, errs, f"step {sid!r}.title")
        _scan_vars(step.get("description"), declared_vars, errs, f"step {sid!r}.description")
        for lbl in step.get("labels") or []:
            _scan_vars(lbl, declared_vars, errs, f"step {sid!r}.labels")
        for need in step.get("needs") or []:
            if need not in step_ids:
                errs.append(f"step {sid!r}.needs: {need!r} is not a declared step id")
    return errs


def validate_one(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        return [f"invalid JSON: {e}"]
    except OSError as e:
        return [f"cannot read file: {e}"]
    errs = []
    errs += check_required_keys(data)
    if "formula" in data:
        errs += check_filename(path, data)
    if "steps" in data:
        errs += check_dep_trap(data)
        errs += check_references(data)
    return errs


def main():
    ap = argparse.ArgumentParser(description="Validate mol-*.formula.json files.")
    ap.add_argument("dirs", nargs="+", help="Directories to walk for *.formula.json")
    args = ap.parse_args()
    files = find_formulas(args.dirs)
    if not files:
        print("No *.formula.json files found in: " + ", ".join(args.dirs))
        return 0
    failures = 0
    for path in files:
        errs = validate_one(path)
        if errs:
            failures += 1
            print(f"FAIL {path}")
            for e in errs:
                print(f"  - {e}")
        else:
            print(f"OK   {path}")
    print()
    print(f"{len(files)} formula(s) checked, {failures} failed.")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
