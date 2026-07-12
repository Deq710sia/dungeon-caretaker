#!/usr/bin/env python3
"""
Design Lab — Movement + Salvage telemetry analyzer.

Parses a telemetry JSONL file produced by the Telemetry autoload +
PlaytestDriver, computes movement + salvage metrics, and writes:
  - metrics.json   (machine-comparable across versions)
  - report.txt     (human-readable summary)

Usage:
    python3 analyze.py <telemetry.jsonl> [--out-dir DIR]

If --out-dir is omitted, outputs go alongside the input file.

Event types consumed (emitted by ghost_movement.gd + salvage.gd):
    run_start, run_end
    state_change           {from, to, pos, vel, momentum, chain_count}
    tick                   {state, pos, vel, speed_pct, momentum, chain_count, input, phase_active, phase_cd}  # 10Hz
    phase_activated        {from_coast, momentum, chain_count, pos, shards_remaining}
    phase_expired_natural  {pos, vel, momentum, chain_count}        # v0.36 path
    dive_entered           {energy_pct, momentum_before, momentum_after, chain_count, dive_mult, pos}
    coast_entered          {momentum, pos}
    pulse_fired            {momentum_before, momentum_after, state, pos}
    pulse_denied           {momentum, pos}
    salvage_start          {stage, wave, spirit, shards, fork_y, deeper_h, deeper_w, corridor_w, hazard_count}
    crossroads_committed   {pos, time_elapsed, spirit, shards, momentum}
    qte_started            {qte_type, hazard_type, is_deeper, pos}
    qte_completed          {qte_type, hazard_type, is_deeper, success, time_taken_ms}
    corpse_collected       {corpse_name, gear_name, gear_type, is_deeper, pos, time_elapsed, collected_count}
    damage_taken           {cause, is_deeper, pos, spirit_remaining, time_elapsed}
    exit_reached           {path, time_elapsed, corpses_collected, spirit_remaining, spirit_max, shards}
"""
from __future__ import annotations

import argparse
import json
import os
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from typing import Any


# ---------- Event loading ----------

def load_events(path: str) -> list[dict]:
    events = []
    with open(path, "r", encoding="utf-8") as f:
        for line_no, line in enumerate(f, 1):
            line = line.strip()
            if not line:
                continue
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError as e:
                sys.stderr.write(f"warn: bad JSON at line {line_no}: {e}\n")
    return events


# ---------- Movement metrics ----------

@dataclass
class MovementMetrics:
    total_ticks: int = 0
    state_seconds: dict[str, float] = field(default_factory=dict)  # state -> seconds (10Hz ticks * 0.1)
    state_pct: dict[str, float] = field(default_factory=dict)
    state_transitions: dict[str, int] = field(default_factory=dict)  # "FROM->TO" -> count
    chains: list[list[str]] = field(default_factory=list)  # ordered list of state sequences
    chain_lengths: list[int] = field(default_factory=list)
    avg_chain_length: float = 0.0
    top_chains: list[tuple[str, int]] = field(default_factory=list)  # (chain_str, count)
    phase_activations: int = 0
    phase_cancels_manual: int = 0  # dive_entered events where energy_pct > 0.05 (not natural expiry)
    phase_expiries_natural: int = 0  # phase_expired_natural events
    phase_cancel_rate: float = 0.0  # manual / (manual + natural)
    pulse_fires: int = 0
    pulse_denials: int = 0
    pulse_per_phase: float = 0.0
    momentum_avg: float = 0.0
    momentum_peak: float = 0.0
    momentum_retention_1s: float = 0.0  # avg momentum 1s after a phase activation
    momentum_retention_3s: float = 0.0
    expression_score: float = 0.0
    dominant_state: str = ""
    dominant_state_pct: float = 0.0


