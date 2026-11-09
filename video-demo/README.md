# Demo Videos

Sources, scripts, and notes for the mods' YouTube demo videos. Large media (recordings, masters, audio, uploads, screenshots) lives in the git-ignored `video-demo-output/` next to this folder, under the same per-video names; every script here reads and writes there.

| Video | Published | Folder |
| --- | --- | --- |
| Warp Drive (3:28) | <https://www.youtube.com/watch?v=FKd6wIzOH2k> | `warp-drive/` |
| Space Lab (1:42) | <https://www.youtube.com/watch?v=JVCqwXjkNm8> | `spacelab/` |

Each folder keeps the uploaded subtitles (`*.en.srt`), the YouTube title and description (`youtube-description.txt`), and the thumbnail (`thumbnail.jpg`).

## Tools

- `ffmpeg-full` (Homebrew, `/opt/homebrew/opt/ffmpeg-full/bin/ffmpeg`) for every cut, encode, and mix.
- Kokoro TTS in `~/.cache/narrated-screen-demo/venv` (set up by the `narrated-screen-demo` skill). Both videos use the `af_bella` voice at speed 1.25; shorten a line rather than speed it up, because faster lines sound rushed.
- Factorio from Steam. Starting the Steam build with arguments needs `SteamAppId=427520`, and Steam asks once per launch to allow the custom arguments. Steam restarts the game from another directory, so every path passed to Factorio must be absolute.
- Space Lab only: Xcode command-line tools (`swiftc`) for the two helpers in `spacelab/tools/`, and Screen Recording permission for the terminal or app that runs the scripts.

## Warp Drive: hand-recorded, narrated afterwards

The game was played and recorded by hand with QuickTime (`Demo-recording.mov`, game sound only), then edited and narrated. The recording starts from the author's save `Continents - start recording.zip` (a platform on the Shattered Planet route with a Warp Drive and a circuit-controlled speed cap, plus the third-party mods listed in the Warp Drive README). Saves are not in the repository; to make a similar video, build a comparable platform in your own game first.

1. `narration-draft.txt` is the spoken commentary written before recording. It became the subtitle cues.
2. `./render.sh edit` cuts the recording (drops the first 7 s and slows the run-up to the first jump to 0.6x) into a picture-only and a game-sound-only file.
3. `subtitles.py` holds the cues as `(start, end, text)` in edited-video seconds, anchored to events checked frame by frame, and writes `warp-drive-demo.en.srt`.
4. `voiceover.py af_bella V2-bella` speaks each cue at its start time and mixes the voice over the game sound (`V2-bella.m4a`).
5. `./render.sh youtube` renders the 1440p upload. YouTube gives 1080p uploads only its lower-quality processing, which blurs dialog text, so even 1080p sources are upscaled.
6. `./render.sh thumbnail` rebuilds `thumbnail.jpg` from a frame of the first jump.

## Space Lab: scripted camera, recorded automatically

The camera, building windows, and timing are driven by a temporary helper mod (`director/`), so a take can be repeated exactly. Machines in the save must actually run: the director prefers a building that is crafting with room in its output, and logs `DIRECTOR no working ...` when none qualifies. Fix the save's bottlenecks and record again rather than working around it.

The save is not in the repository. Both `record.sh` and `thumbnail.sh` load the author's `Continents - SpaceLab - Demo.zip` from the Factorio saves folder by default; set `SAVE=/path/to/save.zip` to use another one. To reproduce the video, first build a similar save:

- A space platform with every building and recipe the scenes show: asteroid collectors and crushers (including the Space Lab stone-focused and Shattered Synthesis recipes), cryogenic plants for ammonia extraction and Flurolite condensation, Growth Facilities for biter eggs and Yumako, a biochamber making agricultural science, the four planetary science packs, and labs.
- The platform on surface `platform-8`, or `SURFACE` in `scenes.py` changed to match. The save used here runs the platform `Stargazer` on the route to the Shattered Planet.
- Camera targets in `scenes.py` updated to the new building positions. The director picks the nearest suitable building within 40 tiles of each target, so rough positions are enough.
- Every machine shown running without shortages or full outputs, and the third-party mods from your mod folder that the save needs (`record.sh` copies all installed mods and their settings).

