#!/usr/bin/env python3
"""Listening dashboard — generate a single HTML page with all artifacts.

Every time music changes, this generates:
  - Quality scores (with bars)
  - Test results (pass/fail)
  - Piano roll images (melody, bass, chords, combined)
  - Spectrogram
  - Motif analysis
  - Melody story (sequence of motifs)
  - Recommendations

Open in browser to inspect everything before deciding what to change.

Usage:
  python3 tools/music/html_report.py
"""
import json
import sys
from pathlib import Path

REPO = Path(__file__).parent.parent.parent
TOOLS = REPO / "tools" / "music"
OUTPUT_DIR = REPO / "generated" / "reports"
PIANO_ROLL_DIR = REPO / "tools" / "music" / "output"
SPECTROGRAM_DIR = REPO / "generated" / "spectrograms"

def load_json(path):
    if path.exists():
        with open(path) as f:
            return json.load(f)
    return {}

def img_tag(path, alt="", max_width="100%"):
    """Generate an <img> tag with relative path if file exists."""
    if path.exists():
        return f'<img src="{path}" alt="{alt}" style="max-width:{max_width};border:1px solid #333;margin:10px 0;">'
    return f'<p style="color:#888;">[not found: {path.name}]</p>'

def generate_html():
    analysis = load_json(TOOLS / "analysis.json")
    scores = load_json(TOOLS / "scores.json")
    test_results = load_json(TOOLS / "test_results.json")
    motif = load_json(TOOLS / "motif_analysis.json")
    
    # Determine export status
    all_pass = all(t.get('passed', False) for t in test_results) if test_results else False
    
    # Build HTML
    html = f"""<!DOCTYPE html>
<html>
<head>
    <meta charset="utf-8">
    <title>Music Analysis Dashboard</title>
    <style>
        body {{ font-family: 'Segoe UI', Arial, sans-serif; background: #1a1a2e; color: #e0e0e0; margin: 20px; }}
        h1 {{ color: #00d4ff; border-bottom: 2px solid #00d4ff; padding-bottom: 10px; }}
        h2 {{ color: #00d4ff; margin-top: 40px; }}
        .score-bar {{ display: inline-block; height: 20px; border-radius: 3px; vertical-align: middle; }}
        .score-pass {{ background: #00ff88; }}
        .score-warn {{ background: #ffaa00; }}
        .score-fail {{ background: #ff4444; }}
        .export-yes {{ background: #00aa44; color: white; padding: 15px; border-radius: 5px; font-size: 1.2em; font-weight: bold; }}
        .export-no {{ background: #aa0000; color: white; padding: 15px; border-radius: 5px; font-size: 1.2em; font-weight: bold; }}
        table {{ border-collapse: collapse; width: 100%; margin: 10px 0; }}
        td, th {{ border: 1px solid #333; padding: 8px; text-align: left; }}
        th {{ background: #16213e; }}
        .test-pass {{ color: #00ff88; }}
        .test-fail {{ color: #ff4444; }}
        img {{ max-width: 100%; border: 1px solid #333; margin: 10px 0; }}
        .grid {{ display: grid; grid-template-columns: 1fr 1fr; gap: 20px; }}
        .card {{ background: #16213e; padding: 15px; border-radius: 5px; }}
    </style>
</head>
<body>
    <h1>🎵 Music Analysis Dashboard</h1>
    <p>BPM: {analysis.get('metadata', {}).get('bpm', '?')} | 
       Chords: {analysis.get('metadata', {}).get('total_chords', '?')} | 
       Motifs: {analysis.get('metadata', {}).get('total_motifs', '?')} |
       Duration: {analysis.get('layers', {}).get('total_duration_seconds', '?')}s</p>
"""
    
    # Export gate
    if all_pass:
        html += '<div class="export-yes">✓ ALL TESTS PASS — Export to game: YES</div>\n'
    else:
        failed = sum(1 for t in test_results if not t.get('passed', False))
        html += f'<div class="export-no">✗ {failed} TEST(S) FAILED — Export to game: NO — Continue iterating</div>\n'
    
    # Quality scores
    html += '<h2>📊 Quality Scores</h2>\n<table>\n'
    for k, v in scores.items():
        color_class = "score-pass" if v >= 80 else ("score-warn" if v >= 60 else "score-fail")
        bar_width = v
        status = "✓" if v >= 80 else ("⚠" if v >= 60 else "✗")
        html += f'<tr><td>{k}</td><td><div class="score-bar {color_class}" style="width:{bar_width}%;">&nbsp;</div></td><td>{v} {status}</td></tr>\n'
    html += '</table>\n'
    
    # Test results
    html += '<h2>🧪 Test Results</h2>\n<table>\n<tr><th>Test</th><th>Status</th><th>Details</th></tr>\n'
    for t in test_results:
        status = "PASS" if t.get('passed') else "FAIL"
        cls = "test-pass" if t.get('passed') else "test-fail"
        html += f'<tr><td>{t.get("name","")}</td><td class="{cls}">{status}</td><td>{t.get("message","")}</td></tr>\n'
    html += '</table>\n'
    
    # Melody analysis
    html += '<h2>🎵 Melody</h2>\n<div class="grid">\n<div class="card">\n'
    m = analysis.get('melody', {})
    html += f'<p><b>Range:</b> {m.get("range","?")} ({m.get("range_semitones","?")} semitones)</p>'
    html += f'<p><b>Avg leap:</b> {m.get("avg_leap_semitones","?")} semitones</p>'
    html += f'<p><b>Max leap:</b> {m.get("largest_leap_semitones","?")} semitones {"⚠" if m.get("largest_leap_warning") else "✓"}</p>'
    html += f'<p><b>Contour:</b> {m.get("contour","?")} (↑{m.get("ascending_steps",0)} ↓{m.get("descending_steps",0)})</p>'
    html += f'<p><b>Total notes:</b> {m.get("total_notes","?")}</p>'
    html += f'<p><b>Unique motifs:</b> {m.get("unique_motifs","?")}</p>'
    html += f'<p><b>Motif reuse:</b> {m.get("motif_reuse_ratio","?")}</p>'
    html += f'<p><b>Phrase lengths:</b> {m.get("phrase_lengths","?")}</p>'
    html += '</div>\n</div>\n</div>\n'
    
    # Harmony
    html += '<h2>🎹 Harmony</h2>\n<div class="card">\n'
    h = analysis.get('harmony', {})
    html += f'<p><b>Key:</b> {h.get("detected_key","?")} (confidence: {h.get("key_confidence","?")})</p>'
    html += f'<p><b>Chords:</b> {h.get("total_chords","?")} | Rate: {h.get("chord_rate_per_beat","?")}/beat</p>'
    html += f'<p><b>Borrowed chords:</b> {h.get("borrowed_chords","?")}</p>'
    html += f'<p><b>Bass roots:</b> {h.get("bass_root_distribution","?")}</p>'
    html += '</div>\n'
    
    # Rhythm
    html += '<h2>🥁 Rhythm</h2>\n<div class="card">\n'
    r = analysis.get('rhythm', {})
    html += f'<p><b>Note density:</b> {r.get("note_density_per_bar","?")} notes/bar</p>'
    html += f'<p><b>Syncopation:</b> {r.get("syncopation_ratio","?")} ({r.get("syncopated_notes",0)}/{r.get("total_notes",0)} off-beat)</p>'
    html += f'<p><b>Durations:</b> {r.get("duration_distribution","?")}</p>'
    html += '</div>\n'
    
    # Bass
    html += '<h2>🎸 Bass</h2>\n<div class="card">\n'
    b = analysis.get('bass', {})
    html += f'<p><b>Range:</b> {b.get("range","?")} ({b.get("range_semitones","?")} semitones)</p>'
    html += f'<p><b>Register stable:</b> {"✓" if b.get("register_stable") else "⚠"}</p>'
    html += f'<p><b>Avg leap:</b> {b.get("avg_leap_semitones","?")} semitones</p>'
    html += '</div>\n'
    
    # Motif analysis
    html += '<h2>🔁 Motif Analysis</h2>\n<div class="card">\n'
    html += f'<p><b>Main motif:</b> {motif.get("main_motif","?")} ({motif.get("main_motif_occurrences",0)} occurrences)</p>'
    html += f'<p><b>Reuse ratio:</b> {motif.get("reuse_ratio","?")}</p>'
    html += f'<p><b>Motif counts:</b></p><ul>'
    for name, count in motif.get('motif_counts', {}).items():
        bar = "█" * count
        html += f'<li>{name}: {bar} {count}</li>'
    html += '</ul>'
    html += '</div>\n'
    
    # Piano rolls
    html += '<h2>🎹 Piano Rolls</h2>\n'
    for name, label in [("piano_roll_melody", "Melody"), ("piano_roll_bass", "Bass"), 
                         ("piano_roll_chords", "Chords"), ("piano_roll_combined", "Combined")]:
        path = PIANO_ROLL_DIR / f"{name}.png"
        html += f'<h3>{label}</h3>\n{img_tag(path, label)}\n'
    
    # Spectrograms
    html += '<h2>📊 Spectrograms</h2>\n'
    spec_path = SPECTROGRAM_DIR / "spectrogram_current.png"
    wave_path = SPECTROGRAM_DIR / "waveform_current.png"
    html += f'<h3>Spectrogram</h3>\n{img_tag(spec_path, "Spectrogram")}\n'
    html += f'<h3>Waveform</h3>\n{img_tag(wave_path, "Waveform")}\n'
    
    # Recommendations
    html += '<h2>💡 Recommendations</h2>\n<div class="card">\n<ul>\n'
    if scores.get('HOOK', 0) < 80:
        html += f'<li><b>HOOK ({scores.get("HOOK",0)}):</b> increase motif reuse to 60-80%</li>'
    if scores.get('PHRASE DEV', 0) < 80:
        html += f'<li><b>PHRASE DEV ({scores.get("PHRASE DEV",0)}):</b> add 2+ phrases of 4-8 bars each</li>'
    if scores.get('DENSITY', 0) < 80:
        html += f'<li><b>DENSITY ({scores.get("DENSITY",0)}):</b> reduce polyphony to 10-18 voices</li>'
    if scores.get('RHYTHM', 0) < 80:
        html += f'<li><b>RHYTHM ({scores.get("RHYTHM",0)}):</b> add syncopation + duration variety</li>'
    if scores.get('TENSION', 0) < 80:
        html += f'<li><b>TENSION ({scores.get("TENSION",0)}):</b> add modal interchange / borrowed chords</li>'
    if not [s for s in scores.values() if s < 80]:
        html += '<li>✓ All scores ≥ 80 — no critical recommendations</li>'
    html += '</ul>\n</div>\n'
    
    html += '</body>\n</html>'
    
    return html

def main():
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    html = generate_html()
    output_path = OUTPUT_DIR / "dashboard.html"
    with open(output_path, 'w') as f:
        f.write(html)
    print(f"Dashboard saved: {output_path}")
    print(f"Open with: file://{output_path.resolve()}")

if __name__ == "__main__":
    main()
