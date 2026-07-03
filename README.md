# Factorio S.I.O.S. Mod

**S.I.O.S.** stands for **Singularity-Integrated Optimized Synthesis**.

An end-game extension mod for **Factorio: Space Age** that prolongs the endgame with new orbital production, asteroid processing, and biology challenges once the Solar System Edge is behind you.

## Prequel: Beyond the Plateau

Space Age provides a fantastic, tightly-tuned progression through the Solar System. The challenge of the Shattered Planet, the logistics of your first space platforms, and the rush of automating the final science packs are genuine highlights that make the game feel cohesive and rewarding.

However, once you have conquered the unique demands of each planet and established a steady flow of their rare materials to your platform, the gameplay shifts. The "puzzles" that defined your journey — managing heat on Aquilo, dealing with spoilage on Gleba, or energy constraints on Fulgora — are replaced by a static, repetitive loop.

> "The current metagame leaves me feeling hollow, empty. Like in the end nothing really mattered that I achieved." — [numgun, Factorio Forums](https://forums.factorio.com/viewtopic.php?t=58404)

At this point, the tech tree continues to offer upgrades, but they feel meaningless: **productivity of producing science, in service of producing more science.** The factory continues to grow, but the nature of the challenge stops evolving.

S.I.O.S. (Singularity-Integrated Optimized Synthesis) is designed to push past this plateau. It doesn't shorten your journey or skip the planets; it asks you to take the mastery you've gained and synthesize it into new, complex orbital infrastructure. By turning your space platform into a "Grand Unified Factory," S.I.O.S. keeps the challenge of logistics-as-a-puzzle alive long after the planets are secured, ensuring the endgame remains as engaging as the first rocket launch.

## Overview

S.I.O.S. is a high-tier industrial expansion designed for the Space Age endgame. Once you have mastered the distinct challenges of Vulcanus, Fulgora, Gleba, and Aquilo, this mod synthesizes that mastery into a new arena: the ability to bring planetary-tier production into orbit.

By utilizing asteroids as a primary chemical feedstock and mastering orbital-scale biological cultivation, S.I.O.S. transforms your space platform into a Grand Unified Factory, capable of producing every science pack in the game without the need for constant planetary maintenance.

## Design Philosophy

- **Additive & Compatible:** This mod does not replace or overwrite any vanilla recipes. All content is gated behind new, high-tier research, ensuring full compatibility with existing late-game saves.
- **Logistics Mastery:** The mod replaces "planetary dependency" with "orbital complexity." Production chains are energy-intensive and require advanced circuit-logic balancing.
- **Closed-Loop Economy:** By extracting rare chemical inputs from asteroid debris, you turn your platform into a self-sustaining ecosystem.

## Core Features

### New Materials

- **Flurolite (Fluoro-Spodumene):** A rare, trace mineral found as a byproduct of asteroid processing. It is the mandatory precursor for high-tier chemical synthesis.

### Asteroid Feedstock

Not all asteroid chunks are created equal. S.I.O.S. distinguishes between three common feedstock types and one rare one, all processed through the Crusher in increasing order of required tech:

- **Metallic Asteroid:** The most common chunk type, dense with iron and copper ore. New Crusher tech extracts bulk Stone from it directly, with a follow-up tier adding a rare chance at Flurolite.
- **Carbonic Asteroid:** Rich in carbon compounds, these chunks are the platform's primary carbon feedstock. Same two-tier Stone-then-Flurolite Crusher progression as Metallic.
- **Oxide Asteroid:** Ice-bearing chunks that supplement on-platform water production. Same two-tier Stone-then-Flurolite Crusher progression as Metallic.
- **Red Asteroid:** A rare, high-value chunk laced with heavy trace metals, requiring the most advanced Crusher tech. Its "Shattered Synthesis" processing is the single richest source of Holmium and Tungsten outside of Aquilo mining, alongside the best per-chunk Flurolite odds.

These three common types share a two-tier recipe progression:

- **Stone-Focused** (early, cheap tech): maximizes raw Stone recovery alongside the base ore. Useful the moment a platform needs Stone at all, since vanilla asteroid processing never yields it, and it doesn't require unlocking Flurolite tech.
- **Flurolite-Focused** (later tech, gated behind Stone-Focused): trades some of that Stone yield for a trace chance at Flurolite, giving platforms far from a Red Asteroid field an alternate Flurolite pipeline once they need one.

Calcite is left to existing Oxide asteroid processing, which already produces it in ample quantity.

### New Buildings

- **Orbital Bio-Lab:** An advanced facility that allows for the growth of Gleba's two staple crops, **Yumako Fruit** and **Jellynut**, and the incubation of Biter/Pentapod eggs in orbit.

### Existing Building Integration

- **Crusher:** Now processes Metallic, Carbonic, and Oxide asteroid chunks, each with a Stone-Focused and a Flurolite-Focused recipe variant, before Red Asteroid shattering ("Shattered Synthesis") unlocks as the top tier.
- **Cryogenic Plant:** Handles ammonia extraction, lithium-focused condensation, and fluorine-focused condensation without introducing additional dedicated processing buildings.

## Recipe Inventory

### Crusher: Asteroid Processing

| Recipe | Time | Inputs | Outputs | Notes |
| --- | --- | --- | --- | --- |
| Metallic Crushing (Stone-Focused) | 2s | 1 Metallic Asteroid | 1 Iron Ore, 1 Copper Ore, 4 Stone | Early, cheap tech; the only way to get bulk Stone out of a Metallic chunk without touching Flurolite research. |
| Carbonic Crushing (Stone-Focused) | 2s | 1 Carbonic Asteroid | 2 Carbon, 4 Stone | Primary orbital Carbon source; pairs well with Ammonia Extraction's Stone demand. |
| Oxide Crushing (Stone-Focused) | 2s | 1 Oxide Asteroid | 2 Ice, 4 Stone | Supplements platform ice supply while giving the best Stone-per-chunk of the three common types. |
| Metallic Crushing (Flurolite-Focused) | 3s | 1 Metallic Asteroid | 1 Iron Ore, 1 Copper Ore, 2 Stone, 5% Flurolite | Later tech, gated behind Stone-Focused; trades half the Stone yield for a Flurolite chance once you actually need one. |
| Carbonic Crushing (Flurolite-Focused) | 3s | 1 Carbonic Asteroid | 2 Carbon, 2 Stone, 5% Flurolite | Same Carbon yield, lower Stone, adds a Flurolite roll. |
| Oxide Crushing (Flurolite-Focused) | 3s | 1 Oxide Asteroid | 2 Ice, 2 Stone, 5% Flurolite | Same Ice yield, lower Stone, adds a Flurolite roll. Calcite is left to the existing (non-Flurolite) Oxide processing recipe. |
| Shattered Synthesis | 4s | 1 Red Asteroid | 1 Holmium, 1 Tungsten, 2 Stone, 5% Flurolite | Most advanced Crusher tech; still the single richest per-chunk Flurolite chance in the game. |

### Cryogenic Plant

| Recipe | Time | Inputs | Outputs | Notes |
| --- | --- | --- | --- | --- |
| Ammonia Extraction | 5s | 5 Stone, 1 Water | 10 Ammonia Gas | Consumes the Stone surplus generated by asteroid crushing; no dedicated building needed. |
| Lithium-Focused | 10s | 1 Flurolite, Power | 40 Lithium Brine, 10 Fluorine Gas | Same inputs as Fluorine-Focused; pick per-recipe based on which byproduct your chain is short on. |
| Fluorine-Focused | 10s | 1 Flurolite, Power | 10 Lithium Brine, 40 Fluorine Gas | Mirror recipe of Lithium-Focused; run both in parallel to balance brine vs. gas demand. |

### Orbital Bio-Lab

| Recipe | Time | Inputs | Outputs | Notes |
| --- | --- | --- | --- | --- |
| Yumako Cultivation | 60s | Nutrient Paste, Water | 2 Yumako Fruit (Spoilage enabled) | Mirrors the Gleba surface growth cycle; feed into Yumako Mash processing same as on-planet. |
| Jellynut Cultivation | 60s | Nutrient Paste, Water | 2 Jellynut (Spoilage enabled) | Grown alongside Yumako so the platform can produce both halves of the Bioflux/Nutrients chain without importing either crop. |
| Egg Incubation | 120s | Nutrient Paste, Heat | 1 Biter/Pentapod Egg | Long incubation reflects the difficulty of maintaining a stable low-gravity nest environment. |

## Scientific Justification

- **Ammonia from Stone:** Carbonaceous asteroids contain nitrogen-bearing phyllosilicates. A Cryogenic Plant uses high-pressure and heat processing to extract ammonia directly from stone.
- **Stone from Crushing:** Vanilla asteroid processing never yields Stone, but mechanical shattering of any silicate or metallic body inherently produces mineral rubble regardless of composition. The Stone-Focused Crusher variants isolate that rubble without the finer sieving needed to detect Flurolite traces, which is why they're the cheaper, earlier-tech option.
- **Flurolite Chemistry:** Lithium and fluorine are geochemically linked in evolved crustal granites. Flurolite represents the trace rare-earth inclusions found within shattered planetary crusts, processed through cryogenic plant distillation. Red Asteroids carry the richest concentration, but trace inclusions also turn up in ordinary Metallic, Carbonic, and Oxide chunks; finding them requires the finer sieving of the higher-tier Flurolite-Focused Crusher variants, at the cost of some Stone throughput. Calcite recovery is left untouched on the existing Oxide processing recipe, which already yields it in ample quantity.
- **Orbital Bio-Lab:** Rather than "stabilizing" life, the Bio-Lab provides the precise environmental parameters, including heat, light, and nutrients, required to maintain planetary species in a low-gravity environment while keeping the high-stakes spoilage mechanics of Space Age intact. Yumako and Jellynut are cultivated as a matched pair, exactly as they grow together on Gleba, so the platform's Bioflux and Nutrients chains stay self-sufficient.

## The Endgame Challenge

S.I.O.S. is not a "shortcut" past the post-game plateau — it's a replacement for it. Success requires balancing your energy grid to support 500MW+ synthesis machines and using circuit networks to optimize chemical yields, the same logistics-as-a-puzzle mastery the planets demanded, now applied in orbit.

It is the next milestone for the factory that must grow.
