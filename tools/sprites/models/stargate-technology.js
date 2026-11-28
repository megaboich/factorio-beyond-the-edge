// Stargate technology icon: the full building (lib/stargate-parts.js), seen nearly face-on with its
// portal open, rendered as one 256 px image, the size Factorio expects for technologies. At that
// size the real model's detail reads, so it is used instead of the item icon's simplified stand-in.
import * as THREE from "three";
import { build, drawVeil, RING } from "../lib/stargate-parts.js";
import icon from "./stargate-icon.js";

export default {
  ...icon,
  elevation: 22,
  sizes: [256],
  export: "stargate/graphics/technology/stargate.png",
  references: [
    "space-age/graphics/technology/lightning-collector.png",
    "space-age/graphics/technology/electromagnetic-plant.png",
    "space-age/graphics/technology/quantum-processor.png"
  ],

  async build() {
    const root = await build({ state: "complete" });
    // One still of the in-game veil, drawn self-lit, brighter and opaque, as an icon has no
    // background for an additive glow to light.
    const veil = root.userData.veil;
    drawVeil(root, 0.15);
    // Recolours the in-game veil's ripple pattern (its blue channel is 0.95 of the pattern's
    // brightness) into a brighter cyan palette, white at the crests.
    const ctx = veil.canvas.getContext("2d");
    const image = ctx.getImageData(0, 0, veil.canvas.width, veil.canvas.height);
    const d = image.data;
    for (let i = 0; i < d.length; i += 4) {
      if (!d[i + 3]) continue;
      const v = Math.min(1.3, d[i + 2] / (0.95 * 255) * 1.15);
      const cyan = Math.max(0, (v - 0.25) / 0.7);
      const hot = Math.max(0, (v - 0.8) / 0.5);
      d[i] = Math.min(255, 10 + 40 * cyan + 205 * hot);
      d[i + 1] = Math.min(255, 60 + 165 * cyan + 30 * hot);
      d[i + 2] = Math.min(255, 165 + 90 * Math.min(1, v));
    }
    ctx.putImageData(image, 0, 0);
    veil.texture.needsUpdate = true;
    root.traverse((mesh) => {
      if (mesh.isMesh && mesh.material === veil.material) {
        mesh.material = new THREE.MeshBasicMaterial({
          map: veil.texture, transparent: true,
          depthWrite: false, side: THREE.DoubleSide, toneMapped: false
        });
        mesh.visible = true;
      }
    });
    root.userData.lights.emissiveIntensity = 2.2;
    // The veil's light on the ring and floor.
    const glow = new THREE.PointLight(0x2fd2ff, 14, 14, 1.4);
    glow.position.set(0, RING.cy, 4.2);
    root.add(glow);
    return root;
  }
};
