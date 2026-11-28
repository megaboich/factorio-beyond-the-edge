// Stargate construction site, the first of six stages: the finished floor, the control cabinet, the
// front east capacitor rack, and the bottom of the ring, inside hazard tape. Layers: main and shadow.
// The stages that follow (stargate-stage1.js to stargate-stage5.js) and the finished gate (stargate.js)
// share its footprint and geometry (lib/stargate-parts.js).
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
  export: "stargate/graphics/entity/construction-site/construction-site",

  build() {
    return build({ state: "site" });
  }
};
