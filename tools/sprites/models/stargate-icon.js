// Stargate inventory icon: a simplified stand-in for the building, like the Growth Facility and Warp
// Drive icons, since the full model's capacitor cans, fans, and grilles turn to noise at 32-64 px.
// A chunky segmented ring with bright clamp lights and an open, glowing veil, between two plain
// towers on a concrete deck with a hazard rim. Units are tiles; x east, y up, z south.
import * as THREE from "three";

const TAU = Math.PI * 2;
const DECK = 0.5;
const CY = 4.4; // ring centre height
const INNER = 3.3;
const OUTER = 4.5;
const DEPTH = 1.1;
const CLAMPS = 9;

/** One still of the open veil: concentric blue ripples brightening to a white-cyan core and rim. */
function veilTexture() {
  const size = 256;
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = size;
  const ctx = canvas.getContext("2d");
  const image = ctx.createImageData(size, size);
  for (let py = 0; py < size; py++) {
    for (let px = 0; px < size; px++) {
      const x = (px + 0.5) / size * 2 - 1, y = (py + 0.5) / size * 2 - 1;
      const r = Math.hypot(x, y);
      if (r > 1) continue;
      const a = Math.atan2(y, x);
      // Three broad ripples, slightly swirled, so they still read at 32 px.
      let v = 0.35 + 0.35 * r ** 2;
      v += 0.2 * (0.5 + 0.5 * Math.cos((r * 3 + 0.04 * Math.sin(3 * a)) * TAU)) * (1 - r * 0.4);
      v += 0.6 * Math.exp(-r * r * 16);
      v += 0.4 * Math.exp(-(((1 - r) / 0.08) ** 2));
      v = Math.min(1.3, v);
      const hot = Math.max(0, (v - 0.75) / 0.55);
      const cyan = Math.max(0, (v - 0.3) / 0.7);
      const i = (py * size + px) * 4;
      image.data[i] = Math.min(255, 20 + 40 * cyan + 200 * hot);
      image.data[i + 1] = Math.min(255, 70 + 160 * cyan + 30 * hot);
      image.data[i + 2] = Math.min(255, 190 + 65 * Math.min(1, v));
      image.data[i + 3] = 255;
    }
  }
  ctx.putImageData(image, 0, 0);
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  return texture;
}

