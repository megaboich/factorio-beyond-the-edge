// Growth Facility: a 9x9 orbital greenhouse. Units are tiles; x east, y up, z south.
//
// A hexagonal hall on a plated plinth, with glass walls and a dirty glass roof over nineteen sci-fi
// cloning tanks in a honeycomb. The hex has flat north and south walls; pipe stubs carry the three
// fluid lanes (z = -2, 0, 2) from its slanted east and west walls to the footprint edge. Tanks and
// pumps fill the square footprint's corners.
//
// Variants: one per growth recipe, each a specimen that grows through its life stages: a Yumako
// tree, a Jellystem bearing Jellynuts, a Biter, or a Pentapod. Capsules are staggered so every stage
// is on show at once. Extra layers, drawn over the building in this order:
// - specimens-<variant>: one variant's specimens. Growth is slow, so these span SLOW building loops
//   in SPECIMEN_FRAMES frames; the game plays them slower than the building.
// - fluid: neutral cloudy fluid with bubbles, at building speed. The game tints it per recipe with
//   the matching VARIANT_COLORS entry.
// The game shows only the running recipe's layers (see spacelab/prototypes/entities.lua). Status
// lamps, consoles, grow lights, and the roof beacon form the untinted `glow-lights` layer.
import * as THREE from "three";
import { clouds, random, textured } from "../lib/textures.js";
import { beam, faceted, part, tube } from "../lib/geometry.js";

const FRAMES = 32;
// The hall is a hexagon with flat north and south walls and points east and west, so its bottom
// edge reads horizontal on screen. The three fluid lanes (x = ±4, z = -2, 0, 2) meet the slanted
// walls, and short pipe stubs carry them out to the footprint edge.
const R = 4.3; // east and west point distance
const FLAT = 4.05; // north and south wall distance
const Z_SCALE = FLAT / (R * Math.cos(Math.PI / 6));
const HEX_START = Math.PI / 6; // first corner at 30° from south, so faces 5 and 2 are south and north
const BASE = 0.1; // top of the ground plate
const DECK = 0.6; // top of the plinth, where the capsules stand
const EAVE = 2.6;
const APEX = 3.4;
const LANES = [-2, 0, 2];
// Capsules: a honeycomb of rows with 3, 4, 5, 4, and 3 capsules, as large as the hall allows while
// the consoles and junction boxes still fit beside them. Capsule units: base radius 0.62.
const CAPSULE_SIZE = 1.02;
const SPACING = 1.49;
const ROWS = [3, 4, 5, 4, 3];
const GLASS_BOTTOM = 0.32;
const GLASS_TOP = 1.36;
const CAPSULE_TOP = 1.62; // capsule height above the deck at size 1, including the cap hub
const FLUID_BOTTOM = 0.34;
const FLUID_TOP = 1.3;
// Specimen groups are scaled by SPECIMEN_SCALE about the fluid's floor, so builders' y = -0.45
// always sits on the capsule floor whatever the scale.
const SPECIMEN_SCALE = 1.3;
const SPECIMEN_Y = FLUID_BOTTOM + 0.02 + 0.45 * SPECIMEN_SCALE;
// Each bubble rises this many times per building loop, plus 0–1 more, picked per bubble.
const BUBBLE_RISES = 2;
const BUBBLES_PER_CAPSULE = 4;
// A specimen's life cycle spans SLOW building loops, rendered in SPECIMEN_FRAMES frames.
const SLOW = 8;
const SPECIMEN_FRAMES = 64;

const VARIANTS = ["yumako", "jellynut", "biter-egg", "pentapod-egg"];
// Fluid tints, duplicated in spacelab/prototypes/entities.lua (recipe_channels).
const VARIANT_COLORS = {
  "yumako": [0.72, 0.38, 0.31],
  "jellynut": [0.78, 0.58, 0.79],
  "biter-egg": [0.86, 0.65, 0.37],
  "pentapod-egg": [0.54, 0.77, 0.45]
};

/** Hex corner `i` (0 = south-east, then counter-clockwise seen from above), `s` times the hall size. */
const corner = (i, s = 1, y = 0) => {
  const theta = HEX_START + (i * Math.PI) / 3;
  return new THREE.Vector3(s * R * Math.sin(theta), y, s * R * Math.cos(theta) * Z_SCALE);
};
/** A flat-sided hex prism (or open shell) matching the hall outline, `s` times its size. */
const hexPrism = (s, height, open = false) => faceted(new THREE.CylinderGeometry(s * R, s * R, height, 6, 1, open, HEX_START).scale(1, 1, Z_SCALE));
/** Distance east or west from the centre to the slanted wall at row `z`, `s` times the hall size. */
const wallX = (z, s = 1) => s * R - (R * Math.abs(z)) / (2 * FLAT);
/** Midpoint, outward normal, and outward-facing Y rotation of hex face `i`, between corners i and i + 1. */
const face = (i, s = 1) => {
  const a = corner(i, s);
  const b = corner(i + 1, s);
  const mid = a.clone().add(b).multiplyScalar(0.5);
  const normal = new THREE.Vector3(b.z - a.z, 0, a.x - b.x);
  if (normal.dot(mid) < 0) normal.negate();
  normal.normalize();
  return { mid, normal, rotation: Math.atan2(normal.x, normal.z) };
};

const TAU = Math.PI * 2;
const smoothstep = (a, b, x) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};
const mix = (a, b, t) => a + (b - a) * t;
/** Zero scale makes a singular matrix, so hidden growth stages shrink to a speck instead. */
const scaleTo = (object, value) => object.scale.setScalar(Math.max(0.001, value));
/** A specimen's presence over its life `s`: it appears from nothing, then dissolves at harvest. */
const presence = (s) => (s < 0.9 ? smoothstep(0, 0.06, s) : 1 - smoothstep(0.9, 0.98, s));

