#!/usr/bin/env python3
"""Stage 8: Quality Scorer — computes measurable composition quality scores.

Reads analysis.json (from analyze_midi.py) and produces a quality report
with CONCRETE SCORES (0-100) for each dimension.

Scoring dimensions:
  HOOK              — motif memorability (reuse ratio + unique motif count)
  VOICE LEADING     — smoothness of melodic motion (avg leap, no big jumps)
  PHRASE DEV        — phrase structure (phrase lengths, variation)
  RHYTHM            — rhythmic interest (syncopation, density, duration variety)
  MOTIF             — motif development (repeats, variations, transformations)
  TENSION           — harmonic tension (borrowed chords, altered tones, key changes)
  REGISTER BALANCE  — spread across registers (bass/mid/high balance)
  DENSITY           — layer density (not too sparse, not too dense)
  OVERALL           — weighted average

Usage:
  python3 tools/music/score_music.py [--target HOOK=85,MOTIF=85]
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).parent.parent.parent
ANALYSIS_PATH = REPO / "tools" / "music" / "analysis.json"

def score_hook(analysis):
    """Motif memorability: high reuse ratio, few unique motifs that repeat."""
    m = analysis.get('melody', {})
    reuse = m.get('motif_reuse_ratio', 0)
    unique = m.get('unique_motifs', 0)
    repeats = sum(m.get('repeated_motifs', {}).values()) if m.get('repeated_motifs') else 0
    
    # Ideal: 60-80% reuse, 4-8 unique motifs that repeat
    reuse_score = min(100, reuse * 125)  # 0.8 = 100
    unique_score = 100 if 4 <= unique <= 8 else (50 if unique <= 12 else 25)
    
    return int(reuse_score * 0.6 + unique_score * 0.4)

def score_voice_leading(analysis):
    """Smoothness: low avg leap, no leaps > 9 semitones."""
    m = analysis.get('melody', {})
    avg_leap = m.get('avg_leap_semitones', 99)
    max_leap = m.get('largest_leap_semitones', 99)
    
    # Ideal: avg leap 2-4 semitones, max leap <= 7 (perfect 5th)
    avg_score = 100 if 2 <= avg_leap <= 4 else (80 if avg_leap <= 5 else 50)
    max_score = 100 if max_leap <= 7 else (70 if max_leap <= 9 else 40)
    
    return int(avg_score * 0.6 + max_score * 0.4)

def score_phrase_dev(analysis):
    """Phrase structure: varied phrase lengths, not all same."""
    m = analysis.get('melody', {})
    phrases = m.get('phrase_lengths', [])
    
    if not phrases:
        return 30  # no phrase structure detected
    
    # Ideal: 2-4 phrases of 4-8 bars each, with variation
    unique_lengths = len(set(phrases))
    avg_len = sum(phrases) / len(phrases) if phrases else 0
    
    len_score = 100 if 4 <= avg_len <= 8 else (60 if avg_len <= 12 else 30)
    var_score = 100 if unique_lengths >= 2 else 50
    
    return int(len_score * 0.5 + var_score * 0.5)

def score_rhythm(analysis):
    """Rhythmic interest: syncopation + duration variety + reasonable density."""
    r = analysis.get('rhythm', {})
    sync = r.get('syncopation_ratio', 0)
    density = r.get('note_density_per_bar', 0)
    durations = r.get('duration_distribution', {})
    
    # Ideal: 20-40% syncopation, 4-8 notes/bar, 2-3 duration values
    sync_score = 100 if 0.2 <= sync <= 0.4 else (70 if sync <= 0.5 else 40)
    density_score = 100 if 4 <= density <= 8 else (60 if density <= 10 else 30)
    dur_score = 100 if len(durations) >= 3 else (60 if len(durations) >= 2 else 30)
    
    return int(sync_score * 0.4 + density_score * 0.3 + dur_score * 0.3)

def score_motif(analysis):
    """Motif development: repeats + variations across sections."""
    m = analysis.get('melody', {})
    repeats = m.get('repeated_motifs', {})
    unique = m.get('unique_motifs', 0)
    
    if not repeats:
        return 20  # no motif reuse = not memorable
    
    # Ideal: 3-5 motifs repeated 3+ times each, with variation
    repeat_count = len(repeats)
    total_repeats = sum(repeats.values())
    
    count_score = 100 if 3 <= repeat_count <= 5 else (70 if repeat_count <= 7 else 40)
    volume_score = 100 if total_repeats >= 15 else (60 if total_repeats >= 10 else 30)
    
    return int(count_score * 0.5 + volume_score * 0.5)

def score_tension(analysis):
    """Harmonic tension: borrowed chords + key changes + altered tones."""
    h = analysis.get('harmony', {})
    borrowed = h.get('borrowed_chords', 0)
    unique_roots = h.get('unique_bass_roots', 0)
    key_conf = h.get('key_confidence', 0)
    
    # Ideal: some borrowed chords (2-6), 5-8 unique roots, key confidence 50-70%
    borrowed_score = 100 if 2 <= borrowed <= 6 else (70 if borrowed <= 8 else 40)
    root_score = 100 if 5 <= unique_roots <= 8 else (60 if unique_roots <= 10 else 30)
    conf_score = 100 if 0.5 <= key_conf <= 0.7 else (60 if key_conf >= 0.3 else 30)
    
    return int(borrowed_score * 0.4 + root_score * 0.3 + conf_score * 0.3)

def score_register_balance(analysis):
    """Register spread: bass/mid/high all represented."""
    b = analysis.get('bass', {})
    m = analysis.get('melody', {})
    
    bass_range = b.get('range_semitones', 0)
    mel_range = m.get('range_semitones', 0)
    bass_stable = b.get('register_stable', False)
    
    # Ideal: bass 10-12 semitones (one octave), melody 12-18 semitones (1.5 octaves)
    bass_score = 100 if 8 <= bass_range <= 14 else 60
    mel_score = 100 if 12 <= mel_range <= 18 else (70 if mel_range <= 24 else 40)
    stable_score = 100 if bass_stable else 50
    
    return int(bass_score * 0.3 + mel_score * 0.4 + stable_score * 0.3)

def score_density(analysis):
    """Layer density: not too sparse, not too dense."""
    l = analysis.get('layers', {})
    poly = l.get('estimated_avg_polyphony', 0)
    
    # Ideal: 10-18 notes avg polyphony
    if 10 <= poly <= 18:
        return 100
    elif poly <= 22:
        return 70
    elif poly <= 25:
        return 40
    else:
        return 20

def main():
    if not ANALYSIS_PATH.exists():
        print("ERROR: analysis.json not found. Run analyze_midi.py first.")
        sys.exit(1)
    
    with open(ANALYSIS_PATH) as f:
        analysis = json.load(f)
    
    scores = {
        "HOOK": score_hook(analysis),
        "VOICE LEADING": score_voice_leading(analysis),
        "PHRASE DEV": score_phrase_dev(analysis),
        "RHYTHM": score_rhythm(analysis),
        "MOTIF": score_motif(analysis),
        "TENSION": score_tension(analysis),
        "REGISTER BALANCE": score_register_balance(analysis),
        "DENSITY": score_density(analysis),
    }
    
    # Weighted overall
    weights = {
        "HOOK": 0.20,
        "VOICE LEADING": 0.10,
        "PHRASE DEV": 0.15,
        "RHYTHM": 0.15,
        "MOTIF": 0.15,
        "TENSION": 0.10,
        "REGISTER BALANCE": 0.05,
        "DENSITY": 0.10,
    }
    overall = sum(scores[k] * weights[k] for k in scores)
    scores["OVERALL"] = int(overall)
    
    # Print
    print("=" * 50)
    print("QUALITY SCORES")
    print("=" * 50)
    for k, v in scores.items():
        bar = "█" * (v // 5) + "░" * (20 - v // 5)
        status = "✓" if v >= 80 else ("⚠" if v >= 60 else "✗")
        if k == "OVERALL":
            print(f"\n  {k:20s} {bar} {v:3d} {status}")
        else:
            print(f"  {k:20s} {bar} {v:3d} {status}")
    
    # Recommendations
    print("\n" + "=" * 50)
    print("RECOMMENDATIONS")
    print("=" * 50)
    
    if scores["HOOK"] < 80:
        print("  • HOOK: increase motif reuse (currently %.0f%%). Aim for 60-80%%." % (analysis['melody']['motif_reuse_ratio'] * 100))
    if scores["VOICE LEADING"] < 80:
        m = analysis['melody']
        print(f"  • VOICE LEADING: avg leap {m['avg_leap_semitones']} st, max {m['largest_leap_semitones']} st. Reduce leaps > 7 st.")
    if scores["PHRASE DEV"] < 80:
        print(f"  • PHRASE DEV: phrase lengths {analysis['melody']['phrase_lengths']}. Add 4-8 bar phrases with variation.")
    if scores["RHYTHM"] < 80:
        r = analysis['rhythm']
        print(f"  • RHYTHM: syncopation {r['syncopation_ratio']}, density {r['note_density_per_bar']}/bar, {len(r['duration_distribution'])} durations. Add syncopation + duration variety.")
    if scores["MOTIF"] < 80:
        print(f"  • MOTIF: {len(analysis['melody']['repeated_motifs'])} repeated motifs. Aim for 3-5 motifs repeated 3+ times.")
    if scores["TENSION"] < 80:
        h = analysis['harmony']
        print(f"  • TENSION: {h['borrowed_chords']} borrowed chords, key confidence {h['key_confidence']}. Add modal interchange.")
    if scores["DENSITY"] < 80:
        l = analysis['layers']
        print(f"  • DENSITY: est. {l['estimated_avg_polyphony']} voices. Reduce to 10-18 for clarity.")
    
    # Save
    score_path = REPO / "tools" / "music" / "scores.json"
    with open(score_path, 'w') as f:
        json.dump(scores, f, indent=2)
    print(f"\nSaved: {score_path}")

if __name__ == "__main__":
    main()
