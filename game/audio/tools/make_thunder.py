#!/usr/bin/env python3
"""Synthesises the thunder rumble. Usage: make_thunder.py <output wav>, then encode to ogg."""
import sys
import wave

import numpy as np

RATE = 44100
SECONDS = 4.5
rng = np.random.default_rng(2080)
count = int(RATE * SECONDS)
time = np.arange(count) / RATE

# Brown noise is the rumble. A cracked start and slow rolling swells make it read as distant thunder.
rumble = np.cumsum(rng.normal(0.0, 1.0, count))
rumble -= np.convolve(rumble, np.ones(RATE // 8) / (RATE // 8), mode="same")
crack = rng.normal(0.0, 1.0, count) * np.exp(-time * 16.0) * 0.25
roll = 0.65 + 0.35 * np.sin(time * 5.3 + 1.0) * np.sin(time * 2.1)
envelope = np.minimum(time / 0.05, 1.0) * np.exp(-time * 1.15) * roll
sound = rumble / np.max(np.abs(rumble)) * envelope + crack * envelope
sound = sound / np.max(np.abs(sound)) * 0.85

with wave.open(sys.argv[1], "wb") as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(RATE)
    out.writeframes((sound * 32767).astype(np.int16).tobytes())
