#!/usr/bin/env python3
"""
Audio Pipeline for ProjectKOS
Generates game-ready SFX and BGM as WAV files using procedural synthesis.
No external dependencies — pure Python stdlib (wave, struct, math).
"""

import os
import math
import struct
import wave

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_ROOT = os.path.abspath(os.path.join(SCRIPT_DIR, "..", ".."))
SFX_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "audio", "sfx")
BGM_DIR = os.path.join(PROJECT_ROOT, "game", "assets", "audio", "bgm")

SAMPLE_RATE = 44100


def _sin(freq: float, t: float) -> float:
    """Sine wave at given frequency and time."""
    return math.sin(2.0 * math.pi * freq * t)


def _clamp(v: float) -> int:
    """Clamp float [-1,1] to 16-bit signed int."""
    return max(-32767, min(32767, int(v * 32767)))


def _write_wav(path: str, samples: list[int]) -> None:
    """Write 16-bit mono WAV file."""
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SAMPLE_RATE)
        data = struct.pack(f"<{len(samples)}h", *samples)
        w.writeframes(data)


def _envelope(t: float, attack: float, decay: float, duration: float) -> float:
    """Simple ADSR-ish envelope (attack, sustain, decay)."""
    if t < attack:
        return t / attack
    elif t > duration - decay:
        return max(0.0, (duration - t) / decay)
    return 1.0


def generate_click(path: str) -> None:
    """Short UI click — 15ms noise burst with fast decay."""
    duration = 0.015
    n = int(SAMPLE_RATE * duration)
    samples = []
    import random
    rng = random.Random(42)
    for i in range(n):
        t = i / SAMPLE_RATE
        env = 1.0 - (t / duration)  # linear decay
        noise = rng.uniform(-1, 1)
        # Mix noise with a high-frequency click
        click = _sin(3500, t) * 0.6 + noise * 0.4
        samples.append(_clamp(click * env * 0.7))
    _write_wav(path, samples)


def generate_coin(path: str) -> None:
    """Classic coin pickup — two ascending tones."""
    duration = 0.25
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = _envelope(t, 0.005, 0.08, duration)
        if t < 0.12:
            freq = 987.8  # B5
        else:
            freq = 1318.5  # E6
        val = _sin(freq, t) * 0.6 + _sin(freq * 2, t) * 0.2
        samples.append(_clamp(val * env * 0.6))
    _write_wav(path, samples)


