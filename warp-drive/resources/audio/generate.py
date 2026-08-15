#!/usr/bin/env python3
"""Generate the Warp Drive sound bank and encode it as Ogg Vorbis."""

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

BUZZ_COUNT = 20
BUZZ_DURATION = 0.5
BUZZ_LOW_HZ = 48.0
BUZZ_HIGH_HZ = 62.0
# libvorbis consumes 128 leading PCM samples when these files are decoded.
BUZZ_ENCODER_PREROLL_SAMPLES = 128
BUZZ_CODEC_FADE = 0.006

ACTIVATION_DURATION = 3.0
DEACTIVATION_DURATION = 3.0
BACKGROUND_DURATION = 12.0
BACKGROUND_SEGMENT_DURATION = BACKGROUND_DURATION / 2.0

OUTPUT_DIRECTORY = Path(__file__).resolve().parent


def clamp(value: float, minimum: float = 0.0, maximum: float = 1.0) -> float:
    return max(minimum, min(maximum, value))


def smoothstep(value: float) -> float:
    value = clamp(value)
    return value * value * (3.0 - 2.0 * value)


def edge_fade(index: int, sample_count: int, fade_in: float, fade_out: float) -> float:
    fade_in_samples = max(1, round(fade_in * SAMPLE_RATE))
    fade_out_samples = max(1, round(fade_out * SAMPLE_RATE))
    return smoothstep(index / fade_in_samples) * smoothstep(
        (sample_count - 1 - index) / fade_out_samples
    )


def one_pole_alpha(cutoff_hz: float) -> float:
    return 1.0 - math.exp(-math.tau * cutoff_hz / SAMPLE_RATE)


def normalize(samples: Sequence[float], peak: float) -> list[float]:
    measured_peak = max(abs(sample) for sample in samples)
    if measured_peak == 0.0:
        return list(samples)
    gain = peak / measured_peak
    return [sample * gain for sample in samples]


def generate_buzz(frequency_hz: float, charge: float, seed: int) -> list[float]:
    """Build a periodic accumulator hum with magnetic and inverter texture."""
    loop_sample_count = round(BUZZ_DURATION * SAMPLE_RATE)
    sample_count = loop_sample_count + BUZZ_ENCODER_PREROLL_SAMPLES
    loop_duration = loop_sample_count / SAMPLE_RATE
    rng = random.Random(seed)
    base_cycles = round(frequency_hz * loop_duration)
    base_frequency = base_cycles / loop_duration
    beat_cycles = round((4.0 + 4.0 * charge) * loop_duration)
    mechanical_cycles = round((92.0 + 28.0 * charge) * loop_duration)
    inverter_cycles = (
        round((540.0 + 1_050.0 * charge) * loop_duration),
        round((1_130.0 + 1_920.0 * charge) * loop_duration),
        round((2_020.0 + 2_580.0 * charge) * loop_duration),
    )
    inverter_phases = tuple(rng.uniform(0.0, math.tau) for _ in inverter_cycles)
    samples: list[float] = []

    for index in range(sample_count):
        time = (index - BUZZ_ENCODER_PREROLL_SAMPLES) / SAMPLE_RATE
        loop_time = time % loop_duration
        phase = math.tau * base_frequency * time
        beat_phase = math.tau * beat_cycles * time / loop_duration
        mechanical_phase = math.tau * mechanical_cycles * time / loop_duration
        magnetic_phase = phase + (0.10 + 0.08 * charge) * math.sin(beat_phase)
        magnetic_wave = math.tanh(
            (1.55 + 0.85 * charge) * math.sin(magnetic_phase)
        )
        transformer_body = (
            0.48 * magnetic_wave
            + 0.15 * math.sin(2.0 * phase + 0.22 * math.sin(beat_phase))
            + 0.06 * math.sin(4.0 * phase)
        )
        mechanical_rattle = (0.07 + 0.05 * charge) * math.sin(
            mechanical_phase + 0.30 * math.sin(phase)
        ) * (0.65 + 0.35 * abs(math.sin(phase)))
        inverter_texture = sum(
            weight
            * (
                math.sin(math.tau * cycles * time / loop_duration + phase_offset)
                - math.sin(phase_offset)
            )
            for cycles, phase_offset, weight in zip(
                inverter_cycles, inverter_phases, (0.56, 0.29, 0.15)
            )
        )
        sample = (0.44 + 0.10 * charge) * transformer_body + mechanical_rattle
        sample += (0.012 + 0.055 * charge**1.7) * inverter_texture
        codec_envelope = smoothstep(loop_time / BUZZ_CODEC_FADE) * smoothstep(
            (loop_duration - loop_time) / BUZZ_CODEC_FADE
        )
        samples.append(codec_envelope * sample)

    measured_peak = max(abs(sample) for sample in samples)
    if measured_peak > 0.90:
        return normalize(samples, peak=0.90)
    return samples


