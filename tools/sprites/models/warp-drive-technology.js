// Warp Drive technology icon: the simplified icon model rendered as one 256 px image, the size
// Factorio expects for technologies.
import icon from "./warp-drive-icon.js";

export default {
  ...icon,
  sizes: [256],
  export: "warp-drive/graphics/technology/warp-drive.png",
  references: [
    "space-age/graphics/technology/fusion-reactor.png",
    "space-age/graphics/technology/space-platform-thruster.png",
    "base/graphics/technology/nuclear-power.png"
  ]
};
