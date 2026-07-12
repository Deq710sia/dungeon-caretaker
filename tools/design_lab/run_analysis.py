#!/usr/bin/env python3
"""
Design Lab — master analysis runner (v2).

Runs analyze.py + validate.py against a telemetry JSONL file, writes all
outputs to a per-run directory under generated/design_lab/runs/, and
appends the run's key metrics to history.json for cross-version comparison.

New in v2:
  - Passes --notes through to analyze.py (design hypothesis stored in metrics + history)
  - Stores more metrics in history (momentum_curve, coast_duration, decision_frequency, recovery)
  - Auto-generates a trend report when history has >=3 runs with the same label prefix

Usage:
    python3 run_analysis.py <telemetry.jsonl> [--label LABEL] [--notes "design hypothesis"]
    python3 run_analysis.py --diff <label_a> <label_b>
    python3 run_analysis.py --trend [<prefix>]    # e.g. --trend baseline or --trend v03
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
from collections import defaultdict
from typing import Any


SCRIPT_DIR = Path(__file__).resolve().parent
ANALYZE_PY = SCRIPT_DIR / "analyze.py"
VALIDATE_PY = SCRIPT_DIR / "validate.py"
CONSTITUTION_DIR = SCRIPT_DIR  # contains constitution_4state.json + constitution_2state.json
# generated/ lives at the repo root (two levels up from this script)
REPO_ROOT = SCRIPT_DIR.parent.parent
RUNS_DIR = REPO_ROOT / "generated" / "design_lab" / "runs"
HISTORY_FILE = REPO_ROOT / "generated" / "design_lab" / "history.json"


def run_one(telemetry_file: str, label: str | None, notes: str | None) -> int:
    if not os.path.isfile(telemetry_file):
        sys.stderr.write("error: %s not found\n" % telemetry_file)
        return 1

    if not label:
        label = os.path.basename(telemetry_file).replace("telemetry_", "").replace(".jsonl", "")

    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    run_dir = RUNS_DIR / f"{timestamp}_{label}"
    run_dir.mkdir(parents=True, exist_ok=True)

    telemetry_copy = run_dir / "telemetry.jsonl"
    shutil.copyfile(telemetry_file, telemetry_copy)

    # Run analyzer (v2 — passes --notes)
    print(f"--- Analyzing {telemetry_file} ---")
    analyze_cmd = [sys.executable, str(ANALYZE_PY), str(telemetry_copy),
                   "--out-dir", str(run_dir), "--label", label]
    if notes:
        analyze_cmd += ["--notes", notes]
    rc = subprocess.call(analyze_cmd)
    if rc != 0:
        sys.stderr.write("error: analyze.py failed with rc=%d\n" % rc)
        return rc

    # Run validator (v2 — auto-picks constitution by profile)
    print(f"\n--- Validating against constitution ---")
    metrics_path = run_dir / "metrics.json"
    validation_path = run_dir / "validation.txt"
    validate_cmd = [sys.executable, str(VALIDATE_PY), str(metrics_path),
                    "--constitution", str(CONSTITUTION_DIR), "--out", str(validation_path)]
    rc = subprocess.call(validate_cmd)
    if rc >= 2:
        sys.stderr.write("error: validate.py failed with rc=%d\n" % rc)
        return rc

    # Append to history.json (v2 — more metrics stored)
    with open(metrics_path, "r", encoding="utf-8") as f:
        metrics = json.load(f)
    history_entry = {
        "timestamp": timestamp,
        "label": label,
        "notes": notes or "",
        "movement_profile": metrics.get("movement_profile", "unknown"),
        "run_dir": str(run_dir.relative_to(REPO_ROOT)),
        "movement": {
            "expression_score": metrics["movement"]["expression_score"],
            "avg_chain_length": metrics["movement"]["avg_chain_length"],
            "dominant_state": metrics["movement"]["dominant_state"],
            "dominant_state_pct": metrics["movement"]["dominant_state_pct"],
            "phase_cancel_rate": metrics["movement"]["phase_cancel_rate"],
            "pulse_per_phase": metrics["movement"]["pulse_per_phase"],
            "decision_frequency": metrics["movement"]["decision_frequency"],
            "momentum_avg": metrics["movement"]["momentum_avg"],
            "momentum_peak": metrics["movement"]["momentum_peak"],
            "momentum_retention_3s": metrics["movement"]["momentum_retention_3s"],
            "momentum_curve": metrics["movement"]["momentum_curve"],
            "momentum_recovery_after_mistake": metrics["movement"]["momentum_recovery_after_mistake"],
            "coast_entries": metrics["movement"]["coast_entries"],
            "coast_duration_avg": metrics["movement"]["coast_duration_avg"],
            "state_pct": metrics["movement"]["state_pct"],
            "top_chains": metrics["movement"]["top_chains"],
            "top_transitions": metrics["movement"]["top_transitions"],
        },
        "salvage": {
            "completed": metrics["salvage"]["completed"],
            "path_taken": metrics["salvage"]["path_taken"],
            "completion_time_s": metrics["salvage"]["completion_time_s"],
            "committed_deeper": metrics["salvage"]["committed_deeper"],
            "corpses_collected": metrics["salvage"]["corpses_collected"],
            "qte_pass_rate": metrics["salvage"]["qte_pass_rate"],
            "qte_gate_total": metrics["salvage"]["qte_gate_total"],
            "qte_gate_pass": metrics["salvage"]["qte_gate_pass"],
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

    # Auto-generate trend report if we have >=3 runs with the same label prefix
    label_prefix = label.split("_")[0] if "_" in label else label
    same_prefix = [h for h in history if h["label"].split("_")[0] == label_prefix]
    if len(same_prefix) >= 3:
        print(f"\n--- Auto-generating trend report ({len(same_prefix)} runs with prefix '{label_prefix}') ---")
        trend_path = RUNS_DIR.parent / f"trend_{label_prefix}.txt"
        write_trend_report(same_prefix, trend_path, label_prefix)
        print(f"--- Trend report: {trend_path.relative_to(REPO_ROOT)} ---")

    return 0


def write_trend_report(runs: list[dict], out_path: Path, prefix: str) -> None:
    """Write a trend report showing metric drift across runs with the same prefix."""
    lines: list[str] = []
    lines.append("=" * 70)
    lines.append("TREND REPORT — %s (runs with prefix '%s')" % (prefix, prefix))
    lines.append("=" * 70)
    lines.append("")
    lines.append("Shows metric drift across %d runs. Look for:" % len(runs))
    lines.append("  - Expression score: should trend UP across iterations")
    lines.append("  - Dominant state %: should trend DOWN (more state diversity)");
    lines.append("  - Coast duration: should trend UP (if fixing coast observability)");
    lines.append("  - QTE pass rate: should stabilize in 40-90% band");
    lines.append("")
    lines.append("-" * 70)

    # Header row
    metrics_to_show = [
        ("Expression", "movement.expression_score", "%.1f"),
        ("ChainLen", "movement.avg_chain_length", "%.2f"),
        ("DomState%", "movement.dominant_state_pct", "%.1f"),
        ("CancelRate", "movement.phase_cancel_rate", "%.2f"),
        ("Pulse/Ph", "movement.pulse_per_phase", "%.2f"),
        ("DecFreq", "movement.decision_frequency", "%.2f"),
        ("MomAvg", "movement.momentum_avg", "%.2f"),
        ("MomRet3s", "movement.momentum_retention_3s", "%.2f"),
        ("CoastDur", "movement.coast_duration_avg", "%.2f"),
        ("CoastEnt", "movement.coast_entries", "%d"),
        ("Path", "salvage.path_taken", "%s"),
        ("SalvTime", "salvage.completion_time_s", "%.1f"),
        ("Corpses", "salvage.corpses_collected", "%d"),
        ("QTE%%", "salvage.qte_pass_rate", "%.2f"),
        ("SpiritLost", "salvage.spirit_lost", "%d"),
    ]

    # Print as a table
    header = "Label".ljust(30)
    for name, _, _ in metrics_to_show:
        header += name.rjust(10)
    lines.append(header)
    lines.append("-" * len(header))

    for run in runs:
        row = run["label"][:30].ljust(30)
        for _, path, fmt in metrics_to_show:
            val = _get_nested(run, path)
            if val is None:
                row += "n/a".rjust(10)
            else:
                try:
                    row += (fmt % val).rjust(10)
                except (TypeError, ValueError):
                    row += str(val)[:10].rjust(10)
        lines.append(row)

    lines.append("")
    lines.append("=" * 70)

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def _get_nested(data: dict, dotted_path: str) -> Any:
    parts = dotted_path.split(".")
    cur: Any = data
    for p in parts:
        if isinstance(cur, dict) and p in cur:
            cur = cur[p]
        else:
            return None
    return cur


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
        arrow = "^" if (delta > 0) == higher_is_better else "v"
        return f"{fmt} ({sign}{fmt}) {arrow}" % (b_val, delta)

    print("MOVEMENT")
    print(f"  Expression score:     {fmt_delta(a['movement']['expression_score'], b['movement']['expression_score'], '%.1f')}")
    print(f"  Avg chain length:     {fmt_delta(a['movement']['avg_chain_length'], b['movement']['avg_chain_length'])}")
    print(f"  Dominant state %:     {fmt_delta(a['movement']['dominant_state_pct'], b['movement']['dominant_state_pct'], '%.1f', higher_is_better=False)}")
    print(f"  Phase cancel rate:    {fmt_delta(a['movement']['phase_cancel_rate'], b['movement']['phase_cancel_rate'], '%.2f')}")
    print(f"  Pulse per phase:      {fmt_delta(a['movement']['pulse_per_phase'], b['movement']['pulse_per_phase'], '%.2f')}")
    print(f"  Decision frequency:   {fmt_delta(a['movement']['decision_frequency'], b['movement']['decision_frequency'], '%.2f')}")
    print(f"  Momentum avg:         {fmt_delta(a['movement']['momentum_avg'], b['movement']['momentum_avg'])}")
    print(f"  Momentum retention 3s:{fmt_delta(a['movement']['momentum_retention_3s'], b['movement']['momentum_retention_3s'])}")
    print(f"  Coast duration:       {fmt_delta(a['movement'].get('coast_duration_avg', 0), b['movement'].get('coast_duration_avg', 0), '%.2f')}")
    print(f"  Coast entries:        {fmt_delta(a['movement'].get('coast_entries', 0), b['movement'].get('coast_entries', 0), '%d')}")

    print("\nSALVAGE")
    print(f"  Path taken:           {a['salvage']['path_taken']:>6}  ->  {b['salvage']['path_taken']:>6}")
    print(f"  Completion time:      {fmt_delta(a['salvage']['completion_time_s'], b['salvage']['completion_time_s'], '%.1f', higher_is_better=False)}")
    print(f"  Corpses collected:    {fmt_delta(a['salvage']['corpses_collected'], b['salvage']['corpses_collected'], '%d')}")
    print(f"  QTE pass rate:        {fmt_delta(a['salvage']['qte_pass_rate'], b['salvage']['qte_pass_rate'], '%.2f')}")
    print(f"  Spirit lost:          {fmt_delta(a['salvage']['spirit_lost'], b['salvage']['spirit_lost'], '%d', higher_is_better=False)}")

    print(f"\n{'='*60}")
    return 0


def show_trend(prefix: str | None) -> int:
    if not HISTORY_FILE.exists():
        sys.stderr.write("error: no history.json yet\n")
        return 1
    with open(HISTORY_FILE, "r", encoding="utf-8") as f:
        history = json.load(f)

    if prefix:
        runs = [h for h in history if h["label"].split("_")[0] == prefix]
    else:
        runs = history

    if len(runs) < 2:
        sys.stderr.write(f"error: need >=2 runs (have {len(runs)} matching prefix '{prefix}')\n")
        return 1

    trend_path = RUNS_DIR.parent / f"trend_{prefix or 'all'}.txt"
    write_trend_report(runs, trend_path, prefix or "all")
    print(f"Wrote {trend_path}")
    print()
    with open(trend_path, "r", encoding="utf-8") as f:
        sys.stdout.write(f.read())
    return 0


def main() -> int:
    ap = argparse.ArgumentParser(description="Design Lab master analysis runner v2")
    ap.add_argument("telemetry_file", nargs="?", help="Path to telemetry_<label>.jsonl")
    ap.add_argument("--label", help="Run label (default: derived from filename)")
    ap.add_argument("--notes", help="Free-text design hypothesis for this run (recorded in history)")
    ap.add_argument("--diff", nargs=2, metavar=("LABEL_A", "LABEL_B"), help="Diff two historical runs by label")
    ap.add_argument("--trend", nargs="?", const="", default=None,
                    help="Show trend report for runs with given prefix (or all if no prefix)")
    args = ap.parse_args()

    if args.trend is not None:
        return show_trend(args.trend if args.trend else None)

    if args.diff:
        return diff_runs(args.diff[0], args.diff[1])

    if not args.telemetry_file:
        ap.error("telemetry_file is required (or use --diff LABEL_A LABEL_B or --trend [PREFIX])")

    return run_one(args.telemetry_file, args.label, args.notes)


if __name__ == "__main__":
    sys.exit(main())