def generate_success(path: str) -> None:
    """Cheerful ascending three-note chime."""
    notes = [(523.25, 0.15), (659.25, 0.15), (783.99, 0.3)]  # C5, E5, G5
    samples = []
    for freq, dur in notes:
        n = int(SAMPLE_RATE * dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            env = _envelope(t, 0.005, 0.1, dur)
            val = _sin(freq, t) * 0.5 + _sin(freq * 2, t) * 0.2 + _sin(freq * 3, t) * 0.1
            samples.append(_clamp(val * env * 0.6))
    _write_wav(path, samples)


def generate_error(path: str) -> None:
    """Descending two-tone buzz for wrong answer."""
    duration = 0.3
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = _envelope(t, 0.005, 0.1, duration)
        # Descend from ~400Hz to ~200Hz
        freq = 400 - (200 * t / duration)
        # Square-ish wave for buzzy character
        val = _sin(freq, t) * 0.5 + _sin(freq * 3, t) * 0.15
        samples.append(_clamp(val * env * 0.5))
    _write_wav(path, samples)


def generate_bgm(path: str) -> None:
    """Simple cheerful 8-bar melody loop (~8 seconds)."""
    bpm = 120
    beat = 60.0 / bpm  # 0.5 seconds per beat

    # C major melody: each tuple is (freq_hz, beats)
    melody = [
        (523.25, 1), (587.33, 1), (659.25, 1), (523.25, 1),  # C5 D5 E5 C5
        (659.25, 1), (698.46, 1), (783.99, 2),                # E5 F5 G5--
        (783.99, 0.5), (880.00, 0.5), (783.99, 0.5), (698.46, 0.5),  # G5 A5 G5 F5
        (659.25, 1), (523.25, 1), (523.25, 2),                # E5 C5 C5--
        # Second phrase
        (523.25, 1), (392.00, 1), (392.00, 1), (440.00, 1),  # C5 G4 G4 A4
        (493.88, 1), (440.00, 1), (392.00, 2),                # B4 A4 G4--
        (440.00, 1), (493.88, 1), (523.25, 1), (440.00, 1),  # A4 B4 C5 A4
        (392.00, 1), (349.23, 1), (523.25, 2),                # G4 F4 C5--
    ]

    # Bass notes (root of chord, one per bar)
    bass_pattern = [
        (130.81, 4), (130.81, 4),  # C3 C3
        (130.81, 4), (130.81, 4),  # C3 C3
        (130.81, 4), (98.00, 4),   # C3 G2
        (110.00, 4), (130.81, 4),  # A2 C3
    ]

    total_beats = sum(b for _, b in melody)
    total_duration = total_beats * beat
    n = int(SAMPLE_RATE * total_duration)

    # Pre-compute melody timeline
    melody_events = []
    t_offset = 0.0
    for freq, beats in melody:
        dur = beats * beat
        melody_events.append((t_offset, t_offset + dur, freq))
        t_offset += dur

    bass_events = []
    t_offset = 0.0
    for freq, beats in bass_pattern:
        dur = beats * beat
        bass_events.append((t_offset, t_offset + dur, freq))
        t_offset += dur

    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        val = 0.0

        # Melody voice
        for start, end, freq in melody_events:
            if start <= t < end:
                local_t = t - start
                dur = end - start
                env = _envelope(local_t, 0.01, 0.15, dur)
                val += (_sin(freq, t) * 0.3 + _sin(freq * 2, t) * 0.1) * env
                break

        # Bass voice
        for start, end, freq in bass_events:
            if start <= t < end:
                local_t = t - start
                dur = end - start
                env = _envelope(local_t, 0.02, 0.2, dur)
                val += _sin(freq, t) * 0.15 * env
                break

        # Master envelope for smooth loop edges
        if t < 0.05:
            val *= t / 0.05
        elif t > total_duration - 0.05:
            val *= (total_duration - t) / 0.05

        samples.append(_clamp(val * 0.7))

    _write_wav(path, samples)


def generate_bounce(path: str) -> None:
    """Rubber-band bounce — spring sine sweep down."""
    duration = 0.15
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = (1.0 - t / duration) ** 2  # quadratic decay
        freq = 800 - 500 * (t / duration)  # sweep 800 → 300 Hz
        val = _sin(freq, t) * 0.6 + _sin(freq * 1.5, t) * 0.2
        samples.append(_clamp(val * env * 0.65))
    _write_wav(path, samples)


def generate_swipe(path: str) -> None:
    """Quick filtered noise sweep — card swipe / UI gesture."""
    duration = 0.12
    n = int(SAMPLE_RATE * duration)
    samples = []
    import random
    rng = random.Random(77)
    for i in range(n):
        t = i / SAMPLE_RATE
        env = _envelope(t, 0.01, 0.04, duration)
        # Filtered noise with rising frequency cutoff
        noise = rng.uniform(-1, 1)
        cutoff_t = t / duration
        # Simple low-pass via mixing with sine
        tone = _sin(1200 + 2000 * cutoff_t, t) * 0.3
        val = noise * 0.5 + tone * 0.5
        samples.append(_clamp(val * env * 0.5))
    _write_wav(path, samples)


def generate_reward(path: str) -> None:
    """Triumphant ascending arpeggio — C-E-G-C octave."""
    notes = [
        (523.25, 0.1),   # C5
        (659.25, 0.1),   # E5
        (783.99, 0.1),   # G5
        (1046.50, 0.2),  # C6 (octave, longer)
    ]
    samples = []
    for freq, dur in notes:
        n = int(SAMPLE_RATE * dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            env = _envelope(t, 0.005, 0.08, dur)
            val = (_sin(freq, t) * 0.4 + _sin(freq * 2, t) * 0.15
                   + _sin(freq * 3, t) * 0.08)
            samples.append(_clamp(val * env * 0.6))
    _write_wav(path, samples)


def generate_pop(path: str) -> None:
    """Bubble pop — short sine burst with fast attack and harmonic decay."""
    duration = 0.08
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = (1.0 - t / duration) ** 3  # cubic decay
        freq = 600 + 400 * (1.0 - t / duration)  # sweep 1000 → 600 Hz
        val = _sin(freq, t) * 0.5 + _sin(freq * 2.5, t) * 0.2
        samples.append(_clamp(val * env * 0.7))
    _write_wav(path, samples)


def generate_slide(path: str) -> None:
    """UI slide — smooth sine glide up."""
    duration = 0.1
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = _envelope(t, 0.01, 0.03, duration)
        freq = 300 + 700 * (t / duration)  # sweep 300 → 1000 Hz
        val = _sin(freq, t) * 0.4 + _sin(freq * 1.5, t) * 0.15
        samples.append(_clamp(val * env * 0.55))
    _write_wav(path, samples)


def generate_star(path: str) -> None:
    """Star collect — sparkly ascending two-tone with shimmer."""
    duration = 0.2
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = _envelope(t, 0.005, 0.08, duration)
        if t < 0.08:
            freq = 1046.50  # C6
        else:
            freq = 1318.51  # E6
        shimmer = _sin(freq * 4, t) * 0.08 * max(0, 1.0 - t / duration)
        val = _sin(freq, t) * 0.4 + _sin(freq * 2, t) * 0.15 + shimmer
        samples.append(_clamp(val * env * 0.6))
    _write_wav(path, samples)


def generate_tap(path: str) -> None:
    """Soft tap — wood-block style short percussive hit."""
    duration = 0.03
    n = int(SAMPLE_RATE * duration)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = (1.0 - t / duration) ** 4  # very fast decay
        val = _sin(1800, t) * 0.4 + _sin(2700, t) * 0.2 + _sin(900, t) * 0.2
        samples.append(_clamp(val * env * 0.6))
    _write_wav(path, samples)


def generate_toggle(path: str) -> None:
    """Toggle switch — double click with pitch shift."""
    samples = []
    for note_idx in range(2):
        freq = 800 if note_idx == 0 else 1000
        dur = 0.025
        n = int(SAMPLE_RATE * dur)
        for i in range(n):
            t = i / SAMPLE_RATE
            env = (1.0 - t / dur) ** 2
            val = _sin(freq, t) * 0.5 + _sin(freq * 2, t) * 0.15
            samples.append(_clamp(val * env * 0.6))
        # 15ms silence between clicks
        samples.extend([0] * int(SAMPLE_RATE * 0.015))
    _write_wav(path, samples)


def generate_whoosh(path: str) -> None:
    """Whoosh — filtered noise sweep for transitions."""
    duration = 0.18
    n = int(SAMPLE_RATE * duration)
    samples = []
    import random
    rng = random.Random(99)
    for i in range(n):
        t = i / SAMPLE_RATE
        progress = t / duration
        # Bell-shaped envelope (peak at center)
        env = math.sin(math.pi * progress) * 0.7
        noise = rng.uniform(-1, 1)
        # Sweep center frequency
        center = 400 + 2000 * progress
        tone = _sin(center, t) * 0.3
        val = noise * 0.4 + tone * 0.3
        samples.append(_clamp(val * env * 0.5))
    _write_wav(path, samples)


def main() -> None:
    print("=== ProjectKOS Audio Generator ===")
    os.makedirs(SFX_DIR, exist_ok=True)
    os.makedirs(BGM_DIR, exist_ok=True)

    generators = [
        ("sfx/click.wav", SFX_DIR, "click.wav", generate_click),
        ("sfx/coin.wav", SFX_DIR, "coin.wav", generate_coin),
        ("sfx/success.wav", SFX_DIR, "success.wav", generate_success),
        ("sfx/error.wav", SFX_DIR, "error.wav", generate_error),
        ("bgm/bgm_loop.wav", BGM_DIR, "bgm_loop.wav", generate_bgm),
        ("sfx/bounce.wav", SFX_DIR, "bounce.wav", generate_bounce),
        ("sfx/swipe.wav", SFX_DIR, "swipe.wav", generate_swipe),
        ("sfx/reward.wav", SFX_DIR, "reward.wav", generate_reward),
        ("sfx/pop.wav", SFX_DIR, "pop.wav", generate_pop),
        ("sfx/slide.wav", SFX_DIR, "slide.wav", generate_slide),
        ("sfx/star.wav", SFX_DIR, "star.wav", generate_star),
        ("sfx/tap.wav", SFX_DIR, "tap.wav", generate_tap),
        ("sfx/toggle.wav", SFX_DIR, "toggle.wav", generate_toggle),
        ("sfx/whoosh.wav", SFX_DIR, "whoosh.wav", generate_whoosh),
    ]

    for label, directory, filename, gen_func in generators:
        path = os.path.join(directory, filename)
        print(f"  Generating {label}...", end="")
        gen_func(path)
        size_kb = os.path.getsize(path) / 1024
        print(f"  OK ({size_kb:.1f} KB)")

    print()
    print(f"=== Done: {len(generators)}/{len(generators)} audio files generated ===")
    print("All audio is procedurally generated — no licensing issues.")


if __name__ == "__main__":
    main()
