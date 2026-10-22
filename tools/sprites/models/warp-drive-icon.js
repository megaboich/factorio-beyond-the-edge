// Warp Drive inventory icon: a simplified stand-in for the building, since the full model's ribs,
// rings, and conduits turn to noise at 32–64 px. The same core column in its warp state: a glowing
// blue-violet core inside a ring stack and six ribs between two caps, on a square deck with four
// corner projectors linked by glowing conduits. Units are tiles; x east, y up, z south.
import * as THREE from "three";

const TAU = Math.PI * 2;
const DECK = 0.5;
const CAP = 1.7; // top of the lower cap
const TUBE_TOP = 6.4;
const TOP = 7.4; // top of the upper cap
const RADIUS = 1.6;
const PROJECTOR = 3.3;

export default {
  type: "icon",
  // Lower than the building's 50°, like vanilla icons, so the column reads tall.
  elevation: 28,
  export: "warp-drive/graphics/icons/warp-drive.png",
  references: [
    "space-age/graphics/icons/fusion-reactor.png",
    "space-age/graphics/icons/thruster.png",
    "base/graphics/icons/nuclear-reactor.png"
  ],

  build() {
    const root = new THREE.Group();
    const material = (color, roughness = 0.5, metalness = 0.5, extra = {}) =>
      new THREE.MeshStandardMaterial({ color, roughness, metalness, ...extra });
    const deck = material(0x3f444a, 0.55, 0.6);
    const cap = material(0x7c838b, 0.4, 0.75);
    const rib = material(0x24272c, 0.8, 0.35);
    const trim = material(0xb4bac0, 0.35, 0.8);
    const hazard = material(0xd9a423, 0.5, 0.3);
    const copper = material(0xb0703f, 0.35, 0.9, { emissive: 0x3a1a08, emissiveIntensity: 0.4 });
    const glow = (color, intensity) => material(0x101020, 0.4, 0, { emissive: color, emissiveIntensity: intensity });
    const core = glow(0xd8e4ff, 3.2);
    const plasma = glow(0x5a6dff, 2.4);
    const conduit = glow(0x39b8ff, 2);
    const crystal = glow(0x5fd0ff, 3);
    const glass = material(0xcfe8ff, 0.05, 0, { transparent: true, opacity: 0.18, depthWrite: false, envMapIntensity: 3 });
    const add = (geometry, mat, position = [0, 0, 0], order = 0) => {
      const mesh = new THREE.Mesh(geometry, mat);
      mesh.position.set(...position);
      mesh.renderOrder = order;
      root.add(mesh);
      return mesh;
    };
    const cylinder = (r1, r2, bottom, top, mat, segments = 48) => add(new THREE.CylinderGeometry(r1, r2, top - bottom, segments), mat, [0, (bottom + top) / 2, 0]);

    // Deck with a hazard rim, and the round dais.
    add(new THREE.BoxGeometry(8.4, DECK, 8.4), deck, [0, DECK / 2, 0]);
    add(new THREE.BoxGeometry(8.48, 0.08, 8.48), hazard, [0, DECK - 0.1, 0]);
    cylinder(2.9, 3.0, DECK, DECK + 0.4, cap);

    // Column: lower cap, core and rings in a glass tube, six ribs, upper cap and dome.
    cylinder(RADIUS + 0.2, RADIUS + 0.35, DECK + 0.4, CAP, cap);
    cylinder(0.3, 0.3, CAP, TUBE_TOP, core, 24);
    cylinder(0.8, 0.8, CAP, TUBE_TOP, plasma, 32);
    for (let k = 0; k < 4; k++) {
      add(new THREE.TorusGeometry(1.2, 0.15, 10, 40).rotateX(Math.PI / 2), copper, [0, CAP + 0.85 + k * 1.2, 0]);
    }
    cylinder(RADIUS, RADIUS, CAP, TUBE_TOP, glass, 48).renderOrder = 2;
    for (let i = 0; i < 6; i++) {
      const a = Math.PI / 6 + (i * TAU) / 6;
      add(new THREE.BoxGeometry(0.3, TUBE_TOP - CAP, 0.36), rib, [Math.sin(a) * (RADIUS + 0.1), (CAP + TUBE_TOP) / 2, Math.cos(a) * (RADIUS + 0.1)]).rotation.y = a;
    }
    cylinder(RADIUS + 0.3, RADIUS + 0.2, TUBE_TOP, TOP, cap);
    add(new THREE.TorusGeometry(RADIUS + 0.3, 0.1, 8, 48).rotateX(Math.PI / 2), trim, [0, TUBE_TOP + 0.05, 0]);
    add(new THREE.SphereGeometry(RADIUS + 0.2, 32, 12, 0, TAU, 0, Math.PI / 2).scale(1, 0.4, 1), trim, [0, TOP, 0]);

    // Corner projectors with glowing crystals, linked to the caps by glowing conduits.
    for (const [sx, sz] of [[-1, -1], [1, -1], [-1, 1], [1, 1]]) {
      const x = sx * PROJECTOR;
      const z = sz * PROJECTOR;
      add(new THREE.CylinderGeometry(0.55, 0.7, 2.4, 20), cap, [x, DECK + 1.2, z]);
      add(new THREE.OctahedronGeometry(0.7, 0).scale(1, 1.5, 1), crystal, [x, DECK + 3.0, z]);
      const d = [sx / Math.SQRT2, sz / Math.SQRT2];
      const at = (r, y) => new THREE.Vector3(d[0] * r, y, d[1] * r);
      const corner = PROJECTOR * Math.SQRT2;
      const curve = new THREE.CatmullRomCurve3([at(RADIUS + 0.2, TUBE_TOP + 0.5), at(3.2, TUBE_TOP + 0.3), at(corner - 0.1, DECK + 3.0)]);
      add(new THREE.TubeGeometry(curve, 24, 0.2, 8), conduit);
    }
    return root;
  }
};
