// Stargate with its train station activated: the finished gate with rails along both lanes. Not
// exported yet; it is previewed until train passage uses it.
import { build } from "../lib/stargate-parts.js";
import stargate from "./stargate.js";

export default {
  ...stargate,
  // The finished gate's preview shows every stage; this one keeps only the vanilla references.
  references: stargate.references.filter((ref) => !ref.model),
  export: null,

  build() {
    return build({ state: "complete", tracks: true });
  }
};
