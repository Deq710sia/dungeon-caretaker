#!/usr/bin/env python3
"""
Design Lab — master analysis runner.

Runs analyze.py + validate.py against a telemetry JSONL file, writes all
outputs to a per-run directory under generated/design_lab/runs/, and
appends the run's key metrics to history.json for cross-version comparison.

Usage:
    python3 run_analysis.py <telemetry.jsonl> [--label LABEL] [--notes "free text"]

Workflow:
    1. PlaytestDriver produces user://telemetry_<label>.jsonl
    2. Copy that file into the repo (or pass it directly)
    3. Run this script
    4. Outputs go to generated/design_lab/runs/<timestamp>_<label>/
       - telemetry.jsonl   (copy of input)
       - metrics.json
       - report.txt
       - validation.txt
    5. Key metrics appended to generated/design_lab/history.json
    6. Prints report + validation to stdout

The history.json file is the source of truth for cross-version trend lines.
Compare two runs with:
    python3 run_analysis.py --diff <label_a> <label_b>
"""
from __future__ import annotations

import argparse
import datetime
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path


SCRIPT_DIR = Path(__file__).resolve().parent
ANALYZE_PY = SCRIPT_DIR / "analyze.py"
VALIDATE_PY = SCRIPT_DIR / "validate.py"
CONSTITUTION = SCRIPT_DIR / "constitution.json"
# generated/ lives at the repo root (two levels up from this script)
REPO_ROOT = SCRIPT_DIR.parent.parent
RUNS_DIR = REPO_ROOT / "generated" / "design_lab" / "runs"
HISTORY_FILE = REPO_ROOT / "generated" / "design_lab" / "history.json"


def run_one(telemetry_file: str, label: str | None, notes: str | None) -> int:
    if not os.path.isfile(telemetry_file):
        sys.stderr.write("error: %s not found\n" % telemetry_file)
        return 1

    # Derive label from filename if not provided
    if not label:
        label = os.path.basename(telemetry_file).replace("telemetry_", "").replace(".jsonl", "")

    # Create per-run directory
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    run_dir = RUNS_DIR / f"{timestamp}_{label}"
    run_dir.mkdir(parents=True, exist_ok=True)

    # Copy telemetry into run dir for archival
    telemetry_copy = run_dir / "telemetry.jsonl"
    shutil.copyfile(telemetry_file, telemetry_copy)

    # Run analyzer
    print(f"--- Analyzing {telemetry_file} ---")
    analyze_cmd = [sys.executable, str(ANALYZE_PY), str(telemetry_copy),
                   "--out-dir", str(run_dir), "--label", label]
    rc = subprocess.call(analyze_cmd)
    if rc != 0:
        sys.stderr.write("error: analyze.py failed with rc=%d\n" % rc)
        return rc

    # Run validator
    print(f"\n--- Validating against constitution ---")
    metrics_path = run_dir / "metrics.json"
    validation_path = run_dir / "validation.txt"
    validate_cmd = [sys.executable, str(VALIDATE_PY), str(metrics_path),
                    "--constitution", str(CONSTITUTION), "--out", str(validation_path)]
    rc = subprocess.call(validate_cmd)
    # rc=1 means FAIL/WARN, rc=0 means PASS — both are valid analysis outcomes.
    # Only rc>=2 would indicate a real script error.
    if rc >= 2:
        sys.stderr.write("error: validate.py failed with rc=%d\n" % rc)
        return rc

    # Append to history.json
    with open(metrics_path, "r", encoding="utf-8") as f:
        metrics = json.load(f)
    history_entry = {
        "timestamp": timestamp,
        "label": label,
        "notes": notes or "",
        "run_dir": str(run_dir.relative_to(REPO_ROOT)),
        "movement": {
            "expression_score": metrics["movement"]["expression_score"],
            "avg_chain_length": metrics["movement"]["avg_chain_length"],
            "dominant_state": metrics["movement"]["dominant_state"],
            "dominant_state_pct": metrics["movement"]["dominant_state_pct"],
            "phase_cancel_rate": metrics["movement"]["phase_cancel_rate"],
            "pulse_per_phase": metrics["movement"]["pulse_per_phase"],
            "momentum_avg": metrics["movement"]["momentum_avg"],
            "momentum_retention_3s": metrics["movement"]["momentum_retention_3s"],
            "state_pct": metrics["movement"]["state_pct"],
        },
        "salvage": {
            "completed": metrics["salvage"]["completed"],
            "path_taken": metrics["salvage"]["path_taken"],
            "completion_time_s": metrics["salvage"]["completion_time_s"],
            "committed_deeper": metrics["salvage"]["committed_deeper"],
            "corpses_collected": metrics["salvage"]["corpses_collected"],
            "qte_pass_rate": metrics["salvage"]["qte_pass_rate"],
            "spirit_lost": metrics["salvage"]["spirit_lost"],
        },
    }

    HISTORY_FILE.parent.mkdir(parents=True, exist_ok=True)
    history: list[dict] = []
    if HISTORY_FILE.exists():
        try:
            with open(HISTORY_FILE, "r", encoding="utf-8") as f:
                history = json.load(f)
        except json.JSONDecodeError:
            sys.stderr.write("warn: history.json was corrupt, starting fresh\n")
            history = []
    history.append(history_entry)
    with open(HISTORY_FILE, "w", encoding="utf-8") as f:
        json.dump(history, f, indent=2)

    print(f"\n--- Run archived at {run_dir.relative_to(REPO_ROOT)} ---")
    print(f"--- History updated: {HISTORY_FILE.relative_to(REPO_ROOT)} ({len(history)} runs) ---")
    return 0


