#!/usr/bin/env python3
"""Composes and builds the adaptive music stems for Before the Flood.

One gentle original piano theme, 16 bars in C major at 63 BPM. The theme splits
into four stems that share a beat grid, so they stay sample aligned:

    melody   the tune, singing register
    harmony  slow block chords under it
    low      root and fifth bass notes
    detuned  the melody again, bent 35 cents flat for the damaged future

Each stem is rendered with fluidsynth from a hand written MIDI file (standard
library only, MIDI bytes built below), wrapped into a sample accurate loop of
exactly 64 beats * 42000 samples, loudness matched, then encoded to Ogg Vorbis.
A low passed copy of every stem is rendered the same way for the Web fallback,
where audio effects are unavailable.

Run from the repo root:  python3 game/audio/tools/make_music.py

SoundFont: /usr/share/soundfonts/FluidR3_GM.sf2 (FluidR3 GM by Frank Wen, MIT).
"""

from __future__ import annotations

import array
import math
import os
import subprocess
import sys
import wave

# --- composition -----------------------------------------------------------

BPM = 63                      # 63 BPM -> exactly 42000 samples per beat at 44100 Hz
BEATS = 64                    # 16 bars of 4/4
TAIL_BEATS = 4                # silence kept after the loop point, folded back for the seam
TICKS_PER_BEAT = 480
SAMPLE_RATE = 44100
SAMPLES_PER_BEAT = SAMPLE_RATE * 60 // BPM          # 42000
LOOP_SAMPLES = BEATS * SAMPLES_PER_BEAT              # 2688000 = 60.952 s
LOWPASS_HZ = 650.0

PIANO = 0                      # General MIDI program: acoustic grand
SILENT_BARS = TAIL_BEATS // 4  # trailing bars with no notes, for the loop seam

# One chord per bar, 16 bars: the theme's harmonic spine.
CHORDS = [
    "C", "Am", "F", "G",      # opening phrase
    "C", "Am", "Dm", "G",     # phrase repeats, new ending
    "F", "G", "Em", "Am",     # bridge, the high point
    "F", "Em", "Dm", "G",     # return, ends open on G so the loop resolves to C
]

# Melody: (bar, beat in bar, length in beats, midi pitch). Quarter and half
# notes, mostly stepwise; the bridge climbs to its highest note, then the
# return settles back down to the G that leads into the loop's first C.
MELODY = [
    (0, 0.0, 1.0, 67), (0, 1.0, 1.0, 64), (0, 2.0, 2.0, 72),
    (1, 0.0, 1.0, 72), (1, 1.0, 1.0, 71), (1, 2.0, 2.0, 69),
    (2, 0.0, 1.0, 69), (2, 1.0, 1.0, 67), (2, 2.0, 1.0, 65), (2, 3.0, 1.0, 67),
    (3, 0.0, 2.0, 69), (3, 2.0, 2.0, 74),
    (4, 0.0, 1.0, 67), (4, 1.0, 1.0, 64), (4, 2.0, 2.0, 72),
    (5, 0.0, 1.0, 72), (5, 1.0, 1.0, 71), (5, 2.0, 2.0, 69),
    (6, 0.0, 1.0, 65), (6, 1.0, 1.0, 64), (6, 2.0, 2.0, 62),
    (7, 0.0, 2.0, 62), (7, 2.0, 2.0, 67),
    (8, 0.0, 1.0, 65), (8, 1.0, 1.0, 67), (8, 2.0, 2.0, 69),
    (9, 0.0, 1.0, 71), (9, 1.0, 1.0, 72), (9, 2.0, 2.0, 74),
    (10, 0.0, 2.0, 76), (10, 2.0, 1.0, 74), (10, 3.0, 1.0, 71),
    (11, 0.0, 2.0, 72), (11, 2.0, 2.0, 69),
    (12, 0.0, 1.0, 69), (12, 1.0, 1.0, 67), (12, 2.0, 2.0, 65),
    (13, 0.0, 1.0, 67), (13, 1.0, 1.0, 64), (13, 2.0, 2.0, 62),
    (14, 0.0, 1.0, 65), (14, 1.0, 1.0, 64), (14, 2.0, 2.0, 62),
    (15, 0.0, 2.0, 62), (15, 2.0, 1.0, 59), (15, 3.0, 1.0, 62),
]

