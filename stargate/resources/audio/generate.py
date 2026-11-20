#!/usr/bin/env python3
"""Generate the Stargate sound bank and encode it as Ogg Vorbis.

Every sound is synthesised from seeded noise and oscillators, so a rerun over unchanged code writes
identical files. Needs ffmpeg with libvorbis. Helpers are duplicated from warp-drive's generator on
purpose: the mods share no code. The sounds are mixed from the patterns measured in the film's gate
sounds (see the elements below), mainly its kawoosh and wash, with Warp Drive's hall, swell, drone,
wind and thump.

  stargate-open     the veil bursting out: a swell sucked into a kawoosh, then the wash and the hum
  stargate-close    the veil collapsing: the wash backwards, the hum bending down, a thump, a dead stop
  stargate-depart   stepping in: a small falling kawoosh
  stargate-arrive   stepping out: a swell up to a small rising kawoosh ARRIVE_PEAK seconds in,
                    matching the 64-tick arrival (scripts/transfer.lua)
  stargate-car-in   a carriage plunging in: a fast falling kawoosh and a passing roar
  stargate-car-out  a carriage breaking out: a rising kawoosh and a roar rushing away
  stargate-hum      the open gate's seamless loop: a gigawatt drone and the gap's wind
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


def normalize(samples: Sequence[float], peak: float = PEAK) -> list[float]:
    measured = max(abs(sample) for sample in samples) or 1.0
    return [sample * peak / measured for sample in samples]


def fade_edges(samples: list[float], fade_in: float = 0.004, fade_out: float = 0.08) -> list[float]:
    count = len(samples)
    rise, fall = samples_for(fade_in), samples_for(fade_out)
    return [s * smoothstep(i / rise) * smoothstep((count - 1 - i) / fall) for i, s in enumerate(samples)]


# Elements: the separate patterns heard in the film's gate sounds, each rendered alone so they can be judged
# and then mixed into every sound the same way. Measured from the film's open and close (3.4 s each):
#   rumble   a sub-bass roar centred near 68 Hz under the whole sound, pulsing irregularly 2-4 times a second
#   chord    a harmonic stack on a ~163 Hz fundamental (partials near 650-2000 Hz), with close detuned pairs
#            that beat; it glides up about a fifth in its first 0.2 s, holds, and stops dead (open, 0.1-1.0 s)
#   kawoosh  a band of noise sweeping down from ~4 kHz to ~500 Hz and straight back up: the splash (open, 1.0-1.6 s)
#   wash     broadband noise up to ~5 kHz that wobbles and decays slowly: the veil settling (open, 1.6-3.4 s)
#   ripple   a low tone wandering between 150 and 250 Hz: the puddle's surface (open, 1.8-2.6 s)
#   whine    a thin steady tone near 1.2 kHz with slight vibrato (close, throughout, clearest at 2.1-2.7 s)
#   thump    a low swell at 100-150 Hz, the veil falling in on itself (close, 1.75 s)
#   cut      not a sound but an envelope: the close stops dead at 2.8 s, leaving only a faint room tail
ELEMENT_DURATION = 3.0


def element_rumble(count: int = samples_for(ELEMENT_DURATION), seed: int = 0xE001) -> list[float]:
    generator = random.Random(seed)
    low = svf(svf(noise(count, seed), 90), 90)
    pulses = [(generator.uniform(1.4, 4.2), generator.uniform(0, math.tau)) for _ in range(3)]
    output = []
    for index in range(count):
        time = index / SAMPLE_RATE
        pulse = 0.55 + 0.45 * sum(math.sin(math.tau * rate * time + phase) for rate, phase in pulses) / len(pulses)
        tone = math.sin(math.tau * 68 * time + 0.6 * math.sin(math.tau * 0.7 * time))
        output.append(pulse * (3.0 * low[index] + 0.25 * tone))
    return normalize(output)


def element_chord(count: int = samples_for(ELEMENT_DURATION), seed: int = 0xE002, glide: float = 0.2) -> list[float]:
    generator = random.Random(seed)
    partials = []
    for harmonic in range(4, 13):
        for detune in (0.0, generator.uniform(2.0, 6.0)):
            partials.append((harmonic, detune, generator.uniform(0, math.tau), generator.uniform(0.4, 1.0) / harmonic ** 0.5))
    phases = [phase for _, _, phase, _ in partials]
    output = []
    for index in range(count):
        time = index / SAMPLE_RATE
        fundamental = 163 * (2 / 3 + (1 / 3) * smoothstep(time / glide))
        value = 0.0
        for number, (harmonic, detune, _, gain) in enumerate(partials):
            phases[number] += math.tau * (fundamental * harmonic + detune) / SAMPLE_RATE
            value += gain * math.sin(phases[number])
        output.append(value)
    return normalize(output)


def element_kawoosh(count: int = samples_for(ELEMENT_DURATION), seed: int = 0xE003, down: float = 0.25, up: float = 0.3) -> list[float]:
    def cutoff(time: float) -> float:
        if time < down:
            return 4000 * (500 / 4000) ** smoothstep(time / down)
        return 500 * (4000 / 500) ** smoothstep((time - down) / up)

    band = svf(noise(count, seed), [cutoff(i / SAMPLE_RATE) for i in range(count)], q=2.5, mode="band")
    body = svf(noise(count, seed + 1), 700)
    output = []
    for index in range(count):
        time = index / SAMPLE_RATE
        envelope = smoothstep(time / 0.03) * (1.0 if time < down + up else math.exp(-(time - down - up) / 0.25))
        output.append(envelope * (band[index] + 0.6 * body[index] * math.exp(-time / 0.35)))
    return normalize(output)


def element_wash(count: int = samples_for(ELEMENT_DURATION), seed: int = 0xE004, decay: float = 1.4) -> list[float]:
    generator = random.Random(seed)
    wobbles = [(generator.uniform(3.0, 9.0), generator.uniform(0, math.tau)) for _ in range(2)]
    cutoffs = [2500 + 1500 * math.sin(math.tau * 0.8 * i / SAMPLE_RATE) for i in range(count)]
    hiss = svf(svf(noise(count, seed), cutoffs), 250, mode="high")
    output = []
    for index in range(count):
        time = index / SAMPLE_RATE
        wobble = 0.7 + 0.3 * sum(math.sin(math.tau * rate * time + phase) for rate, phase in wobbles) / 2
        output.append(hiss[index] * wobble * smoothstep(time / 0.08) * math.exp(-time / decay))
    return normalize(output)


def element_ripple(count: int = samples_for(ELEMENT_DURATION), seed: int = 0xE005) -> list[float]:
    generator = random.Random(seed)
    drifts = [(generator.uniform(0.6, 2.5), generator.uniform(0, math.tau)) for _ in range(3)]
    phase = 0.0
    output = []
    for index in range(count):
        time = index / SAMPLE_RATE
        frequency = 200 + 50 * sum(math.sin(math.tau * rate * time + offset) for rate, offset in drifts) / 3
        phase += math.tau * frequency / SAMPLE_RATE
        output.append((math.sin(phase) + 0.3 * math.sin(2 * phase)) * smoothstep(time / 0.2))
    return normalize(output)


def element_whine(count: int = samples_for(ELEMENT_DURATION)) -> list[float]:
    phase = 0.0
    output = []
    for index in range(count):
        time = index / SAMPLE_RATE
        phase += math.tau * (1210 + 12 * math.sin(math.tau * 5.5 * time)) / SAMPLE_RATE
        output.append(math.sin(phase) * smoothstep(time / 0.3))
    return normalize(output)


def element_thump(count: int = samples_for(ELEMENT_DURATION), at: float = 0.2) -> list[float]:
    phase = 0.0
    output = []
    for index in range(count):
        elapsed = index / SAMPLE_RATE - at
        frequency = 150 - 50 * smoothstep(elapsed / 0.3)
        phase += math.tau * frequency / SAMPLE_RATE
        envelope = 0.0 if elapsed < -0.08 else smoothstep((elapsed + 0.08) / 0.08) * math.exp(-max(0.0, elapsed) / 0.18)
        output.append(envelope * math.sin(phase))
    return normalize(output)


def elements() -> dict[str, Callable[[], Sequence[float]]]:
    return {
        "rumble": element_rumble,
        "chord": element_chord,
        "kawoosh": element_kawoosh,
        "wash": element_wash,
        "ripple": element_ripple,
        "whine": element_whine,
        "thump": element_thump,
    }


# Building blocks borrowed from Warp Drive's generator (mono here; the mods share no code), so the
# gate and the drive sound like the same family of machines.


def silence(seconds: float) -> list[float]:
    return [0.0] * samples_for(seconds)


def place(target: list[float], source: Sequence[float], at: float, gain: float = 1.0) -> None:
    offset = samples_for(at)
    for index, sample in enumerate(source):
        if 0 <= offset + index < len(target):
            target[offset + index] += gain * sample


def kawoosh(seconds: float, seed: int, top: float = 4000, bottom: float = 500, down: float = 0.25,
            up: float = 0.3, ring: float = 0.25, body: float = 0.6) -> list[float]:
    """The film's splash: a noise band sweeping from `top` down to `bottom` and back up, over a dull
    burst. `up = 0` sweeps down only (plunging in); `down = 0` sweeps up only (breaking out)."""
    count = samples_for(seconds)

    def cutoff(time: float) -> float:
        if time < down:
            return top * (bottom / top) ** smoothstep(time / down)
        return bottom * (top / bottom) ** smoothstep((time - down) / up) if up else bottom

    band = svf(noise(count, seed), [cutoff(i / SAMPLE_RATE) for i in range(count)], q=2.5, mode="band")
    dull = svf(noise(count, seed + 1), 700)
    output = []
    for index in range(count):
        time = index / SAMPLE_RATE
        shape = smoothstep(time / 0.02) * (1.0 if time < down + up else math.exp(-(time - down - up) / ring))
        output.append(shape * (band[index] + body * dull[index] * math.exp(-time / 0.35)))
    return output


def wash(seconds: float, seed: int, decay: float = 1.4, attack: float = 0.08) -> list[float]:
    """The film's settling veil: broad hiss whose brightness and loudness wobble as it fades."""
    count = samples_for(seconds)
    generator = random.Random(seed)
    wobbles = [(generator.uniform(3.0, 9.0), generator.uniform(0, math.tau)) for _ in range(2)]
    cutoffs = [2500 + 1500 * math.sin(math.tau * 0.8 * i / SAMPLE_RATE) for i in range(count)]
    hiss = svf(svf(noise(count, seed), cutoffs), 250, mode="high")
    output = []
    for index in range(count):
        time = index / SAMPLE_RATE
        wobble = 0.7 + 0.3 * sum(math.sin(math.tau * rate * time + phase) for rate, phase in wobbles) / 2
        output.append(hiss[index] * wobble * smoothstep(time / attack) * math.exp(-time / decay))
    return output