export default {
  tiles: [9, 9],
  height: 3.7,
  elevation: 50,
  frames: FRAMES,
  // Matches the game: animation_speed (0.5 / 4) / 2 frames per tick at crafting speed 4, 60 ticks a second.
  fps: 15,
  export: "spacelab/graphics/entity/growth-facility/growth-facility",
  variants: VARIANTS,
  variantColors: VARIANT_COLORS,
  layers: [
    // Specimens are muted (30% less saturation and contrast) so they sit calmly in the fluid.
    ...VARIANTS.map((v) => ({ name: `specimens-${v}`, tag: "specimen", variant: v, frames: SPECIMEN_FRAMES, span: SLOW, mute: 0.3, preview: { variant: v } })),
    { name: "fluid", tag: "fluid", variant: "fluid", frames: FRAMES, span: 1, preview: { tint: "variant" } }
  ],
  references: [
    {
      label: "Vanilla Biolab (5x5), for style",
      tiles: [5, 5],
      layers: [
        { file: "factorio:space-age/graphics/entity/biolab/biolab-shadow.png", width: 476, height: 262, shift: [39.5 / 32, 21 / 32], blend: "shadow", frame_count: 32, line_length: 8 },
        { file: "factorio:space-age/graphics/entity/biolab/biolab-anim.png", width: 366, height: 404, shift: [2 / 32, -5 / 32], blend: "normal", frame_count: 32, line_length: 8 },
        { file: "factorio:space-age/graphics/entity/biolab/biolab-lights.png", width: 326, height: 362, shift: [1 / 32, -6.5 / 32], blend: "additive", frame_count: 32, line_length: 8 }
      ]
    }
  ],

  build() {
    const root = new THREE.Group();
    const state = { variant: null, lamps: [], bubbles: [], capsules: [], fluidMeshes: [], fluids: {}, clouds: [], fans: [] };
    root.userData = state;
    const rand = random(42);

    const m = {
      base: textured({ color: 0x55595b, panels: 3, rivets: true, grime: 0.6, rust: 0.18, scratches: 0.5, scale: 3, metalness: 0.55, roughness: 0.6, seed: 13 }),
      plating: textured({ color: 0x8d8f8a, panels: 2, rivets: true, grime: 0.55, rust: 0.2, scratches: 0.4, scale: 1.6, metalness: 0.45, roughness: 0.55, seed: 3 }),
      dark: textured({ color: 0x43474c, panels: 1, rivets: true, grime: 0.55, rust: 0.25, scale: 1.2, metalness: 0.65, roughness: 0.5, seed: 5 }),
      frame: textured({ color: 0x6a7077, grime: 0.45, scratches: 0.5, scale: 1, metalness: 0.7, roughness: 0.45, seed: 7 }),
      hazard: textured({ color: 0x55585b, stripes: true, grime: 0.55, scale: 1.2, metalness: 0.3, roughness: 0.6, seed: 9 }),
      grating: textured({ color: 0x4a4e52, holes: 20, grime: 0.55, rust: 0.1, scale: 1.4, metalness: 0.6, roughness: 0.5, seed: 11 }),
      light: textured({ color: 0xa3a6a0, panels: 1, grime: 0.45, rust: 0.1, scale: 1, metalness: 0.45, roughness: 0.45, seed: 15 }),
      pipe: textured({ color: 0x7d8288, grime: 0.35, scratches: 0.4, rust: 0.08, scale: 0.8, metalness: 0.8, roughness: 0.35, seed: 17 }),
      cable: new THREE.MeshStandardMaterial({ color: 0x1d1f21, roughness: 0.7 })
    };
    /** Glass with grimy smudges and faint pane seams; `order` keeps nested glass drawing back to front. */
    const glass = (color, opacity, order, panels = 0, seed = 21) => {
      const material = textured({ color, panels, grime: 0.75, scratches: 0.2, variation: 0.05, scale: 2.2, metalness: 0, roughness: 0.08, seed });
      material.roughnessMap = null;
      material.bumpMap = null;
      material.roughness = 0.08;
      Object.assign(material, { transparent: true, opacity, depthWrite: false, envMapIntensity: 1.8 });
      material.userData.renderOrder = order;
      return material;
    };
    const roofGlass = glass(0xc6e2dc, 0.36, 4, 2);
    const wallGlass = glass(0xd2e8e4, 0.26, 3, 1, 23);
    const capsuleGlass = glass(0xeef8ff, 0.18, 2, 0, 25);

    // Capsule contents: cloudy fluid whose two noise layers drift in opposite directions, and bubbles.
    const cloudColor = clouds(101, 0.4, 1);
    const cloudDensity = clouds(202, 0.3, 1);
    cloudColor.repeat.set(2, 1);
    cloudDensity.repeat.set(3, 1.5);
    state.clouds = [cloudColor, cloudDensity];
    const fluidMaterial = (color, opacity, glow, tag) => {
      const material = new THREE.MeshStandardMaterial({
        color, map: cloudColor, alphaMap: cloudDensity, emissive: color, emissiveMap: cloudColor, emissiveIntensity: glow,
        roughness: 0.2, metalness: 0, transparent: true, opacity, depthWrite: false, side: THREE.DoubleSide
      });
      material.userData = { tag, renderOrder: 1 };
      return material;
    };
    // Murky water in idle capsules, part of the building itself; the tinted fluid layer covers it.
    state.fluids.idle = fluidMaterial(0x8a9a94, 0.3, 0.05, null);
    state.fluids.fluid = fluidMaterial(0xf2f2f2, 0.45, 0.4, "fluid");
    const bubble = new THREE.MeshStandardMaterial({ color: 0xffffff, emissive: 0xffffff, emissiveIntensity: 0.4, roughness: 0.1 });
    bubble.userData.tag = "fluid";
    const glare = new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.32, depthWrite: false, side: THREE.DoubleSide });
    glare.userData.renderOrder = 3;
    const s = specimenMaterials();
    // Tank lids always hide the specimen and fluid layers where they are drawn (render.js
    // `cutsLayers`), so specimens seen through the glass never appear over a lid.
    const cutting = (material) => {
      const copy = material.clone();
      copy.userData.cutsLayers = true;
      return copy;
    };
    const lid = { dome: cutting(m.dark), hub: cutting(m.frame), stub: cutting(m.pipe) };

    /** A small light that blinks `cycles` times per loop, lit for `duty` of each cycle. */
    const lamp = (parent, geometry, color, position, { cycles = 1, phase = 0, duty = 0.5, on = 3, off = 0.08, scale = 0.9 } = {}) => {
      const material = new THREE.MeshStandardMaterial({ color: 0x1c1c1c, emissive: color, emissiveIntensity: off, roughness: 0.3 });
      material.userData.glow = { layer: "lights", scale };
      state.lamps.push({ material, cycles, phase, duty, on, off });
      return part(parent, geometry, material, position);
    };

    // Ground plate, hazard skirt, and plinth.
    part(root, new THREE.BoxGeometry(8.7, BASE, 8.7), m.base, [0, BASE / 2, 0]);
    part(root, hexPrism(1.0, 0.1), m.hazard, [0, BASE + 0.05, 0]);
    part(root, hexPrism(0.99, DECK - BASE - 0.1), m.plating, [0, (BASE + 0.1 + DECK) / 2, 0]);
    part(root, hexPrism(1.005, 0.07), m.dark, [0, DECK - 0.035, 0]);
    part(root, hexPrism(0.96, 0.02), m.grating, [0, DECK + 0.01, 0]);

    // Plinth faces: vent grilles and status lamps on the flat south (5) and north (2) walls, a
    // smaller grille on each slanted wall clear of its fluid connection.
    for (const [i, offsets, lamps] of [[5, [-1.1, 0.0], true], [2, [-1.1, 0.0], true], [0, [1.25], false], [1, [1.25], false], [3, [1.25], false], [4, [1.25], false]]) {
      const { mid, rotation, normal } = face(i, 0.99);
      const out = (d) => mid.clone().addScaledVector(normal, d);
      const along = new THREE.Vector3(Math.cos(rotation), 0, -Math.sin(rotation));
      for (const offset of offsets) {
        const p = out(0.025).addScaledVector(along, offset);
        part(root, new THREE.BoxGeometry(0.8, 0.2, 0.05), m.grating, [p.x, 0.37, p.z]).rotation.y = rotation;
        const frameP = out(0.02).addScaledVector(along, offset);
        part(root, new THREE.BoxGeometry(0.86, 0.26, 0.03), m.dark, [frameP.x, 0.37, frameP.z]).rotation.y = rotation;
      }
      if (!lamps) continue;
      for (let k = 0; k < 3; k++) {
        const p = out(0.03).addScaledVector(along, 0.75 + k * 0.14);
        lamp(root, new THREE.BoxGeometry(0.08, 0.06, 0.04), [0x7dff6a, 0xffb020, 0xff4030][k], [p.x, 0.37, p.z],
          { cycles: 2, phase: (k / 3 + i * 0.17) % 1, duty: 0.3 }).rotation.y = rotation;
      }
    }
    // Fluid connections: a stub from the slanted wall out to the footprint edge, flanged at both ends.
    for (const side of [-1, 1]) {
      for (const z of LANES) {
        const wall = wallX(z, 0.99);
        if (4.2 - wall > 0.05) {
          beam(root, new THREE.Vector3(side * (wall - 0.05), 0.36, z), new THREE.Vector3(side * 4.2, 0.36, z), 0.12, m.pipe, 16);
        }
        part(root, new THREE.CylinderGeometry(0.17, 0.17, 0.1, 16), m.pipe, [side * (wall + 0.03), 0.36, z], [0, 0, Math.PI / 2]);
        part(root, new THREE.CylinderGeometry(0.18, 0.18, 0.06, 16), m.dark, [side * 4.27, 0.36, z], [0, 0, Math.PI / 2]);
      }
    }

    // Hall: glass walls and roof on a light frame.
    part(root, hexPrism(0.975, EAVE - DECK, true), wallGlass, [0, (DECK + EAVE) / 2, 0]);
    part(root, faceted(new THREE.ConeGeometry(R * 0.985, APEX - EAVE, 6, 1, true, HEX_START).scale(1, 1, Z_SCALE)), roofGlass, [0, (EAVE + APEX) / 2, 0]);
    const apex = new THREE.Vector3(0, APEX, 0);
    for (let i = 0; i < 6; i++) {
      const c = corner(i, 0.975);
      part(root, new THREE.BoxGeometry(0.13, EAVE - DECK, 0.13), m.frame, [c.x, (DECK + EAVE) / 2, c.z]);
      beam(root, corner(i, 0.975, DECK + 0.05), corner(i + 1, 0.975, DECK + 0.05), 0.05, m.frame);
      beam(root, corner(i, 0.975, EAVE), corner(i + 1, 0.975, EAVE), 0.055, m.frame);
      beam(root, corner(i, 0.975, EAVE), apex, 0.04, m.frame);
      // Grow-light strip just under each roof rib.
      const along = (f) => corner(i, 0.975, EAVE).lerp(apex, f).add(new THREE.Vector3(0, -0.08, 0));
      const strip = new THREE.MeshStandardMaterial({ color: 0x302028, emissive: 0xff9ad6, emissiveIntensity: 0.75, roughness: 0.4 });
      strip.userData.glow = { layer: "lights", scale: 0.5 };
      beam(root, along(0.12), along(0.7), 0.02, strip, 6);
    }
    part(root, new THREE.CylinderGeometry(0.24, 0.28, 0.14, 6), m.dark, [0, APEX + 0.02, 0]);
    lamp(root, new THREE.SphereGeometry(0.07, 16, 8), 0xff3020, [0, APEX + 0.14, 0], { cycles: 2, duty: 0.2, on: 4, scale: 0.7 });

    // Growth capsules in honeycomb rows. Each row's cap hubs feed an overhead pipe that drops to the
    // deck in the gap between the row's last capsule and the wall.
    const rowZ = SPACING * Math.sin(Math.PI / 3);
    const pipeY = DECK + CAPSULE_TOP * CAPSULE_SIZE + 0.05;
    const baseRadius = 0.62 * CAPSULE_SIZE;
    let index = 0;
    ROWS.forEach((count, row) => {
      const z = (row - (ROWS.length - 1) / 2) * rowZ;
      const half = ((count - 1) / 2) * SPACING;
      for (let k = 0; k < count; k++) {
        const x = -half + k * SPACING;
        // Golden-ratio phases spread the capsules evenly over the growth cycle.
        capsule(x, z, (index++ * 0.618034) % 1);
      }
      const drop = (half + baseRadius + wallX(z, 0.96)) / 2;
      beam(root, new THREE.Vector3(-half, pipeY, z), new THREE.Vector3(half, pipeY, z), 0.045, m.pipe, 10);
      for (const side of [-1, 1]) {
        tube(root, [[side * half, pipeY, z], [side * (drop - 0.05), pipeY - 0.05, z], [side * drop, pipeY - 0.3, z], [side * drop, DECK + 0.05, z]], 0.045, m.pipe, 16);
        part(root, new THREE.CylinderGeometry(0.08, 0.08, 0.1, 12), m.dark, [side * drop, DECK + 0.05, z]);
      }
    });

    // Consoles against the north and south walls, facing into the hall.
    for (const z of [-1, 1]) {
      const g = new THREE.Group();
      g.position.set(-z * 1.4, DECK, z * 3.55);
      g.rotation.y = z > 0 ? Math.PI : 0;
      root.add(g);
      part(g, new THREE.BoxGeometry(0.8, 0.32, 0.36), m.dark, [0, 0.16, 0]);
      part(g, new THREE.BoxGeometry(0.8, 0.05, 0.4), m.frame, [0, 0.34, 0.01]);
      for (let k = 0; k < 3; k++) {
        lamp(g, new THREE.BoxGeometry(0.2, 0.012, 0.16), [0x60e0ff, 0x7dff9a, 0x60e0ff][k], [-0.25 + k * 0.25, 0.37, 0.02],
          { cycles: 4, phase: k * 0.37 + (z > 0 ? 0.5 : 0), duty: 0.7, on: 1.4, off: 0.6, scale: 0.5 });
      }
    }

    // Corner equipment: nutrient tanks in the north corners, pumps with fans in the south corners.
    for (const side of [-1, 1]) {
      const x = side * 3.5;
      const z = -3.5;
      part(root, new THREE.CylinderGeometry(0.62, 0.66, 0.12, 32), m.dark, [x, BASE + 0.06, z]);
      part(root, new THREE.CylinderGeometry(0.5, 0.5, 1.2, 32), m.light, [x, BASE + 0.6, z]);
      part(root, new THREE.SphereGeometry(0.5, 32, 12, 0, Math.PI * 2, 0, Math.PI / 2), m.light, [x, BASE + 1.2, z]);
      part(root, new THREE.CylinderGeometry(0.515, 0.515, 0.14, 32), m.hazard, [x, BASE + 0.3, z]);
      part(root, new THREE.CylinderGeometry(0.52, 0.52, 0.06, 32), m.dark, [x, BASE + 1.15, z]);
      part(root, new THREE.CylinderGeometry(0.1, 0.1, 0.16, 12), m.pipe, [x, BASE + 1.72, z]);
      lamp(root, new THREE.BoxGeometry(0.1, 0.55, 0.04), 0x7dff9a, [x - side * 0.12, BASE + 0.75, z + 0.48],
        { cycles: 1, phase: side > 0 ? 0.5 : 0, duty: 0.85, on: 1.6, off: 0.8, scale: 0.6 });
      beam(root, new THREE.Vector3(x * 0.9, 0.45, z * 0.9), new THREE.Vector3(side * 2.78, 0.45, -2.78), 0.08, m.pipe);
      tube(root, [[x, BASE + 1.78, z], [x * 0.88, BASE + 1.9, z * 0.88], [side * 2.84, 0.5, -2.84]], 0.05, m.pipe, 20);
    }
    for (const side of [-1, 1]) {
      const x = side * 3.5;
      const z = 3.5;
      part(root, new THREE.BoxGeometry(0.85, 0.5, 0.85), m.dark, [x, BASE + 0.25, z]);
      part(root, new THREE.BoxGeometry(0.9, 0.06, 0.9), m.frame, [x, BASE + 0.52, z]);
      part(root, new THREE.CylinderGeometry(0.36, 0.36, 0.03, 24), m.grating, [x, BASE + 0.56, z]);
      const fan = new THREE.Group();
      fan.position.set(x, BASE + 0.6, z);
      root.add(fan);
      part(fan, new THREE.CylinderGeometry(0.07, 0.07, 0.05, 12), m.pipe);
      for (let b = 0; b < 4; b++) {
        const blade = part(fan, new THREE.BoxGeometry(0.3, 0.015, 0.09), m.frame, [Math.cos((b * Math.PI) / 2) * 0.17, 0, Math.sin((b * Math.PI) / 2) * 0.17]);
        blade.rotation.set(0.35, -(b * Math.PI) / 2, 0);
      }
      state.fans.push({ fan, base: side * 0.4 });
      part(root, new THREE.TorusGeometry(0.38, 0.025, 6, 32), m.frame, [x, BASE + 0.6, z], [Math.PI / 2, 0, 0]);
      lamp(root, new THREE.BoxGeometry(0.1, 0.06, 0.03), 0xffb020, [x, BASE + 0.32, z + 0.44], { cycles: 4, phase: side > 0 ? 0.25 : 0, duty: 0.5 });
      beam(root, new THREE.Vector3(x * 0.88, 0.32, z * 0.88), new THREE.Vector3(side * 2.78, 0.32, 2.78), 0.08, m.pipe);
    }

    // Specimens never rise above the fluid surface, so nothing pokes out of a tank or over its lid
    // (render.js enables local clipping). Three.js discards fragments on the plane's negative side.
    const surface = new THREE.Plane(new THREE.Vector3(0, -1, 0), DECK + CAPSULE_SIZE * (FLUID_TOP - 0.02));
    root.traverse((object) => {
      if (!object.isMesh) return;
      if (object.material.userData.renderOrder) object.renderOrder = object.material.userData.renderOrder;
      if (object.material.userData.tag === "specimen") object.material.clippingPlanes = [surface];
    });
    return root;

    /**
     * Builds a sci-fi cloning tank at (x, z) whose specimens run `phase` ahead in their growth cycle:
     * a heavy hazard-striped base, a glass cylinder with glare streaks, illuminator rings that make
     * the fluid glow, three struts, side cables, and a machinery cap feeding the row's overhead pipe.
     */
    function capsule(x, z, phase) {
      const g = new THREE.Group();
      g.position.set(x, DECK, z);
      g.scale.setScalar(CAPSULE_SIZE);
      root.add(g);
      const glassHeight = GLASS_TOP - GLASS_BOTTOM;
      const glassMid = (GLASS_TOP + GLASS_BOTTOM) / 2;

      // Base: plinth, hazard band, and collar, with status lamps facing the camera.
      part(g, new THREE.CylinderGeometry(0.58, 0.62, 0.24, 32), m.dark, [0, 0.12, 0]);
      part(g, new THREE.CylinderGeometry(0.625, 0.625, 0.07, 32), m.hazard, [0, 0.08, 0]);
      part(g, new THREE.CylinderGeometry(0.56, 0.58, 0.08, 32), m.frame, [0, 0.28, 0]);
      lamp(g, new THREE.BoxGeometry(0.12, 0.06, 0.04), 0x7dff6a, [-0.08, 0.17, 0.6], { cycles: 1, phase, duty: 0.6 });
      lamp(g, new THREE.BoxGeometry(0.06, 0.06, 0.04), 0xffb020, [0.08, 0.17, 0.6], { cycles: 3, phase: (phase * 2) % 1, duty: 0.4 });

      // Fluid, glass, glare streaks on the camera-facing side, and the two illuminator rings.
      const fluid = new THREE.Mesh(new THREE.CylinderGeometry(0.47, 0.47, FLUID_TOP - FLUID_BOTTOM, 32), state.fluids.idle);
      fluid.position.y = (FLUID_TOP + FLUID_BOTTOM) / 2;
      fluid.rotation.y = rand() * TAU;
      g.add(fluid);
      state.fluidMeshes.push(fluid);
      part(g, new THREE.CylinderGeometry(0.5, 0.5, glassHeight, 32, 1, true), capsuleGlass, [0, glassMid, 0]);
      for (const [start, width] of [[-0.75, 0.22], [-0.42, 0.07], [0.55, 0.05]]) {
        part(g, new THREE.CylinderGeometry(0.505, 0.505, glassHeight * 0.88, 6, 1, true, start, width), glare, [0, glassMid, 0]);
      }
      for (const y of [GLASS_BOTTOM + 0.03, GLASS_TOP - 0.03]) {
        part(g, new THREE.TorusGeometry(0.48, 0.022, 8, 32), m.frame, [0, y, 0], [Math.PI / 2, 0, 0]);
      }

      // Struts and side cables between base and cap.
      for (const a of [Math.PI / 3, Math.PI, (5 * Math.PI) / 3]) {
        part(g, new THREE.CylinderGeometry(0.028, 0.028, glassHeight + 0.04, 8), m.frame, [Math.sin(a) * 0.52, glassMid, Math.cos(a) * 0.52]);
      }
      for (const a of [Math.PI * 0.62, Math.PI * 1.38]) {
        const at = (r, y) => [Math.sin(a) * r, y, Math.cos(a) * r];
        tube(g, [at(0.56, GLASS_TOP + 0.04), at(0.62, glassMid + 0.2), at(0.6, glassMid - 0.25), at(0.58, GLASS_BOTTOM - 0.02)], 0.022, m.cable, 16);
      }

      // Top: a glass disc in a thin dark rim, so the glowing fluid shows from above, with a small
      // domed lid (half the tank's width) and a hub with a stub up to the overhead pipe.
      part(g, new THREE.CircleGeometry(0.5, 32), capsuleGlass, [0, GLASS_TOP, 0], [-Math.PI / 2, 0, 0]);
      part(g, new THREE.TorusGeometry(0.5, 0.03, 8, 32), m.frame, [0, GLASS_TOP, 0], [Math.PI / 2, 0, 0]);
      part(g, new THREE.SphereGeometry(0.25, 24, 8, 0, TAU, 0, Math.PI / 2).scale(1, 0.4, 1), lid.dome, [0, GLASS_TOP, 0]);
      part(g, new THREE.CylinderGeometry(0.06, 0.075, 0.06, 12), lid.hub, [0, GLASS_TOP + 0.11, 0]);
      part(g, new THREE.CylinderGeometry(0.035, 0.035, CAPSULE_TOP - GLASS_TOP - 0.13, 10), lid.stub, [0, (CAPSULE_TOP + GLASS_TOP + 0.13) / 2, 0]);
      lamp(g, new THREE.SphereGeometry(0.03, 10, 6), 0x60e0ff, [0, GLASS_TOP + 0.02, 0.5], { cycles: 2, phase: (phase * 3) % 1, duty: 0.5, on: 2 });

      const specimens = {};
      const seed = Math.floor(rand() * 1000);
      for (const name of VARIANTS) {
        const group = new THREE.Group();
        group.position.y = SPECIMEN_Y;
        group.scale.setScalar(SPECIMEN_SCALE);
        group.rotation.y = rand() * TAU;
        group.visible = false;
        g.add(group);
        specimens[name] = { group, update: SPECIMENS[name](group, seed, s) };
      }
      state.capsules.push({ specimens, phase });

      for (let b = 0; b < BUBBLES_PER_CAPSULE; b++) {
        const radius = 0.016 + rand() * 0.018;
        const mesh = part(g, new THREE.SphereGeometry(radius, 8, 6), bubble);
        mesh.visible = false;
        const r = Math.sqrt(rand()) * 0.36;
        const a = rand() * TAU;
        state.bubbles.push({ mesh, x: Math.sin(a) * r, z: Math.cos(a) * r, cycles: BUBBLE_RISES + Math.floor(rand() * 2), phase: rand() });
      }
    }
  },

  /** Shows one recipe's specimens, the neutral fluid layer (`"fluid"`), or the idle building (`null`). */
  setVariant(root, name) {
    const state = root.userData;
    state.variant = name;
    for (const fluid of state.fluidMeshes) fluid.material = state.fluids[name === "fluid" ? "fluid" : "idle"];
    for (const capsule of state.capsules) {
      for (const [variant, specimen] of Object.entries(capsule.specimens)) specimen.group.visible = variant === name;
    }
    for (const bubble of state.bubbles) bubble.mesh.visible = name === "fluid";
  },

  // `t` counts building loops (0 to 1 for the building, up to SLOW for specimen layers). Every
  // motion uses whole cycles per loop so the last frame leads seamlessly into the first; each
  // capsule's specimen grows once per SLOW loops from its own phase.
  animate(root, t) {
    const { variant, lamps, bubbles, capsules, clouds: [cloudColor, cloudDensity], fans } = root.userData;
    for (const lamp of lamps) {
      lamp.material.emissiveIntensity = (t * lamp.cycles + lamp.phase) % 1 < lamp.duty ? lamp.on : lamp.off;
    }
    cloudColor.offset.set(t, -t);
    cloudDensity.offset.set(-t, -2 * t);
    for (const bubble of bubbles) {
      const rise = (t * bubble.cycles + bubble.phase) % 1;
      const wobble = 0.02 * Math.sin(TAU * (t * bubble.cycles * 3 + bubble.phase));
      bubble.mesh.position.set(bubble.x + wobble, FLUID_BOTTOM + 0.05 + rise * (FLUID_TOP - FLUID_BOTTOM - 0.08), bubble.z);
      bubble.mesh.scale.setScalar(rise > 0.92 ? Math.max(0.001, 1 - (rise - 0.92) / 0.08) : 1);
    }
    if (variant && variant !== "fluid") {
      const slow = t / SLOW;
      for (const capsule of capsules) capsule.specimens[variant].update((slow + capsule.phase) % 1, slow, capsule.phase);
    }
    for (const { fan, base } of fans) fan.rotation.y = base + t * (Math.PI / 2) * 3;
  }
};

