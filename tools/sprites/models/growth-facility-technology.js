// Growth Facility technology icon: the simplified icon model rendered as one 256 px image, the
// size Factorio expects for technologies.
import icon from "./growth-facility-icon.js";

export default {
  ...icon,
  sizes: [256],
  export: "spacelab/graphics/technology/growth-facility.png",
  references: [
    "space-age/graphics/technology/biochamber.png",
    "space-age/graphics/technology/cryogenic-plant.png",
    "space-age/graphics/technology/biolab.png"
  ]
};