def sub_drop(seconds: float, start: float, end: float, sweep: float, decay: float) -> list[float]:
    """A saturated falling sine: the chest-thump under every impact."""
    phase = 0.0
    output = []
    for index in range(samples_for(seconds)):
        time = index / SAMPLE_RATE
        phase += math.tau * (end + (start - end) * math.exp(-time / sweep)) / SAMPLE_RATE
        output.append(smoothstep(time / 0.003) * math.exp(-time / decay) * math.tanh(2.2 * math.sin(phase)))
    return output


def puff(seconds: float, decay: float, cutoff: float, seed: int) -> list[float]:
    """A soft, low burst of displaced air."""
    raw = [x * smoothstep(i / samples_for(0.008)) * math.exp(-(i / SAMPLE_RATE) / decay)
           for i, x in enumerate(noise(samples_for(seconds), seed))]
    return svf(raw, cutoff)


def jet_flange(seconds: float, low_ms: float, high_ms: float, sweep: float, decay: float, seed: int) -> list[float]:
    """Noise through a feedback comb whose delay sweeps: the phasing roar of something passing fast."""
    count = samples_for(seconds)
    source = noise(count, seed)
    comb = [0.0] * count
    for index in range(count):
        time = index / SAMPLE_RATE
        position = index - (low_ms + (high_ms - low_ms) * (1.0 - math.exp(-time / sweep))) * SAMPLE_RATE / 1000.0
        before = math.floor(position)
        delayed = 0.0
        if before >= 0:
            after = comb[before + 1] if before + 1 < index else comb[before]
            delayed = comb[before] + (after - comb[before]) * (position - before)
        comb[index] = source[index] + 0.75 * delayed
    return [0.25 * x * smoothstep(i / samples_for(0.03)) * math.exp(-(i / SAMPLE_RATE) / decay)
            for i, x in enumerate(svf(comb, 5000.0))]