// Specimens. Each builder adds its meshes to a group centred in a capsule (capsule units: the
// floor is y -0.45; groups are then scaled by SPECIMEN_SCALE, so keep specimens within about 0.3
// of the axis and 0.65 above the floor) and returns update(stage, slow, phase). `stage` is
// the specimen's life stage from 0 (appearing) to 1 (harvested); `slow` runs 0 to 1 over the
// SLOW-loop specimen animation, so idle motion uses whole cycles of it.

function organic(geometry, seed, amount) {
  const p = geometry.attributes.position;
  const v = new THREE.Vector3();
  for (let i = 0; i < p.count; i++) {
    v.fromBufferAttribute(p, i);
    const n = v.clone().normalize();
    const f = 1 + amount * (Math.sin(n.x * 5 + seed) * Math.sin(n.y * 4 + seed * 1.7) + 0.6 * Math.sin(n.z * 7 + seed * 2.3));
    p.setXYZ(i, v.x * f, v.y * f, v.z * f);
  }
  geometry.computeVertexNormals();
  return geometry;
}

/** Mottled vertex colours, so specimens read as living tissue rather than plastic. */
function mottled(geometry, color, seed, contrast = 0.3) {
  const p = geometry.attributes.position;
  const base = new THREE.Color(color);
  const colors = new Float32Array(p.count * 3);
  for (let i = 0; i < p.count; i++) {
    const k = 0.78 + contrast * Math.sin(p.getX(i) * 31 + seed) * Math.sin(p.getY(i) * 27 + seed * 0.7) * Math.sin(p.getZ(i) * 23);
    colors.set([base.r * k, base.g * k, base.b * k], i * 3);
  }
  geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3));
  return geometry;
}

