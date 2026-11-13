// Stargate inventory icon: the finished gate seen nearly face-on, so the ring reads as a circle at
// 32-64 px. Same geometry as models/stargate.js (lib/stargate-parts.js).
import { build } from "../lib/stargate-parts.js";

export default {
  type: "icon",
  elevation: 22,
  export: "stargate/graphics/icons/stargate.png",
  references: [
    "space-age/graphics/icons/fulgoran-ruin-attractor.png",
    "space-age/graphics/icons/lightning-collector.png",
    "space-age/graphics/icons/electromagnetic-plant.png"
  ],

  build() {
    return build({ state: "complete" });
  }
};