def wind_howl(seconds: float, centres: Sequence[float], seed: int, attack: float = 0.08, decay: float = 1e9) -> list[float]:
    """Resonant bands of noise wandering slowly in pitch: wind howling through the gap between worlds."""
    count = samples_for(seconds)
    generator = random.Random(seed)
    source = noise(count, seed)
    howl = [0.0] * count
    for centre in centres:
        rate, phase = generator.uniform(0.15, 0.4), generator.uniform(0, math.tau)
        path = [centre * (1.0 + 0.18 * math.sin(math.tau * rate * i / SAMPLE_RATE + phase)) for i in range(count)]
        for index, sample in enumerate(svf(source, path, q=9.0, mode="band")):
            howl[index] += sample
    return [0.9 * x * smoothstep(i / samples_for(attack)) * math.exp(-(i / SAMPLE_RATE) / decay) for i, x in enumerate(howl)]


HUM_FUNDAMENTAL = 50.0
HUM_THROB = 1.5


def hum_bloom(seconds: float, attack: float, decay: float = 1e9, fall: float = 0.0) -> list[float]:
    """The powered gate's drone: harmonics of HUM_FUNDAMENTAL beating against slightly sharp twins,
    breathing at HUM_THROB. `fall` bends the pitch down by that fraction over the sound (powering off)."""
    phases = [0.0] * 20
    output = []
    count = samples_for(seconds)
    for index in range(count):
        time = index / SAMPLE_RATE
        bend = 1.0 - fall * smoothstep(index / count)
        value = 0.0
        for twin, detune in enumerate((0.0, 0.35)):
            partial = 0.0
            for harmonic in range(1, 11):
                slot = twin * 10 + harmonic - 1
                # Rounded to quarter hertz so every partial completes whole cycles in the hum loop.
                frequency = round(4 * (harmonic * HUM_FUNDAMENTAL + detune * harmonic ** 0.5)) / 4
                phases[slot] += math.tau * bend * frequency / SAMPLE_RATE
                partial += math.sin(phases[slot]) / harmonic ** 0.85
            value += math.tanh(0.7 * partial)
        throb = 0.75 + 0.25 * math.cos(math.tau * HUM_THROB * time)
        output.append(0.5 * value * throb * smoothstep(time / attack) * math.exp(-time / decay))
    return output