/** A lumpy, mottled blob of `radius`, stretched by `stretch`. */
function blob(radius, color, seed, amount = 0.06, stretch = [1, 1, 1], detail = 3) {
  return mottled(organic(new THREE.IcosahedronGeometry(radius, detail), seed, amount).scale(...stretch), color, seed);
}

/**
 * Colours and bulges a sphere-like geometry from a function of its surface direction:
 * `pattern(lat, lon)` returns 0 (groove: `dark`) to 1 (raised: `light`), and raised areas push out by `relief`.
 */
function patterned(geometry, dark, light, relief, pattern) {
  const p = geometry.attributes.position;
  const v = new THREE.Vector3();
  const a = new THREE.Color(dark);
  const b = new THREE.Color(light);
  const colors = new Float32Array(p.count * 3);
  for (let i = 0; i < p.count; i++) {
    v.fromBufferAttribute(p, i);
    const n = v.clone().normalize();
    const k = Math.min(1, Math.max(0, pattern(Math.acos(Math.max(-1, Math.min(1, n.y))), Math.atan2(n.x, n.z))));
    v.multiplyScalar(1 + relief * (k - 0.5));
    p.setXYZ(i, v.x, v.y, v.z);
    colors.set([mix(a.r, b.r, k), mix(a.g, b.g, k), mix(a.b, b.b, k)], i * 3);
  }
  geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3));
  geometry.computeVertexNormals();
  return geometry;
}

