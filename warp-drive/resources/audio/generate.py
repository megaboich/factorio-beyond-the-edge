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
from collections import deque
from collections.abc import Callable, Sequence
from pathlib import Path


SAMPLE_RATE = 48_000
VORBIS_QUALITY = 5

BUZZ_COUNT = 20
BUZZ_DURATION = 0.5
BUZZ_LOW_HZ = 48.0
BUZZ_HIGH_HZ = 62.0
# The capacitor whine carries the charge on speakers that cannot reproduce the hum.
WHINE_LOW_HZ = 190.0
WHINE_HIGH_HZ = 760.0
# libvorbis consumes 128 leading PCM samples when these files are decoded.
BUZZ_ENCODER_PREROLL_SAMPLES = 128
BUZZ_CODEC_FADE = 0.006
BUZZ_OUTPUT_GAIN = 1.25
BUZZ_EARLY_PRESENCE_GAIN = 1.35
FAILED_ACTIVATION_DURATION = 1.6

# Activation: a short suction into the breach, timed with the building's flash, then a long
# stereo aftermath that fades into the warp ambience.
ACTIVATION_DURATION = 5.0
ACTIVATION_BREACH = 0.54
DEACTIVATION_DURATION = 3.2
DEACTIVATION_EXIT = 0.75
TRANSITION_PEAK = 0.64
BACKGROUND_DURATION = 12.0
BACKGROUND_SEGMENT_DURATION = BACKGROUND_DURATION / 2.0
BACKGROUND_OUTPUT_GAIN = 1.3
# The building's loop while warp holds: four 64-tick animation loops.
FIELD_HUM_DURATION = 256 / 60
FIELD_HUM_PEAK = 0.7
OUTPUT_PEAK_LIMIT = 0.88
ENCODER_SAFE_PEAK = 0.82

OUTPUT_DIRECTORY = Path(__file__).resolve().parent

Stereo = tuple[list[float], list[float]]


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


def periodic_sample(samples: Sequence[float], position: float) -> float:
    """Read a looping waveform with interpolation so accelerating it remains smooth."""
    before = math.floor(position) % len(samples)
    after = (before + 1) % len(samples)
    fraction = position - math.floor(position)
    return samples[before] + (samples[after] - samples[before]) * fraction


def silence(seconds: float) -> list[float]:
    return [0.0] * round(seconds * SAMPLE_RATE)


def add_into(target: list[float], source: Sequence[float], offset: int, gain: float = 1.0) -> None:
    for index, sample in enumerate(source):
        position = offset + index
        if 0 <= position < len(target):
            target[position] += gain * sample


def svf(
    samples: Sequence[float],
    cutoff: float | Sequence[float],
    q: float = 0.707,
    mode: str = "low",
) -> list[float]:
    """Topology-preserving state-variable filter; `cutoff` may vary per sample.

    The band output is scaled by 1/Q so its peak gain stays at unity as Q changes.
    """
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
        if mode == "low":
            output.append(v2)
        elif mode == "band":
            output.append(k * v1)
        else:
            output.append(x - k * v1 - v2)
    return output


# Freeverb tunings at 44.1 kHz, scaled to the output rate.
COMB_TUNING = (1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617)
ALLPASS_TUNING = (556, 441, 341, 225)
STEREO_SPREAD = 23


def reverb(source: Sequence[float], seconds: float, room: float, damp: float) -> Stereo:
    """Freeverb-style stereo hall: a mono send becomes a decorrelated wide tail."""
    scale = SAMPLE_RATE / 44_100
    padded = list(source) + silence(seconds)

    def channel(spread: int) -> list[float]:
        mixed = [0.0] * len(padded)
        for tuning in COMB_TUNING:
            buffer = [0.0] * round((tuning + spread) * scale)
            size = len(buffer)
            position = 0
            store = 0.0
            for index, x in enumerate(padded):
                output = buffer[position]
                store = output * (1.0 - damp) + store * damp
                buffer[position] = 0.015 * x + store * room
                mixed[index] += output
                position += 1
                if position == size:
                    position = 0
        for tuning in ALLPASS_TUNING:
            buffer = [0.0] * round((tuning + spread) * scale)
            size = len(buffer)
            position = 0
            for index, x in enumerate(mixed):
                delayed = buffer[position]
                buffer[position] = x + 0.5 * delayed
                mixed[index] = delayed - x
                position += 1
                if position == size:
                    position = 0
        return mixed

    return channel(0), channel(STEREO_SPREAD)


