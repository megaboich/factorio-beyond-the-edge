// Stargate construction kit icon: the lower half of the ring between the tower frames (models/stargate-stage1.js), seen nearly face-on.
import { build } from "../lib/stargate-parts.js";
import icon from "./stargate-icon.js";

export default {
  ...icon,
  export: "stargate/graphics/icons/construction-kit.png",

  build() {
    return build({ state: "stage1" });
  }
};
