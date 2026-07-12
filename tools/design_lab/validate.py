#!/usr/bin/env python3
"""
Design Lab — Constitution validator.

Runs the design rules in constitution.json against a metrics.json file
produced by analyze.py. Writes validation.txt with pass/fail/warn per rule.

Usage:
    python3 validate.py <metrics.json> [--constitution PATH] [--out PATH]
"""
from __future__ import annotations

import argparse
import json
import operator
import os
import sys
from dataclasses import dataclass
from typing import Any


COMPARATORS = {
    "<": operator.lt,
    "<=": operator.le,
    ">": operator.gt,
    ">=": operator.ge,
    "==": operator.eq,
    "!=": operator.ne,
}


@dataclass
class RuleResult:
    name: str
    description: str
    metric_path: str
    metric_value: Any
    comparator: str
    threshold: Any
    severity: str
    status: str  # PASS, FAIL, WARN, SKIP, ERROR
    detail: str = ""


def get_metric(data: dict, dotted_path: str) -> Any:
    """Resolve a dotted path like 'movement.state_pct.FLOAT'."""
    parts = dotted_path.split(".")
    cur: Any = data
    for p in parts:
        if isinstance(cur, dict) and p in cur:
            cur = cur[p]
        else:
            return None
    return cur


def eval_skip_condition(data: dict, condition: str) -> bool:
    """Evaluate a simple 'a == b' or 'a > b' skip condition. Returns True if rule should skip."""
    if not condition:
        return False
    for op_str in ["==", "!=", ">=", "<=", ">", "<"]:
        if op_str in condition:
            left, right = condition.split(op_str, 1)
            left = left.strip()
            right = right.strip()
            left_val = get_metric(data, left)
            if left_val is None:
                try:
                    left_val = float(left)
                except ValueError:
                    return False
            try:
                right_val = float(right)
            except ValueError:
                return False
            op = COMPARATORS[op_str]
            return op(left_val, right_val)
    return False


def run_rules(metrics: dict, constitution: dict) -> list[RuleResult]:
    results: list[RuleResult] = []
    for rule in constitution.get("rules", []):
        name = rule.get("name", "?")
        desc = rule.get("description", "")
        metric_path = rule.get("metric", "")
        comp_str = rule.get("comparator", ">")
        threshold = rule.get("threshold", 0)
        severity = rule.get("severity", "FAIL")
        skip_if = rule.get("skip_if", "")

        if skip_if and eval_skip_condition(metrics, skip_if):
            results.append(RuleResult(name, desc, metric_path, None, comp_str, threshold, severity, "SKIP",
                                     detail="skip_if condition met: %s" % skip_if))
            continue

        value = get_metric(metrics, metric_path)
        if value is None:
            results.append(RuleResult(name, desc, metric_path, None, comp_str, threshold, severity, "SKIP",
                                     detail="metric not present (likely no telemetry for this dimension)"))
            continue

        op = COMPARATORS.get(comp_str)
        if op is None:
            results.append(RuleResult(name, desc, metric_path, value, comp_str, threshold, severity, "ERROR",
                                     detail="unknown comparator: %s" % comp_str))
            continue

        passed = op(value, threshold)
        # PASS if the rule's assertion holds; FAIL if it doesn't.
        # Severity field tells us whether a failure is FAIL or WARN.
        status = "PASS" if passed else severity
        detail = "%.4f %s %.4f -> %s" % (value, comp_str, threshold, "holds" if passed else "violated")

        results.append(RuleResult(name, desc, metric_path, value, comp_str, threshold, severity, status, detail))

    return results


def write_validation_report(results: list[RuleResult], out_path: str, metrics_label: str) -> None:
    lines: list[str] = []
    lines.append("=" * 60)
    lines.append("DESIGN CONSTITUTION VALIDATION — %s" % metrics_label)
    lines.append("=" * 60)
    lines.append("")

    pass_count = sum(1 for r in results if r.status == "PASS")
    fail_count = sum(1 for r in results if r.status == "FAIL")
    warn_count = sum(1 for r in results if r.status == "WARN")
    skip_count = sum(1 for r in results if r.status == "SKIP")
    error_count = sum(1 for r in results if r.status == "ERROR")

    lines.append("Summary: %d PASS, %d FAIL, %d WARN, %d SKIP, %d ERROR" % (
        pass_count, fail_count, warn_count, skip_count, error_count))
    if fail_count > 0:
        lines.append("VERDICT: FAIL — design rules violated. Fix before shipping.")
    elif warn_count > 0:
        lines.append("VERDICT: WARN — no hard failures, but design tension exists.")
    else:
        lines.append("VERDICT: PASS — all rules satisfied.")
    lines.append("")
    lines.append("-" * 60)

    for r in results:
        marker = {"PASS": "OK", "FAIL": "XX", "WARN": "!!", "SKIP": "--", "ERROR": "??"}[r.status]
        lines.append("[%s] %s" % (marker, r.name))
        lines.append("     %s" % r.description)
        if r.metric_value is not None:
            lines.append("     metric: %s = %s | rule: %s %s %s" % (
                r.metric_path, r.metric_value, r.metric_path, r.comparator, r.threshold))
            lines.append("     %s" % r.detail)
        else:
            lines.append("     %s" % r.detail)
        lines.append("")

    lines.append("=" * 60)

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def main() -> int:
    ap = argparse.ArgumentParser(description="Design Lab constitution validator")
    ap.add_argument("metrics_file", help="Path to metrics.json from analyze.py")
    ap.add_argument("--constitution", default=None, help="Path to constitution.json (default: alongside this script)")
    ap.add_argument("--out", default=None, help="Output path for validation.txt (default: alongside metrics file)")
    args = ap.parse_args()

    if not os.path.isfile(args.metrics_file):
        sys.stderr.write("error: %s not found\n" % args.metrics_file)
        return 1

    constitution_path = args.constitution or os.path.join(os.path.dirname(__file__), "constitution.json")
    if not os.path.isfile(constitution_path):
        sys.stderr.write("error: constitution not found at %s\n" % constitution_path)
        return 1

    with open(args.metrics_file, "r", encoding="utf-8") as f:
        metrics = json.load(f)
    with open(constitution_path, "r", encoding="utf-8") as f:
        constitution = json.load(f)

    label = metrics.get("label", os.path.basename(args.metrics_file).replace(".json", ""))

    results = run_rules(metrics, constitution)
    out_path = args.out or os.path.join(os.path.dirname(args.metrics_file), "validation.txt")
    write_validation_report(results, out_path, label)

    print("Wrote %s" % out_path)
    print()
    with open(out_path, "r", encoding="utf-8") as f:
        sys.stdout.write(f.read())

    # Exit code: 0 if PASS or WARN-only, 1 if any FAIL or ERROR
    has_hard_fail = any(r.status in ("FAIL", "ERROR") for r in results)
    return 1 if has_hard_fail else 0


if __name__ == "__main__":
    sys.exit(main())