def compute_movement_metrics(events: list[dict]) -> MovementMetrics:
    m = MovementMetrics()
    ticks = [e for e in events if e.get("type") == "tick"]
    m.total_ticks = len(ticks)
    if m.total_ticks == 0:
        return m

    # State time distribution (10Hz ticks * 0.1s = seconds)
    state_ticks: Counter = Counter()
    for t in ticks:
        state_ticks[t.get("state", "?")] += 1
    total_seconds = m.total_ticks * 0.1
    for state, count in state_ticks.items():
        m.state_seconds[state] = count * 0.1
        m.state_pct[state] = (count / m.total_ticks) * 100.0

    # Dominant state
    if state_ticks:
        m.dominant_state, top_count = state_ticks.most_common(1)[0]
        m.dominant_state_pct = (top_count / m.total_ticks) * 100.0

    # State transitions + chains
    state_seq: list[str] = []
    prev_state: str | None = None
    for t in ticks:
        s = t.get("state", "?")
        if s != prev_state:
            state_seq.append(s)
            if prev_state is not None:
                key = f"{prev_state}->{s}"
                m.state_transitions[key] = m.state_transitions.get(key, 0) + 1
            prev_state = s

    # Chain length = number of distinct state visits in a row before returning to FLOAT
    # Build chains by walking state_seq and splitting on FLOAT returns of >0.5s
    # (simpler: split on any FLOAT occurrence that lasts > 0.5s; here we approximate
    # by splitting state_seq on consecutive FLOATs)
    current_chain: list[str] = []
    for s in state_seq:
        if s == "FLOAT" and len(current_chain) > 0:
            # End of a chain
            current_chain.append(s)
            m.chains.append(current_chain)
            m.chain_lengths.append(len(current_chain))
            current_chain = []
        else:
            current_chain.append(s)
    if current_chain:
        m.chains.append(current_chain)
        m.chain_lengths.append(len(current_chain))

    if m.chain_lengths:
        m.avg_chain_length = sum(m.chain_lengths) / len(m.chain_lengths)

    # Top chains (by frequency, as a string)
    chain_strs: Counter = Counter()
    for c in m.chains:
        if len(c) >= 2:
            chain_strs[" -> ".join(c)] += 1
    m.top_chains = chain_strs.most_common(5)

    # Phase activation / cancel / expiry
    m.phase_activations = sum(1 for e in events if e.get("type") == "phase_activated")
    m.phase_expiries_natural = sum(1 for e in events if e.get("type") == "phase_expired_natural")
    # Manual cancels = dive_entered events where energy_pct > 0.05 (i.e. phase was canceled with time remaining)
    m.phase_cancels_manual = sum(
        1 for e in events
        if e.get("type") == "dive_entered" and e.get("energy_pct", 0) > 0.05
    )
    total_phase_exits = m.phase_cancels_manual + m.phase_expiries_natural
    if total_phase_exits > 0:
        m.phase_cancel_rate = m.phase_cancels_manual / total_phase_exits

    # Pulse
    m.pulse_fires = sum(1 for e in events if e.get("type") == "pulse_fired")
    m.pulse_denials = sum(1 for e in events if e.get("type") == "pulse_denied")
    if m.phase_activations > 0:
        m.pulse_per_phase = m.pulse_fires / m.phase_activations

    # Momentum
    if ticks:
        momenta = [t.get("momentum", 0.0) for t in ticks]
        m.momentum_avg = sum(momenta) / len(momenta)
        m.momentum_peak = max(momenta)

    # Momentum retention: avg momentum 1s and 3s after each phase activation
    phase_acts = [e for e in events if e.get("type") == "phase_activated"]
    retention_1s: list[float] = []
    retention_3s: list[float] = []
    for pa in phase_acts:
        t0 = pa.get("t", 0.0)
        for t in ticks:
            tt = t.get("t", 0.0)
            if 0.9 <= (tt - t0) <= 1.1:
                retention_1s.append(t.get("momentum", 0.0))
                break
        for t in ticks:
            tt = t.get("t", 0.0)
            if 2.9 <= (tt - t0) <= 3.1:
                retention_3s.append(t.get("momentum", 0.0))
                break
    if retention_1s:
        m.momentum_retention_1s = sum(retention_1s) / len(retention_1s)
    if retention_3s:
        m.momentum_retention_3s = sum(retention_3s) / len(retention_3s)

    # Expression score (0-100) — composite
    #   state_diversity (25): are all 4 states used? 25/4 per state used
    #   chain_length (25): avg chain length / 5 * 25, capped
    #   momentum_retention (20): momentum_retention_3s / 2.0 * 20
    #   pulse_usage (15): pulse_per_phase capped at 1.0 * 15
    #   phase_cancel_rate (15): rewards intentional cancel (manual) over natural expiry
    states_used = len([s for s in ["FLOAT", "PHASE", "DIVE", "COAST"] if state_ticks.get(s, 0) > 0])
    state_diversity = (states_used / 4.0) * 25
    chain_length_score = min(m.avg_chain_length / 5.0, 1.0) * 25
    momentum_score = min(m.momentum_retention_3s / 2.0, 1.0) * 20
    pulse_score = min(m.pulse_per_phase / 1.0, 1.0) * 15
    cancel_score = m.phase_cancel_rate * 15
    m.expression_score = round(state_diversity + chain_length_score + momentum_score + pulse_score + cancel_score, 1)

    return m