# Block chords for the harmony stem, one per bar, kept in a narrow band.
VOICINGS = {
    "C":  [60, 64, 67],      # C4 E4 G4
    "Am": [57, 60, 64],      # A3 C4 E4
    "F":  [57, 60, 65],      # A3 C4 F4
    "G":  [59, 62, 67],      # B3 D4 G4
    "Dm": [57, 62, 65],      # A3 D4 F4
    "Em": [55, 59, 64],      # G3 B3 E4
}

# Bass line for the low stem: root on beat 1, fifth on beat 3.
BASS = [
    (48, 55), (45, 52), (41, 48), (43, 50),
    (48, 55), (45, 52), (50, 57), (43, 50),
    (41, 48), (43, 50), (40, 47), (45, 52),
    (41, 48), (40, 47), (50, 57), (43, 50),
]

# Dynamics: a gentle arc per four bars, no randomness so every build is identical.
MELODY_DYNAMICS = [64, 66, 64, 66, 64, 64, 62, 60, 64, 70, 74, 70, 66, 62, 60, 56]
HARMONY_VELOCITY = 48
BASS_VELOCITY = 42
DETUNE_CENTS = -35.0
ARTICULATION_GAP = 0.05     # beats shaved off every note before its note off


def _varlen(value: int) -> bytes:
    """MIDI variable length quantity."""
    out = bytearray([value & 0x7F])
    value >>= 7
    while value:
        out.insert(0, 0x80 | (value & 0x7F))
        value >>= 7
    return bytes(out)


class Track:
    """One MIDI track under construction: events collected, then serialized."""

    def __init__(self, name: str, channel: int, program: int) -> None:
        self.name = name
        self.channel = channel
        self.events: list[tuple[int, int, bytes]] = []
        self.add(0, 0, bytes([0xFF, 0x03]) + _varlen(len(name)) + name.encode("ascii"))
        self.add(0, 0, bytes([0xC0 | channel, program]))

    def add(self, tick: int, priority: int, payload: bytes) -> None:
        assert 0 <= tick
        self.events.append((tick, priority, payload))

    def control(self, tick: int, controller: int, value: int) -> None:
        self.add(tick, 1, bytes([0xB0 | self.channel, controller, value & 0x7F]))

    def bend(self, tick: int, value: int) -> None:
        self.add(tick, 0, bytes([0xE0 | self.channel, value & 0x7F, (value >> 7) & 0x7F]))

    def note(self, start: float, length: float, pitch: int, velocity: int) -> None:
        on_tick = round(start * TICKS_PER_BEAT)
        off_tick = round((start + length - ARTICULATION_GAP) * TICKS_PER_BEAT)
        self.add(on_tick, 2, bytes([0x90 | self.channel, pitch, max(1, min(127, velocity))]))
        self.add(off_tick, 3, bytes([0x80 | self.channel, pitch, 0]))


def _pedal(track: Track) -> None:
    """Sustain down through each bar, lifted just before the next one."""
    for bar in range(len(CHORDS)):
        start = bar * 4 * TICKS_PER_BEAT
        end = start + 4 * TICKS_PER_BEAT
        track.control(start, 64, 127)
        track.control(end - 24, 64, 0)


def build_midi(name: str, channel: int, melody: bool, detune: bool) -> bytes:
    track = Track(name, channel, PIANO)
    if detune:
        # Pitch bend range: RPN 0, plus or minus 2 semitones (the GM default,
        # set explicitly so the render is deterministic).
        track.control(0, 101, 0)
        track.control(0, 100, 0)
        track.control(0, 6, 2)
        track.control(0, 38, 0)
        center = 0x2000
        bend = round(center + DETUNE_CENTS / 200.0 * 0x2000)
        track.bend(0, bend)
    if melody:
        for index, (bar, beat, length, pitch) in enumerate(MELODY):
            velocity = MELODY_DYNAMICS[bar] + ((index * 7) % 5) - 2
            track.note(bar * 4 + beat, length, pitch, velocity)
    else:
        for bar, chord in enumerate(CHORDS):
            for pitch in VOICINGS[chord]:
                track.note(bar * 4, 4.0, pitch, HARMONY_VELOCITY)
    _pedal(track)
    return _serialize(track)