/** A Jellynut: a ribbed, pale-pink pod of plump kernels, like the in-game fruit and Jellystem clusters. */
function jellynutPod(radius, seed) {
  const geometry = new THREE.SphereGeometry(radius, 28, 20).scale(0.9, 1.2, 0.85);
  return patterned(geometry, 0x7a1858, 0xffc8e6, 0.2, (lat, lon) =>
    Math.pow(Math.abs(Math.sin(lat * 5 + seed)), 0.6) * Math.pow(Math.abs(Math.sin(lon * 4 + seed * 0.3)), 0.35));
}

/** A Biter egg: amber with dark brown bands across its length, slightly ribbed, as in game. */
function biterEgg(radius) {
  const geometry = new THREE.SphereGeometry(radius, 32, 24).scale(1, 1.3, 1);
  return patterned(geometry, 0x4a2008, 0xf2b84a, 0.08, (lat) => Math.pow(Math.abs(Math.sin(lat * 4.5)), 1.2));
}

/**
 * One biter abdomen ring: an ochre armour band, darker where it tucks under its neighbours
 * (front and back edges) and on its belly, like the segmented vanilla biter carapace.
 */
function biterRing(radius, length, seed) {
  const geometry = new THREE.SphereGeometry(1, 24, 16);
  const p = geometry.attributes.position;
  const base = new THREE.Color(0x8e6a34);
  const groove = new THREE.Color(0x2e1e0c);
  const colors = new Float32Array(p.count * 3);
  for (let i = 0; i < p.count; i++) {
    const x = p.getX(i), y = p.getY(i), z = p.getZ(i);
    const edge = Math.pow(Math.abs(z), 3);
    const belly = 0.55 + 0.45 * smoothstep(-0.7, 0.3, y);
    const mottle = 0.85 + 0.15 * Math.sin(x * 23 + seed) * Math.sin(z * 19 + seed * 0.7);
    const k = (1 - edge) * belly * mottle;
    colors.set([mix(groove.r, base.r, k), mix(groove.g, base.g, k), mix(groove.b, base.b, k)], i * 3);
  }
  geometry.setAttribute("color", new THREE.BufferAttribute(colors, 3));
  return geometry.scale(radius, radius * 0.7, length);
}

