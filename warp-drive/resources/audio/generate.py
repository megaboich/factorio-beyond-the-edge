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
BUZZ_OUTPUT_GAIN = 1.40
BUZZ_EARLY_PRESENCE_GAIN = 1.40
FAILED_ACTIVATION_DURATION = 1.6

ACTIVATION_DURATION = 1.5
DEACTIVATION_DURATION = ACTIVATION_DURATION
TRANSITION_OUTPUT_GAIN = 1.20
BACKGROUND_DURATION = 12.0
BACKGROUND_SEGMENT_DURATION = BACKGROUND_DURATION / 2.0
BACKGROUND_OUTPUT_GAIN = 2.0
OUTPUT_PEAK_LIMIT = 0.88
ENCODER_SAFE_PEAK = 0.82

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


def gain_with_peak_limit(
    samples: Sequence[float], gain: float, peak: float = OUTPUT_PEAK_LIMIT
) -> list[float]:
    """Raise perceived level while containing only the strongest transient peaks."""
    knee = peak * 0.75
    limited: list[float] = []
    for sample in samples:
        driven = sample * gain
        magnitude = abs(driven)
        if magnitude > knee:
            magnitude = knee + (peak - knee) * (
                1.0 - math.exp(-(magnitude - knee) / (peak - knee))
            )
        limited.append(math.copysign(magnitude, driven))
    return limited


def add_encoder_headroom(samples: Sequence[float]) -> list[float]:
    """Leave room for Vorbis reconstruction overshoot on dense transition mixes."""
    measured_peak = max(abs(sample) for sample in samples)
    if measured_peak > ENCODER_SAFE_PEAK:
        return normalize(samples, ENCODER_SAFE_PEAK)
    return list(samples)


def periodic_sample(samples: Sequence[float], position: float) -> float:
    """Read a looping waveform with interpolation so accelerating it remains smooth."""
    before = math.floor(position) % len(samples)
    after = (before + 1) % len(samples)
    fraction = position - math.floor(position)
    return samples[before] + (samples[after] - samples[before]) * fraction


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
        early_presence = 1.0 + (
            BUZZ_EARLY_PRESENCE_GAIN - 1.0
        ) * (1.0 - charge) ** 1.4
        samples.append(codec_envelope * sample * BUZZ_OUTPUT_GAIN * early_presence)

    measured_peak = max(abs(sample) for sample in samples)
    if measured_peak > OUTPUT_PEAK_LIMIT:
        return normalize(samples, peak=OUTPUT_PEAK_LIMIT)
    return samples


