#!/usr/bin/env python3
"""
Design Lab — Movement + Salvage telemetry analyzer (v2).

Supports BOTH movement models automatically (no flags needed):
  - 4-state model (main branch, v0.36+): FLOAT / PHASE / DIVE / COAST
  - 2-state model (game-nightly branch): NORMAL / PHASE (+ is_coasting flag)

Profile is auto-detected from the tick stream. Constitution rules and
metric computation adapt to whichever profile the run uses.

New in v2 (per ChatGPT Design Lab advice + user direction):
  - Momentum conservation curve (PF lesson: momentum should decay as a curve,
    not a cliff — sample avg momentum at 0/0.5/1/2/3/5s after phase activation)
  - Recovery rate after mistakes (QTE failures + wall collisions — how fast
    does momentum recover to pre-mistake levels?)
  - Decision frequency (phase activations + pulses per 10s — meaningful
    choices per unit time, not APM)
  - is_coasting duration (for 2-state model where COAST is a momentum tier,
    not a state — measures how long the player stays above the coasting
    threshold per coast entry)
  - N-gram chain miner (transitions by frequency + direction)
  - Velocity profile (per-tile bucketed, text heatmap)
  - Design notes field (free-text hypothesis per run)

Usage:
    python3 analyze.py <telemetry.jsonl> [--out-dir DIR] [--notes "free text"]

If --out-dir is omitted, outputs go alongside the input file.

Event types consumed:
    run_start, run_end
    state_change           {from, to, pos, vel, momentum, [chain_count]}
    tick                   {state, [is_coasting], pos, vel, speed_pct, momentum,
                            [chain_count], input, phase_active, phase_cd}  # 10Hz
    phase_activated        {[from_coast|from_coasting], momentum, [chain_count], pos, shards_remaining}
    phase_expired_natural  {pos, vel, momentum, [chain_count]}    # v0.36 path
    dive_entered           {energy_pct, momentum_before, momentum_after,
                            [chain_count|impulse_mult], pos}      # manual cancel
    coast_entered          {momentum, pos}                         # 2-state synthetic
    coast_exited           {momentum, pos}                         # 2-state synthetic
    pulse_fired            {momentum_before, momentum_after, state, [is_coasting], pos}
    pulse_denied           {momentum, pos}
    salvage_start          {stage, wave, spirit, shards, fork_y, deeper_h, deeper_w, corridor_w, hazard_count}
    crossroads_committed   {pos, time_elapsed, spirit, shards, momentum}
    qte_started            {qte_type, hazard_type, is_deeper, [is_gate], pos}
    qte_completed          {qte_type, hazard_type, is_deeper, [is_gate], success, time_taken_ms}
    corpse_collected       {corpse_name, gear_name, gear_type, is_deeper, pos, time_elapsed, collected_count}
    damage_taken           {cause, is_deeper, [is_gate], pos, spirit_remaining, time_elapsed}
    exit_reached           {path, time_elapsed, corpses_collected, spirit_remaining, spirit_max, shards}
"""
from __future__ import annotations

import argparse
import json
import math
import os
import sys
from collections import Counter, defaultdict
from dataclasses import dataclass, field
from typing import Any


# ---------- Movement profiles ----------

@dataclass
class MovementProfile:
    """Describes a movement model. Auto-detected from telemetry."""
    name: str  # "4state" or "2state"
    states: list[str]  # all possible states
    float_state: str  # the "default" walking state (FLOAT or NORMAL)
    phase_state: str  # always "PHASE"
    has_dive_state: bool  # DIVE is a discrete state (4-state only)
    has_coast_state: bool  # COAST is a discrete state (4-state only)
    uses_is_coasting_flag: bool  # 2-state: coast is a momentum tier, tracked via flag

    @property
    def state_diversity_max(self) -> int:
        """How many states count toward the diversity score."""
        return len(self.states)


