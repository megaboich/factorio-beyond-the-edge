# Warp Drive Audio

**Document role:** this is the maintainer reference for audio assets, synthesis,
runtime playback, persistent scheduling state, and regeneration. `README.md` is
authoritative for player-facing behavior; `BUILDING.md` covers the composite
entity and electrical lifecycle; `PLAN.md` tracks unfinished work.

## Sound Bank

All runtime audio is mono, 48 kHz Ogg Vorbis under `resources/audio/`.

| Assets | Duration | Role |
| --- | --- | --- |
| `warp-command.ogg` | About 1.29 seconds | Locally synthesized "Engage warp drive!" readiness command |
| `warp-buzz-01.ogg` through `warp-buzz-20.ogg` | 0.5 seconds each | Charge-progress machinery hum |
| `warp-failed-activation-01.ogg` through `warp-failed-activation-20.ogg` | 1.6 seconds each | Charge-matched interrupted-activation power-down |
| `warp-activation.ogg` | 1.5 seconds | Final hum transformed into a dimensional implosion |
| `warp-deactivation.ogg` | 1.5 seconds | Reverse-derived warp exit transition |
| `warp-background-01.ogg`, `warp-background-02.ogg` | 6 seconds each | Phase-contiguous active-warp ambience |

`resources/audio/generate.py` deterministically synthesizes every asset except
`warp-command.ogg`. The charge bank progressively increases magnetic and inverter
activity while output compensation keeps early steps present. Each charge step is
a periodic waveform with a shared zero-crossing boundary and a six-millisecond
codec-safe edge taper. The generator adds libvorbis encoder preroll so each file
decodes to exactly 24,000 samples.

Each failed-activation sound begins with its corresponding hum waveform and pitch,
then sags unevenly, sheds inverter texture, and ends with a muted relay thud. This
keeps interrupted buildup continuous instead of cutting to an unrelated effect.

Activation opens with the exact step-20 waveform and transforms it through
acceleration, close detuning, and filtered air. At 0.54 seconds, a brief suction
notch makes room for a wide fracture, descending dark inharmonic folds, rapidly
low-passed noise, and a deep inward pressure pulse. The event settles rapidly into
near-silence. Deactivation reverses the complete activation composition.

The background is one 12-second phase-contiguous composition split into two files.
It contains quiet machinery ambience, sparse retro console pings, and long
hyperspace-sonar calls in its second half. Activation includes the composition's
final 80 milliseconds and hands off to segment 01; segments 01 and 02 then alternate.

## Runtime Playback

`scripts/warp.lua` plays drive audio globally on the platform surface. Omitting a
position from `LuaSurface.play_sound` prevents attenuation around the controller.

The readiness command plays when every non-charge warp-entry requirement first
becomes valid. `readiness_announced` latches that transition so an unchanged ready
state cannot replay it on every 10-tick update. Invalid preparation, cooldown,
experimental mode, and warp exit clear the latch. A save already charging when the
command was introduced is marked announced without playing it midway through the
buildup.

Charging schedules a half-second hum every 30 ticks. At each file boundary, reserve
progress selects one of the 20 steps. If preparation becomes invalid after an
audible hum has started, runtime plays the matching failed-activation sound and
starts the existing 300-tick cooldown. Invalid preparation before the first hum
does not play a power-down or start that cooldown.

Warp entry replaces charge scheduling with activation. After its 90-tick duration,
background segment 01 starts, followed by alternating segments every 360 ticks.
Warp exit stops scheduling future segments, lets any current segment finish, and
plays deactivation.

Factorio exposes neither a runtime sound handle nor a stop operation. Playback is
therefore composed from one-shots and serialized deadlines rather than stoppable
loops. The relevant drive-record fields are:

| Field | Role |
| --- | --- |
| `readiness_announced`, `readiness_sound_tick` | One-shot readiness latch and command start tick |
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
```

Edit the constants near the top of `generate.py` to change durations, pitch range,
output count, sample rate, Vorbis quality, or final mix gains. Buzz steps use
`BUZZ_OUTPUT_GAIN`, with `BUZZ_EARLY_PRESENCE_GAIN` tapering extra gain away as
charge rises. Activation and deactivation use `TRANSITION_OUTPUT_GAIN`; ambience
and the activation tail use `BACKGROUND_OUTPUT_GAIN`. `OUTPUT_PEAK_LIMIT` contains
transition peaks, while `ENCODER_SAFE_PEAK` reserves headroom for Vorbis
reconstruction. Temporary PCM files use the system temporary directory and are
removed automatically.

## Regenerate Voice Command

`warp-command.ogg` uses the standard macOS `Karen` Australian voice saying
"Engage warp drive!" at 165 words per minute. Light speech-band filtering,
compression, limiting, and edge padding produce the committed mono asset without
copied source media.

On macOS with the `Karen` system voice installed:

```sh
say -v Karen -r 165 -o /tmp/warp-command.aiff "Engage warp drive!"
ffmpeg -y -i /tmp/warp-command.aiff \
  -af "silenceremove=start_periods=1:start_duration=0.02:start_threshold=-50dB:stop_periods=-1:stop_duration=0.12:stop_threshold=-50dB,highpass=f=90:poles=2,lowpass=f=9000:poles=2,acompressor=threshold=0.09:ratio=2.5:attack=10:release=80:makeup=1.8,apad=pad_dur=0.12,afade=t=in:st=0:d=0.015,alimiter=limit=0.89:attack=5:release=50" \
  -map_metadata -1 -ar 48000 -ac 1 -c:a libvorbis -q:a 5 \
  -fflags +bitexact -flags:a +bitexact -write_xing 0 -serial_offset 1 \
  warp-drive/resources/audio/warp-command.ogg
```

System voice revisions can change the waveform across macOS releases. Review the
result before replacing the committed asset.

## Validation

After changing audio assets, prototypes, or scheduling, from the repository root:

1. Inspect regenerated files with `ffprobe` and listen to transitions in sequence.
2. Run `./make.sh warp-drive` and verify the assets are present in the ZIP.
3. Run Factorio with `--dump-data` and inspect the resolved sound prototypes.
4. Run `./warp-drive/tests/run-runtime-tests.sh`.
5. Run `git diff --check`.

Headless tests verify sound paths and scheduling state, but Factorio disables audio
in that mode. Interactive checks remain necessary for loudness, intelligibility,
seam quality, interruptions, and transition timing.