# Freeverb tunings at 44.1 kHz, scaled to the output rate.
COMB_TUNING = (1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617)
ALLPASS_TUNING = (556, 441, 341, 225)


def hall(source: Sequence[float], tail: float = 1.0, room: float = 0.86, damp: float = 0.3) -> list[float]:
    """Freeverb-style hall (one channel of Warp Drive's): the big room the gate's sounds ring in."""
    scale = SAMPLE_RATE / 44_100
    padded = list(source) + silence(tail)
    mixed = [0.0] * len(padded)
    for tuning in COMB_TUNING:
        buffer = [0.0] * round(tuning * scale)
        position = 0
        store = 0.0
        for index, x in enumerate(padded):
            output = buffer[position]
            store = output * (1.0 - damp) + store * damp
            buffer[position] = 0.015 * x + store * room
            mixed[index] += output
            position = (position + 1) % len(buffer)
    for tuning in ALLPASS_TUNING:
        buffer = [0.0] * round(tuning * scale)
        position = 0
        for index, x in enumerate(mixed):
            delayed = buffer[position]
            buffer[position] = x + 0.5 * delayed
            mixed[index] = delayed - x
            position = (position + 1) % len(buffer)
    return mixed


def reverse_swell(source: Sequence[float], seconds: float) -> list[float]:
    """The reversed hall of a hit: a crescendo that sucks into the moment it lands."""
    return hall(source)[:samples_for(seconds)][::-1]


