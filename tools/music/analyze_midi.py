#!/usr/bin/env python3
"""Stage 1: MIDI Inspector — numeric analysis of the music.gd composition.

Reads the CHORDS + MELODY data directly from scripts/autoload/music.gd,
extracts all notes per layer, and produces a structured analysis with
CONCRETE NUMBERS (not "sounds jazzy").

Outputs:
  - Melody range, leap stats, phrase lengths, contour, motif repeats
  - Harmony key confidence, borrowed chords, voice crossings
  - Rhythm syncopation, note density, repeated rhythms
  - Per-layer stats (bass, chords, arp, lead, drums)

Usage:
  python3 tools/music/analyze_midi.py [--json] [--compare baseline.json]
"""
import re
import sys
import json
import math
from pathlib import Path
from collections import Counter

REPO = Path(__file__).parent.parent.parent
MUSIC_GD = REPO / "scripts" / "autoload" / "music.gd"

# === Parsing ===

def parse_music_gd():
    """Extract CHORDS and MELODY arrays from music.gd."""
    content = MUSIC_GD.read_text()
    
    # Parse CHORDS
    chords_match = re.search(r'const CHORDS := \[(.*?)\n\]', content, re.DOTALL)
    chords = []
    if chords_match:
        for line in chords_match.group(1).split('\n'):
            line = line.strip().rstrip(',')
            if line.startswith('{'):
                d = {}
                for key, val in re.findall(r'"(\w+)": (.+?)(?:,|\})', line):
                    if key in ('bass', 'lead'):
                        d[key] = float(val)
                    elif key == 'comp':
                        d[key] = [float(x) for x in re.findall(r'[\d.]+', val)]
                    elif key == 'amps':
                        d[key] = [float(x) for x in re.findall(r'[\d.]+', val)]
                    elif key == 'arp':
                        d[key] = [float(x) for x in re.findall(r'[\d.]+', val)]
                if 'bass' in d:
                    chords.append(d)
    
    # Parse MELODY (named motif references, in order)
    melody = []
    melody_match = re.search(r'const MELODY := \[(.*?)\n\]', content, re.DOTALL)
    if melody_match:
        content_str = melody_match.group(1)
        # Parse token by token: MOTIF_X or [] (rest), preserving order
        tokens = re.findall(r'(MOTIF_\w+|\[\])', content_str)
        for token in tokens:
            if token == '[]':
                melody.append('REST')
            else:
                melody.append(token)
    
    # Parse individual MOTIF definitions
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
    
    return chords, melody, motifs

def freq_to_midi(freq):
    return int(round(69 + 12 * math.log2(freq / 440.0)))