def detect_profile(events: list[dict]) -> MovementProfile:
    """Detect movement model from tick stream."""
    states_seen: set[str] = set()
    has_is_coasting_flag: bool = False
    for e in events:
        if e.get("type") == "tick":
            s = e.get("state", "")
            if s:
                states_seen.add(s)
            if "is_coasting" in e:
                has_is_coasting_flag = True
    if "NORMAL" in states_seen:
        return MovementProfile(
            name="2state",
            states=["NORMAL", "PHASE"],
            float_state="NORMAL",
            phase_state="PHASE",
            has_dive_state=False,
            has_coast_state=False,
            uses_is_coasting_flag=True,
        )
    # Default to 4-state (FLOAT/PHASE/DIVE/COAST)
    return MovementProfile(
        name="4state",
        states=["FLOAT", "PHASE", "DIVE", "COAST"],
        float_state="FLOAT",
        phase_state="PHASE",
        has_dive_state=True,
        has_coast_state=True,
        uses_is_coasting_flag=False,
    )


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
    profile_name: str = ""
    total_ticks: int = 0
    state_seconds: dict[str, float] = field(default_factory=dict)
    state_pct: dict[str, float] = field(default_factory=dict)
    state_transitions: dict[str, int] = field(default_factory=dict)  # "FROM->TO" -> count
    chains: list[list[str]] = field(default_factory=list)
    chain_lengths: list[int] = field(default_factory=list)
    avg_chain_length: float = 0.0
    top_chains: list[tuple[str, int]] = field(default_factory=list)
    top_transitions: list[tuple[str, int]] = field(default_factory=list)  # n-gram miner
    phase_activations: int = 0
    phase_cancels_manual: int = 0  # dive_entered events (impulse fired)
    phase_expiries_natural: int = 0  # phase_expired_natural events
    phase_cancel_rate: float = 0.0  # manual / (manual + natural)
    pulse_fires: int = 0
    pulse_denials: int = 0
    pulse_per_phase: float = 0.0
    decision_frequency: float = 0.0  # decisions per 10s (phase activations + pulses)
    momentum_avg: float = 0.0
    momentum_peak: float = 0.0
    momentum_retention_1s: float = 0.0
    momentum_retention_3s: float = 0.0
    momentum_curve: dict[str, float] = field(default_factory=dict)  # {"0s": x, "0.5s": y, ...}
    momentum_recovery_after_mistake: float = 0.0  # avg time to recover to pre-damage momentum
    coast_entries: int = 0
    coast_duration_avg: float = 0.0  # avg seconds per coast (for 2-state: is_coasting durations; for 4-state: COAST state time)
    expression_score: float = 0.0
    dominant_state: str = ""
    dominant_state_pct: float = 0.0