def generate_activation() -> list[float]:
    """Synthesize a dramatic warp release and align its tail with the ambience."""
    sample_count = round(ACTIVATION_DURATION * SAMPLE_RATE)
    rng = random.Random(0xA71C)
    noise_low = 0.0
    noise_high = 0.0
    transient_samples: list[float] = []

    for index in range(sample_count):
        time = index / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0)
        noise_low += one_pole_alpha(210.0) * (noise - noise_low)
        noise_high += one_pole_alpha(4_800.0) * (noise - noise_high)
        shock_air = noise_high - noise_low

        bass_phase = math.tau * (96.0 * time - 24.0 * time * time)
        sample = 0.78 * math.exp(-3.6 * time) * math.sin(bass_phase)
        sample += 0.34 * math.exp(-8.5 * time) * math.sin(
            math.tau * (238.0 * time - 52.0 * time * time)
        )

        impact_time = time - 0.09
        if impact_time >= 0.0:
            impact_phase = math.tau * (
                68.0 * impact_time - 13.0 * impact_time * impact_time
            )
            sample += 0.92 * math.exp(-4.1 * impact_time) * math.sin(impact_phase)
            sample += 0.24 * math.exp(-15.0 * impact_time) * math.sin(
                math.tau * 330.0 * impact_time
            )

        sample += 0.50 * math.exp(-26.0 * time) * noise
        sample += 0.30 * math.exp(-5.8 * time) * shock_air
        sample += 0.19 * math.exp(-2.8 * time) * math.sin(
            math.tau * (1_760.0 * time - 410.0 * time * time)
            + 4.2 * math.sin(math.tau * 8.0 * time)
        )
        sample += 0.08 * math.exp(-1.8 * time) * math.sin(
            math.tau * (620.0 * time + 95.0 * time * time)
        )

        sample *= smoothstep(time / 0.003)
        transient_samples.append(sample)

    transient_samples = normalize(transient_samples, peak=0.90)
    samples: list[float] = []
    for index, transient in enumerate(transient_samples):
        time = index / SAMPLE_RATE
        ambience_gain = smoothstep((time - 0.35) / 1.10)
        ambience_time = BACKGROUND_DURATION - ACTIVATION_DURATION + time
        samples.append(transient + ambience_gain * background_sample(ambience_time))

    next_sample_delta = abs(background_sample(0.0) - samples[-1])
    if next_sample_delta > 0.01:
        raise RuntimeError("activation tail no longer joins the background cleanly")
    return samples