def build_bass_midi(name: str, channel: int) -> bytes:
    track = Track(name, channel, PIANO)
    for bar, (root, fifth) in enumerate(BASS):
        track.note(bar * 4, 2.0, root, BASS_VELOCITY + (bar % 2) * 2)
        track.note(bar * 4 + 2, 2.0, fifth, BASS_VELOCITY)
    _pedal(track)
    return _serialize(track)


def _serialize(track: Track) -> bytes:
    """Write one type 0 MIDI file: meta first, then the track's events."""
    total = (BEATS + TAIL_BEATS) * TICKS_PER_BEAT
    tempo = round(60_000_000 / BPM)
    body = bytearray()
    body += _varlen(0) + b"\xff\x51\x03" + tempo.to_bytes(3, "big")
    body += _varlen(0) + b"\xff\x58\x04\x04\x02\x18\x08"
    last = 0
    for tick, _priority, payload in sorted(track.events, key=lambda e: (e[0], e[1])):
        body += _varlen(tick - last)
        body += payload
        last = tick
    body += _varlen(max(0, total - last)) + b"\xff\x2f\x00"
    data = b"MTrk" + len(body).to_bytes(4, "big") + bytes(body)
    return b"MThd" + (6).to_bytes(4, "big") + (0).to_bytes(2, "big") + (1).to_bytes(2, "big") + TICKS_PER_BEAT.to_bytes(2, "big") + data


# --- rendering and post processing -----------------------------------------

SOUNDFONT = "/usr/share/soundfonts/FluidR3_GM.sf2"
STEMS = ["melody", "harmony", "low", "detuned"]
TARGET_RMS_DB = -20.0
PEAK_CEILING = 0.891      # -1 dBFS


def _run(cmd: list[str]) -> None:
    print("  $", " ".join(cmd))
    subprocess.run(cmd, check=True, capture_output=True)


def _read_wav(path: str) -> tuple[int, int, array.array]:
    assert sys.byteorder == "little", "this script assumes little endian WAV"
    with wave.open(path, "rb") as handle:
        assert handle.getsampwidth() == 2, "expected 16 bit renders"
        channels = handle.getnchannels()
        rate = handle.getframerate()
        frames = handle.getnframes()
        samples = array.array("h")
        samples.frombytes(handle.readframes(frames))
    return rate, channels, samples


def _write_wav(path: str, rate: int, samples: array.array) -> None:
    with wave.open(path, "wb") as handle:
        handle.setnchannels(2)
        handle.setsampwidth(2)
        handle.setframerate(rate)
        handle.writeframes(samples.tobytes())


def _wrap_loop(samples: array.array) -> array.array:
    """Fold everything past the loop point back onto the start.

    The extra tail beats hold the piano's release and reverb, so carrying them
    to the top makes the loop seamless instead of cut off mid decay.
    """
    frames = len(samples) // 2
    assert frames >= LOOP_SAMPLES, f"render too short: {frames} < {LOOP_SAMPLES}"
    left = samples[0::2]
    right = samples[1::2]
    out = array.array("h", bytes(LOOP_SAMPLES * 4))
    tail_frames = frames - LOOP_SAMPLES
    for channel_data, offset in ((left, 0), (right, 1)):
        for i in range(LOOP_SAMPLES):
            value = channel_data[i]
            if i < tail_frames:
                value = max(-32768, min(32767, value + channel_data[LOOP_SAMPLES + i]))
            out[i * 2 + offset] = value
    return out


def _measure(samples: array.array) -> tuple[float, float]:
    frames = len(samples) // 2
    mono = array.array("i", (samples[i * 2] for i in range(frames)))
    mono.extend(samples[i * 2 + 1] for i in range(frames))
    peak = max(abs(v) for v in mono) / 32768.0
    rms = math.sqrt(sum(v * v for v in mono) / len(mono)) / 32768.0
    return peak, rms