def compute_movement_metrics(events: list[dict], profile: MovementProfile) -> MovementMetrics:
    m = MovementMetrics()
    m.profile_name = profile.name
    ticks = [e for e in events if e.get("type") == "tick"]
    m.total_ticks = len(ticks)
    if m.total_ticks == 0:
        return m

    # --- State time distribution ---
    state_ticks: Counter = Counter()
    for t in ticks:
        state_ticks[t.get("state", "?")] += 1
    total_seconds = m.total_ticks * 0.1
    for state, count in state_ticks.items():
        m.state_seconds[state] = count * 0.1
        m.state_pct[state] = (count / m.total_ticks) * 100.0
    if state_ticks:
        m.dominant_state, top_count = state_ticks.most_common(1)[0]
        m.dominant_state_pct = (top_count / m.total_ticks) * 100.0

    # --- State sequence + chains ---
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

    # Chains: split on returns to float_state (FLOAT or NORMAL)
    current_chain: list[str] = []
    for s in state_seq:
        if s == profile.float_state and len(current_chain) > 0:
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

    # Top chains (full sequences)
    chain_strs: Counter = Counter()
    for c in m.chains:
        if len(c) >= 2:
            chain_strs[" -> ".join(c)] += 1
    m.top_chains = chain_strs.most_common(5)

    # Top transitions (n-gram miner — single transitions)
    m.top_transitions = sorted(m.state_transitions.items(), key=lambda x: -x[1])[:8]

    # --- Phase activation / cancel / expiry ---
    m.phase_activations = sum(1 for e in events if e.get("type") == "phase_activated")
    m.phase_expiries_natural = sum(1 for e in events if e.get("type") == "phase_expired_natural")
    m.phase_cancels_manual = sum(1 for e in events if e.get("type") == "dive_entered")
    total_phase_exits = m.phase_cancels_manual + m.phase_expiries_natural
    if total_phase_exits > 0:
        m.phase_cancel_rate = m.phase_cancels_manual / total_phase_exits

    # --- Pulse ---
    m.pulse_fires = sum(1 for e in events if e.get("type") == "pulse_fired")
    m.pulse_denials = sum(1 for e in events if e.get("type") == "pulse_denied")
    if m.phase_activations > 0:
        m.pulse_per_phase = m.pulse_fires / m.phase_activations

    # --- Decision frequency (phase activations + pulses per 10s) ---
    run_end = next((e for e in reversed(events) if e.get("type") == "run_end"), None)
    elapsed = run_end.get("elapsed", 0.0) if run_end else (ticks[-1].get("t", 0.0) if ticks else 0.0)
    if elapsed > 0:
        m.decision_frequency = ((m.phase_activations + m.pulse_fires) / elapsed) * 10.0

    # --- Momentum ---
    if ticks:
        momenta = [t.get("momentum", 0.0) for t in ticks]
        m.momentum_avg = sum(momenta) / len(momenta)
        m.momentum_peak = max(momenta)

    # --- Momentum retention (1s, 3s after phase activation) ---
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

    # --- Momentum conservation curve (PF lesson) ---
    # Sample avg momentum at 0, 0.5, 1, 2, 3, 5s after each phase activation.
    curve_points = [0.0, 0.5, 1.0, 2.0, 3.0, 5.0]
    for sample_t in curve_points:
        samples: list[float] = []
        for pa in phase_acts:
            t0 = pa.get("t", 0.0)
            for t in ticks:
                tt = t.get("t", 0.0)
                if sample_t - 0.1 <= (tt - t0) <= sample_t + 0.1:
                    samples.append(t.get("momentum", 0.0))
                    break
        if samples:
            m.momentum_curve[f"{sample_t}s"] = sum(samples) / len(samples)

    # --- Recovery rate after mistakes ---
    # For each damage_taken event, find momentum before + time to recover to that level.
    damage_events = [e for e in events if e.get("type") == "damage_taken"]
    recovery_times: list[float] = []
    for dmg in damage_events:
        t_dmg = dmg.get("t", 0.0)
        # Find momentum at the tick just before damage
        pre_momentum = 0.0
        for t in ticks:
            if t.get("t", 0.0) >= t_dmg:
                break
            pre_momentum = t.get("momentum", 0.0)
        # Find time when momentum recovers to pre_momentum
        for t in ticks:
            tt = t.get("t", 0.0)
            if tt > t_dmg and t.get("momentum", 0.0) >= pre_momentum:
                recovery_times.append(tt - t_dmg)
                break
    if recovery_times:
        m.momentum_recovery_after_mistake = sum(recovery_times) / len(recovery_times)

    # --- Coast duration ---
    if profile.uses_is_coasting_flag:
        # 2-state: measure is_coasting=True durations from ticks
        coast_segments: list[float] = []
        in_coast = False
        seg_start = 0.0
        for t in ticks:
            tt = t.get("t", 0.0)
            is_c = t.get("is_coasting", False)
            if is_c and not in_coast:
                in_coast = True
                seg_start = tt
                m.coast_entries += 1
            elif not is_c and in_coast:
                in_coast = False
                coast_segments.append(tt - seg_start)
        if in_coast and ticks:
            coast_segments.append(ticks[-1].get("t", 0.0) - seg_start)
        if coast_segments:
            m.coast_duration_avg = sum(coast_segments) / len(coast_segments)
    elif profile.has_coast_state:
        # 4-state: measure COAST state durations from ticks
        coast_segments: list[float] = []
        in_coast = False
        seg_start = 0.0
        for t in ticks:
            tt = t.get("t", 0.0)
            is_c = t.get("state") == "COAST"
            if is_c and not in_coast:
                in_coast = True
                seg_start = tt
                m.coast_entries += 1
            elif not is_c and in_coast:
                in_coast = False
                coast_segments.append(tt - seg_start)
        if in_coast and ticks:
            coast_segments.append(ticks[-1].get("t", 0.0) - seg_start)
        if coast_segments:
            m.coast_duration_avg = sum(coast_segments) / len(coast_segments)
    else:
        # Fallback: use coast_entered events (2-state synthetic)
        m.coast_entries = sum(1 for e in events if e.get("type") == "coast_entered")

    # --- Expression score (0-100) — profile-aware ---
    states_used = len([s for s in profile.states if state_ticks.get(s, 0) > 0])
    state_diversity = (states_used / profile.state_diversity_max) * 25
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
    path_taken: str = ""
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
    qte_by_type: dict[str, dict[str, int]] = field(default_factory=dict)
    qte_avg_time_ms: float = 0.0
    qte_gate_total: int = 0  # QTEs at the deeper gate
    qte_gate_pass: int = 0
    damage_events: int = 0
    damage_from_deeper: int = 0
    damage_from_gate: int = 0


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

    corpse_events = [e for e in events if e.get("type") == "corpse_collected"]
    s.corpses_from_deeper = sum(1 for e in corpse_events if e.get("is_deeper", False))

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
        if e.get("is_gate", False):
            s.qte_gate_total += 1
            if e.get("success", False):
                s.qte_gate_pass += 1

    damage_events = [e for e in events if e.get("type") == "damage_taken"]
    s.damage_events = len(damage_events)
    s.damage_from_deeper = sum(1 for e in damage_events if e.get("is_deeper", False))
    s.damage_from_gate = sum(1 for e in damage_events if e.get("is_gate", False))

    return s


