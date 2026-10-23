# Warp Drive Audio

**Document role:** this is the maintainer reference for audio assets, synthesis,
runtime playback, persistent scheduling state, and regeneration. `README.md` is
authoritative for player-facing behavior; `BUILDING.md` covers the composite
entity and electrical lifecycle.

## Sound Bank

All runtime audio is 48 kHz Ogg Vorbis under `resources/audio/`, synthesized by
`resources/audio/generate.py`. Activation and deactivation are stereo; everything else
is mono.

| Assets | Duration | Role |
| --- | --- | --- |
| `warp-buzz-01.ogg` through `warp-buzz-20.ogg` | 0.5 seconds each | Charge-progress hum and capacitor whine |
| `warp-failed-activation-01.ogg` through `warp-failed-activation-20.ogg` | 1.6 seconds each | Charge-matched interrupted-activation power-down |
| `warp-activation.ogg` | 5 seconds | A vortex breaking through the dimensional edge, fading into the ambience |
| `warp-deactivation.ogg` | 3.2 seconds | The vortex rushing back in, an exit thump, and spin-down |
| `warp-background-01.ogg`, `warp-background-02.ogg` | 6 seconds each | Phase-contiguous ship-wide active-warp ambience |
| `warp-field-hum.ogg` | 256 ticks (about 4.27 seconds) | Seamless positional loop the building plays while warp holds |

Loudness targets small speakers as well as full-range ones. Laptop speakers and small
headphones reproduce little below about 150 Hz, so every event carries its weight in the
midrange; sub-bass only adds to it. Compare candidates with ffmpeg's `ebur128` filter both
unfiltered and after a 150 Hz high-pass.

`resources/audio/generate.py` deterministically synthesizes every asset in pure Python
(no third-party packages). The charge bank
progressively increases magnetic and inverter activity, raises a capacitor whine from
190 Hz to 760 Hz while its pulse rate quickens, and adds denser electrical sparks;
output compensation keeps early steps present. Each charge step is a periodic waveform
whose every component completes whole cycles per file, with a shared zero-crossing
boundary and a six-millisecond codec-safe edge taper, so steps join without clicks.
The generator adds libvorbis encoder preroll so each file decodes to exactly 24,000
samples.

Each failed-activation sound begins with its corresponding hum waveform and pitch,
then sags unevenly, sheds inverter texture, and ends with a muted relay thud. This
keeps interrupted buildup continuous instead of cutting to an unrelated effect.

Activation is timed with the building's activation overlay, whose core flashes at
0.54 seconds:

- Suction (0 to 0.54 s): the exact step-20 waveform accelerates while the whine
  screams up 1.6 octaves, a band of air is drawn upward, and the reversed hall of the
  coming roar swells into the breach. Everything cuts out for a breath just before it.
- Breach (0.54 s), `breach_layers`: a vortex. A soft thump of displaced air over a
  sub-bass drop from 90 Hz to 30 Hz; a jet-like phasing roar (noise through a feedback
  comb whose delay sweeps from 0.4 ms to 9 ms) tearing across the stereo field; wind
  howling through resonant bands that wander in pitch; and a deep 55 Hz harmonic hum
  that blooms underneath, each harmonic beating against a slightly sharp twin and the
  whole drone breathing at the core's 1.875 Hz pulse. A Freeverb-style stereo hall
  makes the event fill the ship rather than one machine.
- Aftermath: lows below 120 Hz are pulled down so the limiter spends its headroom on
  the audible midrange; the opening is saturated and limited for density, then eases
  back to the clean signal while the hall decays and the ambience fades in beneath it.

Deactivation uses the same palette: a short vortex reversed rushes back in, lands on a
thump and a fading gust, and the capacitor whine and hum spin down while the deep hum
dies away and a relay clunks off.

The vortex was chosen by audition over three alternatives built from the same kind of
material: a formant "om" choir hum, a Doppler pass-through, and a harmonic-chord
resonance. Earlier brass and shattering-glass layers were rejected as not fitting a
passage into another dimension.

Transitions pass a 4 ms look-ahead limiter at 0.64 of full scale. Saturated material
overshoots in Vorbis reconstruction, and this ceiling keeps decoded peaks below
-0.5 dBFS; `write_wave` also rejects any PCM above `ENCODER_SAFE_PEAK`.

The background is one 12-second phase-contiguous composition split into two files.
It contains quiet machinery ambience, sparse retro console pings, and long
hyperspace-sonar calls in its second half. Activation fades in the composition's
final seconds beneath its tail and ends exactly on the loop's start, so segment 01
continues it seamlessly; segments 01 and 02 then alternate.

