// Stargate construction site: the bare start. The basin and the trench under the ring dug in raw
// concrete with formwork, stacked steel, and a crane mast. Layers: main and shadow.
// The stages that follow (stargate-stage1.js, stargate-stage2.js) and the finished gate (stargate.js)
// share its footprint and geometry (lib/stargate-parts.js).
import { build } from "../lib/stargate-parts.js";
import stargate from "./stargate.js";

export default {
  ...stargate,
  // The finished gate's preview shows every stage; this one keeps only the vanilla references.
  references: stargate.references.filter((ref) => !ref.model),
  export: "stargate/graphics/entity/construction-site/construction-site",

  build() {
    return build({ state: "site" });
  }
};
