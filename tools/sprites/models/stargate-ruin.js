// Stargate remnants: what a destroyed gate, site, or gate under assembly leaves (lib/stargate-parts.js,
// ruin()). Layers: main and shadow.
import { build } from "../lib/stargate-parts.js";
import stargate from "./stargate.js";

export default {
  ...stargate,
  // The finished gate's preview shows every stage; this one keeps only the vanilla references.
  references: stargate.references.filter((ref) => !ref.model),
  // Only main and shadow: no lights, veil, or sounds before the gate is finished.
  layers: [],
  variants: [],
  sounds: null,
  loop: 1,
  setVariant() {},
  animate() {},
  export: "stargate/graphics/entity/remnants/remnants",

  build() {
    return build({ state: "ruin" });
  }
};