def master(samples: Sequence[float], seconds: float, peak: float = PEAK, drive: float = 1.6) -> list[float]:
    """Cut to length, soft-saturate so impacts are dense rather than peaky, and level."""
    cut = list(samples[:samples_for(seconds)]) + silence(max(0.0, seconds - len(samples) / SAMPLE_RATE))
    return fade_edges(normalize([math.tanh(drive * x) for x in normalize(cut, 1.0)], peak))


# The sound bank. Every gate sound is built from the film's kawoosh and wash, ringing in the same hall,
# over the gate's hum, so they read as one machine.

OPEN_HIT = 0.6
OPEN_DURATION = 3.6
CLOSE_HIT = 1.1
CLOSE_DURATION = 2.4
DEPART_DURATION = 1.6
ARRIVE_PEAK = 64 / 60
ARRIVE_DURATION = ARRIVE_PEAK + 1.1
CAR_DURATION = 0.9
# The hum loops while a gate is open; every component completes whole cycles in it, so it repeats
# without a seam. 4 s holds 200 cycles of 50 Hz and 6 of the 1.5 Hz throb.
HUM_DURATION = 4.0


def generate_open() -> list[float]:
    """The veil bursting out: a reversed hall swells and wind is drawn in until the kawoosh lands at
    OPEN_HIT with a thump, then the wash settles while the hum blooms underneath into the loop."""
    total = OPEN_DURATION + 1.0
    splash = kawoosh(2.0, 0x0901, top=4500, bottom=450, down=0.22, up=0.32, ring=0.35)
    output = silence(total)
    place(output, reverse_swell(splash, OPEN_HIT), 0.0, 0.9)
    place(output, [x * smoothstep(i / samples_for(OPEN_HIT)) ** 2 for i, x in
                   enumerate(wind_howl(OPEN_HIT, (220.0, 330.0, 500.0), 0x0902, attack=0.01))], 0.0, 0.5)
    place(output, splash, OPEN_HIT, 1.0)
    place(output, sub_drop(1.5, 95.0, 32.0, sweep=0.2, decay=0.6), OPEN_HIT, 0.7)
    place(output, puff(1.0, 0.14, 1400.0, 0x0903), OPEN_HIT, 1.0)
    place(output, hall(splash, tail=0.0), OPEN_HIT, 0.8)
    place(output, wash(OPEN_DURATION - OPEN_HIT - 0.3, 0x0904, decay=1.3), OPEN_HIT + 0.3, 0.7)
    place(output, hum_bloom(OPEN_DURATION - OPEN_HIT, attack=0.9), OPEN_HIT, 0.175)
    place(output, wind_howl(OPEN_DURATION - OPEN_HIT, (180.0, 270.0, 410.0), 0x0905, attack=1.0), OPEN_HIT, 0.125)
    return master(output, OPEN_DURATION)


