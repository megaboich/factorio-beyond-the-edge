// Stargate construction kit icon: the ring half built between the towers (models/stargate-stage2.js), seen nearly face-on.
import { build } from "../lib/stargate-parts.js";
import icon from "./stargate-icon.js";

export default {
  ...icon,
  export: "stargate/graphics/icons/construction-kit.png",

  build() {
    return build({ state: "stage2" });
  }
};
