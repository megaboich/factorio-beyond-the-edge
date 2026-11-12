# Reddit post (r/factorio)

Posted on r/factorio (https://www.reddit.com/r/factorio/comments/1xs3eze/the_shattered_planet_was_4000000_km_of_waiting/) as a Text post with the Modded flair, with both videos and the four images inline.

## How to post

- Reddit takes no subtitle files and plays at most about 1080p30, so the videos are 1080p30 copies with burned-in subtitles, made by `../video-demo/reddit.sh` (`media-posts/video-demo/reddit.sh` from the repository root; the generated MP4s are git-ignored, about 300 MB and 150 MB).
- Videos and images can be placed inline only in a Text post in the rich text editor, and only where the subreddit allows media in text posts.
- The rich text editor does not convert pasted Markdown; it keeps it as raw text, which showed up as one long unwrapped code-like block. Either paste the body in Markdown mode and then switch back to rich text to insert media, or format it with the editor's toolbar.
- For this revised version, keep the AI disclosure first. Insert `warp-drive-demo-reddit.mp4` and images 1-2 in the Warp Drive section, and `spacelab-demo-reddit.mp4` and images 3-4 in the Space Lab section. Follow with the combined platform goal, brief implementation notes and links. Review the speed table after switching editors, since it may need to be recreated with the rich text table tool.
- This revision follows the hand-edited forum post, with a shorter implementation section. It is an AI-assisted adaptation; review the wording before publishing. Editing this file does not update the live Reddit post.

## Images

1. `1-warp-drive-jump.jpg`: "Warp Drive: the moment the platform breaches subspace"
2. `2-warp-drive-subspace.jpg`: "Warp Drive: cruising through subspace, with no asteroids in sight"
3. `3-space-lab-shattered-synthesis.jpg`: "Space Lab: Shattered Synthesis crushes promethium chunks into tungsten, holmium and Flurolite"
4. `4-space-lab-growth-facilities.jpg`: "Space Lab: Growth Facilities growing Yumako and Jellynut in orbit"

## Title

The Shattered Planet was 4,000,000 km of waiting for nothing, so I made a Warp Drive to get there and a reason to stay

## Body

I wanted to continue enjoying my Space Age playthrough after reaching the Solar System Edge, but the next destination did not give me much motivation. The Shattered Planet is 4,000,000 km away, and getting there felt like a lot of waiting without much to do at the end. I could keep increasing science production, of course, but at some point it started to feel pointless: producing science for the sake of more efficient science production did not seem very inspiring.

So, after lots of thinking, tinkering and playing with some other mods, I had some ideas to implement. And now here we are: two new mods are ready and published under the name **Beyond the Edge**.

They are separate mods, so you can use either one without the other. Both require **Factorio 2.1 with Space Age**.

***Disclaimer about AI use:** All of the mod code was written by AI agents. My part was deciding what I wanted, writing specifications, reviewing the code and results, and testing in game. I also used AI assistance to generate game assets and to edit and record promotional videos. This post was adapted from my forum description with AI assistance.*

### Warp Drive

Warp Drive is heavily inspired by existing sci-fi lore, adapted to make some sense in Factorio. And it does exactly what you would expect from its name: it unlocks subspace travel at very impressive speeds. You first charge the drive from the platform's power grid, then jump into subspace. Thrusters, fuel, weight and available power still matter; it is not a teleport.

At least 50 km/s of engine speed is needed, and higher engine speeds allow higher warp levels:

| Engine speed | Warp level | Effective speed | Time for 4M km |
| --- | --- | --- | --- |
| 50 km/s | Warp-1 | 500 km/s | 2 h 13 m 20 s |
| 200 km/s | Warp-4 | 8,000 km/s | 8 m 20 s |
| 350 km/s | Warp-7 | 24,500 km/s | ~2 m 43 s |

These are the speeds after the drive has reached the corresponding warp level, assuming enough power to sustain it. The times are ideal estimates at those constant speeds. Actual trips take longer because of charging, warp acceleration, unwarped sections near the route endpoints and stops to collect resources.

The mod does not give you the engine immediately. First you research the experimental drive and build one as a **tachyon detector**. The final Practical Warp Drive research is deliberately enormous: one billion research units. What makes it possible is the detector's research boost, which gets stronger towards the edge of occupied space and is strongest at the Shattered Planet destination. So the idea is to build a resilient spaceship, activate its detector and send it as far as possible along that route.

Once the research is complete, the same building becomes a working warp engine. When not in warp, its detector can also boost ordinary research. There is a catch to travelling in subspace, though: asteroids disappear, so the ship stops collecting materials. You need to leave warp to replenish supplies. Engage and disengage can be controlled with circuit conditions, so this becomes part of the ship's automation.

### Space Lab

This mod was mostly inspired by the infuriating fact that, in vanilla Space Age, stone cannot be mined from asteroids. This seemed too ridiculous to be true, so I started with this simple modification. After playing with it some more, the goal expanded to making the resources needed for all kinds of science packs obtainable in space.

I know there are other mods which make production in space possible. What I wanted here was something as non-intrusive as possible: keep the existing recipe ingredients and crafting times, use the standard machines wherever possible, and add just one new building. The only change to vanilla recipes is removing the surface restrictions from the four planetary science packs, so existing factories can keep working as before.

Space Lab adds crusher and cryogenic recipes for materials including stone, ammonia, lithium and fluorine, with tungsten and holmium available from promethium chunks. There is also a new mineral, **Flurolite**, used for the lithium and fluorine recipes.

The new building is the **Growth Facility**. It grows Yumako and Jellynut from seeds and incubates biter and pentapod eggs. Together with the new material recipes, this lets you maintain the biological production chains in orbit instead of constantly shipping fresh ingredients from Gleba or Nauvis.

### What I wanted to build with them

The combination makes a self-sufficient research factory on a space platform possible. It collects red asteroids, turns them into resources, makes science and travels quickly along the Shattered Planet route thanks to the Warp Drive. That is the final challenge I wanted to try: a platform operating entirely on resources from the Shattered Planet asteroid belt, with its labs benefiting from the stronger tachyon signal far from home.

### A few implementation details

The AI involvement was not limited to a few snippets: the agents wrote the Lua, packaging tools and asset generators. I gave them requirements, reviewed the changes, tried the results in game and asked for changes. The building graphics come from Three.js models, and the Warp Drive sounds are synthesized with Python. The [GitHub repository](https://github.com/megaboich/factorio-beyond-the-edge) has the source, generators, tests and development notes if you are interested in how it works.

These are the first public releases, so the balance is something I would like feedback on. Does the research give you a reason to improve the ship, or does it still feel like waiting? Once warp is available, is there still enough reason to care about the platform's production and fuel supply? Compatibility reports with other space mods would be useful too.

### Links

- Mod Portal: [Warp Drive](https://mods.factorio.com/mod/bte-warp-drive) · [Space Lab](https://mods.factorio.com/mod/bte-spacelab)
- Demo videos: [Warp Drive, 3.5 min](https://www.youtube.com/watch?v=FKd6wIzOH2k) · [Space Lab, 1.7 min](https://www.youtube.com/watch?v=JVCqwXjkNm8)
- [Source, full manuals and issues](https://github.com/megaboich/factorio-beyond-the-edge)
- [Forum post](https://forums.factorio.com/viewtopic.php?t=136909)