# ---------- Salvage metrics ----------

@dataclass
class SalvageMetrics:
    started: bool = False
    stage: int = 0
    wave: int = 0
    completed: bool = False
    completion_time_s: float = 0.0
    path_taken: str = ""  # "main" or "deeper"
    committed_deeper: bool = False
    deeper_commit_time_s: float = 0.0
    corpses_collected: int = 0
    corpses_from_deeper: int = 0
    spirit_remaining: int = 0
    spirit_max: int = 0
    spirit_lost: int = 0
    shards: int = 0
    qte_total: int = 0
    qte_success: int = 0
    qte_fail: int = 0
    qte_pass_rate: float = 0.0
    qte_by_type: dict[str, dict[str, int]] = field(default_factory=dict)  # type -> {success, fail}
    qte_avg_time_ms: float = 0.0
    damage_events: int = 0
    damage_from_deeper: int = 0


def compute_salvage_metrics(events: list[dict]) -> SalvageMetrics:
    s = SalvageMetrics()
    salvage_start = next((e for e in events if e.get("type") == "salvage_start"), None)
    if salvage_start:
        s.started = True
        s.stage = salvage_start.get("stage", 0)
        s.wave = salvage_start.get("wave", 0)
        s.spirit_max = salvage_start.get("spirit", 3)

    exit_event = next((e for e in events if e.get("type") == "exit_reached"), None)
    if exit_event:
        s.completed = True
        s.completion_time_s = exit_event.get("time_elapsed", 0.0)
        s.path_taken = exit_event.get("path", "main")
        s.committed_deeper = (s.path_taken == "deeper")
        s.corpses_collected = exit_event.get("corpses_collected", 0)
        s.spirit_remaining = exit_event.get("spirit_remaining", 0)
        s.spirit_max = exit_event.get("spirit_max", s.spirit_max)
        s.shards = exit_event.get("shards", 0)
        s.spirit_lost = s.spirit_max - s.spirit_remaining

    commit_event = next((e for e in events if e.get("type") == "crossroads_committed"), None)
    if commit_event:
        s.deeper_commit_time_s = commit_event.get("time_elapsed", 0.0)

    # Corpses
    corpse_events = [e for e in events if e.get("type") == "corpse_collected"]
    s.corpses_from_deeper = sum(1 for e in corpse_events if e.get("is_deeper", False))

    # QTEs
    qte_completions = [e for e in events if e.get("type") == "qte_completed"]
    s.qte_total = len(qte_completions)
    s.qte_success = sum(1 for e in qte_completions if e.get("success", False))
    s.qte_fail = s.qte_total - s.qte_success
    if s.qte_total > 0:
        s.qte_pass_rate = s.qte_success / s.qte_total
        s.qte_avg_time_ms = sum(e.get("time_taken_ms", 0) for e in qte_completions) / s.qte_total
    for e in qte_completions:
        qt = e.get("qte_type", "unknown")
        if qt not in s.qte_by_type:
            s.qte_by_type[qt] = {"success": 0, "fail": 0}
        if e.get("success", False):
            s.qte_by_type[qt]["success"] += 1
        else:
            s.qte_by_type[qt]["fail"] += 1

    # Damage
    damage_events = [e for e in events if e.get("type") == "damage_taken"]
    s.damage_events = len(damage_events)
    s.damage_from_deeper = sum(1 for e in damage_events if e.get("is_deeper", False))

    return s


# ---------- Report generation ----------