def generate_close() -> list[float]:
    """The veil collapsing: the wash played backwards sucks into the ring while the hum bends down
    and the wind falls away, then a thump and a dead stop at CLOSE_HIT, leaving only the hall."""
    output = silence(CLOSE_DURATION + 1.0)
    place(output, wash(CLOSE_HIT, 0x0C01, decay=0.5)[::-1], 0.0, 0.9)
    place(output, [x * (1 - smoothstep(i / samples_for(CLOSE_HIT))) for i, x in
                   enumerate(hum_bloom(CLOSE_HIT, attack=0.01, fall=0.45))], 0.0, 0.2)
    place(output, wind_howl(CLOSE_HIT, (410.0, 270.0, 180.0), 0x0C02, attack=0.02, decay=0.5), 0.0, 0.175)
    hit = kawoosh(1.0, 0x0C03, top=2200, bottom=250, down=0.12, up=0.0, ring=0.08, body=0.9)
    place(output, hit, CLOSE_HIT, 0.8)
    place(output, sub_drop(1.2, 110.0, 35.0, sweep=0.12, decay=0.35), CLOSE_HIT, 0.9)
    place(output, puff(0.8, 0.1, 1100.0, 0x0C04), CLOSE_HIT, 0.9)
    pre = silence(CLOSE_HIT)
    place(pre, wash(CLOSE_HIT, 0x0C01, decay=0.5)[::-1], 0.0, 0.5)
    place(output, hall(pre + hit, tail=0.0), 0.0, 0.7)
    return master(output, CLOSE_DURATION)


def generate_depart() -> list[float]:
    """Stepping into the veil: a small kawoosh sweeping down, a breath of wash, the hall."""
    splash = kawoosh(1.2, 0x0D01, top=3500, bottom=400, down=0.18, up=0.2, ring=0.2, body=0.4)
    output = silence(DEPART_DURATION + 1.0)
    place(output, splash, 0.0, 1.0)
    place(output, puff(0.6, 0.08, 1200.0, 0x0D02), 0.0, 0.6)
    place(output, wash(DEPART_DURATION - 0.2, 0x0D03, decay=0.45), 0.2, 0.5)
    place(output, hall(splash, tail=0.0), 0.0, 0.7)
    return master(output, DEPART_DURATION)


def generate_arrive() -> list[float]:
    """Stepping out: a reversed hall swells up to ARRIVE_PEAK, matching the 64-tick arrival in
    scripts/transfer.lua, where a small rising kawoosh breaks out with a thump."""
    splash = kawoosh(1.2, 0x0A01, top=3500, bottom=400, down=0.0, up=0.22, ring=0.25, body=0.5)
    output = silence(ARRIVE_DURATION + 1.0)
    place(output, reverse_swell(splash, ARRIVE_PEAK), 0.0, 1.0)
    place(output, splash, ARRIVE_PEAK - 0.05, 0.9)
    place(output, sub_drop(0.8, 90.0, 40.0, sweep=0.15, decay=0.3), ARRIVE_PEAK, 0.45)
    place(output, puff(0.6, 0.1, 1200.0, 0x0A02), ARRIVE_PEAK, 0.7)
    place(output, wash(ARRIVE_DURATION - ARRIVE_PEAK, 0x0A03, decay=0.5), ARRIVE_PEAK + 0.1, 0.45)
    place(output, hall(splash, tail=0.0), ARRIVE_PEAK - 0.05, 0.6)
    return master(output, ARRIVE_DURATION)


def generate_car_in() -> list[float]:
    """One carriage plunging into the veil: a fast falling kawoosh, a puff, and the phasing roar
    of the carriage rushing past."""
    output = silence(CAR_DURATION + 1.0)
    splash = kawoosh(CAR_DURATION, 0xCA01, top=4000, bottom=350, down=0.16, up=0.0, ring=0.18, body=0.7)
    place(output, splash, 0.0, 1.0)
    place(output, jet_flange(CAR_DURATION, 0.4, 6.0, sweep=0.2, decay=0.22, seed=0xCA02), 0.0, 1.4)
    place(output, sub_drop(0.6, 80.0, 40.0, sweep=0.1, decay=0.15), 0.0, 0.35)
    place(output, puff(0.5, 0.07, 1000.0, 0xCA03), 0.0, 0.7)
    place(output, hall(splash, tail=0.0), 0.0, 0.5)
    return master(output, CAR_DURATION, peak=PEAK * 0.8)


