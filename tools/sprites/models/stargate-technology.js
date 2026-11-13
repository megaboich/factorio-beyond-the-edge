// Stargate technology icon: the finished gate rendered as one 256 px image, the size Factorio
// expects for technologies.
import icon from "./stargate-icon.js";

export default {
  ...icon,
  sizes: [256],
  export: "stargate/graphics/technology/stargate.png",
  references: [
    "space-age/graphics/technology/lightning-collector.png",
    "space-age/graphics/technology/electromagnetic-plant.png",
    "space-age/graphics/technology/quantum-processor.png"
  ]
};
