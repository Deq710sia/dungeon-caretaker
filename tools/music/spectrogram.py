#!/usr/bin/env python3
"""Stage 4: Spectrogram generator — render spectrogram from WAV.

Generates spectrogram.png from the latest rendered WAV. Can also generate
a comparison if a reference WAV is provided.

Usage:
  python3 tools/music/spectrogram.py [--reference path/to/ref.wav]
"""
import sys
import subprocess
from pathlib import Path

REPO = Path(__file__).parent.parent.parent
WAV_DIR = REPO / "generated" / "wav"
SPEC_DIR = REPO / "generated" / "spectrograms"
SPEC_DIR.mkdir(parents=True, exist_ok=True)

def find_latest_wav():
    """Find the latest WAV in generated/wav/."""
    wavs = sorted(WAV_DIR.glob("*.wav"))
    return wavs[-1] if wavs else None

def generate_spectrogram(wav_path, output_path, title="Spectrogram"):
    """Generate a spectrogram PNG from a WAV using ffmpeg."""
    cmd = [
        "ffmpeg", "-y", "-i", str(wav_path),
        "-lavfi", f"showspectrumpic=s=800x400:mode=combined:color=intensity:scale=log",
        "-frames:v", "1",
        str(output_path)
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"  SAVED {output_path}")
        return True
    else:
        print(f"  FAIL {wav_path}: {result.stderr[:200]}")
        return False

def generate_comparison(current_wav, reference_wav, output_path):
    """Generate side-by-side spectrograms for comparison."""
    # Generate individual spectrograms
    curr_spec = SPEC_DIR / "_current_temp.png"
    ref_spec = SPEC_DIR / "_reference_temp.png"
    generate_spectrogram(current_wav, curr_spec, "Current")
    generate_spectrogram(reference_wav, ref_spec, "Reference")
    
    # Combine side by side using ffmpeg
    cmd = [
        "ffmpeg", "-y",
        "-i", str(curr_spec),
        "-i", str(ref_spec),
        "-filter_complex", "[0:v][1:v]hstack=inputs=2",
        str(output_path)
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"  SAVED comparison: {output_path}")
    else:
        print(f"  FAIL comparison: {result.stderr[:200]}")
    
    # Cleanup temp files
    curr_spec.unlink(missing_ok=True)
    ref_spec.unlink(missing_ok=True)

def main():
    wav = find_latest_wav()
    if wav is None:
        print("ERROR: no WAV found in generated/wav/. Render music first.")
        sys.exit(1)
    
    print(f"Generating spectrogram from: {wav.name}")
    
    # Current spectrogram
    output = SPEC_DIR / "spectrogram_current.png"
    generate_spectrogram(wav, output)
    
    # Waveform too
    waveform_output = SPEC_DIR / "waveform_current.png"
    cmd = [
        "ffmpeg", "-y", "-i", str(wav),
        "-lavfi", "showwavespic=s=800x200:colors=0x4080FF|0x4080FF:split_channels=1",
        "-frames:v", "1",
        str(waveform_output)
    ]
    result = subprocess.run(cmd, capture_output=True, text=True)
    if result.returncode == 0:
        print(f"  SAVED {waveform_output}")
    
    # Reference comparison if requested
    if '--reference' in sys.argv:
        ref_idx = sys.argv.index('--reference') + 1
        if ref_idx < len(sys.argv):
            ref_wav = Path(sys.argv[ref_idx])
            if ref_wav.exists():
                print(f"\nGenerating comparison with reference: {ref_wav.name}")
                comp_output = SPEC_DIR / "spectrogram_comparison.png"
                generate_comparison(wav, ref_wav, comp_output)
            else:
                print(f"  Reference not found: {ref_wav}")
    
    print(f"\nSpectrograms saved to {SPEC_DIR}/")

if __name__ == "__main__":
    main()
