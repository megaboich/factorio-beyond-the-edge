// Stargate construction site, the first of six stages: the finished floor, the control cabinet, the
// front east capacitor rack, and the bottom of the ring, inside hazard tape. Layers: main and shadow.
// The stages that follow (stargate-stage1.js to stargate-stage5.js) and the finished gate (stargate.js)
// share its footprint and geometry (lib/stargate-parts.js).
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
  export: "stargate/graphics/entity/construction-site/construction-site",

  build() {
    return build({ state: "site" });
  }
};