export default {
  type: "icon",
  // Nearly face-on, so the ring reads as a circle.
  elevation: 26,
  export: "stargate/graphics/icons/stargate.png",
  references: [
    "space-age/graphics/icons/fulgoran-ruin-attractor.png",
    "space-age/graphics/icons/lightning-collector.png",
    "space-age/graphics/icons/electromagnetic-plant.png"
  ],

  build() {
    const root = new THREE.Group();
    const material = (color, roughness = 0.5, metalness = 0.5, extra = {}) =>
      new THREE.MeshStandardMaterial({ color, roughness, metalness, ...extra });
    const deck = material(0x55534f, 0.8, 0.1);
    const steel = material(0x8a929b, 0.4, 0.7);
    const dark = material(0x2a2d32, 0.55, 0.6);
    const panel = material(0x40454c, 0.6, 0.5);
    const trim = material(0xd0d5da, 0.3, 0.8);
    const hazard = material(0xd9a423, 0.5, 0.3);
    const lamp = material(0x0c2b33, 0.4, 0, { emissive: 0x2fd2ff, emissiveIntensity: 2.6 });
    const add = (geometry, mat, position = [0, 0, 0], rotation = [0, 0, 0]) => {
      const mesh = new THREE.Mesh(geometry, mat);
      mesh.position.set(...position);
      mesh.rotation.set(...rotation);
      root.add(mesh);
      return mesh;
    };
    const sector = (r0, r1, a0, a1, depth) => {
      const shape = new THREE.Shape();
      shape.absarc(0, 0, r1, a0, a1, false);
      shape.absarc(0, 0, r0, a1, a0, true);
      const geometry = new THREE.ExtrudeGeometry(shape, { depth, bevelEnabled: false, curveSegments: 8 });
      geometry.translate(0, 0, -depth / 2);
      return geometry;
    };

    // Deck with a hazard rim.
    add(new THREE.BoxGeometry(11, DECK, 5), deck, [0, DECK / 2, 0]);
    add(new THREE.BoxGeometry(11.08, 0.1, 5.08), hazard, [0, DECK - 0.12, 0]);

    // Towers either side: a dark body framed by light trim on every vertical edge and the cap, a
    // recessed front panel with grille slats, and light bars, so their outline reads at 32 px.
    for (const side of [-1, 1]) {
      const x = side * 4.9, h = 6.2, w = 1.6, d = 2.4;
      add(new THREE.BoxGeometry(w, h, d), dark, [x, DECK + h / 2, 0]);
      for (const dx of [-1, 1]) for (const dz of [-1, 1]) {
        add(new THREE.BoxGeometry(0.16, h, 0.16), trim, [x + dx * (w / 2 - 0.06), DECK + h / 2, dz * (d / 2 - 0.06)]);
      }
      add(new THREE.BoxGeometry(w + 0.2, 0.35, d + 0.2), steel, [x, DECK + h + 0.17, 0]);
      add(new THREE.BoxGeometry(w + 0.24, 0.06, d + 0.24), trim, [x, DECK + h + 0.36, 0]);
      add(new THREE.BoxGeometry(w - 0.4, h - 1.2, 0.05), panel, [x, DECK + h / 2, d / 2 + 0.01]);
      for (let y = DECK + 2.3; y < DECK + 4.6; y += 0.35) {
        add(new THREE.BoxGeometry(w - 0.6, 0.1, 0.05), steel, [x, y, d / 2 + 0.04]);
      }
      add(new THREE.BoxGeometry(1.0, 0.18, 0.05), lamp, [x, DECK + 5.3, d / 2 + 0.05]);
      add(new THREE.BoxGeometry(1.0, 0.18, 0.05), lamp, [x, DECK + 1.4, d / 2 + 0.05]);
    }

    // The ring: light steel segments over a dark core, with dark gaps, a bright bevel along the
    // outer edge, an inner emitter line, and lit clamps.
    const segments = 18, step = TAU / segments;
    for (let i = 0; i < segments; i++) {
      const a0 = i * step + 0.03, a1 = (i + 1) * step - 0.03;
      add(sector(INNER + 0.5, OUTER, a0, a1, DEPTH), steel, [0, CY, 0]);
      add(sector(INNER + 0.7, OUTER - 0.25, a0 + 0.03, a1 - 0.03, 0.05), panel, [0, CY, DEPTH / 2 + 0.01]);
      add(sector(INNER, INNER + 0.5, a0, a1, DEPTH * 0.85), dark, [0, CY, 0]);
    }
    add(sector(OUTER - 0.09, OUTER + 0.03, 0, TAU, DEPTH + 0.06), trim, [0, CY, 0]);
    add(sector(INNER + 0.46, INNER + 0.54, 0, TAU, DEPTH + 0.04), trim, [0, CY, 0]);
    add(sector(INNER + 0.02, INNER + 0.14, 0, TAU, DEPTH * 0.9 + 0.04), lamp, [0, CY, 0]);
    for (let i = 0; i < CLAMPS; i++) {
      const a = Math.PI / 2 + i * TAU / CLAMPS;
      const group = new THREE.Group();
      group.position.set(Math.cos(a) * (OUTER - 0.05), CY + Math.sin(a) * (OUTER - 0.05), 0);
      group.rotation.z = a - Math.PI / 2;
      root.add(group);
      const clamp = new THREE.Mesh(new THREE.BoxGeometry(0.75, 0.45, DEPTH + 0.2), trim);
      clamp.position.y = 0.1;
      group.add(clamp);
      const light = new THREE.Mesh(new THREE.BoxGeometry(0.45, 0.14, 0.05), lamp);
      light.position.set(0, 0.05, (DEPTH + 0.2) / 2 + 0.02);
      group.add(light);
    }

    // The open veil, self-lit and opaque, with its light on the ring and deck.
    add(new THREE.CircleGeometry(INNER + 0.02, 96),
      new THREE.MeshBasicMaterial({ map: veilTexture(), toneMapped: false }), [0, CY, 0.05]);
    const glow = new THREE.PointLight(0x2fd2ff, 18, 10, 1.4);
    glow.position.set(0, CY, 1.6);
    root.add(glow);
    return root;
  }
};