function tag(material) {
  material.userData.tag = "specimen";
  return material;
}

function specimenMaterials() {
  const tissue = (glow = 0x000000, intensity = 0, roughness = 0.5) =>
    tag(new THREE.MeshStandardMaterial({ color: 0xffffff, vertexColors: true, roughness, emissive: glow, emissiveIntensity: intensity }));
  const plain = (color, roughness = 0.6, emissive = 0x000000, intensity = 0, metalness = 0) =>
    tag(new THREE.MeshStandardMaterial({ color, roughness, emissive, emissiveIntensity: intensity, metalness }));
  // `userData.mute` overrides the layer's mute for one part (render.js): plant stems recede
  // strongly, while Yumako fruit and Jellynut pods keep their full colour.
  const muted = (material, amount) => {
    material.userData.mute = amount;
    return material;
  };
  return {
    tissue: tissue(),
    fruit: muted(tissue(), 0),
    pod: muted(tissue(0xa0205c, 0.6, 0.35), 0),
    carapace: tissue(0x000000, 0, 0.55),
    bark: muted(plain(0x5a3d2c, 0.75), 0.7),
    root: muted(plain(0xc9b08a, 0.7), 0.7),
    frond: muted(plain(0x3f8f6a, 0.6), 0.7),
    jellystem: muted(tissue(0x000000, 0, 0.6), 0.7),
    biterLeg: plain(0xa86a4c, 0.5),
    eye: plain(0x120a08, 0.2),
    biterClaw: plain(0x5a2018, 0.4),
    pentaLeg: plain(0x46602a, 0.5)
  };
}

/** A per-capsule egg shell whose opacity follows the specimen's stage. */
function shell() {
  return tag(new THREE.MeshStandardMaterial({ color: 0xffffff, vertexColors: true, roughness: 0.4, transparent: true, depthWrite: false }));
}