def diff_runs(label_a: str, label_b: str) -> int:
    if not HISTORY_FILE.exists():
        sys.stderr.write("error: no history.json yet\n")
        return 1
    with open(HISTORY_FILE, "r", encoding="utf-8") as f:
        history = json.load(f)
    a = next((h for h in history if h["label"] == label_a), None)
    b = next((h for h in history if h["label"] == label_b), None)
    if a is None or b is None:
        sys.stderr.write(f"error: label(s) not found in history (have: {[h['label'] for h in history]})\n")
        return 1

    print(f"\n{'='*60}")
    print(f"DIFF: {label_a}  ->  {label_b}")
    print(f"{'='*60}\n")

    def fmt_delta(a_val, b_val, fmt="%.2f", higher_is_better=True):
        if a_val is None or b_val is None:
            return "n/a"
        delta = b_val - a_val
        sign = "+" if delta > 0 else ""
        arrow = "↑" if (delta > 0) == higher_is_better else "↓"
        return f"{fmt} ({sign}{fmt}) {arrow}" % (b_val, delta)

    print("MOVEMENT")
    print(f"  Expression score:     {fmt_delta(a['movement']['expression_score'], b['movement']['expression_score'], '%.1f')}")
    print(f"  Avg chain length:     {fmt_delta(a['movement']['avg_chain_length'], b['movement']['avg_chain_length'])}")
    print(f"  Dominant state %:     {fmt_delta(a['movement']['dominant_state_pct'], b['movement']['dominant_state_pct'], '%.1f', higher_is_better=False)}")
    print(f"  Phase cancel rate:    {fmt_delta(a['movement']['phase_cancel_rate'], b['movement']['phase_cancel_rate'], '%.2f')}")
    print(f"  Pulse per phase:      {fmt_delta(a['movement']['pulse_per_phase'], b['movement']['pulse_per_phase'], '%.2f')}")
    print(f"  Momentum avg:         {fmt_delta(a['movement']['momentum_avg'], b['movement']['momentum_avg'])}")
    print(f"  Momentum retention 3s:{fmt_delta(a['movement']['momentum_retention_3s'], b['movement']['momentum_retention_3s'])}")

    print("\nSALVAGE")
    print(f"  Path taken:           {a['salvage']['path_taken']:>6}  ->  {b['salvage']['path_taken']:>6}")
    print(f"  Completion time:      {fmt_delta(a['salvage']['completion_time_s'], b['salvage']['completion_time_s'], '%.1f', higher_is_better=False)}")
    print(f"  Corpses collected:    {fmt_delta(a['salvage']['corpses_collected'], b['salvage']['corpses_collected'], '%d')}")
    print(f"  QTE pass rate:        {fmt_delta(a['salvage']['qte_pass_rate'], b['salvage']['qte_pass_rate'], '%.2f')}")
    print(f"  Spirit lost:          {fmt_delta(a['salvage']['spirit_lost'], b['salvage']['spirit_lost'], '%d', higher_is_better=False)}")

    print(f"\n{'='*60}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Design Lab master analysis runner")
    ap.add_argument("telemetry_file", nargs="?", help="Path to telemetry_<label>.jsonl")
    ap.add_argument("--label", help="Run label (default: derived from filename)")
    ap.add_argument("--notes", help="Free-text notes for this run (recorded in history)")
    ap.add_argument("--diff", nargs=2, metavar=("LABEL_A", "LABEL_B"), help="Diff two historical runs by label")
    args = ap.parse_args()

    if args.diff:
        return diff_runs(args.diff[0], args.diff[1])

    if not args.telemetry_file:
        ap.error("telemetry_file is required (or use --diff LABEL_A LABEL_B)")

    return run_one(args.telemetry_file, args.label, args.notes)


if __name__ == "__main__":
    sys.exit(main())
