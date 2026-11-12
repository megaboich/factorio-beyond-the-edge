# Factorio forum post

Posted on 2026-11-10: https://forums.factorio.com/viewtopic.php?t=136909

Where: forums.factorio.com, Mods → Mods (https://forums.factorio.com/viewforum.php?f=190), where release threads use titles like "[MOD 2.1] Name". The forum uses phpBB BBCode, not Markdown: paste the body below into the editor as is. External images and GIFs load from GitHub. The forum has no video embedding (posts with YouTube videos only show links), so each video is a clickable thumbnail: the YouTube thumbnail at 416x234 (`<mod>-video-thumbnail.jpg` here, made with ffmpeg from `../video-demo/<mod>/thumbnail.jpg`), loaded from GitHub, so it must be pushed before posting. Screenshots work the same way: `shot-*.jpg` here are 416x234 previews of the full-size `../reddit-post/*.jpg` they link to. Technical details are left to the GitHub manuals and source.

After the `media-posts/` directory move is published, update the live post with the image URLs below. This local source change does not update the existing forum post automatically.

This draft was initially AI-assisted and then hand-edited by the author. Further editing should be limited to grammar and minor sentence structure; keep substantive suggestions separate.

## Title

[MOD 2.1] Beyond the Edge: Warp Drive & Space Lab - extending the Space Age endgame

## Body

```bbcode
[size=200][b]Factorio: Beyond the Edge[/b][/size]

[i][b]Disclaimer about AI use:[/b] All of the mod code was written by AI agents. My part was deciding what I wanted, writing specifications, reviewing the code and results, and testing in game. I also used AI assistance to generate game assets and to edit and record promotional videos.[/i]

I wanted to continue enjoying my Space Age playthrough after reaching the Solar System Edge, but the next destination did not give me much motivation. The Shattered Planet is 4,000,000 km away, and getting there felt like a lot of waiting without much to do at the end. I could keep increasing science production, of course, but at some point it started to feel pointless: producing science for the sake of more efficient science production did not seem very inspiring.

So, after lots of thinking, tinkering and playing with some other mods, I had some ideas to implement. And now here we are: two new mods are ready and published.

They are separate mods, so you can use either one without the other. Both require Factorio 2.1 with Space Age.

[size=150][b]Warp Drive[/b][/size]

Demo video (3.5 min, click to watch on YouTube):
[url=https://www.youtube.com/watch?v=FKd6wIzOH2k][img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/media-posts/forum-post/warp-drive-video-thumbnail.jpg[/img][/url]
Screenshots (click for full size):
[url=https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/media-posts/reddit-post/1-warp-drive-jump.jpg][img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/media-posts/forum-post/shot-1-warp-drive-jump.jpg[/img][/url] [url=https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/media-posts/reddit-post/2-warp-drive-subspace.jpg][img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/media-posts/forum-post/shot-2-warp-drive-subspace.jpg[/img][/url]

Warp Drive is heavily inspired by existing sci-fi lore, adapted to make some sense in Factorio. And it does exactly what you would expect from its name: it unlocks subspace travel at very impressive speeds. The travel itself is split into two parts: the jump into subspace and actual subspace travel. The jump requires a lot of stored energy, a minimum stable platform speed of 50 km/s and a distance of 1,000 km from any planet. Subspace travel requires maintaining your engine speed above 50 km/s, with higher engine speeds effectively multiplying your warp-speed factor.

[code]
Engine speed | Warp level | Effective speed | Time for 4M km
-------------+------------+-----------------+---------------
     50 km/s |     Warp-1 |        500 km/s | 2 h 13 m 20 s
    200 km/s |     Warp-4 |      8,000 km/s |      8 m 20 s
    350 km/s |     Warp-7 |     24,500 km/s |    ~ 2 m 43 s
[/code]
These are the speeds after the drive has reached the corresponding warp level, assuming enough power is available to sustain it. The travel times are ideal estimates at those constant speeds; actual trips take longer because of charging, warp acceleration, unwarped sections near the route endpoints and any stops to collect resources.

The warp drive building:
[img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/warp-drive/docs/warp-drive-warp.gif[/img]

The mod does not give you the engine immediately. To make the gameplay interesting, the player needs to research a technology, then build an experimental drive which, with some extra research and player involvement, helps unlock the final practical warp engine.

The gameplay mechanic I am talking about is that the final "Practical Warp Drive" research is an enormous scientific undertaking: 1B science packs. This makes it almost impossible to complete using the standard approach. What makes it possible is the new mechanic: "Tachyon research boost". In short, the Warp Drive building works as a "tachyon detector", producing a signal which significantly boosts research progress for this particular technology. The tachyon signal is much stronger towards the edge of occupied space and strongest at the Shattered Planet destination. So, to research the required technology quickly, the player needs to build a resilient spaceship, put a Warp Drive on it with detection activated and send it as far as possible along the Shattered Planet route.

[size=150][b]Space Lab[/b][/size]

Demo video (1.7 min, click to watch on YouTube):
[url=https://www.youtube.com/watch?v=JVCqwXjkNm8][img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/media-posts/forum-post/spacelab-video-thumbnail.jpg[/img][/url]

Screenshots (click for full size):
[url=https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/media-posts/reddit-post/3-space-lab-shattered-synthesis.jpg][img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/media-posts/forum-post/shot-3-space-lab-shattered-synthesis.jpg[/img][/url] [url=https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/media-posts/reddit-post/4-space-lab-growth-facilities.jpg][img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/media-posts/forum-post/shot-4-space-lab-growth-facilities.jpg[/img][/url]

This mod was mostly inspired by the infuriating fact that, in vanilla Space Age, stone cannot be mined from asteroids.
This seemed too ridiculous to be true, so I started with this simple modification. And after playing with it some more, the goal expanded to making all the game's resources obtainable in space and eventually making all kinds of science packs there as well.

I know there are other mods which make production in space possible. What I wanted here was something as non-intrusive as possible: keep the existing recipe ingredients and crafting times, use the standard machines wherever possible, and add just one new building. The only change to vanilla recipes is removing the surface restrictions from the four planetary science packs, so existing factories can keep working as before.

So, apart from adding new crusher recipes, this mod introduces a new building and a new mineral: Flurolite, used for the lithium and fluorine recipes.

The new building, the Growth Facility:
[img]https://raw.githubusercontent.com/megaboich/factorio-beyond-the-edge/main/spacelab/docs/growth-facility-biter-egg.gif[/img]

It grows Yumako and Jellynut from seeds and incubates biter and pentapod eggs. Together with the new material recipes, this lets you maintain the biological production chains in orbit instead of constantly shipping fresh ingredients from Gleba or Nauvis.

[size=150][b]What I wanted to build with them[/b][/size]

The combination of both mods makes a self-sufficient research factory on a space platform possible. It collects red asteroids, turns them into resources, makes science and travels quickly along the Shattered Planet route thanks to the Warp Drive. This combination makes a final challenge possible, if you want to try it: building this kind of self-sufficient platform, operating entirely on resources from the Shattered Planet asteroid belt.

[size=150][b]A few implementation details[/b][/size]

As I mentioned, I used AI-assisted development, and it was not limited to just a few snippets. All the Lua code, mod packaging, deployment and even some unit testing were done by AI agents. I even managed to steer AI towards producing more or less acceptable graphics and sounds. I gave them requirements, reviewed the changes, tried the results in the game and asked for changes. After repeating this loop for a while, the results started to look like what I wanted, and now the mods seem ready for release.

There were some interesting Factorio-specific problems along the way. For example, the Warp Drive looks like one building, but it is a constant combinator with hidden entities for power, animation, circuit outputs and sound. No single entity type provided all the behavior it needed.

The first activation shockwave used smoke, but it turned out that the game does not create that effect if nobody can see the position when it starts. Moving the camera there later did not help. So the effect now uses LuaRendering instead.

The building graphics are rendered from Three.js models into sprite sheets, and the Warp Drive sounds are synthesized with a Python script. Those generators are in the repository too. There are also tests which load the mods in Factorio and check the resolved prototypes, plus headless runtime tests for power, travel and research. They help catch regressions, but do not replace playing with the mods and checking how they feel.

The GitHub manuals have the recipes, research costs and formulas. There is also an AGENTS.md with the development rules and the engine quirks found during this work, in case you are interested in that side of it.

These are the first public releases, so the balance is something I would like feedback on. In particular, does the research give you a reason to improve the ship, or does it still feel like waiting? And once warp is available, is there still enough reason to care about the platform's production and fuel supply? Compatibility reports with other space mods would be useful too.

[size=150][b]Links[/b][/size]

[list]
[*]Mod Portal: [url=https://mods.factorio.com/mod/bte-warp-drive]Warp Drive[/url], [url=https://mods.factorio.com/mod/bte-spacelab]Space Lab[/url]
[*]Source, full manuals and issues: [url]https://github.com/megaboich/factorio-beyond-the-edge[/url]
[*]Reddit discussion: [url=https://www.reddit.com/r/factorio/comments/1xs3eze/the_shattered_planet_was_4000000_km_of_waiting/]r/factorio thread[/url]
[/list]
```
