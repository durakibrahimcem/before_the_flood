#!/usr/bin/env python3
"""Synthesises the time wash: the quiet loop that follows the T scrub.

Layered noise, swaying slowly, so steering its pitch sounds like time pouring.
Usage: make_time.py <repo game folder>
"""
import os
import subprocess
import sys
import wave

import numpy as np
from scipy.signal import butter, sosfilt

RATE = 44100
SECONDS = 7.0
rng = np.random.default_rng(2054)


def clock(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def band(signal, low, high):
    return sosfilt(butter(2, [low, high], btype="band", fs=RATE, output="sos"), signal)


def lowpass(signal, cutoff):
    return sosfilt(butter(2, cutoff, btype="low", fs=RATE, output="sos"), signal)


def sway(seconds, cycles, phase):
    """A slow breathing envelope, an exact number of cycles so the loop seams."""
    return 0.6 + 0.4 * np.sin(2 * np.pi * cycles * clock(seconds) / SECONDS + phase)


def seamless(sound):
    """Fades the tail into the head, so the loop never clicks."""
    overlap = int(RATE * 1.5)
    ramp = np.sin(np.linspace(0.0, np.pi / 2.0, overlap)) ** 2
    loop = sound[:-overlap].copy()
    loop[:overlap] = sound[:overlap] * ramp + sound[-overlap:] * (1.0 - ramp)
    return loop


def time_wash():
    body = lowpass(rng.normal(0.0, 1.0, int(RATE * SECONDS)), 420.0)
    paper = band(rng.normal(0.0, 1.0, int(RATE * SECONDS)), 600.0, 2600.0)
    air = band(rng.normal(0.0, 1.0, int(RATE * SECONDS)), 2200.0, 7800.0)
    wash = body * sway(SECONDS, 2.0, 0.0) * 0.9
    wash += paper * sway(SECONDS, 3.0, 2.1) * 0.35
    wash += air * sway(SECONDS, 5.0, 4.4) * 0.16
    return seamless(wash * sway(SECONDS, 1.0, 1.2))


def main(argv):
    game = os.path.abspath(argv[1])
    build = os.path.join(game, "audio", "tools", "build")
    os.makedirs(build, exist_ok=True)
    wav_path = os.path.join(build, "time_wash.wav")
    sound = time_wash()
    sound = sound / np.max(np.abs(sound)) * 0.9
    with wave.open(wav_path, "wb") as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes((sound * 32767).astype(np.int16).tobytes())
    ogg_path = os.path.join(game, "audio", "sfx", "time_wash.ogg")
    subprocess.run(["/usr/bin/ffmpeg", "-y", "-hide_banner", "-loglevel", "error",
                    "-i", wav_path, "-c:a", "libvorbis", "-q:a", "4", ogg_path], check=True)
    print(f"time_wash.ogg: {os.path.getsize(ogg_path)} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
