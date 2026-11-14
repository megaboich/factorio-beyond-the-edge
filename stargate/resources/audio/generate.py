#!/usr/bin/env python3
"""Generate the Stargate sound bank and encode it as Ogg Vorbis.

Every sound is synthesised from seeded noise and oscillators, so a rerun over unchanged code writes
identical files. Needs ffmpeg with libvorbis. Helpers are duplicated from warp-drive's generator on
purpose: the mods share no code.

  stargate-open     the veil forming: suction into the ring, a soft burst, a shimmering settle
  stargate-close    the veil collapsing: a falling sweep and a sinking hum
  stargate-depart   stepping in: the veil's shimmer, fading
  stargate-arrive   stepping out: the shimmer swelling backwards to a peak as the traveller appears,
                    ARRIVE_PEAK seconds in, matching the 64-tick arrival (scripts/transfer.lua)
"""

from __future__ import annotations

import argparse
import math
import random
import shutil
import struct
import subprocess
import tempfile
import wave
from collections.abc import Callable, Sequence
from pathlib import Path

SAMPLE_RATE = 48_000
VORBIS_QUALITY = 5
PEAK = 0.8
OPEN_DURATION = 2.6
OPEN_BURST = 0.38
CLOSE_DURATION = 1.5
DEPART_DURATION = 1.8
ARRIVE_PEAK = 64 / 60
ARRIVE_DURATION = ARRIVE_PEAK + 0.7

OUTPUT_DIRECTORY = Path(__file__).resolve().parent


def clamp(value: float, minimum: float = 0.0, maximum: float = 1.0) -> float:
    return max(minimum, min(maximum, value))


def smoothstep(value: float) -> float:
    value = clamp(value)
    return value * value * (3.0 - 2.0 * value)


def samples_for(seconds: float) -> int:
    return round(seconds * SAMPLE_RATE)


def noise(count: int, seed: int) -> list[float]:
    generator = random.Random(seed)
    return [generator.uniform(-1.0, 1.0) for _ in range(count)]


def svf(samples: Sequence[float], cutoff: float | Sequence[float], q: float = 0.707, mode: str = "low") -> list[float]:
    """State-variable filter; `cutoff` may vary per sample. Band output has unity peak gain."""
    k = 1.0 / q
    varying = not isinstance(cutoff, (int, float))

    def coefficients(frequency: float) -> tuple[float, float, float]:
        g = math.tan(math.pi * clamp(frequency, 10.0, 0.45 * SAMPLE_RATE) / SAMPLE_RATE)
        a1 = 1.0 / (1.0 + g * (g + k))
        return a1, g * a1, g * g * a1

    a1, a2, a3 = coefficients(cutoff[0] if varying else cutoff)
    ic1 = ic2 = 0.0
    output: list[float] = []
    for index, x in enumerate(samples):
        if varying:
            a1, a2, a3 = coefficients(cutoff[index])
        v3 = x - ic2
        v1 = a1 * ic1 + a2 * v3
        v2 = ic2 + a2 * ic1 + a3 * v3
        ic1 = 2.0 * v1 - ic1
        ic2 = 2.0 * v2 - ic2
        output.append(v2 if mode == "low" else k * v1 if mode == "band" else x - k * v1 - v2)
    return output


def echo(samples: Sequence[float], delays: Sequence[float], feedback: float, tail: float) -> list[float]:
    """A few feedback delays in parallel: a cheap, dark room for the veil's resonance."""
    padded = list(samples) + [0.0] * samples_for(tail)
    output = list(padded)
    for delay in delays:
        length = samples_for(delay)
        buffer = [0.0] * length
        position = 0
        for index, x in enumerate(padded):
            delayed = buffer[position]
            buffer[position] = x + delayed * feedback
            output[index] += delayed / len(delays)
            position = (position + 1) % length
    return output


def normalize(samples: Sequence[float], peak: float = PEAK) -> list[float]:
    measured = max(abs(sample) for sample in samples) or 1.0
    return [sample * peak / measured for sample in samples]


def fade_edges(samples: list[float], fade_in: float = 0.004, fade_out: float = 0.08) -> list[float]:
    count = len(samples)
    rise, fall = samples_for(fade_in), samples_for(fade_out)
    return [s * smoothstep(i / rise) * smoothstep((count - 1 - i) / fall) for i, s in enumerate(samples)]


def shimmer(count: int, start: float, seed: int, decay: float) -> list[float]:
    """Watery high partials that wobble and fade: the veil settling."""
    generator = random.Random(seed)
    partials = [(generator.uniform(500, 1700), generator.uniform(2.0, 7.0), generator.uniform(0, math.tau)) for _ in range(9)]
    output = []
    for index in range(count):
        time = index / SAMPLE_RATE
        elapsed = time - start
        if elapsed < 0:
            output.append(0.0)
            continue
        value = sum(math.sin(math.tau * f * time + 0.004 * f * math.sin(math.tau * w * time + p)) for f, w, p in partials)
        output.append(value / len(partials) * math.exp(-elapsed / decay) * smoothstep(elapsed / 0.05))
    return output


