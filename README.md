# Factorio SPACELAB Mod

**SPACELAB** stands for **Space Platform Asteroid Complete Extraction: Laboratories with Advanced Biotech**.

An end-game extension mod for **Factorio: Space Age** that prolongs the endgame with complete asteroid extraction, orbital laboratories, and advanced biotech challenges once the Solar System Edge is behind you.

## Prequel: Beyond the Plateau

Space Age already delivers a complete arc, from first orbital logistics to the Solar System Edge. SPACELAB starts after that arc, where the factory can keep expanding into a new kind of goal instead of only repeating its final optimization loop.

The main motivation is the point where upgrades risk becoming **meaningless: productivity of producing science, in service of producing more science.** SPACELAB turns that momentum toward alternative possibilities: asteroid-based chemistry, orbital biological systems, and a space platform that becomes a new production frontier rather than only a launch destination.

## Overview

SPACELAB is a high-tier industrial expansion for building a self-sufficient orbital industry. It uses asteroid debris as broad chemical feedstock and adds advanced Bio-Lab recipes so space platforms can support complex material, agricultural, and biological chains.

Instead of replacing the existing journey, SPACELAB extends it with future-facing infrastructure: complete asteroid extraction, high-energy synthesis, orbital cultivation, and closed-loop production that gives late-game factories new systems to design, balance, and scale.

## Design Philosophy

- **Additive & Compatible:** This mod does not replace or overwrite any vanilla recipes. All content is gated behind new, high-tier research, ensuring full compatibility with existing late-game saves.
- **Logistics Mastery:** The mod replaces "planetary dependency" with "orbital complexity." Production chains are energy-intensive and require advanced circuit-logic balancing.
- **Closed-Loop Economy:** By extracting rare chemical inputs from asteroid debris, you turn your platform into a self-sustaining ecosystem.

## Core Features

### New Materials

- **Flurolite (Fluoro-Spodumene):** A rare, trace mineral found as a byproduct of asteroid processing. It is the mandatory precursor for high-tier chemical synthesis.

### Asteroid Feedstock

Not all asteroid chunks are created equal. SPACELAB distinguishes between three common feedstock types and one rare one, all processed through the Crusher in increasing order of required tech:

- **Metallic Asteroid:** The most common chunk type, dense with iron and copper ore. New Crusher tech extracts bulk Stone from it directly, with a follow-up tier adding a rare chance at Flurolite.
- **Carbonic Asteroid:** Rich in carbon compounds, these chunks are the platform's primary carbon feedstock. Same two-tier Stone-then-Flurolite Crusher progression as Metallic.
- **Oxide Asteroid:** Ice-bearing chunks that supplement on-platform water production. Same two-tier Stone-then-Flurolite Crusher progression as Metallic.
- **Red Asteroid:** A rare, high-value chunk laced with heavy trace metals, requiring the most advanced Crusher tech. Its "Shattered Synthesis" processing is the single richest source of Holmium and Tungsten outside of Aquilo mining, alongside the best per-chunk Flurolite odds.

These three common types share a two-tier recipe progression:

- **Stone-Focused** (early, cheap tech): maximizes raw Stone recovery alongside the base ore. Useful the moment a platform needs Stone at all, since vanilla asteroid processing never yields it, and it doesn't require unlocking Flurolite tech.
- **Flurolite-Focused** (later tech, gated behind Stone-Focused): trades some of that Stone yield for a trace chance at Flurolite, giving platforms far from a Red Asteroid field an alternate Flurolite pipeline once they need one.

Calcite is left to existing Oxide asteroid processing, which already produces it in ample quantity.

### New Buildings

- **Orbital Bio-Lab:** An advanced facility that allows for the growth of Gleba's two staple crops, **Yumako Fruit** and **Jellynut**, and separate incubation of Biter and Pentapod eggs in orbit, using high-energy water hydrolysis to supply oxygen for sealed growth chambers.

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
| Yumako Cultivation | 60s | Nutrient Paste, Water, High Energy, Nitrogen, Calcite, Carbon, 1 Yumako Seed | 10 Yumako Fruit | Mirrors the Gleba surface growth cycle; seed stock, oxygen from hydrolyzed water, and mineral/gas conditioning keep orbital cultivation tied to a maintained biological loop. |
| Jellynut Cultivation | 60s | Nutrient Paste, Water, High Energy, Nitrogen, Calcite, Carbon, 1 Jellynut Seed | 10 Jellynut | Grown alongside Yumako so the platform can produce both halves of the Bioflux/Nutrients chain without importing either crop. |
| Biter Egg Incubation | 120s | Nutrient Paste, Bioflux, Water, Heat, High Energy, Nitrogen, Calcite, Carbon, 1 Biter Egg | 10 Biter Eggs | Long incubation reflects the difficulty of maintaining a stable oxygenated low-gravity nest environment for a terrestrial nest organism. |
| Pentapod Egg Incubation | 120s | Nutrient Paste, Bioflux, Water, Heat, High Energy, Nitrogen, Calcite, Carbon, 1 Pentapod Egg | 10 Pentapod Eggs | Separate incubation keeps Gleba-native egg biology distinct from Biter egg handling while preserving the same orbital support requirements. |

## Scientific Justification

- **Ammonia from Stone:** Carbonaceous asteroids contain nitrogen-bearing phyllosilicates. A Cryogenic Plant uses high-pressure and heat processing to extract ammonia directly from stone.
- **Stone from Crushing:** Vanilla asteroid processing never yields Stone, but mechanical shattering of any silicate or metallic body inherently produces mineral rubble regardless of composition. The Stone-Focused Crusher variants isolate that rubble without the finer sieving needed to detect Flurolite traces, which is why they're the cheaper, earlier-tech option.
- **Flurolite Chemistry:** Lithium and fluorine are geochemically linked in evolved crustal granites. Flurolite represents the trace rare-earth inclusions found within shattered planetary crusts, processed through cryogenic plant distillation. Red Asteroids carry the richest concentration, but trace inclusions also turn up in ordinary Metallic, Carbonic, and Oxide chunks; finding them requires the finer sieving of the higher-tier Flurolite-Focused Crusher variants, at the cost of some Stone throughput. Calcite recovery is left untouched on the existing Oxide processing recipe, which already yields it in ample quantity.
- **Orbital Bio-Lab:** Rather than "stabilizing" life, the Bio-Lab provides the precise environmental parameters, including heat, light, nutrients, Bioflux enrichment, nitrogen atmosphere, calcite buffering, carbon feedstock, and high-energy water hydrolysis for oxygen supply, required to maintain planetary species in a low-gravity environment while keeping the high-stakes spoilage mechanics of Space Age intact. Yumako and Jellynut are cultivated from their corresponding seeds as a matched pair, exactly as they grow together on Gleba, while Biter and Pentapod eggs require separate incubation recipes so the platform's Bioflux, Nutrients, and egg chains stay self-sufficient.

## The Endgame Challenge

SPACELAB is not a "shortcut" past the post-game plateau — it's a replacement for it. Success requires balancing your energy grid to support 500MW+ synthesis machines, complete asteroid extraction, and advanced biotech loops while using circuit networks to optimize chemical yields, the same logistics-as-a-puzzle mastery the planets demanded, now applied in orbit.

It is the next milestone for the factory that must grow.