def generate_activation() -> list[float]:
    """Build a rising dimensional tear, portal impact, and phase-aligned tail."""
    sample_count = round(ACTIVATION_DURATION * SAMPLE_RATE)
    final_buzz = generate_buzz(BUZZ_HIGH_HZ, 1.0, 0xB022 + BUZZ_COUNT - 1)[
        BUZZ_ENCODER_PREROLL_SAMPLES:
    ]
    rng = random.Random(0xA71C)
    air_low = 0.0
    air_high = 0.0
    rumble = 0.0
    blast_body = 0.0
    collapse_low = 0.0
    collapse_high = 0.0
    buzz_position = 0.0
    detuned_position_low = 0.0
    detuned_position_high = 0.0
    morph_samples: list[float] = []
    impact_samples: list[float] = []
    portal_time = 0.54

    for index in range(sample_count):
        time = index / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0)
        approach = smoothstep(time / portal_time)
        low_cutoff = 75.0 + 925.0 * approach
        high_cutoff = 700.0 + 9_300.0 * approach
        air_low += one_pole_alpha(low_cutoff) * (noise - air_low)
        air_high += one_pole_alpha(high_cutoff) * (noise - air_high)
        rumble += one_pole_alpha(105.0) * (noise - rumble)
        blast_body += one_pole_alpha(1_350.0) * (noise - blast_body)
        air_band = air_high - air_low
        blast_mid = blast_body - rumble

        morph = smoothstep((time - 0.02) / 0.48)
        playback_rate = 1.0 + 2.4 * morph**1.5
        carrier = periodic_sample(final_buzz, buzz_position)
        detuned_low = periodic_sample(final_buzz, detuned_position_low)
        detuned_high = periodic_sample(final_buzz, detuned_position_high)
        buzz_position += playback_rate
        detuned_position_low += playback_rate * (1.0 - 0.014 * morph)
        detuned_position_high += playback_rate * (1.0 + 0.021 * morph)

        saturated = math.tanh(carrier * (1.4 + 1.7 * morph))
        source_pulse = 0.28 + 0.72 * min(1.0, abs(carrier) * 1.8)
        excited_air = air_band * source_pulse
        accelerated_buzz = (
            0.47 * carrier
            + 0.17 * detuned_low
            + 0.17 * detuned_high
            + 0.19 * saturated
        )
        air_emergence = smoothstep((time - 0.12) / 0.36)
        final_flare = smoothstep((time - (portal_time - 0.12)) / 0.10)
        source_texture = (1.0 - 0.28 * morph) * carrier + morph * (
            0.72 * accelerated_buzz
            + air_emergence * (0.42 + 0.48 * final_flare) * excited_air
            + 0.12 * air_emergence * rumble
        )

        pre_rupture_dip = 1.0 - 0.94 * smoothstep(
            (time - (portal_time - 0.055)) / 0.042
        )
        release = 1.0 - smoothstep((time - portal_time) / 0.065)
        swell_phase = math.tau * (
            31.0 * time + 19.0 * time * time / (2.0 * portal_time)
        )
        shear_phase = math.tau * (
            128.0 * time + 590.0 * time * time / (2.0 * portal_time)
        )
        spectral_shear = math.sin(
            shear_phase + 2.8 * math.sin(math.tau * 5.3 * time)
        ) * source_pulse
        morph_sound = pre_rupture_dip * release * (
            source_texture
            + air_emergence * (
                0.20 * math.sin(swell_phase)
                + (0.07 + 0.13 * final_flare) * spectral_shear
            )
        )

        elapsed = time - portal_time
        impact = 0.0
        if elapsed >= 0.0:
            collapse = smoothstep(elapsed / 0.62)
            collapse_low_cutoff = 1_700.0 * (65.0 / 1_700.0) ** collapse
            collapse_high_cutoff = 5_200.0 * (420.0 / 5_200.0) ** collapse
            collapse_low += one_pole_alpha(collapse_low_cutoff) * (
                noise - collapse_low
            )
            collapse_high += one_pole_alpha(collapse_high_cutoff) * (
                noise - collapse_high
            )
            collapse_air = collapse_high - collapse_low
            pressure_phase = math.tau * (
                72.0 * elapsed - 18.0 * elapsed * elapsed
            )
            sub_phase = math.tau * (
                41.0 * elapsed - 8.0 * elapsed * elapsed
            )
            fold_phase = math.tau * (
                980.0 * elapsed - 610.0 * elapsed * elapsed
            )
            fracture_phase = math.tau * (
                3_200.0 * elapsed - 2_350.0 * elapsed * elapsed
            )
            rupture = math.exp(-82.0 * elapsed)
            fold_envelope = (1.0 - math.exp(-90.0 * elapsed)) * math.exp(
                -4.8 * elapsed
            )
            vacuum_gate = 1.0 - smoothstep((elapsed - 0.58) / 0.34)

            # The wide rupture folds rapidly toward the sub pulse: descending
            # inharmonic bands and a closing noise band imply space collapsing inward.
            impact = -1.95 * math.exp(-5.8 * elapsed) * math.cos(pressure_phase)
            impact -= 1.42 * math.exp(-3.9 * elapsed) * math.sin(sub_phase)
            impact += rupture * (
                1.05 * noise + 0.62 * math.sin(fracture_phase)
            )
            impact += fold_envelope * (
                1.42 * collapse_air
                + 0.74 * math.sin(fold_phase)
                + 0.58 * blast_mid
                + 0.78 * rumble
            )
            impact = vacuum_gate * math.tanh(2.15 * impact)

        fade = edge_fade(index, sample_count, 0.008, 0.12)
        morph_samples.append(morph_sound * fade)
        impact_samples.append(impact * fade)

    morph_peak = max(abs(sample) for sample in morph_samples)
    if morph_peak > 0.64:
        morph_samples = normalize(morph_samples, peak=0.64)
    impact_samples = normalize(impact_samples, peak=0.90)
    samples: list[float] = []
    for index, (morph_sound, impact) in enumerate(
        zip(morph_samples, impact_samples)
    ):
        time = index / SAMPLE_RATE
        # Leave a conspicuous vacuum after the implosion, then meet the background
        # waveform only at the clip boundary so the following segment stays clean.
        ambience_gain = smoothstep((time - (ACTIVATION_DURATION - 0.08)) / 0.08)
        ambience_time = BACKGROUND_DURATION - ACTIVATION_DURATION + time
        samples.append(
            morph_sound
            + impact
            + ambience_gain * background_sample(ambience_time)
        )

    next_sample_delta = abs(background_sample(0.0) - samples[-1])
    if next_sample_delta > 0.01:
        raise RuntimeError("activation tail no longer joins the background cleanly")
    return add_encoder_headroom(gain_with_peak_limit(samples, 1.12, peak=0.90))