def limit(left: list[float], right: list[float], ceiling: float, gain: float) -> Stereo:
    """Look-ahead peak limiter: a 4 ms gain envelope reaches each peak before it plays."""
    window = round(0.004 * SAMPLE_RATE)
    release = 1.0 - math.exp(-1.0 / (0.12 * SAMPLE_RATE))
    count = len(left)
    required = [
        min(1.0, ceiling / max(1e-9, gain * max(abs(left[i]), abs(right[i]))))
        for i in range(count)
    ]
    # Minimum of the next `window` samples, then a box average over the previous `window`
    # minimums, keeps every sample under the ceiling with a smooth attack.
    minimum = [1.0] * count
    candidates: deque[int] = deque()
    for index in range(count + window):
        if index < count:
            while candidates and required[candidates[-1]] >= required[index]:
                candidates.pop()
            candidates.append(index)
        start = index - window
        if start >= 0:
            while candidates[0] < start:
                candidates.popleft()
            minimum[start] = required[candidates[0]]
    envelope = [0.0] * count
    history: deque[float] = deque([1.0] * window)
    total = float(window)
    smoothed = 1.0
    for index in range(count):
        total += minimum[index] - history.popleft()
        history.append(minimum[index])
        target = total / window
        smoothed = target if target < smoothed else smoothed + (target - smoothed) * release
        envelope[index] = min(smoothed, minimum[index])
    return (
        [gain * envelope[i] * left[i] for i in range(count)],
        [gain * envelope[i] * right[i] for i in range(count)],
    )


def whine_frequency(charge: float) -> float:
    return WHINE_LOW_HZ * (WHINE_HIGH_HZ / WHINE_LOW_HZ) ** charge


