// Stargate with its two-track train station: the finished gate with the station track along both
// lanes, in one picture, for previewing. Not exported: in game the track is its own layer
// (models/stargate.js, rails-single and rails-double).
import { build, TRACK_LANES } from "../lib/stargate-parts.js";
import stargate from "./stargate.js";

export default {
  ...stargate,
  // The finished gate's preview shows every stage; this one keeps only the vanilla references.
  references: stargate.references.filter((ref) => !ref.model),
  export: null,

  build() {
    return build({ state: "complete", tracks: TRACK_LANES.double });
  }
};
