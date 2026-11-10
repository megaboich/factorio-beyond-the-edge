# Factorio forum post

Posted on 2026-11-10: https://forums.factorio.com/viewtopic.php?t=136909

Where: forums.factorio.com, Mods → Mods (https://forums.factorio.com/viewforum.php?f=190), where release threads use titles like "[MOD 2.1] Name". The forum uses phpBB BBCode, not Markdown: paste the body below into the editor as is. External images and GIFs load from GitHub. The forum has no video embedding (posts with YouTube videos only show links), so each video is a clickable thumbnail: the YouTube thumbnail at 416x234 (`<mod>-video-thumbnail.jpg` here, made with ffmpeg from `video-demo/<mod>/thumbnail.jpg`), loaded from GitHub, so it must be pushed before posting. Screenshots work the same way: `shot-*.jpg` here are 416x234 previews of the full-size `reddit-post/*.jpg` they link to. Technical details are left to the GitHub manuals and source.

## Title

[MOD 2.1] Beyond the Edge: Warp Drive & Space Lab - a reason to fly to the Shattered Planet

## Body

```bbcode
[size=200][b]Factorio: Beyond the Edge[/b][/size]

Post-game mods for Factorio: Space Age, for factories that have already reached the Solar System Edge and want something to build toward other than more science for its own sake.

In vanilla, the next step is the Shattered Planet, and reaching it felt underwhelming: a 4,000,000 km trip that is mostly waiting, and nothing worth having at the end. These two independent mods give that trip a purpose and a faster way to make it.

[size=150][b]Warp Drive[/b][/size]

[img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/warp-drive/docs/warp-drive-warp.gif[/img]

One 8x8 building per space platform, with two roles:
[list]
[*][b]Tachyon detector:[/b] tachyons get denser the further you fly, peaking at the Shattered Planet. The detector turns them into research speed: first for its own enormously expensive final technology, then as a permanent science boost, strongest for labs on the same platform.
[*][b]Warp travel:[/b] the drive charges up from the platform's power and jumps the ship into subspace. Warp-1 is 10x speed, and higher levels need more engine speed and power. Asteroids can't reach the ship in subspace, but that also means no materials, so long trips become a warp / drop out / collect loop.
[*][b]Circuit control:[/b] engage, disengage and the detector can be automated, and the drive outputs warp level, distance, reserve, speed and tachyon density.
[/list]

Demo video (3.5 min, click to watch on YouTube):
[url=https://www.youtube.com/watch?v=FKd6wIzOH2k][img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/forum-post/warp-drive-video-thumbnail.jpg[/img][/url]

Screenshots (click for full size):
[url=https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/reddit-post/1-warp-drive-jump.jpg][img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/forum-post/shot-1-warp-drive-jump.jpg[/img][/url] [url=https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/reddit-post/2-warp-drive-subspace.jpg][img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/forum-post/shot-2-warp-drive-subspace.jpg[/img][/url]

[size=150][b]Space Lab[/b][/size]

[img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/spacelab/docs/growth-facility-biter-egg.gif[/img]

Lets one platform run a complete late-game science chain on its own:
[list]
[*][b]Asteroid chemistry:[/b] stone, ammonia, lithium, fluorine, tungsten and holmium from asteroid chunks, plus a rare new mineral, Flurolite.
[*][b]Growth Facility:[/b] a 9x9 orbital bio-lab that grows Yumako and Jellynut and incubates biter and pentapod eggs.
[*][b]Science in orbit:[/b] agricultural, cryogenic, electromagnetic and metallurgic science packs can be made on platforms.
[/list]

Demo video (1.7 min, click to watch on YouTube):
[url=https://www.youtube.com/watch?v=JVCqwXjkNm8][img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/forum-post/spacelab-video-thumbnail.jpg[/img][/url]

Screenshots (click for full size):
[url=https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/reddit-post/3-space-lab-shattered-synthesis.jpg][img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/forum-post/shot-3-space-lab-shattered-synthesis.jpg[/img][/url] [url=https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/reddit-post/4-space-lab-growth-facilities.jpg][img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/forum-post/shot-4-space-lab-growth-facilities.jpg[/img][/url]

[size=150][b]Together[/b][/size]

The two mods make an endgame challenge: a fully autonomous research station parked at the Shattered Planet, making every science pack from asteroids, with its labs boosted where the tachyons are densest.

Both require Factorio 2.1 with Space Age and work on their own. They are designed to be safe to add to an existing late-game save: they change no existing recipes or buildings (apart from Space Lab lifting the surface restriction on four science packs) and leave running factories untouched. All art and sounds are original and generated from scripts in the repository.

[size=150][b]Under the hood[/b][/size]

The most notable implementation details. The GitHub manuals and source have the rest, if you're curious.

[i]How it was made[/i]
[list]
[*][b]All of the code was written by AI agents.[/b] I was able to delegate all of the coding; my role was mostly writing specifications, directing the design, reviewing the code and results, and testing in game.
[*][b]The agents' knowledge is on GitHub too.[/b] AGENTS.md holds the development rules and the Factorio engine quirks discovered along the way.
[*][b]Numerous other docs cover the rest.[/b] Each mod has a full manual, the Warp Drive has design notes for its composite building and its audio, and the demo-video workflow is documented as well.
[/list]

[i]Warp Drive[/i]
[list]
[*][b]Warp travel moves the platform along its route directly.[/b] There is no API to make a platform fly faster, so each tick the drive advances the platform's normalized position on its space connection. The travel direction comes from position changes, because platform speed has no sign. The last 1,000 km of every route stay unwarped, so the game's own arrival handling still runs.
[*][b]Subspace is kept asteroid-free by script.[/b] A platform cannot be told to stop spawning asteroids, so during warp the drive destroys new asteroids and asteroid chunks every tick. At entry, an expanding shockwave sweeps away the ones already there, each vanishing as the ring passes it.
[*][b]Warp effects are drawn with LuaRendering, not smoke.[/b] The first shockwave used trivial smoke, but the game silently skips creating smoke where no player can see it, so a ring started off screen never appeared. The shockwave, streaks, anomalies and lightning cloud are now script-driven render objects, visible wherever you look.
[*][b]The Warp Drive building is composite.[/b] No single entity type offers a large selectable building with a GUI, circuit input and output, a continuous animation, and a power draw that changes at runtime. The visible building is a constant combinator, and hidden companions provide the status-lamp animation, an electric energy interface for power, a second combinator for circuit outputs, and a positional hum during warp.
[*][b]The power draw adapts to the ship.[/b] The detector asks for up to 1 GW at normal machine priority. After a shortfall it lowers its request to what it actually received, and when fully supplied it probes 10 MW higher, so it soaks up spare power without starving the rest of the platform.
[*][b]Tachyon research is a simple formula added to normal research.[/b] The bonus multiplies tachyon density (route depth), platform speed, delivered power, and where the labs are (full strength on the same platform, a tenth for planetary labs). It is added as extra progress to the current research, scaled by your labs' actual research rate, so science packs are consumed as usual.
[*][b]Sounds are synthesized, not sampled.[/b] A Python script generates the whole sound bank: the charging whine in 20 steps that follow the charge level, the breach roar, the exit, and a seamless field-hum loop. Mixes are checked to carry on laptop speakers, not only on headphones.
[/list]

[i]Space Lab[/i]
[list]
[*][b]The Growth Facility shows only what it is growing.[/b] Each of its four recipes owns one of the four crafting-machine tint channels: opaque white on its own channel, transparent on the others. The specimens, fluid and glow overlays for that recipe are tinted by its channel, so one building shows trees, jellystems, biters or pentapods with no script. The trick has a hard limit: four channels, four recipes.
[*][b]Vanilla recipes are changed in place, not duplicated.[/b] The four planetary science packs become craftable in space by removing their surface conditions in data-final-fixes. No duplicate recipes or machines are added, so other mods that tweak those recipes keep working.
[*][b]Written for Factorio 2.1 data.[/b] Recipes use the new categories list, and data-stage checks account for Yumako, Jellynut and Bioflux being capsules rather than items.
[/list]

[i]Both mods[/i]
[list]
[*][b]All graphics are rendered from 3D models.[/b] Each building is a Three.js model rendered in headless Chrome into Factorio sprite sheets, with shadow, animation and additive glow layers, plus the icons and the warp effects. Changing the look means editing the model and re-exporting, never painting pixels.
[*][b]Tested against the real game.[/b] A prototype test suite loads vanilla Space Age, each mod alone, and both together, and checks the resolved game data against the values in the README. Headless runtime tests place drives on real platforms and check power, travel, cooldowns and research.
[/list]

This is the first release, so feedback is very welcome, especially on balance and compatibility with other space mods.

[size=150][b]Links[/b][/size]

[list]
[*]Mod Portal: [url=https://mods.factorio.com/mod/bte-warp-drive]Warp Drive[/url], [url=https://mods.factorio.com/mod/bte-spacelab]Space Lab[/url]
[*]Source, full manuals and issues: [url]https://github.com/megaboich/factorio-beyond-the-edge[/url]
[*]Reddit discussion: [url=https://www.reddit.com/r/factorio/comments/1xs3eze/the_shattered_planet_was_4000000_km_of_waiting/]r/factorio thread[/url]
[/list]
```
