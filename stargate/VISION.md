# Beyond the Edge: Stargate — vision

**Build an experiment. Take an uncertain first step. Turn it into a railway between worlds.**

Stargate is a standalone transport mod for Factorio: Space Age. It starts with an engineer-built experiment rather than a guarded ancient ruin, then grows into dependable paired gates and interplanetary train logistics.

> Only construction is implemented so far (see the [manual](README.md)); the rest is planning. The implementation roadmap and unresolved choices live in [PLAN.md](PLAN.md). Stargate requires Factorio and Space Age, not Mechanoids, Warp Drive, Space Lab, or Homecoming Journey.

## 1. Build the first experiment

Basic experimental gate research unlocks an **experimental gate kit**. Placing the kit establishes an unfinished construction site, similar in purpose to restoring a ruin: the player delivers substantial quantities of materials to complete a machine that cannot simply be placed fully operational from one cheap item.

The standalone introduction should be substantially easier to obtain than the former endgame campaign. Exact prerequisites, materials, power, and construction stages need playtesting. Neither ancient artifacts nor a journey to the Solar System Edge should be necessary just to try a gate.

## 2. Make an uncontrolled jump

The first experiment cannot select a destination. It sends the engineer to a **random planet**, into an **unexplored chunk**, a relatively long but still walkable distance from already explored places on that planet.

This should feel like an expedition, not a random death sentence. The player must be told what supplies and risks to expect. Landing on solid ground is not enough: there must be a practical route to a known area, and the experiment needs a recovery policy if no suitable destination exists.

The successful jump completes the experiment and makes the next research available. Exactly which planets qualify, how to handle planets with no explored area, and how emergency return works remain design questions—not settled promises of unrestricted planet discovery.

## 3. Learn to choose the destination

**Controllable Stargate Jumps** follows the successful experiment. Controlled travel requires a **second gate at the far end**, with a clear mechanism for pairing the two endpoints.

The player must get the second kit and its construction materials to the destination and establish the gate there. Ordinary rockets, platforms, and local logistics remain useful: a new destination cannot be created merely by clicking its planet name.

Once both gates are complete, paired, and ready, the connection becomes dependable personal transport. The engineer keeps their existing character, equipment, and carried inventory. Clear status messages explain an unpowered gate, a blocked arrival, or a broken pairing.

Pairing should be understandable and recoverable. Damage or a mistaken configuration must not silently send someone elsewhere. Whether an endpoint can retain multiple pairings is a later design choice; the first useful version needs only one explicit partner.

## 4. Put trains through the gates

A further research unlocks **train passage**. Rail upgrades turn a working pair into a connection between planetary railways, carrying bulk materials, fluids, components, and science packs.

The challenge becomes familiar factory engineering: prepare loading and receiving stations, keep exits clear, supply power, and avoid moving the bottleneck to the other planet. Gates complement conventional space transport rather than making every other logistics system obsolete.

Train passage is a later implementation stage, but part of the complete standalone mod. It has a practical payoff even without a campaign: better-connected production, faster deliveries, and new factory layouts. It does not need a final victory condition to be worth building.

## 5. A useful machine, with or without the story

Standalone Stargate has no intergration with other mods in the family. Its purpose is player-built transportation and the industrial possibilities it creates.

[Homecoming Journey](../homecoming-journey/VISION.md) uses these same construction and transport systems for an ancient network and a larger expedition. That separate campaign owns the story, progression restrictions, enormous research effort, and final gate in deep space.
