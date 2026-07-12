#!/usr/bin/env python3
"""Stage 5: Piano-roll visualization — render each layer as a PNG piano roll.

Generates separate PNGs for melody, chords, bass, and a combined view.
Like DAWs show. Humans (and AI) can spot problems visually:
  - giant leaps
  - dead space
  - overly dense chords
  - boring rhythms

Usage:
  python3 tools/music/visualize_piano_roll.py
"""
import re
import sys
import math
from pathlib import Path
from collections import defaultdict

REPO = Path(__file__).parent.parent.parent
MUSIC_GD = REPO / "scripts" / "autoload" / "music.gd"
OUT_DIR = REPO / "tools" / "music" / "output"

# Use matplotlib for piano roll
import matplotlib
matplotlib.use('Agg')  # headless
import matplotlib.pyplot as plt
import matplotlib.patches as patches

BPM = 128.0
BEAT_DUR = 60.0 / BPM
CHORD_DUR_BEATS = 2

def parse_music_gd():
    """Extract CHORDS and MELODY arrays from music.gd."""
    content = MUSIC_GD.read_text()
    
    chords = []
    chords_match = re.search(r'const CHORDS := \[(.*?)\n\]', content, re.DOTALL)
    if chords_match:
        for line in chords_match.group(1).split('\n'):
            line = line.strip().rstrip(',')
            if line.startswith('{'):
                d = {}
                for key, val in re.findall(r'"(\w+)": (.+?)(?:,|\})', line):
                    if key in ('bass', 'lead'):
                        d[key] = float(val)
                    elif key in ('comp', 'amps', 'arp'):
                        d[key] = [float(x) for x in re.findall(r'[\d.]+', val)]
                if 'bass' in d:
                    chords.append(d)
    
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
    
    return chords, melody, motifs

def freq_to_midi(freq):
    return int(round(69 + 12 * math.log2(freq / 440.0)))

def render_piano_roll(notes, title, filename, color='steelblue', min_midi=None, max_midi=None):
    """Render a piano roll from notes list.
    
    notes: [(start_beat, midi_note, duration_beats), ...]
    """
    if not notes:
        print(f"  SKIP {title} (no notes)")
        return
    
    fig, ax = plt.subplots(1, 1, figsize=(14, 5), constrained_layout=True)
    
    # Calculate range
    pitches = [n[1] for n in notes]
    if min_midi is None:
        min_midi = min(pitches) - 2
    if max_midi is None:
        max_midi = max(pitches) + 2
    
    # Draw notes as rectangles
    for start_beat, midi, dur in notes:
        rect = patches.Rectangle(
            (start_beat, midi), dur, 0.8,
            linewidth=0.5, edgecolor='black',
            facecolor=color, alpha=0.8
        )
        ax.add_patch(rect)
    
    # Formatting
    ax.set_xlim(0, max(n[0] + n[2] for n in notes) + 1)
    ax.set_ylim(min_midi, max_midi)
    ax.set_xlabel('Beat')
    ax.set_ylabel('MIDI Note')
    ax.set_title(title, fontsize=14, fontweight='bold')
    
    # Y-axis: note names
    note_names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
    yticks = list(range(min_midi, max_midi + 1))
    ylabels = [f"{note_names[m % 12]}{m // 12 - 1}" for m in yticks]
    ax.set_yticks(yticks)
    ax.set_yticklabels(ylabels, fontsize=7)
    
    # Grid
    ax.grid(True, axis='x', alpha=0.3, linestyle='--')
    ax.grid(True, axis='y', alpha=0.2, linestyle=':')
    
    # Bar lines (every 4 beats = 1 bar)
    max_beat = max(n[0] + n[2] for n in notes)
    for bar in range(0, int(max_beat) + 4, 4):
        ax.axvline(x=bar, color='red', alpha=0.3, linewidth=1)
    
    fig.savefig(filename, dpi=150)
    plt.close(fig)
    print(f"  SAVED {filename}")

