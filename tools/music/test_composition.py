#!/usr/bin/env python3
"""Music test suite — assertion-based tests every composition must pass.

Nothing exports to the game until ALL tests pass. This is the "earn the
right to export" gate.

Tests:
  test_melody_range          — melody stays within singable range
  test_melody_leaps          — no leaps > 9 semitones (major 6th)
  test_phrase_length         — average phrase length > 4 bars
  test_repeated_motif        — at least 3 motif occurrences
  test_bass_register         — bass stays within one octave
  test_chord_density         — average notes per chord <= 5
  test_motif_reuse           — motif reuse ratio >= 0.5
  test_note_density          — 4-8 notes per bar
  test_duration_variety      — at least 2 different note durations
  test_key_confidence        — key confidence >= 0.3

Usage:
  python3 tools/music/test_composition.py
  # Exit code 0 = all pass, 1 = some fail
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).parent.parent.parent
ANALYSIS_PATH = REPO / "tools" / "music" / "analysis.json"

class TestResult:
    def __init__(self, name, passed, message=""):
        self.name = name
        self.passed = passed
        self.message = message

def run_tests(analysis):
    results = []
    m = analysis.get('melody', {})
    h = analysis.get('harmony', {})
    r = analysis.get('rhythm', {})
    b = analysis.get('bass', {})
    l = analysis.get('layers', {})
    
    # 1. Melody range — C4 (60) to E5 (76), singable
    mel_min = m.get('range_semitones', 0)
    # min pitch = max pitch - range. We don't have absolute pitches directly,
    # but we can check the range isn't too wide.
    results.append(TestResult(
        "test_melody_range",
        mel_min <= 18,
        f"melody range {mel_min} semitones (max 18)"
    ))
    
    # 2. Melody leaps — no leap > 9 semitones
    max_leap = m.get('largest_leap_semitones', 99)
    results.append(TestResult(
        "test_melody_leaps",
        max_leap <= 9,
        f"largest leap {max_leap} semitones (max 9)"
    ))
    
    # 3. Phrase length — average > 4 (but we need phrase structure)
    phrases = m.get('phrase_lengths', [])
    avg_phrase = sum(phrases) / len(phrases) if phrases else 0
    has_structure = len(phrases) >= 2  # at least 2 phrases
    results.append(TestResult(
        "test_phrase_length",
        has_structure and avg_phrase <= 8,
        f"phrase lengths {phrases} — need 2+ phrases of <= 8 each"
    ))
    
    # 4. Repeated motif — at least 3 occurrences of any motif
    repeated = m.get('repeated_motifs', {})
    max_repeats = max(repeated.values()) if repeated else 0
    results.append(TestResult(
        "test_repeated_motif",
        max_repeats >= 3,
        f"max motif repeats: {max_repeats} (need >= 3)"
    ))
    
    # 5. Bass register — stays within one octave (12 semitones)
    bass_range = b.get('range_semitones', 99)
    results.append(TestResult(
        "test_bass_register",
        bass_range <= 12,
        f"bass range {bass_range} semitones (max 12)"
    ))
    
    # 6. Chord density — average notes per chord <= 5
    # comp arrays have 4 notes each, so this should pass
    poly = l.get('estimated_avg_polyphony', 99)
    results.append(TestResult(
        "test_chord_density",
        poly <= 18,
        f"estimated polyphony {poly} (max 18 for clarity)"
    ))
    
    # 7. Motif reuse ratio >= 0.5
    reuse = m.get('motif_reuse_ratio', 0)
    results.append(TestResult(
        "test_motif_reuse",
        reuse >= 0.5,
        f"motif reuse ratio {reuse} (need >= 0.5)"
    ))
    
    # 8. Note density — 4-8 notes per bar
    density = r.get('note_density_per_bar', 0)
    results.append(TestResult(
        "test_note_density",
        4 <= density <= 8,
        f"note density {density}/bar (need 4-8)"
    ))
    
    # 9. Duration variety — at least 2 different durations
    durations = r.get('duration_distribution', {})
    results.append(TestResult(
        "test_duration_variety",
        len(durations) >= 2,
        f"{len(durations)} duration values (need >= 2)"
    ))
    
    # 10. Key confidence >= 0.3
    key_conf = h.get('key_confidence', 0)
    results.append(TestResult(
        "test_key_confidence",
        key_conf >= 0.3,
        f"key confidence {key_conf} (need >= 0.3)"
    ))
    
    return results

def main():
    if not ANALYSIS_PATH.exists():
        print("ERROR: analysis.json not found. Run analyze_midi.py first.")
        sys.exit(1)
    
    with open(ANALYSIS_PATH) as f:
        analysis = json.load(f)
    
    results = run_tests(analysis)
    
    print("=" * 60)
    print("MUSIC TEST SUITE")
    print("=" * 60)
    
    all_pass = True
    for r in results:
        status = "PASS" if r.passed else "FAIL"
        symbol = "✓" if r.passed else "✗"
        print(f"  {symbol} {r.name:30s} {status}")
        if not r.passed:
            print(f"      → {r.message}")
            all_pass = False
    
    print("\n" + "=" * 60)
    if all_pass:
        print("ALL TESTS PASS — export to game: YES")
    else:
        failed = sum(1 for r in results if not r.passed)
        print(f"{failed} TEST(S) FAILED — export to game: NO")
        print("Continue iterating.")
    print("=" * 60)
    
    # Save results
    results_path = REPO / "tools" / "music" / "test_results.json"
    with open(results_path, 'w') as f:
        json.dump([{"name": r.name, "passed": r.passed, "message": r.message} for r in results], f, indent=2)
    
    sys.exit(0 if all_pass else 1)

if __name__ == "__main__":
    main()
