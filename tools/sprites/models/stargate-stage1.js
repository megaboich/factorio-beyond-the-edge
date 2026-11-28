// Stargate under assembly, stage 2 of 6 (the construction site is the first): the picture before it
// with more of the gate in place (lib/stargate-parts.js, STATES). Layers: main and shadow.
import { build } from "../lib/stargate-parts.js";
import { FROZEN_LAYER, frozenVariant } from "../lib/frost.js";
import stargate from "./stargate.js";

export default {
  ...stargate,
  // The finished gate's preview shows every stage; this one keeps only the vanilla references.
  references: stargate.references.filter((ref) => !ref.model),
  // Main and shadow, and the frozen picture (lib/frost.js) shown while unheated on Aquilo: no lights,
  // veil, or sounds before the gate is finished.
  layers: [FROZEN_LAYER],
  variants: [],
  sounds: null,
  loop: 1,
  setVariant: frozenVariant,
  animate() {},
  export: "stargate/graphics/entity/assembling/assembling-1",

  build() {
    return build({ state: "stage1" });
  }
};
