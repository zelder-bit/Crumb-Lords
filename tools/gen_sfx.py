#!/usr/bin/env python3
"""Deterministic, dependency-free toy shooter sounds. Run from any directory."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 44100
PEAK = 10 ** (-3 / 20)
OUT = Path(__file__).resolve().parents[1] / 'assets' / 'sfx'
NAMES = (
    'laser staple reload_twist reload_stapler empty_click hop double_jump land '
    'hurt death bunny_hop bunny_hit bunny_die boss_slam boss_roar boss_hit '
    'pickup gate_open shield_up super_slam level_complete checkpoint'
).split()


def tone(buf, rng, start, duration, freq, end=None, gain=0.6,
         shape='sine', noise=0.0, decay=2.0, vibrato=0.0):
    """Mix a swept oscillator with attack/release, noise, and pitch wobble."""
    first = round(start * RATE)
    count = round(duration * RATE)
    if len(buf) < first + count:
        buf.extend([0.0] * (first + count - len(buf)))
    phase = 0.0
    filtered_noise = 0.0
    end = freq if end is None else end
    for i in range(count):
        u = i / max(1, count - 1)
        t = i / RATE
        hz = freq * (end / freq) ** u
        hz *= 1.0 + vibrato * math.sin(2 * math.pi * 18 * t)
        phase += hz / RATE
        sine = math.sin(2 * math.pi * phase)
        if shape == 'square':
            # A few harmonics give a retro pulse without harsh aliasing.
            sample = sine + 0.25 * math.sin(6 * math.pi * phase)
        elif shape == 'metal':
            sample = sine * 0.5 + math.sin(2 * math.pi * phase * 2.73) * 0.3
        else:
            sample = sine
        white = rng.uniform(-1, 1)
        filtered_noise += 0.22 * (white - filtered_noise)
        attack = min(1.0, t / 0.002)
        release = min(1.0, (duration - t) / 0.012)
        envelope = attack * release * (1 - u) ** decay
        buf[first + i] += gain * envelope * (
            sample * (1 - noise) + (white * 0.3 + filtered_noise) * noise
        )


def synth(name):
    # Explicit per-name seed: independent of Python's randomized hash().
    rng = random.Random('household-havoc-v1:' + name)
    buf = []

    def hit(start, duration, freq, end=None, **kwargs):
        tone(buf, rng, start, duration, freq, end, **kwargs)

    if name == 'laser':
        hit(0, 0.15, 2200, 180, shape='square', decay=1.3)
    elif name == 'staple':
        hit(0, 0.035, 1700, 500, shape='metal', noise=0.4)
        hit(0.035, 0.14, 220, 65, shape='metal', noise=0.3)
    elif name == 'reload_twist':
        for i in range(12):
            hit(i * 0.064, 0.045, 950 + i * 65, 420, shape='metal', noise=0.3)
        hit(0.74, 0.06, 250, 130, shape='square')
    elif name == 'reload_stapler':
        hit(0, 0.48, 180, 440, shape='square', vibrato=0.25, decay=0.3)
        hit(0.55, 0.035, 2200, 650, shape='metal', noise=0.6)
        hit(0.58, 0.17, 200, 60, noise=0.2)
    elif name == 'empty_click':
        hit(0, 0.055, 850, 300, shape='metal', noise=0.5)
    elif name == 'hop':
        hit(0, 0.105, 380, 180, noise=0.12, decay=3)
    elif name == 'double_jump':
        hit(0, 0.48, 620, 120, shape='square', vibrato=0.48, decay=1.6)
    elif name == 'land':
        hit(0, 0.19, 125, 45, noise=0.4, decay=2.5)
    elif name == 'hurt':
        hit(0, 0.23, 380, 110, shape='square', vibrato=0.18, noise=0.12)
    elif name == 'death':
        for i, freq in enumerate((440, 330, 220, 110)):
            hit(i * 0.18, 0.35, freq, freq * 0.65, shape='square', vibrato=0.12)
    elif name.startswith('bunny_'):
        duration, high, low = {
            'bunny_hop': (0.16, 850, 1700),
            'bunny_hit': (0.22, 1900, 700),
            'bunny_die': (0.55, 1800, 220),
        }[name]
        hit(0, duration, high, low, vibrato=0.16, decay=1.4)
        hit(0.02, duration, 170, 85, noise=0.9, gain=0.28)
    elif name in ('boss_slam', 'super_slam'):
        duration = 0.75 if name == 'boss_slam' else 1.1
        hit(0, duration, 110, 28, gain=0.9, decay=2)
        hit(0, 0.24, 240, 60, noise=0.85, gain=0.7)
        if name == 'super_slam':
            hit(0, 0.6, 1200, 85, shape='square', gain=0.3)
    elif name == 'boss_roar':
        hit(0, 1.15, 180, 65, shape='square', noise=0.25, vibrato=0.28, decay=0.5)
        hit(0.04, 0.9, 360, 90, shape='metal', gain=0.25, vibrato=0.2)
    elif name == 'boss_hit':
        hit(0, 0.28, 260, 70, shape='metal', noise=0.4)
    elif name in ('pickup', 'checkpoint', 'level_complete'):
        notes = {
            'pickup': (784, 1047, 1568),
            'checkpoint': (523, 659, 784, 1047),
            'level_complete': (523, 659, 784, 1047, 784, 1047, 1319),
        }[name]
        step = 0.19 if name == 'level_complete' else 0.105
        for i, freq in enumerate(notes):
            duration = 0.55 if i == len(notes) - 1 else 0.24
            hit(i * step, duration, freq, shape='square', decay=1.4, gain=0.5)
            hit(i * step, duration, freq / 2, gain=0.18)
    elif name == 'gate_open':
        hit(0, 1.1, 100, 320, shape='metal', noise=0.28, decay=0.4)
        for i in range(7):
            hit(i * 0.12, 0.09, 450, 170, noise=0.45, gain=0.25)
    elif name == 'shield_up':
        hit(0, 0.58, 180, 1500, shape='square', vibrato=0.06, decay=0.5)
        hit(0.4, 0.3, 1800, 1400, gain=0.3)
    else:
        raise ValueError(name)
    assert len(buf) / RATE < (2.5 if name == 'level_complete' else 1.5)
    scale = PEAK * 32767 / max(abs(sample) for sample in buf)
    return b''.join(struct.pack('<h', round(sample * scale)) for sample in buf)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for name in NAMES:
        pcm = synth(name)
        with wave.open(str(OUT / (name + '.wav')), 'wb') as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(pcm)
        print(f'{name}: {len(pcm) / (2 * RATE):.3f}s')


if __name__ == '__main__':
    main()
