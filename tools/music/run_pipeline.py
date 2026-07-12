#!/usr/bin/env python3
"""Master pipeline — runs all analyzers, generates report, preserves iteration.

This is the "music CI" — run after every music change.

Pipeline:
  1. analyze_midi.py     — extract notes, compute stats
  2. score_music.py      — compute quality scores
  3. test_composition.py — run assertion tests
  4. motif_detector.py   — find recurring motifs
  5. visualize_piano_roll.py — generate piano roll PNGs
  6. spectrogram.py      — generate spectrogram from WAV
  7. html_report.py      — generate dashboard HTML
  8. Preserve iteration  — copy all artifacts to generated/iterations/N/

Usage:
  python3 tools/music/run_pipeline.py
"""
import sys
import json
import shutil
import subprocess
from pathlib import Path
from datetime import datetime

REPO = Path(__file__).parent.parent.parent
TOOLS = REPO / "tools" / "music"
GENERATED = REPO / "generated"
ITERATIONS_DIR = GENERATED / "iterations"

def run_step(name, script):
    """Run a pipeline step."""
    print(f"\n{'='*60}")
    print(f"STEP: {name}")
    print(f"{'='*60}")
    result = subprocess.run([sys.executable, str(TOOLS / script)], capture_output=False)
    return result.returncode == 0

def main():
    start_time = datetime.now()
    print("=" * 60)
    print("MUSIC CI PIPELINE")
    print(f"Started: {start_time.strftime('%Y-%m-%d %H:%M:%S')}")
    print("=" * 60)
    
    # Steps 1-4: analysis + scoring + tests + motifs
    run_step("1. MIDI Analysis", "analyze_midi.py")
    run_step("2. Quality Scoring", "score_music.py")
    
    # Step 3: tests (capture exit code for export gate)
    test_result = subprocess.run([sys.executable, str(TOOLS / "test_composition.py")], capture_output=True, text=True)
    print(test_result.stdout)
    tests_pass = test_result.returncode == 0
    
    run_step("4. Motif Detection", "motif_detector.py")
    run_step("5. Piano Roll Visualization", "visualize_piano_roll.py")
    run_step("6. Spectrogram", "spectrogram.py")
    run_step("7. HTML Report", "html_report.py")
    
    # Step 8: Preserve iteration
    iteration_num = len(list(ITERATIONS_DIR.glob("iteration_*"))) + 1 if ITERATIONS_DIR.exists() else 1
    iter_dir = ITERATIONS_DIR / f"iteration_{iteration_num:03d}"
    iter_dir.mkdir(parents=True, exist_ok=True)
    
    # Copy artifacts
    for src, dst_name in [
        (TOOLS / "analysis.json", "analysis.json"),
        (TOOLS / "scores.json", "scores.json"),
        (TOOLS / "test_results.json", "test_results.json"),
        (TOOLS / "motif_analysis.json", "motif_analysis.json"),
        (GENERATED / "reports" / "dashboard.html", "dashboard.html"),
    ]:
        if src.exists():
            shutil.copy2(src, iter_dir / dst_name)
    
    # Copy piano rolls
    piano_roll_src = TOOLS / "output"
    if piano_roll_src.exists():
        for png in piano_roll_src.glob("*.png"):
            shutil.copy2(png, iter_dir / png.name)
    
    # Copy spectrograms
    spec_src = GENERATED / "spectrograms"
    if spec_src.exists():
        for png in spec_src.glob("*.png"):
            shutil.copy2(png, iter_dir / png.name)
    
    # Save iteration metadata
    end_time = datetime.now()
    duration = (end_time - start_time).total_seconds()
    
    # Load scores for metadata
    scores = {}
    scores_path = TOOLS / "scores.json"
    if scores_path.exists():
        with open(scores_path) as f:
            scores = json.load(f)
    
    metadata = {
        "iteration": iteration_num,
        "timestamp": end_time.isoformat(),
        "duration_seconds": duration,
        "tests_pass": tests_pass,
        "export_allowed": tests_pass,
        "overall_score": scores.get("OVERALL", 0),
        "scores": scores,
    }
    with open(iter_dir / "metadata.json", 'w') as f:
        json.dump(metadata, f, indent=2)
    
    # Final summary
    print(f"\n{'='*60}")
    print("PIPELINE COMPLETE")
    print(f"{'='*60}")
    print(f"  Iteration:    {iteration_num}")
    print(f"  Duration:     {duration:.1f}s")
    print(f"  Tests:        {'ALL PASS' if tests_pass else 'SOME FAIL'}")
    print(f"  Export:       {'YES' if tests_pass else 'NO — continue iterating'}")
    print(f"  Overall:      {scores.get('OVERALL', '?')}")
    print(f"  Artifacts:    {iter_dir}")
    print(f"\n  Dashboard:    file://{(GENERATED / 'reports' / 'dashboard.html').resolve()}")
    
    return 0 if tests_pass else 1

if __name__ == "__main__":
    sys.exit(main())
