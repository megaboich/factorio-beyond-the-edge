// The gate on the map, open, with its veil: the inventory icon's model at one larger size, drawn over the
// gate's footprint by scripts/gate.lua.
import icon, { buildIcon } from "./stargate-icon.js";

export default {
  ...icon,
  sizes: [256],
  export: "stargate/graphics/map/stargate-map-open.png",
  build: () => buildIcon({ veil: true })
};
