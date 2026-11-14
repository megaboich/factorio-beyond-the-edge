// Stargate under assembly, stage 3 of 6 (the construction site is the first): the picture before it
// with more of the gate in place (lib/stargate-parts.js, STATES). Layers: main and shadow.
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
  export: "stargate/graphics/entity/assembling/assembling-2",

  build() {
    return build({ state: "stage2" });
  }
};
