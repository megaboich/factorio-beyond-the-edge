// Stargate under assembly, first stage: the floor finished, the support tower frames up, and the lower
// half of the ring set in its trench, with the crane at work. Layers: main and shadow.
import { build } from "../lib/stargate-parts.js";
import stargate from "./stargate.js";

export default {
  ...stargate,
  // The finished gate's preview shows every stage; this one keeps only the vanilla references.
  references: stargate.references.filter((ref) => !ref.model),
  export: "stargate/graphics/entity/assembling/assembling-1",

  build() {
    return build({ state: "stage1" });
  }
};