def generate_buzz(frequency_hz: float, charge: float, seed: int) -> list[float]:
    """Build one periodic charge step: transformer hum, capacitor whine, and sparks.

    Every component completes whole cycles per file, so consecutive steps join without
    phase jumps. The whine rises with charge and pulses faster, carrying the buildup on
    small speakers; the hum supplies weight on larger ones.
    """
    loop_sample_count = round(BUZZ_DURATION * SAMPLE_RATE)
    sample_count = loop_sample_count + BUZZ_ENCODER_PREROLL_SAMPLES
    loop_duration = loop_sample_count / SAMPLE_RATE
    rng = random.Random(seed)
    base_cycles = round(frequency_hz * loop_duration)
    base_frequency = base_cycles / loop_duration
    beat_cycles = round((4.0 + 4.0 * charge) * loop_duration)
    mechanical_cycles = round((92.0 + 28.0 * charge) * loop_duration)
    whine_cycles = round(whine_frequency(charge) * loop_duration)
    pulse_cycles = max(1, round((4.0 + 12.0 * charge) * loop_duration))
    inverter_cycles = (
        round((540.0 + 1_050.0 * charge) * loop_duration),
        round((1_130.0 + 1_920.0 * charge) * loop_duration),
        round((2_020.0 + 2_580.0 * charge) * loop_duration),
    )
    inverter_phases = tuple(rng.uniform(0.0, math.tau) for _ in inverter_cycles)

    # Sparks are short resonant crackles placed inside the loop so they repeat seamlessly.
    noise_table = [rng.uniform(-1.0, 1.0) for _ in range(loop_sample_count)]
    sparks = [
        (
            rng.uniform(0.02, loop_duration - 0.04),
            rng.uniform(2_400.0, 6_500.0),
            rng.uniform(0.002, 0.007),
            rng.uniform(0.5, 1.0),
        )
        for _ in range(round(1 + 9 * charge**1.4))
    ]
    spark_gain = 0.05 + 0.20 * charge**1.5
    samples: list[float] = []

    for index in range(sample_count):
        time = (index - BUZZ_ENCODER_PREROLL_SAMPLES) / SAMPLE_RATE
        loop_time = time % loop_duration
        phase = math.tau * base_frequency * time
        beat_phase = math.tau * beat_cycles * time / loop_duration
        mechanical_phase = math.tau * mechanical_cycles * time / loop_duration
        magnetic_phase = phase + (0.10 + 0.08 * charge) * math.sin(beat_phase)
        magnetic_wave = math.tanh((1.9 + 0.9 * charge) * math.sin(magnetic_phase))
        transformer_body = (
            0.48 * magnetic_wave
            + 0.15 * math.sin(2.0 * phase + 0.22 * math.sin(beat_phase))
            + 0.10 * math.sin(4.0 * phase)
            + 0.05 * math.sin(6.0 * phase + 0.4)
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
        whine_phase = math.tau * whine_cycles * time / loop_duration
        # A second voice one cycle per file higher beats against the first at 2 Hz.
        detuned_phase = math.tau * (whine_cycles + 1) * time / loop_duration
        pulse = 0.5 - 0.5 * math.cos(math.tau * pulse_cycles * time / loop_duration)
        whine = (0.55 + 0.45 * pulse * pulse) * (
            0.62 * math.tanh(1.6 * math.sin(whine_phase))
            + 0.30 * math.sin(detuned_phase + 0.7)
            + 0.12 * math.sin(2.0 * whine_phase + 0.3)
        )
        spark = 0.0
        for start, frequency, decay, gain in sparks:
            elapsed = loop_time - start
            if 0.0 <= elapsed < 0.03:
                noise = noise_table[round(loop_time * SAMPLE_RATE) % loop_sample_count]
                spark += gain * math.exp(-elapsed / decay) * (
                    0.6 * math.sin(math.tau * frequency * elapsed) + 0.4 * noise
                )
        sample = (0.40 + 0.08 * charge) * transformer_body + mechanical_rattle
        sample += (0.012 + 0.055 * charge**1.7) * inverter_texture
        sample += (0.17 + 0.17 * charge) * whine + spark_gain * spark
        codec_envelope = smoothstep(loop_time / BUZZ_CODEC_FADE) * smoothstep(
            (loop_duration - loop_time) / BUZZ_CODEC_FADE
        )
        early_presence = 1.0 + (BUZZ_EARLY_PRESENCE_GAIN - 1.0) * (1.0 - charge) ** 1.4
        samples.append(codec_envelope * sample * BUZZ_OUTPUT_GAIN * early_presence)

    measured_peak = max(abs(sample) for sample in samples)
    if measured_peak > ENCODER_SAFE_PEAK:
        return normalize(samples, peak=ENCODER_SAFE_PEAK)
    return samples


def sub_drop(seconds: float, start_hz: float, end_hz: float, sweep: float, decay: float) -> list[float]:
    """A saturated sine pitch drop: chest-thump body with audible upper harmonics."""
    phase = 0.0
    samples = []
    for index in range(round(seconds * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        frequency = end_hz + (start_hz - end_hz) * math.exp(-time / sweep)
        phase += math.tau * frequency / SAMPLE_RATE
        envelope = smoothstep(time / 0.003) * math.exp(-time / decay)
        samples.append(envelope * math.tanh(2.2 * math.sin(phase)))
    return samples


def envelope(seconds: float, attack: float, decay: float) -> list[float]:
    return [
        smoothstep(time / attack) * math.exp(-time / decay)
        for time in (index / SAMPLE_RATE for index in range(round(seconds * SAMPLE_RATE)))
    ]


def puff(seconds: float, decay: float, cutoff: float, seed: int) -> list[float]:
    """A soft, low burst of displaced air."""
    rng = random.Random(seed)
    raw = [
        rng.uniform(-1.0, 1.0)
        * smoothstep(index / (0.008 * SAMPLE_RATE))
        * math.exp(-(index / SAMPLE_RATE) / decay)
        for index in range(round(seconds * SAMPLE_RATE))
    ]
    return svf(raw, cutoff)


def jet_flange(
    seconds: float, low_ms: float, high_ms: float, sweep: float, decay: float, seed: int
) -> Stereo:
    """Noise through a feedback comb whose delay sweeps: the phasing roar of a jet passing.

    The right channel's sweep runs slightly ahead, so the roar moves across the field.
    """
    channels = []
    count = round(seconds * SAMPLE_RATE)
    shape = envelope(seconds, 0.03, decay)
    for channel, lead in enumerate((0.0, 0.18)):
        rng = random.Random(seed + channel)
        source = [rng.uniform(-1.0, 1.0) for _ in range(count)]
        comb = [0.0] * count
        for index in range(count):
            fall = math.exp(-(index / SAMPLE_RATE + lead * sweep) / sweep)
            position = index - (low_ms + (high_ms - low_ms) * (1.0 - fall)) * SAMPLE_RATE / 1000.0
            before = math.floor(position)
            delayed = 0.0
            if before >= 0:
                fraction = position - before
                after = comb[before + 1] if before + 1 < index else comb[before]
                delayed = comb[before] + (after - comb[before]) * fraction
            comb[index] = source[index] + 0.75 * delayed
        channels.append([0.25 * sample * gain for sample, gain in zip(svf(comb, 5_000.0), shape)])
    return channels[0], channels[1]


def wind_howl(seconds: float, centres: Sequence[float], decay: float, seed: int) -> Stereo:
    """Resonant bands of noise wandering slowly in pitch: wind howling through the hull."""
    count = round(seconds * SAMPLE_RATE)
    shape = envelope(seconds, 0.08, decay)
    channels = []
    for channel in range(2):
        rng = random.Random(seed + 17 * channel)
        noise = [rng.uniform(-1.0, 1.0) for _ in range(count)]
        howl = [0.0] * count
        for centre in centres:
            rate = rng.uniform(0.15, 0.4)
            phase = rng.uniform(0.0, math.tau)
            path = [
                centre
                * (1.0 + 0.18 * math.sin(math.tau * rate * index / SAMPLE_RATE + phase))
                * (0.8 + 0.2 * math.exp(-index / SAMPLE_RATE / 0.8))
                for index in range(count)
            ]
            for index, sample in enumerate(svf(noise, path, q=9.0, mode="band")):
                howl[index] += sample
        channels.append([0.9 * sample * gain for sample, gain in zip(howl, shape)])
    return channels[0], channels[1]


def hum_bloom(seconds: float, fundamental: float, attack: float, decay: float) -> Stereo:
    """A harmonic drone that swells into being and breathes at the warp field's 1.875 Hz pulse."""
    channels = []
    for detune in (0.0, 0.35):
        phases = [0.0] * 10
        samples = []
        for index in range(round(seconds * SAMPLE_RATE)):
            time = index / SAMPLE_RATE
            value = 0.0
            for harmonic in range(10):
                phases[harmonic] += math.tau * (
                    (harmonic + 1) * fundamental + detune * (harmonic + 1) ** 0.5
                ) / SAMPLE_RATE
                value += math.sin(phases[harmonic]) / (harmonic + 1) ** 0.85
            throb = 0.75 + 0.25 * math.cos(math.tau * 1.875 * time)
            samples.append(
                throb * smoothstep(time / attack) * math.exp(-time / decay) * math.tanh(0.7 * value)
            )
        channels.append(samples)
    return channels[0], channels[1]


def mix(*layers: tuple[Stereo, float]) -> Stereo:
    count = max(len(layer[0]) for layer, _ in layers)
    left, right = [0.0] * count, [0.0] * count
    for (layer_left, layer_right), gain in layers:
        add_into(left, layer_left, 0, gain)
        add_into(right, layer_right, 0, gain)
    return left, right


def saturate_onset(layer: Stereo, drive: float, hold: float, release: float) -> Stereo:
    """Saturate an impact's opening so it is dense rather than merely peaky, then crossfade
    back to the clean signal over `release` seconds so the drive never switches audibly."""
    channels = []
    for channel in layer:
        shaped = []
        for index, sample in enumerate(channel):
            clean = 1.0 - smoothstep((index / SAMPLE_RATE - hold) / release)
            shaped.append(math.tanh(drive * sample) / drive * clean + sample * (1.0 - clean))
        channels.append(shaped)
    return channels[0], channels[1]


def mono(samples: Sequence[float]) -> Stereo:
    return list(samples), list(samples)


def hall(layer: Stereo, room: float = 0.88, damp: float = 0.3) -> Stereo:
    return reverb([0.5 * (l + r) for l, r in zip(*layer)], 0.0, room=room, damp=damp)


def tame_bass(layer: Stereo, amount: float = 0.6, cutoff: float = 120.0) -> Stereo:
    """Pull the lows down so the limiter spends its headroom on the audible midrange."""
    return tuple(
        [sample - amount * low for sample, low in zip(channel, svf(channel, cutoff))]
        for channel in layer
    )


def reverse_swell(source: Stereo, seconds: float) -> Stereo:
    """The reversed reverb of a hit: a crescendo that sucks into the moment it lands."""
    wet_left, wet_right = reverb([0.5 * (l + r) for l, r in zip(*source)], 1.0, room=0.86, damp=0.3)
    count = round(seconds * SAMPLE_RATE)
    return list(reversed(wet_left[:count])), list(reversed(wet_right[:count]))


def breach_layers(seconds: float) -> tuple[Stereo, Stereo]:
    """The breach and its aftermath, and the source whose reversed hall swells into it.

    A vortex: a jet-like phasing roar tears across the ship, wind howls through the hull,
    and a deep hum blooms underneath, over a soft thump of displaced air.
    """
    jet = jet_flange(seconds, 0.4, 9.0, sweep=0.55, decay=0.9, seed=0x7E7)
    wind = wind_howl(seconds, (180.0, 270.0, 410.0, 620.0), decay=1.3, seed=0x3117)
    hum = hum_bloom(seconds, 55.0, attack=0.25, decay=1.6)
    body = mix(
        (mono(sub_drop(seconds, 90.0, 30.0, sweep=0.2, decay=0.8)), 0.55),
        (mono(puff(seconds, 0.12, 1_500.0, 0xF0F)), 1.2),
        (jet, 1.3),
        (wind, 0.9),
        (hum, 0.55),
    )
    impact = tame_bass(mix((body, 1.0), (hall(mix((jet, 0.6), (wind, 0.6))), 1.0)))
    # Make-up gain drives the onset saturation and limiter as hard as earlier, denser palettes.
    return mix((impact, 2.66)), jet


def generate_activation() -> Stereo:
    """Tear through the dimensional edge: suction, breach, collapse, and warp ambience.

    0.00-0.54 s: the final charge step accelerates into a rising scream while a reversed hall
    swells and the air is drawn inward; everything cuts out for a breath at the breach.
    0.54 s (the building's flash): `breach_layers`, saturated at its opening for density.
    The tail settles into the warp ambience.
    """
    count = round(ACTIVATION_DURATION * SAMPLE_RATE)
    breach = round(ACTIVATION_BREACH * SAMPLE_RATE)
    impact, swell_source = breach_layers(ACTIVATION_DURATION - ACTIVATION_BREACH)
    impact = saturate_onset(impact, drive=3.0, hold=0.45, release=0.6)

    # Suction: continue the exact final charge step, accelerating into a scream.
    final_buzz = generate_buzz(BUZZ_HIGH_HZ, 1.0, 0xB022 + BUZZ_COUNT - 1)[BUZZ_ENCODER_PREROLL_SAMPLES:]
    rng = random.Random(0xA71C)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(breach)]
    rising_air = svf(
        noise,
        [500.0 * 14.0 ** smoothstep(index / breach) for index in range(breach)],
        q=2.2,
        mode="band",
    )
    position = 0.0
    scream_phases = [0.0, 0.0]
    left, right = [0.0] * count, [0.0] * count
    for index in range(breach):
        time = index / SAMPLE_RATE
        progress = smoothstep(time / (ACTIVATION_BREACH - 0.04))
        carrier = periodic_sample(final_buzz, position)
        position += 1.0 + 2.2 * progress**1.6
        for channel, detune in enumerate((1.0, 1.012)):
            scream_phases[channel] += math.tau * WHINE_HIGH_HZ * detune * 3.0 ** (progress**1.4) / SAMPLE_RATE
        swell = progress**2
        cut = 1.0 - smoothstep((time - (ACTIVATION_BREACH - 0.05)) / 0.03)
        for channel, target in enumerate((left, right)):
            scream = math.tanh(1.8 * math.sin(scream_phases[channel]))
            target[index] = cut * (
                (1.0 - 0.55 * progress) * 0.9 * carrier
                + 0.30 * swell * scream
                + 0.75 * swell * rising_air[index]
            )
    swell_left, swell_right = reverse_swell(swell_source, ACTIVATION_BREACH - 0.05)
    add_into(left, swell_left, 0, 1.6)
    add_into(right, swell_right, 0, 1.6)
    left, right = limit(left, right, TRANSITION_PEAK, 1.0)

    impact_left, impact_right = limit(impact[0], impact[1], TRANSITION_PEAK, 7.0)
    add_into(left, impact_left, breach)
    add_into(right, impact_right, breach)

    # Fade the aftermath away and hand off to the background loop at the file boundary.
    for index in range(count):
        time = index / SAMPLE_RATE
        tail = 1.0 - smoothstep((time - (ACTIVATION_DURATION - 1.3)) / 1.2)
        ambience = smoothstep((time - 2.0) / 2.6) * background_sample(
            BACKGROUND_DURATION - ACTIVATION_DURATION + time
        )
        left[index] = tail * left[index] + ambience
        right[index] = tail * right[index] + ambience

    for channel in (left, right):
        if abs(background_sample(0.0) - channel[-1]) > 0.01:
            raise RuntimeError("activation tail no longer joins the background cleanly")
    return left, right


def generate_deactivation() -> Stereo:
    """Fall back into normal space: the vortex rushes back in, lands, and the drive spins down
    while the building's deep hum dies away."""
    count = round(DEACTIVATION_DURATION * SAMPLE_RATE)
    exit_index = round(DEACTIVATION_EXIT * SAMPLE_RATE)
    aftermath = DEACTIVATION_DURATION - DEACTIVATION_EXIT

    # The approach is a short vortex reversed: roar, wind, and hum all rush back inward.
    rush_jet = jet_flange(1.2, 0.4, 7.0, sweep=0.35, decay=0.5, seed=0xDA7E)
    rush = mix(
        (rush_jet, 1.2),
        (wind_howl(1.2, (200.0, 300.0, 450.0), decay=0.6, seed=0xDA31), 0.8),
        (hum_bloom(1.2, 55.0, attack=0.05, decay=0.6), 0.5),
    )
    rush = tame_bass(mix((rush, 1.0), (hall(rush), 1.6)))
    approach = round((DEACTIVATION_EXIT - 0.02) * SAMPLE_RATE)
    left, right = [0.0] * count, [0.0] * count
    for channel, target in zip(rush, (left, right)):
        reversed_rush = list(reversed(channel[:approach]))
        for index in range(approach):
            target[index] = reversed_rush[index] * smoothstep(index / (0.25 * SAMPLE_RATE))
    left, right = limit(left, right, TRANSITION_PEAK, 3.0)

    # Exit: a thump of air, a fading gust, then the capacitor whine and hum spin down.
    rng = random.Random(0xDE0F)
    phases = [0.0, 0.0]
    hum_phase = 0.0
    spin_down: Stereo = ([], [])
    for index in range(round(aftermath * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        fall = math.exp(-time / 0.55)
        hum_phase += math.tau * (BUZZ_HIGH_HZ * (0.45 + 0.55 * fall)) / SAMPLE_RATE
        shape = smoothstep(time / 0.05) * math.exp(-time / 0.8)
        hum = 0.5 * math.tanh(2.0 * math.sin(hum_phase))
        for channel, detune in enumerate((1.0, 1.01)):
            phases[channel] += math.tau * detune * (45.0 + (WHINE_HIGH_HZ - 45.0) * fall) / SAMPLE_RATE
            whine = math.tanh(1.5 * math.sin(phases[channel]))
            spin_down[channel].append(shape * (0.6 * whine + hum + 0.05 * rng.uniform(-1.0, 1.0)))
    relay = sub_drop(aftermath, 70.0, 40.0, sweep=0.05, decay=0.09)
    relay = [0.0] * round(1.55 * SAMPLE_RATE) + relay[: len(relay) - round(1.55 * SAMPLE_RATE)]
    gust = jet_flange(aftermath, 3.0, 0.6, sweep=0.3, decay=0.35, seed=0xDE6A)
    wind = wind_howl(aftermath, (160.0, 240.0, 360.0), decay=0.7, seed=0xDE11)
    exit_hit = mix(
        (mono(sub_drop(aftermath, 95.0, 32.0, sweep=0.12, decay=0.45)), 0.6),
        (mono(puff(aftermath, 0.1, 1_500.0, 0xDEC2)), 1.2),
        (gust, 1.2),
        (wind, 0.7),
        (spin_down, 0.75),
        (hum_bloom(aftermath, 55.0, attack=0.01, decay=0.9), 0.6),
        (mono(relay), 0.5),
    )
    exit_hit = tame_bass(mix((exit_hit, 1.0), (hall(mix((gust, 0.6), (wind, 0.5), (spin_down, 0.4))), 1.2)))
    exit_hit = saturate_onset(exit_hit, drive=2.5, hold=0.3, release=0.5)
    exit_left, exit_right = limit(exit_hit[0], exit_hit[1], TRANSITION_PEAK, 7.0)
    add_into(left, exit_left, exit_index)
    add_into(right, exit_right, exit_index)
    for index in range(count):
        fade = edge_fade(index, count, 0.004, 0.6)
        left[index] *= fade
        right[index] *= fade
    return left, right


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
            sample += 0.30 * math.exp(-13.0 * thud_time) * math.tanh(2.0 * math.sin(thud_phase))
        samples.append(sample * edge_fade(index, sample_count, 0.006, 0.08))

    return gain_with_peak_limit(samples, 1.15, peak=0.80)


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


def generate_field_hum() -> list[float]:
    """A seamless loop for the building while warp holds: the activation's deep, shimmering
    hum, a breath of plasma pulsing with the core's waves, and faint sparks.

    The loop lasts 256 ticks, four of the building's 64-tick animation loops, and every
    component completes whole cycles in it. Its 1.875 Hz throb is the core's two waves per
    animation loop. Noise is filtered circularly so it, too, repeats without a seam.
    """
    loop_count = round(FIELD_HUM_DURATION * SAMPLE_RATE)
    cycle = 1.0 / FIELD_HUM_DURATION

    def tone(hz: float) -> float:
        return round(hz / cycle) * cycle

    rng = random.Random(0xF1E1D)
    noise = [rng.uniform(-1.0, 1.0) for _ in range(loop_count)]
    # Filtering two passes of the loop and keeping the second leaves no start-up transient,
    # so the end of the filtered loop flows back into its start.
    breath = svf(noise + noise, tone(900.0), q=0.9, mode="band")[loop_count:]
    rumble = svf(noise + noise, tone(160.0), q=0.7)[loop_count:]
    sparks = [
        (rng.uniform(0.0, FIELD_HUM_DURATION - 0.03), rng.uniform(2_500.0, 6_000.0), rng.uniform(0.002, 0.006))
        for _ in range(14)
    ]
    fundamental = tone(55.0)
    throb_hz = tone(1.875)
    twins = [
        [
            (fundamental * harmonic + tone(detune * harmonic**0.5), 1.0 / harmonic**0.85)
            for harmonic in range(1, 11)
        ]
        for detune in (0.0, 0.35)
    ]
    samples: list[float] = []
    for loop_index in range(loop_count):
        time = loop_index / SAMPLE_RATE
        throb = 0.5 - 0.5 * math.cos(math.tau * throb_hz * time)
        # The activation's deep hum (`hum_bloom`), held: each harmonic and its slightly sharp
        # twin beat against each other, which makes the drone shimmer.
        drone = 0.0
        for twin in twins:
            value = sum(
                math.sin(math.tau * frequency * time) * weight for frequency, weight in twin
            )
            drone += math.tanh(0.7 * value)
        drone *= 0.75 + 0.25 * math.cos(math.tau * throb_hz * time)
        shimmer = math.sin(math.tau * tone(2_420.0) * time) * (
            0.5 + 0.5 * math.sin(math.tau * tone(0.47) * time)
        )
        spark = 0.0
        for start, frequency, decay in sparks:
            elapsed = time - start
            if 0.0 <= elapsed < 0.03:
                spark += math.exp(-elapsed / decay) * math.sin(math.tau * frequency * elapsed)
        samples.append(
            0.5 * drone
            + 0.30 * breath[loop_index] * (0.35 + 0.65 * throb)
            + 0.20 * rumble[loop_index]
            + 0.025 * shimmer
            + 0.06 * spark
        )
    return normalize(samples, FIELD_HUM_PEAK)


def write_wave(path: Path, samples: Sequence[float] | Stereo) -> None:
    """Write mono samples, or a (left, right) pair as interleaved stereo."""
    channels = samples if isinstance(samples, tuple) else (samples,)
    if max(abs(sample) for channel in channels for sample in channel) > ENCODER_SAFE_PEAK:
        raise RuntimeError(f"{path.name} exceeds the Vorbis-safe peak {ENCODER_SAFE_PEAK}")
    pcm = bytearray()
    for frame in zip(*channels):
        for sample in frame:
            pcm.extend(struct.pack("<h", round(clamp(sample, -1.0, 1.0) * 32_767.0)))

    with wave.open(str(path), "wb") as output:
        output.setnchannels(len(channels))
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
    generator: Callable[[], Sequence[float] | Stereo],
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
    parser.add_argument(
        "--only",
        nargs="+",
        metavar="NAME",
        help="render only these outputs, such as warp-activation or warp-buzz-20",
    )
    return parser.parse_args()


def outputs() -> dict[str, Callable[[], Sequence[float] | Stereo]]:
    sounds: dict[str, Callable[[], Sequence[float] | Stereo]] = {}
    for index in range(BUZZ_COUNT):
        frequency = BUZZ_LOW_HZ * (BUZZ_HIGH_HZ / BUZZ_LOW_HZ) ** (index / (BUZZ_COUNT - 1))
        charge = index / (BUZZ_COUNT - 1)
        seed = 0xB022 + index
        sounds[f"warp-buzz-{index + 1:02d}"] = (
            lambda frequency=frequency, charge=charge, seed=seed: generate_buzz(frequency, charge, seed)
        )
        sounds[f"warp-failed-activation-{index + 1:02d}"] = (
            lambda frequency=frequency, charge=charge, seed=seed: generate_failed_activation(
                frequency, charge, seed
            )
        )
    sounds["warp-activation"] = generate_activation
    sounds["warp-deactivation"] = generate_deactivation
    sounds["warp-field-hum"] = generate_field_hum
    for index in range(2):
        sounds[f"warp-background-{index + 1:02d}"] = (
            lambda index=index: generate_background_segment(index * BACKGROUND_SEGMENT_DURATION)
        )
    return sounds


def main() -> None:
    arguments = parse_arguments()
    ffmpeg = shutil.which(arguments.ffmpeg)
    if ffmpeg is None:
        raise SystemExit("ffmpeg is required; install it with: brew install ffmpeg")

    sounds = outputs()
    selected = arguments.only or list(sounds)
    unknown = sorted(set(selected) - set(sounds))
    if unknown:
        raise SystemExit(f"unknown outputs: {', '.join(unknown)}")
    with tempfile.TemporaryDirectory(prefix="warp-audio-") as temporary:
        for name in selected:
            render_sound(ffmpeg, Path(temporary), name, sounds[name])


if __name__ == "__main__":
    main()
