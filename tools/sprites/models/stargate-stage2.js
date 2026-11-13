// Stargate under assembly, second stage: the towers clad, the lane bridges in, and the ring all but
// its top, with scaffolding at the gap. Layers: main and shadow.
import { build } from "../lib/stargate-parts.js";
import stargate from "./stargate.js";

export default {
  ...stargate,
  // The finished gate's preview shows every stage; this one keeps only the vanilla references.
  references: stargate.references.filter((ref) => !ref.model),
  export: "stargate/graphics/entity/assembling/assembling-2",

  build() {
    return build({ state: "stage2" });
  }
};
