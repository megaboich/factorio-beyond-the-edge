# Warp Drive Audio

`generate.py` deterministically synthesizes the Warp Drive sound bank. It creates
20 half-second accumulator-hum charge steps with progressively stronger magnetic
and inverter activity, followed by a three-second activation release and a
three-second deactivation implosion with descending hum. The background is split
into `warp-background-01.ogg` and `warp-background-02.ogg`, two
phase-contiguous six-second segments of a quiet machinery ambience with sparse
retro console pings and long hyperspace-sonar calls in its second half. Alternate
01, 02, 01, 02 while warp remains active and stop scheduling the next segment on
disengage. The activation effect mixes its impact over the background sequence's
final quarter, then hands off phase-aligned to segment 01. All output is mono,
48 kHz Ogg Vorbis.

Each charge step is synthesized as a periodic half-second waveform with a shared
zero-crossing boundary and a six-millisecond codec-safe edge taper. The generator
adds Vorbis encoder preroll so each file decodes to exactly 24,000 samples, or
half a second. Loop steps continuously, and change steps at loop boundaries or
with a short runtime crossfade; abruptly replacing a playing sound at an
arbitrary phase can still click regardless of the source files.

## Regenerate

Requirements:

- Python 3.9 or newer
- `ffmpeg` with `libvorbis` support (`brew install ffmpeg`)

Run from any directory:

```sh
python3 resources/audio/generate.py
```

Edit the constants near the top of `generate.py` to change durations, pitch
range, output count, sample rate, or Vorbis quality. The synthesis functions
contain the tone, whoosh, and implosion layers. Temporary PCM files are written
to the system temporary directory and removed automatically.