# ---------- Velocity profile (text heatmap) ----------

def compute_velocity_profile(events: list[dict], profile: MovementProfile) -> dict:
    """Bucket positions into a coarse grid, compute avg speed per bucket.
    Returns dict with grid dimensions + list of (bucket_x, bucket_y, avg_speed, visit_count)."""
    ticks = [e for e in events if e.get("type") == "tick"]
    if not ticks:
        return {"buckets": []}
    # Determine world bounds from ticks
    xs = [t.get("pos", [0, 0])[0] for t in ticks]
    ys = [t.get("pos", [0, 0])[1] for t in ticks]
    if not xs or not ys:
        return {"buckets": []}
    x_min, x_max = min(xs), max(xs)
    y_min, y_max = min(ys), max(ys)
    # Bucket size: 32px (2 tiles at 16px/tile)
    bucket_size = 32
    buckets: dict[tuple[int, int], list[float]] = defaultdict(list)
    for t in ticks:
        pos = t.get("pos", [0, 0])
        vel = t.get("vel", [0, 0])
        bx = int(pos[0] // bucket_size)
        by = int(pos[1] // bucket_size)
        speed = math.sqrt(vel[0] ** 2 + vel[1] ** 2)
        buckets[(bx, by)].append(speed)
    bucket_list = []
    for (bx, by), speeds in buckets.items():
        avg_speed = sum(speeds) / len(speeds)
        bucket_list.append({
            "bx": bx, "by": by,
            "avg_speed": round(avg_speed, 1),
            "visit_count": len(speeds),
            "x_range": [bx * bucket_size, (bx + 1) * bucket_size],
            "y_range": [by * bucket_size, (by + 1) * bucket_size],
        })
    return {
        "bucket_size": bucket_size,
        "world_bounds": {"x": [x_min, x_max], "y": [y_min, y_max]},
        "buckets": sorted(bucket_list, key=lambda b: -b["visit_count"])[:20],  # top 20 by visits
    }


# ---------- Report generation ----------

def write_report(movement: MovementMetrics, salvage: SalvageMetrics, profile: MovementProfile,
                 velocity_profile: dict, out_path: str, run_label: str, notes: str) -> None:
    lines: list[str] = []
    lines.append("=" * 60)
    lines.append("DESIGN LAB REPORT — %s" % run_label)
    lines.append("=" * 60)
    if notes:
        lines.append("")
        lines.append("DESIGN NOTES: %s" % notes)
    lines.append("")
    lines.append("Movement profile: %s (states: %s)" % (profile.name, ", ".join(profile.states)))
    lines.append("")

    # --- Movement ---
    lines.append("MOVEMENT")
    lines.append("-" * 60)
    if movement.total_ticks == 0:
        lines.append("  (no movement telemetry captured)")
    else:
        lines.append("  Total tick samples:    %d (%.1fs of gameplay)" % (movement.total_ticks, movement.total_ticks * 0.1))
        lines.append("  State distribution:")
        for state in profile.states:
            pct = movement.state_pct.get(state, 0.0)
            secs = movement.state_seconds.get(state, 0.0)
            lines.append("    %-6s  %5.1f%%  (%5.1fs)" % (state, pct, secs))
        if profile.uses_is_coasting_flag:
            # For 2-state, also show is_coasting time
            coast_secs = movement.state_seconds.get(profile.float_state, 0.0)  # placeholder
            lines.append("    (is_coasting=True for %.1f%% of NORMAL ticks)" % (movement.coast_duration_avg * 100 if movement.coast_duration_avg else 0))
        lines.append("  Dominant state:        %s (%.1f%%)" % (movement.dominant_state, movement.dominant_state_pct))
        lines.append("")
        lines.append("  Phase activations:     %d" % movement.phase_activations)
        lines.append("    Manual cancels:      %d  (impulse fired)" % movement.phase_cancels_manual)
        lines.append("    Natural expiries:    %d  (v0.36 path — clean exit)" % movement.phase_expiries_natural)
        lines.append("    Cancel rate:         %.1f%%  (intentional play indicator)" % (movement.phase_cancel_rate * 100))
        lines.append("")
        lines.append("  Pulse fires:           %d  (denials: %d)" % (movement.pulse_fires, movement.pulse_denials))
        lines.append("    Pulse per phase:     %.2f  (active play indicator)" % movement.pulse_per_phase)
        lines.append("    Decision frequency:  %.2f decisions/10s  (phase+pulse)" % movement.decision_frequency)
        lines.append("")
        lines.append("  Momentum:")
        lines.append("    Average:             %.2f / 2.0" % movement.momentum_avg)
        lines.append("    Peak:                %.2f / 2.0" % movement.momentum_peak)
        lines.append("    Retention +1s:       %.2f" % movement.momentum_retention_1s)
        lines.append("    Retention +3s:       %.2f" % movement.momentum_retention_3s)
        if movement.momentum_curve:
            lines.append("    Conservation curve: (PF 'momentum has memory' check)")
            for sample_t, val in movement.momentum_curve.items():
                bar = "#" * int(val * 10)
                lines.append("      %4s: %.2f %s" % (sample_t, val, bar))
        if movement.momentum_recovery_after_mistake > 0:
            lines.append("    Recovery after mistake: %.2fs avg (time to regain pre-damage momentum)" % movement.momentum_recovery_after_mistake)
        lines.append("")
        lines.append("  Coast:")
        lines.append("    Entries:             %d" % movement.coast_entries)
        lines.append("    Avg duration:        %.2fs" % movement.coast_duration_avg)
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
        lines.append("  Top transitions (n-gram miner):")
        if movement.top_transitions:
            for trans, count in movement.top_transitions:
                lines.append("      %-40s  %d" % (trans, count))
        else:
            lines.append("      (no transitions)")
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
        if salvage.qte_gate_total > 0:
            lines.append("    Gate QTEs:           %d/%d passed  (%.0f%%)" % (
                salvage.qte_gate_pass, salvage.qte_gate_total,
                (salvage.qte_gate_pass / salvage.qte_gate_total * 100)))
        if salvage.qte_by_type:
            lines.append("    By type:")
            for qt, stats in salvage.qte_by_type.items():
                total = stats["success"] + stats["fail"]
                rate = (stats["success"] / total * 100) if total > 0 else 0
                lines.append("      %-10s  %d/%d  (%.0f%%)" % (qt, stats["success"], total, rate))
        lines.append("")
        lines.append("  Damage:")
        lines.append("    Total events:        %d  (from deeper: %d, from gate: %d)" % (
            salvage.damage_events, salvage.damage_from_deeper, salvage.damage_from_gate))
    lines.append("")

    # --- Velocity profile ---
    if velocity_profile.get("buckets"):
        lines.append("VELOCITY PROFILE (top 20 visited buckets, 32px grid)")
        lines.append("-" * 60)
        lines.append("  Shows where the ghost spent time + how fast it moved there.")
        lines.append("  High visit_count + low avg_speed = stuck/lingering.")
        lines.append("  Low visit_count + high avg_speed = pass-through.")
        for b in velocity_profile["buckets"]:
            speed_bar = "#" * int(b["avg_speed"] / 10)
            lines.append("    bucket(%2d,%2d)  visits=%3d  avg_speed=%5.1f %s" % (
                b["bx"], b["by"], b["visit_count"], b["avg_speed"], speed_bar))
        lines.append("")

    lines.append("=" * 60)

    with open(out_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines) + "\n")


def write_metrics_json(movement: MovementMetrics, salvage: SalvageMetrics, profile: MovementProfile,
                       velocity_profile: dict, out_path: str, run_label: str, notes: str) -> None:
    data = {
        "label": run_label,
        "notes": notes,
        "movement_profile": profile.name,
        "movement": {
            "total_ticks": movement.total_ticks,
            "state_seconds": movement.state_seconds,
            "state_pct": movement.state_pct,
            "dominant_state": movement.dominant_state,
            "dominant_state_pct": movement.dominant_state_pct,
            "state_transitions": movement.state_transitions,
            "avg_chain_length": movement.avg_chain_length,
            "top_chains": [{"chain": c, "count": n} for c, n in movement.top_chains],
            "top_transitions": [{"transition": t, "count": n} for t, n in movement.top_transitions],
            "phase_activations": movement.phase_activations,
            "phase_cancels_manual": movement.phase_cancels_manual,
            "phase_expiries_natural": movement.phase_expiries_natural,
            "phase_cancel_rate": movement.phase_cancel_rate,
            "pulse_fires": movement.pulse_fires,
            "pulse_denials": movement.pulse_denials,
            "pulse_per_phase": movement.pulse_per_phase,
            "decision_frequency": movement.decision_frequency,
            "momentum_avg": movement.momentum_avg,
            "momentum_peak": movement.momentum_peak,
            "momentum_retention_1s": movement.momentum_retention_1s,
            "momentum_retention_3s": movement.momentum_retention_3s,
            "momentum_curve": movement.momentum_curve,
            "momentum_recovery_after_mistake": movement.momentum_recovery_after_mistake,
            "coast_entries": movement.coast_entries,
            "coast_duration_avg": movement.coast_duration_avg,
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
            "qte_gate_total": salvage.qte_gate_total,
            "qte_gate_pass": salvage.qte_gate_pass,
            "qte_by_type": salvage.qte_by_type,
            "damage_events": salvage.damage_events,
            "damage_from_deeper": salvage.damage_from_deeper,
            "damage_from_gate": salvage.damage_from_gate,
        },
        "velocity_profile": {
            "bucket_size": velocity_profile.get("bucket_size", 32),
            "buckets": velocity_profile.get("buckets", []),
        },
    }
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)


