// Stargate: a 14x14 modern gate, a segmented steel ring between two support towers, standing in a
// concrete basin. The geometry lives in lib/stargate-parts.js, shared with the construction stages.
// Layers: main and shadow, and glow-lights (status lights, additive).
import { build } from "../lib/stargate-parts.js";

export default {
  tiles: [14, 14],
  height: 10,
  elevation: 50,
  frames: 1,
  export: "stargate/graphics/entity/stargate/stargate",
  // Nauvis grass around the gate in the preview, with the construction stages beside it; render
  // stargate-site, stargate-stage1, and stargate-stage2 before this model.
  // grass-1.png holds sixteen 4x4-tile variants in the row at y = 320.
  ground: { file: "factorio:base/graphics/terrain/grass-1.png", y: 320, size: 256, count: 16 },
  references: [
    { model: "stargate-site", label: "Construction site (first phase)" },
    { model: "stargate-stage1", label: "Second phase" },
    { model: "stargate-stage2", label: "Third phase" },
    {
      label: "Vanilla Fusion Reactor (6x6), for scale",
      tiles: [6, 6],
      layers: [
        { file: "factorio:space-age/graphics/entity/fusion-reactor/fusion-reactor-shadow.png", width: 542, height: 346, shift: [40 / 32, 9.5 / 32], blend: "shadow" },
        { file: "factorio:space-age/graphics/entity/fusion-reactor/fusion-reactor-main.png", width: 444, height: 456, shift: [1 / 32, -5.5 / 32], blend: "normal" },
        { file: "factorio:space-age/graphics/entity/fusion-reactor/fusion-reactor-glow.png", width: 396, height: 428, shift: [1.5 / 32, -11 / 32], blend: "additive" }
      ]
    }
  ],

  build() {
    return build({ state: "complete" });
  }
};
