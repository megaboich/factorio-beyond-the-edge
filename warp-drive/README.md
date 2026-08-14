# Factorio Warp Drive Mod

Warp Drive is a standalone Factorio: Space Age post-game mod. It adds one platform-only building and two technologies. The experimental drive detects tachyons to accelerate its own final research; the completed drive emulates subspace travel with a speed boost derived from active engine thrust.

![Warp Drive animation](graphics/warp-drive.gif)

*The Warp Drive building uses this exact illustration. See [Asset Attribution](#asset-attribution).*

The mod requires `base >= 2.1.0` and `space-age >= 2.1.0`. SPACELAB is optional.

## Why This Mod Exists

The Shattered Planet route is `4,000,000 km` long. Its rising asteroid density turns the post-game into an open-ended platform-engineering challenge, but eventually progress becomes waiting at a rate the factory cannot improve.

Warp Drive makes distance a production input. Deep space becomes the best place to research a technology that removes the travel plateau. The expedition is still a factory problem: a light, well-powered platform detects more tachyons, reaches warp sooner, and travels faster.

Warp is accelerated travel, not teleportation. Entering subspace starts at Warp-1 and a `10x` effective speed boost. After support power stabilizes, the drive accelerates through approximately one additional warp level every 2 seconds while engine thrust and support power permit. Thrusters, fuel, weight, power, schedules, and route direction all continue to matter. Asteroids vanish in subspace, so speed also cuts off the platform's raw-material supply.

## Design

Warp Drive turns deep-space distance into research output, then turns that research into faster travel. It keeps the challenge factory-driven:

- Research still uses the normal queue, laboratories, and science packs.
- Engine thrust sets the maximum warp level; reaching it takes time and sufficient power.
- Charge scales with platform weight; support power scales with both weight and warp level.
- Asteroids disappear during warp, so sustained travel interrupts asteroid collection.
- Circuits are optional but can automate warp around platform reserves.

The mod adds no laboratories, science packs, particle items, or separate research pool. Exactly one Warp Drive may be installed per platform.

## Subspace And Tachyons

Subspace Tachyon Particles are transient observations, not resources. They cannot be collected, stored, shipped, or crafted into an item. Their signal strengthens with distance travelled toward the outermost destination in a connected route network.

The experimental Warp Drive is first a detector. Its observations provide bonus research through eligible working laboratories. Where that bonus applies depends on whether all required science packs can be produced in space.

Once Practical Warp Drive is researched, the same building becomes an engine. Warp moves the platform through subspace, where ordinary asteroid chunks do not exist. Departure and arrival still occur in normal space, which is why the first and final `1,000 km` remain conventional travel.

## Research

Before Practical Warp Drive is researched, the drive acts as a detector:

- It consumes up to `1 GW` of surplus platform power. Other powered facilities take priority.
- `200 MW` preserves the base detector rate; each additional `200 MW` adds another full power factor, up to `5x` at `1 GW`.
- Partial power scales its research bonus continuously.
- The bonus applies only while you are actively researching Practical Warp Drive.
- Labs consume the technology's normal science packs at their normal rate; tachyons add progress without increasing pack consumption.

### Where Research Happens

Warp Drive automatically checks whether every required science pack can be produced on a space platform. It checks available recipes, not installed mod names.

| Available science production | Labs receiving the bonus |
| --- | --- |
| Every required pack can be produced in space | Working labs on the drive's platform only |
| One or more required packs cannot be produced in space | All of your working labs, wherever they are located |

In an unmodded Space Age game, several required science packs cannot be produced in space. The drive therefore relays its observations to all working laboratories, allowing the detector platform to travel while the laboratory base remains at home. If another mod makes every required pack producible in space, only working laboratories on the drive's own platform receive the bonus.

This avoids a dead end: Agricultural Science Packs spoil long before a platform can carry an imported stockpile deep into the final route. When every pack can be produced in orbit, the expedition instead becomes a self-contained research-platform challenge.

### Tachyon Signal

Signal density rises geometrically with kilometres travelled toward the deepest location in the platform's connected route network. Separate route networks are measured independently.

The route-depth ratio $r$ and tachyon density $D$ are:

```math
r = \operatorname{clamp}\left(
  \frac{\ln\left(\max(d, d_{min}) / d_{min}\right)}
       {\ln\left(d_{max} / d_{min}\right)},
  0, 1
\right)
```

```math
D = 20 \left(\frac{10000}{20}\right)^r
```

Here, $d$ is the distance travelled into the route network, $d_{min}$ is its shortest connection, and $d_{max}$ is the full depth to its outermost destination. $D$ is measured in particles per second.

| Position in vanilla | Kilometres flown | Route depth | Density |
| --- | ---: | ---: | ---: |
| Nauvis | `0` | `0%` | `20 particles/s` |
| Vulcanus, Gleba, or Fulgora | `15,000` | `0%` | `20 particles/s` |
| Aquilo | `45,000` | `20%` | `67 particles/s` |
| Solar System Edge | `145,000` | `40%` | `246 particles/s` |
| Halfway through the final route | `2,145,000` | `88%` | `4,828 particles/s` |
| Shattered Planet | `4,145,000` | `100%` | `10,000 particles/s` |

Platform speed and delivered detector power produce the final research multiplier:

```math
S = 1 + \frac{v}{100}
```

```math
P = \operatorname{clamp}\left(\frac{P_{delivered}}{200\ \mathrm{MW}}, 0, 5\right)
```

```math
B = D S P
```

Here, $v$ is platform speed in km/s, $P_{delivered}$ is delivered detector power, and $B$ is the bonus multiplier added on top of each eligible laboratory's ordinary research. Thus stationary is `1x` speed scaling, `100 km/s` is `2x`, and each additional `100 km/s` adds `1x` with no cap. At maximum density and `100 km/s`, `200 MW` adds approximately `20,000x` bonus research while `1 GW` adds approximately `100,000x`.

For example, without an additional SPACELAB facility bonus, `300,000 km` toward Shattered Planet gives approximately `549 particles/s` of tachyon density. At `50 km/s`, the speed multiplier is `1.5x`; at `500 MW`, the power multiplier is `2.5x`. The resulting effective signal is approximately `2,057 particles/s`, so every eligible laboratory adds about `2,057x` its ordinary rate as bonus research.

## Warp Travel

After Practical Warp Drive is researched:

- Activation costs `500 J` per kilogram of current platform weight.
- The charge buffer accepts up to `200 MW`, stores up to `100 GJ`, and uses surplus power.
- Automatic engagement requires at least `50 km/s`, sufficient charge, active travel, and more than `1,000 km` clearance from both route endpoints.
- Subspace travel always begins at Warp-1, applying a `10x` boost.
- After a brief support-power stabilization interval, the drive gains approximately one warp level every 2 seconds. Each level requires another `50 km/s` of engine speed and `20 W/kg` of support power.
- Warp-10 therefore requires at least `500 km/s`, provides a `100x` boost, and takes approximately 18 seconds to reach from Warp-1 after stabilization.
- Warp level has no scripted maximum; Factorio's platform physics and the increasing power demand provide the limits.
- The drive probes the next fractional level's support demand before accelerating into it.
- Lost engine speed or support power lowers the warp level immediately to the maximum sustainable level. Falling below Warp-1 exits warp.
- Warp removes asteroid chunks while active.
- Warp exits immediately if Warp-1 support power, minimum engine speed, route eligibility, or automatic engagement is lost.
- Every exit starts a 10-second charge and re-entry lockout.
- The first and final `1,000 km` of each connection use conventional travel. Connections no longer than `2,000 km` cannot use warp.

For a `10,000 tonne` platform, activation requires `5 GJ`, charging at the maximum `200 MW` takes 25 seconds, and support demand starts at `200 MW` at Warp-1. The same platform requires `2 GW` at Warp-10.

The exact mass and speed scaling is:

```math
E_{activation} = m \cdot 500\ \mathrm{J/kg}
```

```math
L_{engine} = \frac{v_{engine}}{50\ \mathrm{km/s}}
```

```math
L_{power} = \frac{P_{available}}{m \cdot 20\ \mathrm{W/kg}}
```

```math
L_{target} = \min(L_{engine}, L_{power})
```

```math
B = 10L_{current}
```

```math
P_{support} = m \cdot 20\ \mathrm{W/kg} \cdot L_{requested}
```

```math
v_{subspace} = B \cdot v_{engine}
```

```math
t_{charge} = \frac{E_{activation}}{P_{charge}}
```

Here, $m$ is current platform mass in kilograms, $L_{current}$ is the continuous active warp level, $L_{requested}$ is the next small acceleration step, $B$ is the effective speed boost, $P_{available}$ is measured support power, $P_{charge}$ is available charge power up to `200 MW`, and $v_{engine}$ is the platform's current engine-derived speed. Entry sets $L_{current}=1$. After support power stabilizes, it rises at `0.5 levels/s` toward $L_{target}$ and falls to a lower target immediately. Warp requires delivery of at least 99.9% of Warp-1 demand; neither the level nor boost has a scripted upper limit.

## The Endgame Challenge

Warp relocates the post-game problem rather than removing it. A platform in subspace collects no asteroid chunks and eventually starves if it remains there continuously.

The intended solution is an automated cycle: circuits permit warp while reserves are healthy, disengage when they fall, allow collection in normal space, and re-engage after recovery. The drive imposes no resource thresholds, so each platform defines which reserves matter and how low they may fall.

## Controls

Open the drive to view detector power, route progress, platform speed, tachyon rate, eligible lab count and average rate, research contribution, estimated completion time, charge, current and target warp levels, acceleration state, boost, effective speed, requested and delivered support power, endpoint clearance, cooldown, and engagement settings.

Connect red or green circuit wire near the drive's top-left edge. Circuit engagement requires a positive `E` signal when enabled.

| Output | Value |
| --- | --- |
| `W` | `1` during warp, otherwise `0` |
| `C` | Charge percentage |
| `S` | Effective subspace speed in km/s |
| `P` | Detector power as a percentage of the `200 MW` reference, up to `500` |

## Building And Technologies

The Warp Drive occupies a `6x6` platform footprint and takes 120 seconds to craft from:

- 200 Quantum Processors
- 500 Superconductors
- 1,000 Tungsten Plates
- 500 Carbon Fibers
- 500 Supercapacitors

| Technology | Cost | Unlock |
| --- | --- | --- |
| Theoretical Warp Drive | `10,000` units at 120 seconds each | Experimental detector |
| Practical Warp Drive | `1,000,000,000` units at 120 seconds each | Functional warp travel |

Both technologies use Automation, Logistic, Military, Chemical, Production, Utility, Space, Metallurgic, Electromagnetic, Agricultural, Cryogenic, and Promethium science packs. Practical Warp Drive is intentionally prohibitive without the detector bonus.

## Optional SPACELAB Integration

Warp Drive began as the final chapter of SPACELAB and was split into a standalone mod so subspace research and travel would not require an orbital-industry overhaul. SPACELAB makes platforms self-sufficient; Warp Drive gives them a reason to travel deep into space.

SPACELAB is never required or detected by name. Its orbital science recipes make every required pack producible in space, so the research bonus applies only to working laboratories on the drive's platform. Any mod providing the same capability has the same effect.

## Asset Attribution

The bundled Quantum Stabilizer artwork is by **Hurricane046**. The source post and its Figma resource describe the artwork as free to use; explicit permission has not yet been requested. The creator will be contacted before release.

| Link | Description |
| --- | --- |
| [Hurricane046 on Factorio Mods](https://mods.factorio.com/user/Hurricane046) | Artist profile and published Factorio mods |
| [Original Reddit post](https://www.reddit.com/r/factorio/comments/1g6cnhu/ive_been_learning_how_to_make_custom_factorio/) | Source post introducing the custom building artwork |
| [Factorio Buildings on Figma](https://www.figma.com/proto/y1IQG08ZG2jIeJ5sTyF4MP/Factorio-Buildings) | Showcase of the artist's Factorio building artwork |