1. **Scenes** (`scenes.py`): one entry per shot with the camera target `(x, y, zoom)` on surface `platform-8`, an optional building window to open (`(entity, recipe)`), and narration lines. Each line is one complete sentence that belongs to its own shot.
2. **Plan** (`plan.py`, Kokoro venv python): speaks every line, lays the shots out on a timeline sized to the speech, and writes `director/scenes.lua` (camera keyframes and window ticks), the voice track, and the subtitles. Run it only before a new recording; it moves the shot timings.
3. **Record** (`./record.sh`): copies your installed mods and `mod-settings.dat` beside the director, runs the game windowed at 1920x1080 with a private copy of your config, moves the mouse pointer off the window, and records the game area with picture and system sound (`screencapture -v -A`) until the scene list ends. Keep the game's sound on and turn on Do Not Disturb.
4. **Master** (`master.py`): finds the director's dark frames at both ends, cuts there, stretches the take to the planned length (the game runs slightly below 60 UPS), and writes a 1440p picture-only master and the game sound as WAV. Run once per recording; it is the only slow step.
5. **Narration** (`voice.py`, Kokoro venv python): fits the narration from `scenes.py` into the recorded shot times and writes the voice track and `spacelab-demo.en.srt`. It speeds a shot's lines up only when they do not fit and reports it.
6. **Mux** (`mux.py`): mixes voice and game sound under the master without re-encoding the picture, in a few seconds. `mux.py pointer` uses the pointer master instead.
7. **Pointer** (`pointer.py`, optional): draws Factorio's own mouse pointer onto a copy of the master, gliding to each building as its window opens. The published video uses this version.
8. **Thumbnail** (`./thumbnail.sh`): takes in-game screenshots with `shots-mod/` and composes `thumbnail.jpg`. `SKIP_SHOTS=1` reuses the last screenshots. With another save, update the surface name and shot positions in `shots-mod/control.lua` and the crop offsets in `thumbnail.sh`.

After a narration change, run `voice.py` then `mux.py pointer`; after a new recording, run `master.py`, `pointer.py`, `voice.py`, then `mux.py pointer`.

## Reddit copies

`./reddit.sh` renders both videos for Reddit into `reddit-post/` (git-ignored): 1920x1080 at 30 fps, about 12 Mbit/s, with the narration and the subtitles burned in. Reddit accepts no subtitle files, re-encodes to at most about 1080p30, and its own scaling and frame-rate conversion are poor, so upscaled or 60 fps uploads gain nothing there. The post text, images, and posting notes are in `reddit-post/post.md`.

## Lessons Learned

- Factorio ignores the cutscene controller on space platforms; the director moves the remote-view camera with `set_controller` every tick instead.
- Remote-view zoom below about 0.3 switches to the map view.
- The hovered-entity panel follows the real mouse pointer even with selection updates off, so a pointer left over the game freezes it on whatever it covers. The director sets `player.selected` itself and the pointer is moved away.
- Full-screen 2560x1440 capture with ffmpeg reached only about 11 fps on this ship; the 1920x1080 window with `screencapture` gives about 57 fps.
- `screencapture` records at about 23 Mbit/s with the hardware encoder, which softens fine detail; the 1440p lanczos upscale still improves the YouTube result.
- `game.take_screenshot` taller than 1080 px renders in tiles that repeat the same picture; take 1920x1080 shots and crop.
- Building windows cover 22-78% of a 1080p frame, so the director frames the chosen building 736 px left of centre, which is also where the fake pointer clicks.
- YouTube drops all chapters if any chapter is shorter than 10 s.
