// Growth Facility inventory icon: a deliberately simplified stand-in for the building, since the
// full model's tanks, pipes, and specimens turn to noise at 32–64 px. Same hexagonal outline as
// models/growth-facility.js, with seven large glowing tanks under a thick glass roof frame.
// Units are tiles; x east, y up, z south.
import * as THREE from "three";
import { faceted } from "../lib/geometry.js";

const R = 4.3; // east and west point distance, as on the building
const FLAT = 4.05;
const Z_SCALE = FLAT / (R * Math.cos(Math.PI / 6));
const HEX_START = Math.PI / 6;
// Taller than the building, so the icon fills its square instead of a wide strip.
const PLINTH = 1.0;
const TANK = 2.3;
const EAVE = 3.9;
const APEX = 6.2;

const corner = (i, s = 1, y = 0) => {
  const theta = HEX_START + (i * Math.PI) / 3;
  return new THREE.Vector3(s * R * Math.sin(theta), y, s * R * Math.cos(theta) * Z_SCALE);
};
const hexPrism = (s, height, open = false) =>
  faceted(new THREE.CylinderGeometry(s * R, s * R, height, 6, 1, open, HEX_START).scale(1, 1, Z_SCALE));

export default {
  type: "icon",
  // Lower than the building's 50°, like vanilla icons, so walls and tank sides read.
  elevation: 32,
  export: "spacelab/graphics/icons/growth-facility.png",
  // Vanilla icons shown beside it in the preview, at the same sizes.
  references: [
    "space-age/graphics/icons/biolab.png",
    "space-age/graphics/icons/cryogenic-plant.png",
    "space-age/graphics/icons/biochamber.png"
  ],

  build() {
    const root = new THREE.Group();
    const material = (color, roughness = 0.5, metalness = 0.5, extra = {}) =>
      new THREE.MeshStandardMaterial({ color, roughness, metalness, ...extra });
    const dark = material(0x3a3f46, 0.55, 0.6);
    const frame = material(0x5d646c, 0.4, 0.75);
    const trim = material(0xa9b0b6, 0.35, 0.8);
    const hazard = material(0xd9a423, 0.5, 0.3);
    // Lit and shaded like a liquid column, with a little glow so it stays saturated.
    const fluid = material(0x36c94c, 0.3, 0, { emissive: 0x139a2c, emissiveIntensity: 0.7 });
    const tankGlass = material(0xffffff, 0.04, 0, { transparent: true, opacity: 0.18, depthWrite: false, envMapIntensity: 3 });
    const lid = material(0x2c3036, 0.45, 0.6);
    const beacon = material(0x400808, 0.3, 0, { emissive: 0xff3b2a, emissiveIntensity: 2.5 });
    const glass = material(0x9fd8cc, 0.05, 0, { transparent: true, opacity: 0.16, depthWrite: false });
    const add = (geometry, mat, position = [0, 0, 0], order = 0) => {
      const mesh = new THREE.Mesh(geometry, mat);
      mesh.position.set(...position);
      mesh.renderOrder = order;
      root.add(mesh);
      return mesh;
    };
    const bar = (from, to, radius, mat) => {
      const geometry = new THREE.CylinderGeometry(radius, radius, from.distanceTo(to), 8);
      geometry.rotateX(Math.PI / 2);
      add(geometry, mat, [(from.x + to.x) / 2, (from.y + to.y) / 2, (from.z + to.z) / 2]).lookAt(to);
    };

    // Plinth with a hazard band, and the deck.
    add(hexPrism(1.0, PLINTH - 0.2), dark, [0, (PLINTH - 0.2) / 2, 0]);
    add(hexPrism(1.01, 0.2), hazard, [0, PLINTH - 0.1, 0]);
    add(hexPrism(0.95, 0.04), lid, [0, PLINTH + 0.02, 0]);

    // Seven tanks: glowing fluid columns with dark bases and caps.
    const spots = [[0, 0], ...Array.from({ length: 6 }, (_, k) => {
      const a = (k * Math.PI) / 3;
      return [Math.sin(a) * 2.25, Math.cos(a) * 2.25 * Z_SCALE];
    })];
    for (const [x, z] of spots) {
      add(new THREE.CylinderGeometry(0.88, 0.92, 0.22, 24), dark, [x, PLINTH + 0.11, z]);
      add(new THREE.CylinderGeometry(0.74, 0.74, TANK, 32), fluid, [x, PLINTH + 0.22 + TANK / 2, z]);
      add(new THREE.CylinderGeometry(0.8, 0.8, TANK, 32, 1, true), tankGlass, [x, PLINTH + 0.22 + TANK / 2, z], 1);
      add(new THREE.CylinderGeometry(0.84, 0.84, 0.16, 24), lid, [x, PLINTH + 0.3 + TANK, z]);
      add(new THREE.CylinderGeometry(0.34, 0.4, 0.16, 16), trim, [x, PLINTH + 0.45 + TANK, z]);
      for (const y of [0.3, 0.3 + TANK - 0.1]) add(new THREE.TorusGeometry(0.8, 0.06, 6, 24).rotateX(Math.PI / 2), frame, [x, PLINTH + y, z]);
    }

    // A faint glass roof on a thick open frame, so the hex reads at a glance without hazing the tanks.
    add(faceted(new THREE.ConeGeometry(R * 0.99, APEX - EAVE, 6, 1, true, HEX_START).scale(1, 1, Z_SCALE)), glass, [0, (EAVE + APEX) / 2, 0], 3);
    const apex = new THREE.Vector3(0, APEX, 0);
    for (let i = 0; i < 6; i++) {
      bar(corner(i, 0.98, PLINTH), corner(i, 0.98, EAVE), 0.13, frame);
      bar(corner(i, 0.98, EAVE), corner(i + 1, 0.98, EAVE), 0.13, frame);
      bar(corner(i, 0.98, EAVE), apex, 0.1, trim);
    }
    add(new THREE.CylinderGeometry(0.35, 0.4, 0.22, 6), dark, [0, APEX + 0.05, 0]);
    add(new THREE.SphereGeometry(0.2, 16, 8), beacon, [0, APEX + 0.25, 0]);
    return root;
  }
};