The field hum holds the activation's deep hum for as long as warp lasts, adding a breath
of band-passed plasma noise and a low rumble that pulse with the core, a faint shimmer,
and sparse sparks. Its loop lasts 256 ticks, four of the building's 64-tick animation
loops, and every component completes whole cycles in it; noise is filtered over two
passes of the loop, keeping the second, so the filter carries no start-up transient into
the seam. Unlike the 0.5-second charge steps, it is written without encoder preroll,
which decodes to exactly one loop (204,800 samples).

## Runtime Playback

`scripts/warp.lua` plays drive audio globally on the platform surface. Omitting a
position from `LuaSurface.play_sound` prevents attenuation around the controller.
Every sound prototype in `data.lua` uses the `game-effect` category: the `ambient`
category is the music slider, which defaults to a third of the game-effects volume
and made the charge hum nearly inaudible. The prototype tests enforce this.

Charging schedules a half-second hum every 30 ticks. At each file boundary, reserve
progress selects one of the 20 steps. If preparation becomes invalid after an
audible hum has started, runtime plays the matching failed-activation sound and
starts the existing 300-tick cooldown. Invalid preparation before the first hum
does not play a power-down or start that cooldown.

Warp entry replaces charge scheduling with activation. After its 300-tick duration
(`WARP_ACTIVATION_SOUND_TICKS`), background segment 01 starts, followed by alternating segments every 360 ticks.
Warp exit stops scheduling future segments, lets any current segment finish, and
plays deactivation.

The building's own hum is positional, so it is audible around the drive and fades with
distance and zoom like other machines. `bte-warp-drive-field-hum` is a hidden
`simple-entity-with-owner` companion whose `working_sound` loops `warp-field-hum.ogg`;
any entity plays its working sound continuously, as Vulcanus's chimney vents do. The
background update creates it while the drive is in warp (fading in over 120 ticks
beneath the activation) and destroys it on exit. Companion recovery adopts or removes
it like the other companions; see `BUILDING.md`.

Factorio exposes neither a runtime sound handle nor a stop operation. Playback is
therefore composed from one-shots and serialized deadlines rather than stoppable
loops. The relevant drive-record fields are:

| Field | Role |
| --- | --- |
| `charge_sound_next_tick`, `charge_sound_step` | Next half-second charge boundary and current progress step |
| `warp_sound_next_tick`, `warp_background_sound_index` | Next background boundary and alternating segment |

These fields preserve one-shot and sequence timing across ordinary save/load. An
active save migrating from the stock sounds has no recoverable playback phase, so
runtime resumes at a background segment boundary instead of guessing mid-file.

## Regenerate Synthesized Bank

Requirements:

- Python 3.9 or newer
- `ffmpeg` with `libvorbis` support (`brew install ffmpeg`)

Run from any directory; from the repository root:

```sh
python3 warp-drive/resources/audio/generate.py
python3 warp-drive/resources/audio/generate.py --only warp-activation warp-deactivation
```

A full run takes about 20 seconds.

Edit the constants near the top of `generate.py` to change durations, pitch range,
output count, sample rate, Vorbis quality, or final mix gains. Buzz steps use
`BUZZ_OUTPUT_GAIN`, with `BUZZ_EARLY_PRESENCE_GAIN` tapering extra gain away as
charge rises. Activation and deactivation are limited to `TRANSITION_PEAK`;
changing `ACTIVATION_DURATION` also requires `WARP_ACTIVATION_SOUND_TICKS` in
`scripts/warp.lua`, and `ACTIVATION_BREACH` must stay on the activation overlay's
flash in `tools/sprites/models/warp-drive.js`. Ambience and the activation tail use
`BACKGROUND_OUTPUT_GAIN`. The field hum's length is `FIELD_HUM_DURATION` and its level
`FIELD_HUM_PEAK`, with its in-game volume and audible distance set on the
`bte-warp-drive-field-hum` prototype. `OUTPUT_PEAK_LIMIT` contains failed-activation
peaks, while `ENCODER_SAFE_PEAK` reserves headroom for Vorbis reconstruction. Temporary
PCM files use the system temporary directory and are removed automatically.

## Validation

After changing audio assets, prototypes, or scheduling, from the repository root:

1. Inspect regenerated files with `ffprobe` and listen to transitions in sequence.
2. Run `./make.sh warp-drive` and verify the assets are present in the ZIP.
3. Run Factorio with `--dump-data` and inspect the resolved sound prototypes.
4. Run `./warp-drive/tests/run-runtime-tests.sh`.
5. Run `git diff --check`.

Headless tests verify sound paths and scheduling state, but Factorio disables audio
in that mode. Interactive checks remain necessary for loudness, seam quality, interruptions,
transition timing, and how the field hum fades with distance and zoom.
