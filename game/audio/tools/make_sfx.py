#!/usr/bin/env python3
"""Synthesises the game's sound effects, so every sound is ours. Usage: make_sfx.py <wav folder>"""
import sys
import wave

import numpy as np
from scipy.signal import butter, sosfilt

RATE = 44100
rng = np.random.default_rng(1926)


def clock(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def noise(seconds):
    return rng.normal(0.0, 1.0, int(RATE * seconds))


def band(signal, low, high):
    return sosfilt(butter(2, [low, high], btype="band", fs=RATE, output="sos"), signal)


def lowpass(signal, cutoff):
    return sosfilt(butter(2, cutoff, btype="low", fs=RATE, output="sos"), signal)


def tone(time, freq, decay):
    return np.sin(2 * np.pi * freq * time) * np.exp(-time * decay)


def wood(seconds, freq):
    time = clock(seconds)
    return tone(time, freq, 28.0) + 0.5 * tone(time, freq * 2.3, 44.0) + 0.25 * band(noise(seconds), 400, 2400) * np.exp(-time * 70.0)


def mix_at(base, sound, start):
    at = int(RATE * start)
    base[at:at + len(sound)] += sound[:len(base) - at]
    return base


def step_dry():
    time = clock(0.09)
    return lowpass(noise(0.09), 900) * np.exp(-time * 55.0) + 0.5 * tone(time, 105, 50.0)


def step_wet():
    time = clock(0.28)
    splash = band(noise(0.28), 500, 3000) * (np.exp(-time * 22.0) + 0.45 * np.exp(-((time - 0.1) * 26.0) ** 2))
    bubble = np.sin(2 * np.pi * (520 * time + 900 * time ** 2)) * np.exp(-time * 26.0) * 0.25
    return splash + bubble


def scribble():
    time = clock(0.36)
    strokes = 0.55 + 0.45 * np.sign(np.sin(2 * np.pi * 15.0 * time))
    return band(noise(0.36), 1500, 6500) * strokes * np.minimum(time / 0.02, 1.0) * np.minimum((0.36 - time) / 0.08, 1.0)


def paper():
    sound = np.zeros(int(RATE * 0.45))
    for start, length in ((0.0, 0.14), (0.12, 0.1), (0.24, 0.2)):
        time = clock(length)
        mix_at(sound, band(noise(length), 2200, 9000) * np.sin(np.pi * time / length) ** 2, start)
    return sound


def switch():
    sound = np.zeros(int(RATE * 0.09))
    for start, level in ((0.0, 1.0), (0.03, 0.7)):
        time = clock(0.012)
        mix_at(sound, band(noise(0.012), 1200, 7000) * np.exp(-time * 420.0) * level, start)
    return sound


def door():
    return wood(0.32, 150) + 0.5 * wood(0.32, 92)


def block():
    time = clock(0.8)
    return tone(time, 62, 7.0) + 0.6 * tone(time, 118, 13.0) + 0.5 * lowpass(noise(0.8), 700) * np.exp(-time * 16.0)


def wave_crash():
    time = clock(3.0)
    swell = np.sin(np.pi * np.minimum(time / 3.0, 1.0)) ** 2 * (1.0 - 0.3 * np.sin(time * 7.0))
    return (lowpass(noise(3.0), 1400) + 0.35 * band(noise(3.0), 2000, 7000)) * swell


def rain():
    length, overlap = RATE * 5, RATE // 2
    drops = band(rng.normal(0.0, 1.0, length + overlap), 900, 7500)
    ramp = np.linspace(0.0, 1.0, overlap)
    loop = drops[:length].copy()
    loop[:overlap] = loop[:overlap] * ramp + drops[length:] * (1.0 - ramp)
    return loop


def pickup():
    time = clock(0.1)
    return np.sin(2 * np.pi * (480 * time + 2600 * time ** 2)) * np.exp(-time * 34.0)


def drop():
    return wood(0.24, 235)


def plant():
    time = clock(0.3)
    return lowpass(noise(0.3), 1300) * np.sin(np.pi * np.minimum(time / 0.3, 1.0)) ** 2


def knock():
    sound = np.zeros(int(RATE * 0.6))
    for start in (0.0, 0.19):
        mix_at(sound, wood(0.2, 178), start)
    return sound


def chime():
    time = clock(0.95)
    first = (tone(time, 523.25, 5.0) + 0.3 * tone(time, 1046.5, 9.0)) * 0.7
    return mix_at(first, (tone(clock(0.8), 659.25, 5.0) + 0.3 * tone(clock(0.8), 1318.5, 9.0)) * 0.7, 0.15)


SOUNDS = [step_dry, step_wet, scribble, paper, switch, door, block, wave_crash, rain, pickup, drop, plant, knock, chime]

for make in SOUNDS:
    sound = make()
    sound = sound / np.max(np.abs(sound)) * 0.9
    with wave.open(f"{sys.argv[1]}/{make.__name__}.wav", "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes((sound * 32767).astype(np.int16).tobytes())