def generate_car_out() -> list[float]:
    """One carriage breaking out of the veil: a rising kawoosh and the roar of it rushing away."""
    output = silence(CAR_DURATION + 1.0)
    splash = kawoosh(CAR_DURATION, 0xCB01, top=4000, bottom=350, down=0.0, up=0.16, ring=0.18, body=0.7)
    place(output, splash, 0.0, 1.0)
    place(output, jet_flange(CAR_DURATION, 6.0, 0.4, sweep=0.2, decay=0.25, seed=0xCB02), 0.0, 1.4)
    place(output, puff(0.5, 0.07, 1000.0, 0xCB03), 0.05, 0.6)
    place(output, hall(splash, tail=0.0), 0.0, 0.5)
    return master(output, CAR_DURATION, peak=PEAK * 0.8)


def generate_hum() -> list[float]:
    """The open gate's loop: a gigawatt drone, the dimensional gap's wind howling through it, and a
    faint wash of the veil. Noise is filtered over two passes and the second kept, so the loop's end
    flows into its start; the howl's pitch wander completes whole cycles in the loop."""
    count = samples_for(HUM_DURATION)
    source = noise(count, 0x4D01)
    howl = [0.0] * count
    for centre, cycles, phase in ((180.0, 1, 0.0), (270.0, 1, 2.1), (410.0, 2, 4.0), (620.0, 1, 1.0)):
        path = [centre * (1.0 + 0.15 * math.sin(math.tau * cycles * i / count + phase)) for i in range(count)]
        for index, sample in enumerate(svf(source + source, path + path, q=9.0, mode="band")[count:]):
            howl[index] += sample
    hiss = svf(svf(source + source, 2200), 300, mode="high")[count:]
    rumble = svf(svf(source + source, 90), 90)[count:]
    drone = hum_bloom(HUM_DURATION, attack=1e-6)
    output = []
    for index in range(count):
        breathe = 0.6 + 0.4 * math.sin(math.tau * 3 * index / count)
        output.append(0.55 * drone[index] + 0.7 * howl[index] * breathe + 0.12 * hiss[index] + 1.5 * rumble[index])
    return normalize(output, PEAK * 0.35)


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
        "stargate-car-in": generate_car_in,
        "stargate-car-out": generate_car_out,
        "stargate-hum": generate_hum,
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
    parser.add_argument("--out", metavar="DIR", type=Path, default=OUTPUT_DIRECTORY,
                        help="write the sound bank here instead of beside this script, to audition it")
    parser.add_argument("--elements", metavar="DIR", type=Path,
                        help="write each element alone as DIR/<element>.wav instead of the sound bank")
    arguments = parser.parse_args()
    if arguments.elements:
        arguments.elements.mkdir(parents=True, exist_ok=True)
        for name, element in elements().items():
            write_wave(arguments.elements / f"{name}.wav", fade_edges(list(element())))
            print(f"wrote {name}.wav")
        return
    ffmpeg = find_ffmpeg(arguments.ffmpeg)
    sounds = outputs()
    names = arguments.only or list(sounds)
    unknown = sorted(set(names) - set(sounds))
    if unknown:
        raise SystemExit(f"unknown outputs: {', '.join(unknown)}")
    arguments.out.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as temporary:
        for name in names:
            wave_path = Path(temporary) / f"{name}.wav"
            write_wave(wave_path, sounds[name]())
            output_path = arguments.out / f"{name}.ogg"
            encode_ogg(ffmpeg, wave_path, output_path)
            print(f"generated {output_path.name}")


if __name__ == "__main__":
    main()