const SPECIMENS = {
  // Yumako: a seed puts down roots, a twisted trunk rises, frond-tipped branches spread, and red
  // fruit swells at their tips.
  "yumako"(g, seed, s) {
    const r = random(seed + 1);
    const seedling = part(g, blob(0.06, 0x7a5232, seed, 0.06, [1, 1.3, 1], 2), s.bark, [0, -0.36, 0]);
    const plant = new THREE.Group();
    plant.position.y = -0.42;
    g.add(plant);
    const roots = new THREE.Group();
    plant.add(roots);
    for (let k = 0; k < 5; k++) {
      const a = (k * TAU) / 5 + r();
      tube(roots, [[0, 0.02, 0], [Math.sin(a) * 0.1, -0.02, Math.cos(a) * 0.1], [Math.sin(a) * 0.22, 0.01 - r() * 0.04, Math.cos(a) * 0.22]], 0.012, s.root, 8);
    }
    const trunk = new THREE.Group();
    plant.add(trunk);
    tube(trunk, [[0, 0, 0], [0.04, 0.2, 0.01], [-0.03, 0.42, -0.02], [0.01, 0.6, 0.01]], 0.035, s.bark, 16);
    const crown = new THREE.Group();
    plant.add(crown);
    const fruits = new THREE.Group();
    crown.add(fruits);
    for (let k = 0; k < 5; k++) {
      const a = (k * TAU) / 5 + r() * 0.4;
      const length = 0.17 + r() * 0.06;
      const end = [Math.sin(a) * length, 0.1 + r() * 0.08, Math.cos(a) * length];
      tube(crown, [[0, 0, 0], [end[0] * 0.5, end[1] * 0.9, end[2] * 0.5], end], 0.018, s.bark, 8);
      part(crown, new THREE.ConeGeometry(0.035, 0.18, 6), s.frond, end).rotation.set(Math.cos(a) * 0.9, 0, -Math.sin(a) * 0.9);
      part(fruits, blob(0.05, 0xe8442a, seed + k, 0.08), s.fruit, [end[0] * 0.85, end[1] - 0.05, end[2] * 0.85]);
    }
    return (stage, slow, phase) => {
      const shown = presence(stage);
      const grow = smoothstep(0.08, 0.6, stage);
      scaleTo(seedling, shown * (1 - smoothstep(0.12, 0.32, stage)));
      scaleTo(plant, shown);
      scaleTo(roots, smoothstep(0.05, 0.4, stage));
      // The trunk reaches 0.75 of its modelled 0.6 height, keeping the tree low in its tank.
      trunk.scale.set(0.4 + 0.6 * grow, Math.max(0.001, 0.75 * grow), 0.4 + 0.6 * grow);
      crown.position.y = 0.41 * grow;
      scaleTo(crown, smoothstep(0.3, 0.65, stage));
      scaleTo(fruits, smoothstep(0.55, 0.8, stage) * (1 + 0.06 * Math.sin(TAU * 8 * slow)));
      plant.rotation.set(0.05 * Math.cos(TAU * (6 * slow + phase)), 0, 0.07 * Math.sin(TAU * (6 * slow + phase)));
    };
  },

  // Jellystem: from a mound, three mauve strands twist upwards into a thick trunk, and clusters
  // of ribbed Jellynut pods swell along it from the bottom up, crowned by a cluster at the top.
  "jellynut"(g, seed, s) {
    const r = random(seed + 2);
    const HEIGHT = 0.62;
    const mound = part(g, blob(0.11, 0x6e3f5c, seed, 0.14, [1.3, 0.45, 1.3]), s.jellystem, [0, -0.45, 0]);
    const plant = new THREE.Group();
    plant.position.y = -0.43;
    g.add(plant);
    const lean = (f) => [0.05 * f * f, 0.03 * f];
    const trunk = new THREE.Group();
    plant.add(trunk);
    for (let k = 0; k < 3; k++) {
      const points = [];
      for (let j = 0; j <= 10; j++) {
        const f = j / 10;
        const angle = (k * TAU) / 3 + f * TAU * 0.85;
        const radius = 0.05 * (1 - 0.45 * f);
        const [lx, lz] = lean(f);
        points.push([Math.sin(angle) * radius + lx, f * HEIGHT, Math.cos(angle) * radius + lz]);
      }
      const strand = tube(trunk, points, 0.03 * (1 - 0.1 * k), s.jellystem, 24);
      mottled(strand.geometry, [0x7a4068, 0x8c5078, 0x6a3460][k], seed + k, 0.25);
    }
    // Pods: [height fraction, angle, size]; the last three crown the top.
    const spots = [[0.3, 0.4, 0.8], [0.45, 2.6, 0.9], [0.58, 4.6, 0.95], [0.7, 1.4, 1], [0.8, 3.6, 1], [0.98, 0.6, 1.05], [0.98, 2.7, 1], [1.02, 4.8, 1.1]];
    const pods = spots.map(([f, angle, size], k) => {
      const pod = new THREE.Group();
      plant.add(pod);
      const out = f > 0.95 ? 0.06 : 0.075;
      part(pod, jellynutPod(0.08 * size, seed + k), s.pod, [Math.sin(angle) * out, 0, Math.cos(angle) * out]).rotation.set(0.3 * Math.cos(angle), angle, -0.3 * Math.sin(angle));
      // A curled mauve leaf cupping each pod from below.
      part(pod, blob(0.04 * size, 0x9a6888, seed + k + 7, 0.12, [1.3, 0.35, 1]), s.jellystem, [Math.sin(angle) * out * 0.7, -0.06 * size, Math.cos(angle) * out * 0.7]).rotation.y = angle;
      return { pod, f: Math.min(1, f), appear: 0.18 + 0.42 * Math.min(1, f) + r() * 0.04, offset: r() };
    });
    return (stage, slow, phase) => {
      const shown = presence(stage);
      const grow = smoothstep(0.06, 0.62, stage);
      scaleTo(mound, shown * (0.5 + 0.5 * smoothstep(0, 0.2, stage)));
      scaleTo(plant, shown);
      const width = 0.45 + 0.55 * grow;
      trunk.scale.set(width, Math.max(0.001, grow), width);
      for (const { pod, f, appear, offset } of pods) {
        const [lx, lz] = lean(f);
        pod.position.set(lx * width, f * HEIGHT * grow, lz * width);
        scaleTo(pod, smoothstep(appear, appear + 0.2, stage) * (1 + 0.05 * Math.sin(TAU * (6 * slow + offset))));
      }
      plant.rotation.set(0.04 * Math.cos(TAU * (4 * slow + phase)), 0, 0.05 * Math.sin(TAU * (4 * slow + phase)));
    };
  },

  // Biter, after the vanilla small biter: a banded amber egg swells and turns translucent to show
  // the curled embryo, then breaks away to free a hatchling. It has a hunched abdomen of
  // overlapping ochre armour rings tapering to the rear, a small pale head held low with a dark
  // eye ring on each side and downturned mandibles, and six thin pale legs with high knees. Once
  // free it stands mostly side-on, like the in-game sprites, and steps in place.
  "biter-egg"(g, seed, s) {
    const eggShell = shell();
    const egg = part(g, biterEgg(0.15), eggShell, [0, -0.22, 0]);
    const bug = new THREE.Group();
    g.add(bug);
    const body = new THREE.Group();
    bug.add(body);
    // Abdomen rings from the rear (-z) to the thorax: [z, y, radius, length].
    const rings = [[-0.165, 0.105, 0.046, 0.034], [-0.13, 0.115, 0.062, 0.038], [-0.09, 0.115, 0.074, 0.04], [-0.047, 0.106, 0.08, 0.042],
      [-0.003, 0.09, 0.078, 0.042], [0.04, 0.07, 0.068, 0.04], [0.077, 0.05, 0.056, 0.034]];
    rings.forEach(([z, y, radius, length], k) => {
      const ring = part(body, biterRing(radius, length, seed + k), s.carapace, [0, y, z]);
      // Tilt each ring along the hunched arc: rear raised, sloping down to the head.
      ring.rotation.x = -0.35 + k * 0.13;
    });
    const head = new THREE.Group();
    head.position.set(0, 0.03, 0.125);
    head.rotation.x = 0.4;
    body.add(head);
    part(head, blob(0.05, 0xa8705a, seed + 9, 0.05, [1, 0.88, 1.2]), s.tissue);
    for (const side of [-1, 1]) {
      // The large dark eye socket rimmed by a pale ridge, the vanilla biter's most visible feature.
      part(head, new THREE.SphereGeometry(0.021, 12, 8), s.eye, [side * 0.04, 0.008, 0.01]);
      part(head, new THREE.TorusGeometry(0.024, 0.008, 6, 16), s.biterLeg, [side * 0.042, 0.008, 0.01], [0, side * Math.PI / 2, 0]);
      tube(head, [[side * 0.018, -0.012, 0.045], [side * 0.026, -0.04, 0.07], [side * 0.01, -0.066, 0.074]], 0.008, s.biterClaw, 8);
    }
    const legs = [];
    for (const side of [-1, 1]) {
      for (const [k, z] of [0.07, 0.035, 0.0].entries()) {
        const leg = new THREE.Group();
        leg.position.set(side * 0.04, 0.035, z);
        body.add(leg);
        const reach = (1 - k) * 0.06;
        // A short thigh out to a knee at mid-body height, then a shin down to the floor.
        tube(leg, [[0, 0, 0], [side * 0.045, 0.03, reach * 0.4], [side * 0.085, 0.035, reach * 0.8]], 0.01, s.biterLeg, 8);
        tube(leg, [[side * 0.085, 0.035, reach * 0.8], [side * 0.11, -0.03, reach * 1.1], [side * 0.12, -0.1, reach * 1.3]], 0.008, s.biterLeg, 8);
        part(leg, new THREE.ConeGeometry(0.008, 0.026, 5), s.biterClaw, [side * 0.121, -0.112, reach * 1.31], [0, 0, Math.PI]);
        legs.push({ leg, side, gait: (k + (side > 0 ? 1 : 0)) % 2 });
      }
    }
    // Side-on, facing either way, as biters are usually seen.
    const facing = (seed % 2 ? 1 : -1) * Math.PI / 2;
    return (stage, slow, phase) => {
      const shown = presence(stage);
      eggShell.opacity = mix(0.97, 0.35, smoothstep(0.32, 0.5, stage)) * (1 - smoothstep(0.55, 0.68, stage));
      egg.visible = eggShell.opacity > 0.01;
      scaleTo(egg, shown * (0.45 + 0.55 * smoothstep(0, 0.3, stage)) * (1 + 0.12 * smoothstep(0.5, 0.68, stage)));
      const hatched = smoothstep(0.55, 0.75, stage);
      scaleTo(bug, shown * smoothstep(0.3, 0.7, stage));
      bug.position.y = mix(-0.24, -0.33, hatched) + 0.008 * Math.sin(TAU * (16 * slow + phase));
      // Curled up in the egg, then upright and turning slowly between its two profiles.
      bug.rotation.set(mix(1.3, 0, hatched), facing + phase * 2 + 0.5 * Math.sin(TAU * (2 * slow + phase)), 0);
      head.rotation.x = 0.35 + 0.15 * hatched * Math.sin(TAU * (8 * slow + phase));
      for (const { leg, side, gait } of legs) {
        // Tripod gait: alternate legs step together once they are free.
        const step = Math.sin(TAU * (16 * slow + gait * 0.5));
        leg.rotation.z = side * mix(-1.2, 0.06 * Math.max(0, step), hatched);
        leg.rotation.y = 0.25 * hatched * step * side;
      }
    };
  },

  // Pentapod: a ridged green egg hatches a five-legged hatchling that paddles slowly upwards.
  "pentapod-egg"(g, seed, s) {
    const eggShell = shell();
    const egg = part(g, blob(0.14, 0x4f8f6a, seed, 0.1, [1, 1.15, 1], 4), eggShell, [0, -0.28, 0]);
    const pod = new THREE.Group();
    g.add(pod);
    part(pod, blob(0.07, 0x9cbf3c, seed + 1, 0.07, [1, 0.75, 1]), s.tissue);
    for (let n = 0; n < 3; n++) {
      part(pod, new THREE.SphereGeometry(0.014, 8, 6), tag(new THREE.MeshStandardMaterial({ color: 0x202010, emissive: 0xfff060, emissiveIntensity: 0.6 })),
        [Math.sin(n * 0.5 - 0.5) * 0.06, 0.035, Math.cos(n * 0.5 - 0.5) * 0.06]);
    }
    const legs = [];
    for (let k = 0; k < 5; k++) {
      const leg = new THREE.Group();
      leg.rotation.y = (k * TAU) / 5;
      pod.add(leg);
      const joint = new THREE.Group();
      leg.add(joint);
      tube(joint, [[0.05, 0, 0], [0.11, 0.06, 0], [0.18, 0.03, 0], [0.23, -0.07, 0]], 0.011, s.pentaLeg, 10);
      legs.push({ joint, k });
    }
    return (stage, slow, phase) => {
      const shown = presence(stage);
      eggShell.opacity = mix(0.95, 0.35, smoothstep(0.3, 0.48, stage)) * (1 - smoothstep(0.52, 0.66, stage));
      egg.visible = eggShell.opacity > 0.01;
      scaleTo(egg, shown * (0.5 + 0.5 * smoothstep(0, 0.28, stage)));
      const hatched = smoothstep(0.52, 0.72, stage);
      scaleTo(pod, shown * 0.9 * smoothstep(0.28, 0.68, stage));
      pod.position.y = -0.28 + 0.25 * smoothstep(0.6, 0.88, stage) + 0.025 * Math.sin(TAU * (8 * slow + phase));
      pod.rotation.y = -TAU * slow + phase * 6;
      for (const { joint, k } of legs) {
        joint.rotation.z = mix(0.9, 0, hatched) + 0.3 * hatched * Math.sin(TAU * (12 * slow + k / 5));
      }
    };
  }
};
