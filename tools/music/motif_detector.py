#!/usr/bin/env python3
"""Stage 6: Motif detector — find recurring motifs and their variations.

Answers:
  - What is the main motif?
  - Where does it appear (which measures)?
  - What's the variation confidence?
  - How many times does it repeat?

This is the single most useful tool for understanding why something
isn't memorable — if there's no identifiable recurring motif, the
melody won't stick.

Usage:
  python3 tools/music/motif_detector.py
"""
import re
import sys
import math
import json
from pathlib import Path
from collections import defaultdict

REPO = Path(__file__).parent.parent.parent
MUSIC_GD = REPO / "scripts" / "autoload" / "music.gd"

BPM = 128.0
CHORD_DUR_BEATS = 2

def parse_music_gd():
    content = MUSIC_GD.read_text()
    
    melody = []
    melody_match = re.search(r'const MELODY := \[(.*?)\n\]', content, re.DOTALL)
    if melody_match:
        for line in melody_match.group(1).split('\n'):
            line = line.strip()
            m = re.match(r'(MOTIF_\w+)', line)
            if m:
                melody.append(m.group(1))
    
    motifs = {}
    for motif_match in re.finditer(r'const (MOTIF_\w+) := \[(.*?)\n\]', content, re.DOTALL):
        motif_name = motif_match.group(1)
        motif_body = motif_match.group(2)
        notes = []
        for note_match in re.finditer(r'\{pos=([\d.]+),\s*freq=([\d.]+),\s*dur=([\d.]+)\}', motif_body):
            notes.append({
                'pos': float(note_match.group(1)),
                'freq': float(note_match.group(2)),
                'dur': float(note_match.group(3)),
            })
        motifs[motif_name] = notes
    
    return melody, motifs

def freq_to_midi(freq):
    return int(round(69 + 12 * math.log2(freq / 440.0)))

def motif_to_interval_pattern(notes):
    """Convert a motif to its interval pattern (semitone differences)."""
    midis = [freq_to_midi(n['freq']) for n in notes]
    intervals = [midis[i+1] - midis[i] for i in range(len(midis)-1)]
    return intervals

def motifs_similar(motif_a, motif_b, tolerance=2):
    """Check if two motifs are similar (within tolerance semitones per interval)."""
    intervals_a = motif_to_interval_pattern(motif_a)
    intervals_b = motif_to_interval_pattern(motif_b)
    
    if len(intervals_a) != len(intervals_b):
        return False, 0.0
    
    if len(intervals_a) == 0:
        return True, 1.0
    
    diffs = [abs(intervals_a[i] - intervals_b[i]) for i in range(len(intervals_a))]
    avg_diff = sum(diffs) / len(diffs)
    
    # Variation confidence: 1.0 = identical, 0.0 = completely different
    confidence = max(0.0, 1.0 - avg_diff / tolerance)
    
    return confidence > 0.5, confidence

def main():
    melody_names, motifs = parse_music_gd()
    
    # Build the full melody as (start_beat, motif_name, notes)
    melody_sequence = []
    for chord_idx, motif_name in enumerate(melody_names):
        if motif_name in motifs:
            melody_sequence.append((chord_idx, motif_name, motifs[motif_name]))
    
    # Find the most repeated motif (by name)
    from collections import Counter
    name_counts = Counter(melody_names)
    main_motif_name = name_counts.most_common(1)[0][0] if name_counts else None
    
    print("=" * 60)
    print("MOTIF ANALYSIS")
    print("=" * 60)
    
    if main_motif_name:
        main_motif = motifs[main_motif_name]
        main_intervals = motif_to_interval_pattern(main_motif)
        main_midis = [freq_to_midi(n['freq']) for n in main_motif]
        
        print(f"\nMain motif: {main_motif_name}")
        print(f"  Notes:        {[freq_to_name(n['freq']) for n in main_motif]}")
        print(f"  MIDI:         {main_midis}")
        print(f"  Intervals:    {main_intervals}")
        print(f"  Occurrences:  {name_counts[main_motif_name]}")
        
        # Where it appears (which measures)
        appearances = []
        for chord_idx, motif_name, _ in melody_sequence:
            if motif_name == main_motif_name:
                measure = (chord_idx * CHORD_DUR_BEATS) // 4 + 1
                appearances.append(measure)
        print(f"  Measures:     {appearances}")
        
        # Check variations — find motifs with same interval pattern (transposed)
        print(f"\n  Variations (similar interval patterns):")
        variations_found = False
        for motif_name, motif_notes in motifs.items():
            if motif_name == main_motif_name:
                continue
            if len(motif_notes) != len(main_motif):
                continue
            similar, confidence = motifs_similar(main_motif, motif_notes)
            if similar:
                print(f"    {motif_name}: variation confidence {confidence:.0%}")
                print(f"      Intervals: {motif_to_interval_pattern(motif_notes)}")
                variations_found = True
        
        if not variations_found:
            print(f"    (none found)")
    
    # Motif reuse summary
    print(f"\n{'=' * 60}")
    print("MOTIF REUSE SUMMARY")
    print(f"{'=' * 60}")
    print(f"  Total motifs defined:     {len(motifs)}")
    print(f"  Total motifs used:        {len(set(melody_names))}")
    print(f"  Total motif placements:   {len(melody_names)}")
    print(f"  Motif reuse ratio:        {sum(c for n, c in name_counts.items() if c > 1) / len(melody_names):.0%}")
    
    print(f"\n  Motif frequency:")
    for name, count in name_counts.most_common():
        bar = "█" * count
        print(f"    {name:30s} {bar} {count}")
    
    # Identify the "story" of the melody
    print(f"\n{'=' * 60}")
    print("MELODY STORY (sequence of motifs)")
    print(f"{'=' * 60}")
    for i, motif_name in enumerate(melody_names):
        measure = (i * CHORD_DUR_BEATS) // 4 + 1
        beat = (i * CHORD_DUR_BEATS) % 4
        # Mark repeats
        is_repeat = name_counts[motif_name] > 1
        marker = "↻" if is_repeat else " "
        print(f"  M{measure:2d} beat {beat}  {marker} {motif_name}")
    
    # Save
    results = {
        "main_motif": main_motif_name,
        "main_motif_occurrences": name_counts[main_motif_name] if main_motif_name else 0,
        "motif_counts": dict(name_counts),
        "total_motifs_defined": len(motifs),
        "total_motifs_used": len(set(melody_names)),
        "reuse_ratio": sum(c for n, c in name_counts.items() if c > 1) / len(melody_names) if melody_names else 0,
    }
    output_path = REPO / "tools" / "music" / "motif_analysis.json"
    with open(output_path, 'w') as f:
        json.dump(results, f, indent=2)
    print(f"\nSaved: {output_path}")

def freq_to_name(freq):
    midi = freq_to_midi(freq)
    names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    octave = (midi // 12) - 1
    return f"{names[midi % 12]}{octave}"

if __name__ == "__main__":
    main()