def _loudness_match(samples: array.array, name: str) -> array.array:
    """Scale a stem to the common working level so mix anchors mean something."""
    peak, rms = _measure(samples)
    assert peak > 0.0 and rms > 0.0, f"{name} rendered silent"
    target = 10.0 ** (TARGET_RMS_DB / 20.0)
    gain = target / rms
    if peak * gain > PEAK_CEILING:
        gain = PEAK_CEILING / peak
        print(f"    {name}: peak guard engaged, gain {gain:.3f}")
    scaled = array.array("h", (max(-32768, min(32767, round(v * gain))) for v in samples))
    new_peak, new_rms = _measure(scaled)
    print(f"    {name}: rms {20 * math.log10(rms):6.1f} -> {20 * math.log10(new_rms):6.1f} dB, peak {new_peak:.3f}")
    return scaled


def main() -> int:
    here = os.path.dirname(os.path.abspath(__file__))
    repo = os.path.abspath(os.path.join(here, "..", "..", ".."))
    midi_dir = os.path.join(here, "midi")
    stems_dir = os.path.join(here, "..", "stems")
    build_dir = os.path.join(repo, "build", "audio")
    os.makedirs(midi_dir, exist_ok=True)
    os.makedirs(stems_dir, exist_ok=True)
    os.makedirs(build_dir, exist_ok=True)
    assert os.path.isfile(SOUNDFONT), f"missing SoundFont: {SOUNDFONT}"

    print(f"theme: {BEATS} beats at {BPM} BPM, loop {LOOP_SAMPLES} samples "
          f"({LOOP_SAMPLES / SAMPLE_RATE:.3f} s)")

    stems = {
        "melody": build_midi("melody", 0, melody=True, detune=False),
        "harmony": build_midi("harmony", 1, melody=False, detune=False),
        "low": build_bass_midi("low", 2),
        "detuned": build_midi("detuned", 3, melody=True, detune=True),
    }

    for name, data in stems.items():
        path = os.path.join(midi_dir, f"{name}.mid")
        with open(path, "wb") as handle:
            handle.write(data)
        print(f"  wrote {path} ({len(data)} bytes)")

    total_bytes = 0
    for name in STEMS:
        midi_path = os.path.join(midi_dir, f"{name}.mid")
        raw_path = os.path.join(build_dir, f"{name}_raw.wav")
        loop_path = os.path.join(build_dir, f"{name}_loop.wav")
        print(f"rendering {name}")
        _run(["fluidsynth", "-ni", "-g", "0.8", "-r", str(SAMPLE_RATE),
              "-R", "1", "-C", "0", "-F", raw_path, SOUNDFONT, midi_path])
        rate, channels, samples = _read_wav(raw_path)
        assert rate == SAMPLE_RATE and channels == 2, "unexpected render format"
        print(f"    render: {len(samples) // channels} frames")
        loop = _loudness_match(_wrap_loop(samples), name)
        _write_wav(loop_path, SAMPLE_RATE, loop)

        for variant, source, filters in (
            ("", loop_path, []),
            ("_lp", loop_path, ["lowpass=f=650"]),
        ):
            wav_path = os.path.join(build_dir, f"{name}{variant}_final.wav")
            ogg_path = os.path.join(stems_dir, f"{name}{variant}.ogg")
            if filters:
                _run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", source,
                      "-af", ",".join(filters), "-c:a", "pcm_s16le", wav_path])
                rate2, channels2, final = _read_wav(wav_path)
                assert channels2 == 2 and len(final) == len(loop), "low pass changed the length"
                final = _loudness_match(final, f"{name}{variant}")
                _write_wav(wav_path, SAMPLE_RATE, final)
            else:
                wav_path = loop_path
            _run(["ffmpeg", "-y", "-hide_banner", "-loglevel", "error", "-i", wav_path,
                  "-c:a", "libvorbis", "-q:a", "1", ogg_path])
            total_bytes += os.path.getsize(ogg_path)
            print(f"    {os.path.basename(ogg_path)}: {os.path.getsize(ogg_path)} bytes")

    print(f"total audio: {total_bytes / 1024 / 1024:.2f} MB (budget 8 MB)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