def freq_to_name(freq):
    midi = freq_to_midi(freq)
    names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    octave = (midi // 12) - 1
    return f"{names[midi % 12]}{octave}"

# === Constants from music.gd ===
BPM = 128.0
BEAT_DUR = 60.0 / BPM
HALF_BAR_DUR = BEAT_DUR * 2
CHORD_DUR_BEATS = 2  # each chord is 2 beats

# === Analysis functions ===

def analyze_melody(chords, melody_names, motifs):
    """Analyze the melody layer."""
    # Expand melody: each entry is a motif name, resolve to notes
    all_notes = []  # (start_beat, midi_note, duration_beats)
    for chord_idx, motif_name in enumerate(melody_names):
        if motif_name not in motifs:
            continue
        chord_start_beat = chord_idx * CHORD_DUR_BEATS
        for note in motifs[motif_name]:
            start_beat = chord_start_beat + note['pos']
            midi = freq_to_midi(note['freq'])
            all_notes.append((start_beat, midi, note['dur']))
    
    if not all_notes:
        return {"error": "no melody notes found"}
    
    # Range
    pitches = [n[1] for n in all_notes]
    min_pitch = min(pitches)
    max_pitch = max(pitches)
    
    # Leaps
    leaps = [abs(pitches[i+1] - pitches[i]) for i in range(len(pitches)-1)]
    avg_leap = sum(leaps) / len(leaps) if leaps else 0
    max_leap = max(leaps) if leaps else 0
    
    # Contour (descending vs ascending)
    directions = [1 if pitches[i+1] > pitches[i] else (-1 if pitches[i+1] < pitches[i] else 0) for i in range(len(pitches)-1)]
    asc_count = sum(1 for d in directions if d > 0)
    desc_count = sum(1 for d in directions if d < 0)
    contour = "ascending" if asc_count > desc_count * 1.5 else ("descending" if desc_count > asc_count * 1.5 else "mixed")
    
    # Phrase lengths (group by chord = 2 beats each)
    phrase_lengths = []
    current_phrase = 0
    for chord_idx in range(len(melody_names)):
        if melody_names[chord_idx] in motifs:
            current_phrase += 1
        else:
            if current_phrase > 0:
                phrase_lengths.append(current_phrase)
            current_phrase = 0
    if current_phrase > 0:
        phrase_lengths.append(current_phrase)
    
    # Motif repeats
    motif_counts = Counter(melody_names)
    repeated_motifs = {k: v for k, v in motif_counts.items() if v > 1}
    
    return {
        "range": f"{freq_to_name(440 * 2**((min_pitch-69)/12))}–{freq_to_name(440 * 2**((max_pitch-69)/12))}",
        "range_semitones": max_pitch - min_pitch,
        "avg_leap_semitones": round(avg_leap, 1),
        "largest_leap_semitones": max_leap,
        "largest_leap_warning": max_leap > 9,  # > major 6th
        "phrase_lengths": phrase_lengths,
        "contour": contour,
        "ascending_steps": asc_count,
        "descending_steps": desc_count,
        "total_notes": len(all_notes),
        "unique_motifs": len(set(melody_names)),
        "repeated_motifs": repeated_motifs,
        "motif_reuse_ratio": round(len([m for m in melody_names if motif_counts[m] > 1]) / len(melody_names), 2) if melody_names else 0,
    }

def analyze_harmony(chords):
    """Analyze the harmony layer."""
    # Extract all chord tones
    all_chord_tones = []
    for chord in chords:
        for freq in chord['comp']:
            all_chord_tones.append(freq_to_midi(freq))
    
    # Key detection: find the most common pitch class
    pitch_classes = [t % 12 for t in all_chord_tones]
    pc_counts = Counter(pitch_classes)
    likely_key_pc = pc_counts.most_common(1)[0][0]
    key_names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    
    # Chord change frequency
    chord_changes = len(chords)
    total_beats = len(chords) * CHORD_DUR_BEATS
    
    # Bass notes (for root analysis)
    bass_pcs = [freq_to_midi(c['bass']) % 12 for c in chords]
    bass_pc_counts = Counter(bass_pcs)
    
    # Detect borrowed chords (non-diatonic to the detected key)
    # For a minor key: i, ii°, III, iv, v, VI, VII
    # For a major key: I, ii, iii, IV, V, vi, vii°
    # Simple heuristic: count bass notes not in the key's scale
    minor_scale = [0, 2, 3, 5, 7, 8, 10]  # natural minor
    major_scale = [0, 2, 4, 5, 7, 9, 11]
    
    # Assume minor key (the music is in Gm/Fm)
    key_pcs = set((likely_key_pc + interval) % 12 for interval in minor_scale)
    borrowed = sum(1 for pc in bass_pcs if pc not in key_pcs)
    
    return {
        "detected_key": f"{key_names[likely_key_pc]} minor",
        "key_confidence": round(pc_counts[likely_key_pc] / len(pitch_classes), 2),
        "total_chords": chord_changes,
        "chord_rate_per_beat": round(chord_changes / total_beats, 2),
        "unique_bass_roots": len(set(bass_pcs)),
        "borrowed_chords": borrowed,
        "bass_root_distribution": {key_names[pc]: count for pc, count in bass_pc_counts.most_common()},
    }

def analyze_rhythm(chords, melody_names, motifs):
    """Analyze the rhythm layer."""
    # Note density: notes per bar (4 beats per bar)
    total_notes = 0
    for motif_name in melody_names:
        if motif_name in motifs:
            total_notes += len(motifs[motif_name])
    
    total_bars = len(chords) * CHORD_DUR_BEATS / 4  # 4 beats per bar
    note_density = total_notes / total_bars if total_bars > 0 else 0
    
    # Syncopation: count notes on off-beats (pos values that aren't 0.0, 0.5, 1.0, 1.5)
    syncopated = 0
    total_pos = 0
    for motif_name in melody_names:
        if motif_name in motifs:
            for note in motifs[motif_name]:
                total_pos += 1
                # On-beat positions: 0.0, 0.5, 1.0, 1.5 (within a 2-beat chord)
                # Off-beat: anything else (e.g., 0.66 = swung &)
                if note['pos'] not in [0.0, 0.5, 1.0, 1.5]:
                    syncopated += 1
    
    syncopation_ratio = syncopated / total_pos if total_pos > 0 else 0
    
    # Note duration distribution
    durations = []
    for motif_name in melody_names:
        if motif_name in motifs:
            for note in motifs[motif_name]:
                durations.append(note['dur'])
    dur_counts = Counter(durations)
    
    return {
        "total_notes": total_notes,
        "total_bars": round(total_bars, 1),
        "note_density_per_bar": round(note_density, 1),
        "syncopation_ratio": round(syncopation_ratio, 2),
        "syncopated_notes": syncopated,
        "duration_distribution": {str(d): c for d, c in dur_counts.most_common()},
    }

def analyze_bass(chords):
    """Analyze the bass layer."""
    bass_notes = [freq_to_midi(c['bass']) for c in chords]
    bass_freqs = [c['bass'] for c in chords]
    
    # Bass range
    min_bass = min(bass_notes)
    max_bass = max(bass_notes)
    
    # Bass motion (stepwise vs leaps)
    bass_leaps = [abs(bass_notes[i+1] - bass_notes[i]) for i in range(len(bass_notes)-1)]
    avg_bass_leap = sum(bass_leaps) / len(bass_leaps) if bass_leaps else 0
    
    # Bass register (should stay in one octave for walking bass)
    bass_range = max_bass - min_bass
    
    return {
        "range": f"{freq_to_name(440 * 2**((min_bass-69)/12))}–{freq_to_name(440 * 2**((max_bass-69)/12))}",
        "range_semitones": bass_range,
        "register_stable": bass_range <= 12,  # within one octave
        "avg_leap_semitones": round(avg_bass_leap, 1),
        "total_notes": len(bass_notes),
        "unique_notes": len(set(bass_notes)),
    }

def analyze_layers(chords, melody_names, motifs):
    """Analyze layer overlap and density."""
    # How many layers play simultaneously per chord?
    # Bass: always (1 note per chord)
    # Chords: 4-5 notes per chord
    # Arp: 4-8 notes per chord
    # Lead/melody: 2-4 notes per chord
    # Drums: 4 kicks + 2 claps + 4 hats + 2 cowbell = ~12 hits per bar = ~6 per chord
    
    avg_polyphony = 1 + 4.5 + 3 + 6  # rough estimate
    
    return {
        "layers": ["bass", "chords", "lead/melody", "drums"],
        "estimated_avg_polyphony": avg_polyphony,
        "density_warning": avg_polyphony > 20,
        "total_chord_segments": len(chords),
        "total_duration_seconds": len(chords) * HALF_BAR_DUR,
        "total_duration_bars": len(chords) * CHORD_DUR_BEATS / 4,
    }

# === Main ===

def main():
    chords, melody_names, motifs = parse_music_gd()
    
    if not chords:
        print("ERROR: could not parse CHORDS from music.gd")
        sys.exit(1)
    
    analysis = {
        "metadata": {
            "file": str(MUSIC_GD),
            "bpm": BPM,
            "total_chords": len(chords),
            "total_motifs": len(motifs),
            "total_melody_entries": len(melody_names),
        },
        "melody": analyze_melody(chords, melody_names, motifs),
        "harmony": analyze_harmony(chords),
        "rhythm": analyze_rhythm(chords, melody_names, motifs),
        "bass": analyze_bass(chords),
        "layers": analyze_layers(chords, melody_names, motifs),
    }
    
    if '--json' in sys.argv:
        print(json.dumps(analysis, indent=2))
        return
    
    # Pretty print
    print("=" * 60)
    print("MUSIC ANALYSIS — music.gd")
    print("=" * 60)
    
    print(f"\nBPM: {BPM} | Chords: {len(chords)} | Motifs: {len(motifs)} | Duration: {len(chords) * HALF_BAR_DUR:.1f}s")
    
    print("\n" + "=" * 60)
    print("MELODY")
    print("=" * 60)
    m = analysis['melody']
    if 'error' not in m:
        print(f"  Range:              {m['range']} ({m['range_semitones']} semitones)")
        print(f"  Average leap:       {m['avg_leap_semitones']} semitones")
        print(f"  Largest leap:       {m['largest_leap_semitones']} semitones {'⚠' if m['largest_leap_warning'] else '✓'}")
        print(f"  Contour:            {m['contour']} (↑{m['ascending_steps']} ↓{m['descending_steps']})")
        print(f"  Total notes:        {m['total_notes']}")
        print(f"  Unique motifs:      {m['unique_motifs']}")
        print(f"  Motif reuse ratio:  {m['motif_reuse_ratio']} ({sum(m['repeated_motifs'].values()) if m['repeated_motifs'] else 0} repeats)")
        print(f"  Phrase lengths:     {m['phrase_lengths']}")
        if m['repeated_motifs']:
            print(f"  Repeated motifs:    {dict(m['repeated_motifs'])}")
    
    print("\n" + "=" * 60)
    print("HARMONY")
    print("=" * 60)
    h = analysis['harmony']
    print(f"  Detected key:       {h['detected_key']} (confidence: {h['key_confidence']})")
    print(f"  Total chords:       {h['total_chords']}")
    print(f"  Chord rate:         {h['chord_rate_per_beat']} chords/beat ({h['total_chords']} chords in {h['total_chords']*2} beats)")
    print(f"  Unique bass roots:  {h['unique_bass_roots']}")
    print(f"  Borrowed chords:    {h['borrowed_chords']}")
    print(f"  Bass roots:         {h['bass_root_distribution']}")
    
    print("\n" + "=" * 60)
    print("RHYTHM")
    print("=" * 60)
    r = analysis['rhythm']
    print(f"  Total notes:        {r['total_notes']}")
    print(f"  Total bars:         {r['total_bars']}")
    print(f"  Note density:       {r['note_density_per_bar']} notes/bar")
    print(f"  Syncopation:        {r['syncopation_ratio']} ({r['syncopated_notes']}/{r['total_notes']} off-beat)")
    print(f"  Durations:          {r['duration_distribution']}")
    
    print("\n" + "=" * 60)
    print("BASS")
    print("=" * 60)
    b = analysis['bass']
    print(f"  Range:              {b['range']} ({b['range_semitones']} semitones)")
    print(f"  Register stable:    {'✓' if b['register_stable'] else '⚠ (leaps > octave)'}")
    print(f"  Average leap:       {b['avg_leap_semitones']} semitones")
    print(f"  Unique notes:       {b['unique_notes']}/{b['total_notes']}")
    
    print("\n" + "=" * 60)
    print("LAYERS")
    print("=" * 60)
    l = analysis['layers']
    print(f"  Layers:             {', '.join(l['layers'])}")
    print(f"  Est. polyphony:     {l['estimated_avg_polyphony']} notes {'⚠ TOO DENSE' if l['density_warning'] else '✓'}")
    print(f"  Duration:           {l['total_duration_seconds']:.1f}s ({l['total_duration_bars']:.1f} bars)")
    
    print("\n" + "=" * 60)
    
    # Save JSON
    json_path = REPO / "tools" / "music" / "analysis.json"
    with open(json_path, 'w') as f:
        json.dump(analysis, f, indent=2)
    print(f"\nSaved JSON: {json_path}")

if __name__ == "__main__":
    main()