def generate_deactivation() -> list[float]:
    """Synthesize an immediate implosion followed by descending, fading hum."""
    sample_count = round(DEACTIVATION_DURATION * SAMPLE_RATE)
    rng = random.Random(0xDEA7)
    phase = 0.0
    noise_high = 0.0
    noise_low = 0.0
    samples: list[float] = []

    for index in range(sample_count):
        time = index / SAMPLE_RATE
        decay = clamp(time / DEACTIVATION_DURATION)
        frequency = 820.0 * (58.0 / 820.0) ** (decay**0.82)
        phase += math.tau * frequency / SAMPLE_RATE

        noise = rng.uniform(-1.0, 1.0)
        high_cutoff = 7_900.0 - 6_800.0 * decay**0.72
        low_cutoff = 2_280.0 - 2_100.0 * decay**0.72
        noise_high += one_pole_alpha(high_cutoff) * (noise - noise_high)
        noise_low += one_pole_alpha(low_cutoff) * (noise - noise_low)
        fading_air = noise_high - noise_low

        tone = (
            0.29 * math.sin(phase + 0.20 * math.sin(math.tau * 6.2 * time))
            + 0.10 * math.sin(2.0 * phase + 0.5)
            + 0.06 * math.sin(0.5 * phase + 1.3)
        )
        hum_envelope = smoothstep(time / 0.05) * (1.0 - smoothstep(decay))
        sample = hum_envelope * (0.45 * tone + 0.18 * (1.0 - decay) * fading_air)

        bass_phase = math.tau * (72.0 * time - 15.0 * time * time)
        sample += 0.88 * math.exp(-3.8 * time) * math.sin(bass_phase)
        sample += 0.24 * math.exp(-9.0 * time) * math.sin(
            math.tau * (168.0 * time - 31.0 * time * time)
        )
        sample += 0.38 * math.exp(-29.0 * time) * noise
        sample -= 0.16 * math.exp(-7.5 * time) * math.cos(math.tau * 38.0 * time)

        sample *= edge_fade(index, sample_count, 0.003, 0.20)
        samples.append(sample)

    return normalize(samples, peak=0.90)


def ping_voice(time: float, start: float, frequency_hz: float, gain: float) -> float:
    """Render one soft console ping with a quick attack and lingering decay."""
    elapsed = time - start
    if elapsed < 0.0 or elapsed > 1.2:
        return 0.0

    envelope = smoothstep(elapsed / 0.012) * math.exp(-4.4 * elapsed)
    phase = math.tau * (
        frequency_hz * elapsed - 0.075 * frequency_hz * elapsed * elapsed
    )
    return gain * envelope * (
        math.sin(phase) + 0.22 * math.sin(2.01 * phase + 0.35)
    )


def hyperspace_sonar_voice(time: float, start: float, gain: float) -> float:
    """Render a long descending sonar call with a faint rising return echo."""
    elapsed = time - start
    if elapsed < 0.0 or elapsed > 2.2:
        return 0.0

    call_envelope = smoothstep(elapsed / 0.08) * math.exp(-1.8 * elapsed)
    call_phase = math.tau * (
        1_080.0 * elapsed - 250.0 * elapsed * elapsed + 26.0 * elapsed**3
    )
    call = call_envelope * (
        math.sin(call_phase + 1.8 * math.sin(math.tau * 2.2 * elapsed))
        + 0.18 * math.sin(0.5 * call_phase + 0.9)
    )

    echo_elapsed = elapsed - 0.72
    echo = 0.0
    if echo_elapsed >= 0.0:
        echo_envelope = smoothstep(echo_elapsed / 0.06) * math.exp(
            -2.7 * echo_elapsed
        )
        echo_phase = math.tau * (
            360.0 * echo_elapsed + 115.0 * echo_elapsed * echo_elapsed
        )
        echo = 0.42 * echo_envelope * math.sin(echo_phase)

    return gain * (call + echo)


def background_bed(time: float) -> float:
    """Render the periodic machinery layer shared by activation and ambience."""
    slow_breathe = 0.92 + 0.08 * math.sin(
        math.tau * 3.0 * time / BACKGROUND_DURATION
    )
    hum = (
        0.030 * math.sin(math.tau * 42.0 * time)
        + 0.016 * math.sin(math.tau * 57.0 * time + 0.8)
        + 0.008 * math.sin(math.tau * 83.0 * time + 1.7)
    )
    machinery = 0.006 * math.sin(
        math.tau * 7.0 * time / BACKGROUND_DURATION
    ) * math.sin(math.tau * 126.0 * time)
    periodic_noise = (
        math.sin(math.tau * 293.0 * time / BACKGROUND_DURATION + 0.4)
        + 0.55 * math.sin(math.tau * 617.0 * time / BACKGROUND_DURATION + 1.8)
        + 0.30 * math.sin(math.tau * 1_201.0 * time / BACKGROUND_DURATION + 2.7)
    )
    return slow_breathe * hum + machinery + 0.0025 * periodic_noise


