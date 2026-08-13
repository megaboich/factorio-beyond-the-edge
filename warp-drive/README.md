# Factorio Warp Drive Mod

Warp Drive is a standalone Factorio: Space Age post-game mod. It adds one platform-only building and two ordinary technologies: Theoretical Warp Drive unlocks the experimental building, and Practical Warp Drive converts it into a functional subspace drive.

## Implemented Mechanics

- Exactly one Warp Drive may be installed on each space platform.
- Before Practical Warp Drive completes, the experimental drive consumes up to `200 MW` of surplus platform power as a tachyon detector. Normal powered facilities take priority, and the detector scales down when no excess generation remains. It does not create or fill its hidden warp-charge buffer in this phase.
- A powered detector accelerates Practical Warp Drive research from working laboratories on the same platform. The dialog reports actual delivered power; partial detector power proportionally reduces the bonus without showing Factorio's binary no-power warning.
- Location multipliers are `10x` while stopped in orbit and rise from `100x` to `1,000x` while traveling; the final portion of the Solar System Edge to Shattered Planet route rises toward `5,000x`.
- Research remains in Factorio's ordinary queue. Labs continue consuming the technology's actual science packs at their ordinary working rate; tachyons add bonus progress only for eligible platform labs.
- After Practical Warp Drive completes, automatic engagement charges the drive and activates warp when the platform is traveling at speed `50` or faster and is more than `1,000 km` from either endpoint.
- Activation costs `500 J` per kilogram of current platform weight. A hidden charge buffer accepts up to `200 MW` and stores up to `100 GJ`; the visible drive is a continuously animated composite structure with no native machine or electrical UI.
- Warp adds `99x` scripted movement to normal engine movement for `100x` effective travel speed.
- Active warp requires `20 W` per kilogram, removes asteroid chunks, and exits immediately if support power, speed, route eligibility, or automatic engagement is lost.
- Every exit starts a 10-second charging and re-entry lockout. The first and final `1,000 km` of each connection remain conventional travel.
- Open the drive to inspect detector power, tachyon rate, working labs, bonus research rate, and research progress. After Practical Warp Drive completes, the dialog also shows warp readiness, charge, speed, endpoint clearance, support demand, lockout, and engagement controls.
- Connect red or green circuit wire near the top-left edge of the drive without opening its dialog. Optional circuit control requires a positive `E` signal before automatic engagement; outputs are `W` for active warp, `C` for charge percentage, `S` for effective speed, and `P` for detector power percentage.

The first release is an experimental runtime proof. Platform speed-to-distance conversion and direct route-distance updates require in-game validation before the travel balance should be considered final.

The Warp Drive occupies a `6x6` platform footprint.

## Recipe

The Warp Drive takes 120 seconds to craft from 200 Quantum Processors, 500 Superconductors, 1,000 Tungsten Plates, 500 Carbon Fibers, and 500 Supercapacitors.

## Technologies

- Theoretical Warp Drive costs 10,000 units at 120 seconds each.
- Practical Warp Drive costs 1,000,000,000 units at 120 seconds each.
- Both use Automation, Logistic, Military, Chemical, Production, Utility, Space, Metallurgic, Electromagnetic, Agricultural, Cryogenic, and Promethium science packs.

## Optional SPACELAB Integration

SPACELAB is optional and does not currently alter Warp Drive behavior. Growth Facility amplification remains disabled pending standalone research-bonus validation.

## Asset Attribution

The bundled Quantum Stabilizer artwork is attributed to **Hurricane046**: <https://mods.factorio.com/user/Hurricane046>.

Source/reference post supplied for the artwork: <https://www.reddit.com/r/factorio/comments/1g6cnhu/ive_been_learning_how_to_make_custom_factorio/>.

The artwork is redistributed with permission from its creator.