def write_report(movement: MovementMetrics, salvage: SalvageMetrics, out_path: str, run_label: str) -> None:
    lines: list[str] = []
    lines.append("=" * 60)
    lines.append("DESIGN LAB REPORT — %s" % run_label)
    lines.append("=" * 60)
    lines.append("")

    # --- Movement ---
    lines.append("MOVEMENT")
    lines.append("-" * 60)
    if movement.total_ticks == 0:
        lines.append("  (no movement telemetry captured)")
    else:
        lines.append("  Total tick samples:    %d (%.1fs of gameplay)" % (movement.total_ticks, movement.total_ticks * 0.1))
        lines.append("  State distribution:")
        for state in ["FLOAT", "PHASE", "DIVE", "COAST"]:
            pct = movement.state_pct.get(state, 0.0)
            secs = movement.state_seconds.get(state, 0.0)
            lines.append("    %-6s  %5.1f%%  (%5.1fs)" % (state, pct, secs))
        lines.append("  Dominant state:        %s (%.1f%%)" % (movement.dominant_state, movement.dominant_state_pct))
        lines.append("")
        lines.append("  Phase activations:     %d" % movement.phase_activations)
        lines.append("    Manual cancels:      %d  (player chose to DIVE)" % movement.phase_cancels_manual)
        lines.append("    Natural expiries:    %d  (v0.36 path — returns to FLOAT)" % movement.phase_expiries_natural)
        lines.append("    Cancel rate:         %.1f%%  (intentional play indicator)" % (movement.phase_cancel_rate * 100))
        lines.append("")
        lines.append("  Pulse fires:           %d  (denials: %d)" % (movement.pulse_fires, movement.pulse_denials))
        lines.append("    Pulse per phase:     %.2f  (active play indicator)" % movement.pulse_per_phase)
        lines.append("")
        lines.append("  Momentum:")
        lines.append("    Average:             %.2f / 2.0" % movement.momentum_avg)
        lines.append("    Peak:                %.2f / 2.0" % movement.momentum_peak)
        lines.append("    Retention +1s:       %.2f  (avg momentum 1s after phase start)" % movement.momentum_retention_1s)
        lines.append("    Retention +3s:       %.2f  (avg momentum 3s after phase start)" % movement.momentum_retention_3s)
        lines.append("")
        lines.append("  Chains:")
        lines.append("    Avg chain length:    %.2f states" % movement.avg_chain_length)
        lines.append("    Top 5 chains:")
        if movement.top_chains:
            for chain_str, count in movement.top_chains:
                lines.append("      %-60s  %d uses" % (chain_str, count))
        else:
            lines.append("      (no multi-state chains detected)")
        lines.append("")
        lines.append("  Expression score:      %.1f / 100" % movement.expression_score)
        lines.append("    (composite: state diversity + chain length + momentum")
        lines.append("     retention + pulse usage + intentional cancel rate)")
    lines.append("")

    # --- Salvage ---
    lines.append("SALVAGE")
    lines.append("-" * 60)
    if not salvage.started:
        lines.append("  (no salvage telemetry captured)")
    else:
        lines.append("  Stage %d Wave %d" % (salvage.stage, salvage.wave))
        if salvage.completed:
            lines.append("  Completed:             YES  (%.1fs)" % salvage.completion_time_s)
            lines.append("  Path taken:            %s" % salvage.path_taken)
        else:
            lines.append("  Completed:             NO  (exited without reaching exit)")
        lines.append("")
        lines.append("  Crossroads:")
        lines.append("    Committed deeper:    %s" % ("YES" if salvage.committed_deeper else "NO"))
        if salvage.committed_deeper:
            lines.append("    Deeper commit time:  %.1fs into run" % salvage.deeper_commit_time_s)
        lines.append("")
        lines.append("  Corpses collected:     %d  (from deeper: %d)" % (salvage.corpses_collected, salvage.corpses_from_deeper))
        lines.append("")
        lines.append("  Spirit:")
        lines.append("    Remaining:           %d / %d  (lost: %d)" % (salvage.spirit_remaining, salvage.spirit_max, salvage.spirit_lost))
        lines.append("")
        lines.append("  QTEs:")
        lines.append("    Total:               %d  (pass: %d, fail: %d)" % (salvage.qte_total, salvage.qte_success, salvage.qte_fail))
        lines.append("    Pass rate:           %.1f%%" % (salvage.qte_pass_rate * 100))
        lines.append("    Avg time:            %.0fms" % salvage.qte_avg_time_ms)
        if salvage.qte_by_type:
            lines.append("    By type:")
            for qt, stats in salvage.qte_by_type.items():
                total = stats["success"] + stats["fail"]
                rate = (stats["success"] / total * 100) if total > 0 else 0
                lines.append("      %-10s  %d/%d  (%.0f%%)" % (qt, stats["success"], total, rate))
        lines.append("")
        lines.append("  Damage:")
        lines.append("    Total events:        %d  (from deeper: %d)" % (salvage.damage_events, salvage.damage_from_deeper))
    lines.append("")
    lines.append("=" * 60)

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def write_metrics_json(movement: MovementMetrics, salvage: SalvageMetrics, out_path: str, run_label: str) -> None:
    data = {
        "label": run_label,
        "movement": {
            "total_ticks": movement.total_ticks,
            "state_seconds": movement.state_seconds,
            "state_pct": movement.state_pct,
            "dominant_state": movement.dominant_state,
            "dominant_state_pct": movement.dominant_state_pct,
            "state_transitions": movement.state_transitions,
            "avg_chain_length": movement.avg_chain_length,
            "top_chains": [{"chain": c, "count": n} for c, n in movement.top_chains],
            "phase_activations": movement.phase_activations,
            "phase_cancels_manual": movement.phase_cancels_manual,
            "phase_expiries_natural": movement.phase_expiries_natural,
            "phase_cancel_rate": movement.phase_cancel_rate,
            "pulse_fires": movement.pulse_fires,
            "pulse_denials": movement.pulse_denials,
            "pulse_per_phase": movement.pulse_per_phase,
            "momentum_avg": movement.momentum_avg,
            "momentum_peak": movement.momentum_peak,
            "momentum_retention_1s": movement.momentum_retention_1s,
            "momentum_retention_3s": movement.momentum_retention_3s,
            "expression_score": movement.expression_score,
        },
        "salvage": {
            "started": salvage.started,
            "stage": salvage.stage,
            "wave": salvage.wave,
            "completed": salvage.completed,
            "completion_time_s": salvage.completion_time_s,
            "path_taken": salvage.path_taken,
            "committed_deeper": salvage.committed_deeper,
            "deeper_commit_time_s": salvage.deeper_commit_time_s,
            "corpses_collected": salvage.corpses_collected,
            "corpses_from_deeper": salvage.corpses_from_deeper,
            "spirit_remaining": salvage.spirit_remaining,
            "spirit_max": salvage.spirit_max,
            "spirit_lost": salvage.spirit_lost,
            "shards": salvage.shards,
            "qte_total": salvage.qte_total,
            "qte_success": salvage.qte_success,
            "qte_fail": salvage.qte_fail,
            "qte_pass_rate": salvage.qte_pass_rate,
            "qte_avg_time_ms": salvage.qte_avg_time_ms,
            "qte_by_type": salvage.qte_by_type,
            "damage_events": salvage.damage_events,
            "damage_from_deeper": salvage.damage_from_deeper,
        },
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


# ---------- Main ----------

def main() -> int:
    ap = argparse.ArgumentParser(description="Design Lab telemetry analyzer")
    ap.add_argument("telemetry_file", help="Path to telemetry_<label>.jsonl")
    ap.add_argument("--out-dir", help="Directory for outputs (default: alongside input)")
    ap.add_argument("--label", help="Run label for report header (default: derived from filename)")
    args = ap.parse_args()

    if not os.path.isfile(args.telemetry_file):
        sys.stderr.write("error: %s not found\n" % args.telemetry_file)
        return 1

    out_dir = args.out_dir or os.path.dirname(args.telemetry_file) or "."
    os.makedirs(out_dir, exist_ok=True)

    label = args.label or os.path.basename(args.telemetry_file).replace("telemetry_", "").replace(".jsonl", "")

    events = load_events(args.telemetry_file)
    print("Loaded %d events from %s" % (len(events), args.telemetry_file))

    movement = compute_movement_metrics(events)
    salvage = compute_salvage_metrics(events)

    metrics_path = os.path.join(out_dir, "metrics.json")
    report_path = os.path.join(out_dir, "report.txt")
    write_metrics_json(movement, salvage, metrics_path, label)
    write_report(movement, salvage, report_path, label)

    print("Wrote %s" % metrics_path)
    print("Wrote %s" % report_path)
    print()
    with open(report_path, "r", encoding="utf-8") as f:
        sys.stdout.write(f.read())
    return 0


if __name__ == "__main__":
    sys.exit(main())