def background_sample(time: float) -> float:
    """Render the complete background mix at one position in its loop."""
    time %= BACKGROUND_DURATION
    sample = background_bed(time)
    second_half = smoothstep((time - 5.8) / 0.55) * (
        1.0 - smoothstep((time - 11.15) / 0.55)
    )
    hyperspace_shimmer = (
        math.sin(math.tau * (372.0 * time + 4.5 * math.sin(math.tau * time / 3.0)))
        + 0.45
        * math.sin(
            math.tau * (561.0 * time - 3.2 * math.sin(math.tau * time / 2.0))
            + 1.1
        )
    )
    sample += 0.0045 * second_half * hyperspace_shimmer

    for start, frequency_hz, gain in (
        (1.35, 740.0, 0.048),
        (1.56, 1_110.0, 0.025),
        (4.10, 620.0, 0.043),
    ):
        sample += ping_voice(time, start, frequency_hz, gain)
    for start, gain in ((6.48, 0.054), (9.12, 0.047)):
        sample += hyperspace_sonar_voice(time, start, gain)
    return sample


def generate_background_segment(start_time: float) -> list[float]:
    """Render one phase-contiguous half of the alternating background sequence."""
    sample_count = round(BACKGROUND_SEGMENT_DURATION * SAMPLE_RATE)
    return [
        background_sample(start_time + index / SAMPLE_RATE)
        for index in range(sample_count)
    ]


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
        [
            ffmpeg,
            "-y",
            "-hide_banner",
            "-loglevel",
            "error",
            "-i",
            str(wave_path),
            "-map_metadata",
            "-1",
            "-bitexact",
            "-serial_offset",
            "1",
            "-c:a",
            "libvorbis",
            "-q:a",
            str(VORBIS_QUALITY),
            str(output_path),
        ],
        check=True,
    )


def render_sound(
    ffmpeg: str,
    temporary_directory: Path,
    output_name: str,
    generator: Callable[[], list[float]],
) -> None:
    wave_path = temporary_directory / f"{output_name}.wav"
    output_path = OUTPUT_DIRECTORY / f"{output_name}.ogg"
    write_wave(wave_path, generator())
    encode_ogg(ffmpeg, wave_path, output_path)
    print(f"generated {output_path.name}")


def parse_arguments() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--ffmpeg",
        default="ffmpeg",
        help="ffmpeg executable to use (default: ffmpeg from PATH)",
    )
    return parser.parse_args()


def main() -> None:
    arguments = parse_arguments()
    ffmpeg = shutil.which(arguments.ffmpeg)
    if ffmpeg is None:
        raise SystemExit("ffmpeg is required; install it with: brew install ffmpeg")

    with tempfile.TemporaryDirectory(prefix="warp-audio-") as temporary:
        temporary_directory = Path(temporary)
        for index in range(BUZZ_COUNT):
            frequency = BUZZ_LOW_HZ * (BUZZ_HIGH_HZ / BUZZ_LOW_HZ) ** (
                index / (BUZZ_COUNT - 1)
            )
            render_sound(
                ffmpeg,
                temporary_directory,
                f"warp-buzz-{index + 1:02d}",
                lambda frequency=frequency, index=index: generate_buzz(
                    frequency,
                    charge=index / (BUZZ_COUNT - 1),
                    seed=0xB022 + index,
                ),
            )

        render_sound(
            ffmpeg, temporary_directory, "warp-activation", generate_activation
        )
        render_sound(
            ffmpeg, temporary_directory, "warp-deactivation", generate_deactivation
        )
        for index in range(2):
            render_sound(
                ffmpeg,
                temporary_directory,
                f"warp-background-{index + 1:02d}",
                lambda index=index: generate_background_segment(
                    index * BACKGROUND_SEGMENT_DURATION
                ),
            )

        obsolete_background = OUTPUT_DIRECTORY / "warp-background.ogg"
        if obsolete_background.exists():
            obsolete_background.unlink()


if __name__ == "__main__":
    main()