# ---------- Main ----------

def main() -> int:
    ap = argparse.ArgumentParser(description="Design Lab telemetry analyzer v2")
    ap.add_argument("telemetry_file", help="Path to telemetry_<label>.jsonl")
    ap.add_argument("--out-dir", help="Directory for outputs (default: alongside input)")
    ap.add_argument("--label", help="Run label for report header (default: derived from filename)")
    ap.add_argument("--notes", default="", help="Free-text design hypothesis for this run")
    args = ap.parse_args()

    if not os.path.isfile(args.telemetry_file):
        sys.stderr.write("error: %s not found\n" % args.telemetry_file)
        return 1

    out_dir = args.out_dir or os.path.dirname(args.telemetry_file) or "."
    os.makedirs(out_dir, exist_ok=True)

    label = args.label or os.path.basename(args.telemetry_file).replace("telemetry_", "").replace(".jsonl", "")

    events = load_events(args.telemetry_file)
    print("Loaded %d events from %s" % (len(events), args.telemetry_file))

    profile = detect_profile(events)
    print("Detected movement profile: %s" % profile.name)

    movement = compute_movement_metrics(events, profile)
    salvage = compute_salvage_metrics(events)
    velocity_profile = compute_velocity_profile(events, profile)

    metrics_path = os.path.join(out_dir, "metrics.json")
    report_path = os.path.join(out_dir, "report.txt")
    write_metrics_json(movement, salvage, profile, velocity_profile, metrics_path, label, args.notes)
    write_report(movement, salvage, profile, velocity_profile, report_path, label, args.notes)

    print("Wrote %s" % metrics_path)
    print("Wrote %s" % report_path)
    print()
    with open(report_path, "r", encoding="utf-8") as f:
        sys.stdout.write(f.read())
    return 0


if __name__ == "__main__":
    sys.exit(main())