def main():
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    
    chords, melody_names, motifs = parse_music_gd()
    
    print("Generating piano rolls...")
    
    # === MELODY ===
    melody_notes = []
    for chord_idx, motif_name in enumerate(melody_names):
        if motif_name not in motifs:
            continue
        chord_start_beat = chord_idx * CHORD_DUR_BEATS
        for note in motifs[motif_name]:
            start_beat = chord_start_beat + note['pos']
            midi = freq_to_midi(note['freq'])
            melody_notes.append((start_beat, midi, note['dur']))
    render_piano_roll(melody_notes, "MELODY", OUT_DIR / "piano_roll_melody.png", color='royalblue')
    
    # === BASS ===
    bass_notes = []
    for chord_idx, chord in enumerate(chords):
        chord_start_beat = chord_idx * CHORD_DUR_BEATS
        # Bass: root on beat 0, chromatic approach on beat 1
        bass_freq = chord['bass']
        next_bass = chords[chord_idx + 1]['bass'] if chord_idx + 1 < len(chords) else chords[0]['bass']
        approach_down = next_bass * pow(2.0, -1.0/12.0)
        approach_up = next_bass * pow(2.0, 1.0/12.0)
        approach = approach_up if bass_freq > next_bass else approach_down
        
        bass_notes.append((chord_start_beat, freq_to_midi(bass_freq), 1.0))
        bass_notes.append((chord_start_beat + 1, freq_to_midi(approach), 1.0))
    render_piano_roll(bass_notes, "BASS", OUT_DIR / "piano_roll_bass.png", color='darkgreen')
    
    # === CHORDS (comp stabs) ===
    # Stab patterns (from music.gd)
    SWING = 0.66
    STAB_PATTERNS = [
        [0, 3, 4, 7], [0, 4, 7], [1, 4, 6], [0, 3, 5], [0, 4], [2, 4, 7],
    ]
    chord_notes = []
    for chord_idx, chord in enumerate(chords):
        chord_start_beat = chord_idx * CHORD_DUR_BEATS
        pattern = STAB_PATTERNS[chord_idx % len(STAB_PATTERNS)]
        for pos in pattern:
            beat_num = pos // 2
            is_off = (pos % 2) == 1
            beat_pos = float(beat_num) + (SWING if is_off else 0.0)
            scaled_pos = beat_pos * 0.5  # scale to 2-beat chord
            for freq in chord['comp']:
                chord_notes.append((chord_start_beat + scaled_pos, freq_to_midi(freq), 0.25))
    render_piano_roll(chord_notes, "CHORDS", OUT_DIR / "piano_roll_chords.png", color='darkorange')
    
    # === COMBINED (all layers) ===
    combined = []
    combined.extend([(s, m, d, 'melody') for s, m, d in melody_notes])
    combined.extend([(s, m, d, 'bass') for s, m, d in bass_notes])
    combined.extend([(s, m, d, 'chords') for s, m, d in chord_notes])
    
    if combined:
        fig, ax = plt.subplots(1, 1, figsize=(16, 8), constrained_layout=True)
        
        colors = {'melody': 'royalblue', 'bass': 'darkgreen', 'chords': 'darkorange'}
        
        for start_beat, midi, dur, layer in combined:
            rect = patches.Rectangle(
                (start_beat, midi), dur, 0.8,
                linewidth=0.3, edgecolor='black',
                facecolor=colors[layer], alpha=0.7
            )
            ax.add_patch(rect)
        
        all_pitches = [c[1] for c in combined]
        ax.set_xlim(0, max(c[0] + c[2] for c in combined) + 1)
        ax.set_ylim(min(all_pitches) - 2, max(all_pitches) + 2)
        ax.set_xlabel('Beat')
        ax.set_ylabel('MIDI Note')
        ax.set_title('COMBINED PIANO ROLL (all layers)', fontsize=14, fontweight='bold')
        
        note_names = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B']
        yticks = list(range(min(all_pitches) - 2, max(all_pitches) + 3))
        ylabels = [f"{note_names[m % 12]}{m // 12 - 1}" for m in yticks]
        ax.set_yticks(yticks)
        ax.set_yticklabels(ylabels, fontsize=6)
        
        ax.grid(True, axis='x', alpha=0.3, linestyle='--')
        for bar in range(0, int(max(c[0] + c[2] for c in combined)) + 4, 4):
            ax.axvline(x=bar, color='red', alpha=0.3, linewidth=1)
        
        # Legend
        from matplotlib.patches import Patch
        legend_elements = [Patch(facecolor=colors[k], label=k.capitalize()) for k in colors]
        ax.legend(handles=legend_elements, loc='upper right')
        
        fig.savefig(OUT_DIR / "piano_roll_combined.png", dpi=150)
        plt.close(fig)
        print(f"  SAVED {OUT_DIR / 'piano_roll_combined.png'}")
    
    print(f"\nAll piano rolls saved to {OUT_DIR}/")

if __name__ == "__main__":
    main()