def generate_open() -> list[float]:
    count = samples_for(OPEN_DURATION)
    hiss = noise(count, 0x5A7E)
    sweep = svf(hiss, [200 * (2500 / 200) ** clamp(i / samples_for(OPEN_BURST)) for i in range(count)], q=2.0, mode="band")
    burst = svf(noise(count, 0x5A7F), 900)
    wash = shimmer(count, OPEN_BURST, 0x5A80, 0.9)
    samples = []
    for index in range(count):
        time = index / SAMPLE_RATE
        before = time < OPEN_BURST
        after = time - OPEN_BURST
        suction = sweep[index] * (smoothstep(time / OPEN_BURST) ** 2 if before else math.exp(-after / 0.05))
        blast = 0.0 if before else burst[index] * math.exp(-after / 0.25) * smoothstep(after / 0.015)
        hum = 0.0 if before else math.sin(math.tau * 74 * time) * smoothstep(after / 0.6) * smoothstep((OPEN_DURATION - time) / 0.8)
        samples.append(0.5 * suction + 0.8 * blast + 0.25 * wash[index] + 0.12 * hum)
    return fade_edges(normalize(echo(samples, (0.043, 0.071, 0.113), 0.45, 0.0)))


def generate_close() -> list[float]:
    count = samples_for(CLOSE_DURATION)
    sweep = svf(noise(count, 0xC105), [2200 * (150 / 2200) ** (i / count) for i in range(count)], q=1.6, mode="band")
    samples = []
    phase = 0.0
    for index in range(count):
        time = index / SAMPLE_RATE
        phase += (74 - 34 * time / CLOSE_DURATION) / SAMPLE_RATE
        envelope = smoothstep(time / 0.06) * (1 - time / CLOSE_DURATION) ** 1.5
        samples.append(envelope * (0.6 * sweep[index] + 0.35 * math.sin(math.tau * phase)))
    return fade_edges(normalize(echo(samples, (0.051, 0.089), 0.4, 0.0)))


def generate_depart() -> list[float]:
    count = samples_for(DEPART_DURATION)
    samples = shimmer(count, 0.0, 0xD3A8, 0.55)
    return fade_edges(normalize(echo(samples, (0.037, 0.061, 0.097), 0.5, 0.0)), fade_in=0.03)


def generate_arrive() -> list[float]:
    count = samples_for(ARRIVE_DURATION)
    peak = samples_for(ARRIVE_PEAK)
    # The shimmer played backwards swells up to the moment of arrival, then rings out forwards.
    swell = shimmer(peak, 0.0, 0xA221, 0.35)[::-1]
    ring = shimmer(count - peak, 0.0, 0xA221, 0.3)
    samples = [swell[i] * smoothstep(i / peak) for i in range(peak)] + ring
    return fade_edges(normalize(echo(samples, (0.041, 0.067), 0.45, 0.0)), fade_in=0.02)


def write_wave(path: Path, samples: Sequence[float]) -> None:
    pcm = bytearray()
    for sample in samples:
        pcm.extend(struct.pack("<h", round(clamp(sample, -1.0, 1.0) * 32_767.0)))
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        output.writeframes(pcm)


def encode_ogg(ffmpeg: str, wave_path: Path, output_path: Path) -> None:
    subprocess.run(
        [ffmpeg, "-y", "-hide_banner", "-loglevel", "error", "-i", str(wave_path), "-map_metadata", "-1",
         "-bitexact", "-serial_offset", "1", "-c:a", "libvorbis", "-q:a", str(VORBIS_QUALITY), str(output_path)],
        check=True,
    )


def outputs() -> dict[str, Callable[[], Sequence[float]]]:
    return {
        "stargate-open": generate_open,
        "stargate-close": generate_close,
        "stargate-depart": generate_depart,
        "stargate-arrive": generate_arrive,
    }


# Homebrew's plain ffmpeg formula has no libvorbis; its ffmpeg-full keg does.
FFMPEG_FULL = "/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg"


def has_libvorbis(ffmpeg: str) -> bool:
    encoders = subprocess.run([ffmpeg, "-hide_banner", "-encoders"], capture_output=True, text=True).stdout
    return " libvorbis " in encoders


def find_ffmpeg(requested: str) -> str:
    for candidate in (shutil.which(requested), shutil.which(FFMPEG_FULL)):
        if candidate and has_libvorbis(candidate):
            return candidate
    raise SystemExit("ffmpeg with libvorbis is required; install it with: brew install ffmpeg-full")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--ffmpeg", default="ffmpeg", help="ffmpeg executable (default: ffmpeg from PATH)")
    parser.add_argument("--only", nargs="+", metavar="NAME", help="render only these outputs, such as stargate-open")
    arguments = parser.parse_args()
    ffmpeg = find_ffmpeg(arguments.ffmpeg)
    sounds = outputs()
    names = arguments.only or list(sounds)
    unknown = sorted(set(names) - set(sounds))
    if unknown:
        raise SystemExit(f"unknown outputs: {', '.join(unknown)}")
    with tempfile.TemporaryDirectory() as temporary:
        for name in names:
            wave_path = Path(temporary) / f"{name}.wav"
            write_wave(wave_path, sounds[name]())
            output_path = OUTPUT_DIRECTORY / f"{name}.ogg"
            encode_ogg(ffmpeg, wave_path, output_path)
            print(f"generated {output_path.name}")


if __name__ == "__main__":
    main()