def generate_failed_activation(
    frequency_hz: float, charge: float, seed: int
) -> list[float]:
    """Wind a matching charge hum down into an uneven, disappointed power-off."""
    sample_count = round(FAILED_ACTIVATION_DURATION * SAMPLE_RATE)
    buzz = generate_buzz(frequency_hz, charge, seed)[BUZZ_ENCODER_PREROLL_SAMPLES:]
    rng = random.Random(seed ^ 0xFA17)
    position = 0.0
    sag_phase = 0.0
    hum = 0.0
    samples: list[float] = []

    for index in range(sample_count):
        time = index / SAMPLE_RATE
        progress = smoothstep(time / FAILED_ACTIVATION_DURATION)
        playback_rate = 1.0 - 0.63 * progress**1.25
        carrier = periodic_sample(buzz, position)
        position += playback_rate

        sag_frequency = frequency_hz * (0.92 - 0.56 * progress)
        sag_phase += math.tau * sag_frequency / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0)
        hum += one_pole_alpha(310.0 - 220.0 * progress) * (noise - hum)
        uneven_power = 1.0 - 0.32 * progress * (
            0.5 + 0.5 * math.sin(math.tau * (2.1 * time + 0.35 * time * time))
        )
        envelope = (1.0 - smoothstep((time - 0.08) / 1.38)) * uneven_power
        sample = envelope * (
            (0.94 - 0.30 * progress) * carrier
            + 0.18 * progress * math.sin(sag_phase)
            + 0.08 * progress * hum
        )

        thud_time = time - 1.22
        if thud_time >= 0.0:
            thud_phase = math.tau * (54.0 * thud_time - 9.0 * thud_time * thud_time)
            sample += 0.24 * math.exp(-13.0 * thud_time) * math.sin(thud_phase)
        samples.append(sample * edge_fade(index, sample_count, 0.006, 0.08))

    return gain_with_peak_limit(samples, 1.0, peak=0.72)


def generate_deactivation() -> list[float]:
    """Reverse activation so deactivation unfolds from the same rupture."""
    reversed_activation = list(reversed(generate_activation()))
    sample_count = len(reversed_activation)
    return [
        sample * edge_fade(index, sample_count, 0.012, 0.012)
        for index, sample in enumerate(reversed_activation)
    ]


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
    return sample * BACKGROUND_OUTPUT_GAIN


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
                ffmpeg,
                temporary_directory,
                f"warp-failed-activation-{index + 1:02d}",
                lambda frequency=frequency, index=index: generate_failed_activation(
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
