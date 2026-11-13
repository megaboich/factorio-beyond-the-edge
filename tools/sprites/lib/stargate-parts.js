// Shared geometry for the Stargate models: the modern, human-built gate. A cast concrete platform
// sunk into a shallow basin, a segmented steel ring with a dark tungsten core, two steel support
// towers with ventilator fans and grilles, cable trays, hazard markings, and cyan status lights.
// Units are tiles; x east, y up, z south. The platform's border is level with the ground (y = 0).
//
// Layout across the 14 tiles (east-west): four tiles of platform, a rail lane (2), a two-tile gap, a
// second rail lane (2), and four more tiles; the lanes are centred two tiles either side of the centre.
// The floor slopes from the border down into a basin (DECK) so the ring can stand lower, and a trench
// across the platform under the ring (TRENCH) holds its lower arc, so the whole ring stays visible
// while its opening at deck level is wide enough for a train on either lane. Steel bridges carry the
// lanes over the trench; the `tracks` option lays rails along them.
//
// One build covers every state of the gate (STATES below):
//   site      the basin and trench dug in raw concrete, formwork, stacked steel, and a crane mast
//   stage1    the floor finished, the tower frames up, the lower half of the ring, the crane at work
//   stage2    the towers clad, the ring all but its top, the bridges in, scaffolding at the gap
//   complete  the finished gate: clamps and lights on the ring, fans, cable trays, and markings
// Lit parts carry `userData.glow = {layer: "lights"}`, exported as `glow-lights`; the earlier states have none.
import * as THREE from "three";
import { factorioTexture, random, textured } from "./textures.js";
import { beam, part, tube } from "./geometry.js";

const TAU = Math.PI * 2;
const DEG = Math.PI / 180;

export const HALF = 7;
// Floor heights: the border, the basin floor the lanes cross, and the bottom of the trench.
const GROUND = 0.08;
const DECK = -0.6;
const TRENCH = -2.9;
// The ring stands this far south of the platform's centre, so its height does not pile up over the
// back of the building on screen. The trench spans the ring along z; its south side is a slope, so the
// camera (looking north and down) can see the ring's lowest point over it.
const RING_Z = 2;
const TRENCH_Z = [RING_Z - 1.25, RING_Z + 2.5];
const TRENCH_X = 5.75;
// The ring's inner edge is 3.1 tiles from its axis at deck level, clearing both lanes (to x = +-3).
export const RING = { cy: 2.8, inner: 4.6, mid: 5.05, outer: 5.5 };
const RING_DEPTH = 1.0;
const TOWER = { x: 6.3, width: 1.3, depth: 2.6, top: 4.4 };
const LANES = [-2, 2];
const CLAMPS = 12;
const CYAN = 0x2fd2ff;

// Ring arcs are lists of [from, to] in degrees, counter-clockwise from east (90 is the top, 270 the
// bottom). `level` is how finished the platform is: 0 raw concrete, 1 finished, 2 with bridges and
// markings. `towers` is 0 none, 1 bare frames, 2 clad, 3 finished.
const STATES = {
  site: { level: 0, towers: 0, ring: [], crane: "mast", stacks: 3, seed: 11 },
  stage1: { level: 1, towers: 1, ring: [[200, 340]], crane: "boom", stacks: 2, seed: 12 },
  stage2: { level: 2, towers: 2, ring: [[130, 410]], scaffold: true, crane: "boom", stacks: 1, seed: 13 },
  complete: { level: 3, towers: 3, ring: [[0, 360]], seed: 5 }
};

// Vanilla refined concrete for the finished floor (plain concrete for the raw site), so it matches tiles laid around the gate: one 512 px variant of the
// sheet covers 9 tiles, which matches the brick size in game. The tint offsets the renderer's brighter lighting. The site's raw floor is the same concrete, darker and dustier.
const CONCRETE = "base/graphics/terrain/concrete/concrete.png";
const REFINED = "base/graphics/terrain/concrete/refined-concrete.png";

export async function materials() {
  return {
    concrete: await factorioTexture(REFINED, { crop: [0, 0, 512], scale: 9, tint: 0xb4b4b4 }),
    raw: await factorioTexture(CONCRETE, { crop: [512, 0, 512], scale: 9, tint: 0x9a8f80 }),
    steel: textured({ color: 0x70777f, panels: 2, rivets: true, grime: 0.35, rust: 0.05, scratches: 0.35, scale: 1.5, metalness: 0.65, roughness: 0.45, seed: 75 }),
    plate: textured({ color: 0x5c636b, panels: 1, grime: 0.3, scratches: 0.3, scale: 1, metalness: 0.6, roughness: 0.5, seed: 77 }),
    tungsten: textured({ color: 0x34373d, panels: 1, grime: 0.3, scratches: 0.4, scale: 1, metalness: 0.75, roughness: 0.4, seed: 79 }),
    grating: textured({ color: 0x3a3d40, holes: 12, grime: 0.4, rust: 0.05, scale: 1.2, metalness: 0.6, seed: 81 }),
    hazard: textured({ color: 0xc9a227, stripes: true, grime: 0.4, scratches: 0.4, scale: 1, metalness: 0.2, seed: 83 }),
    rubber: textured({ color: 0x232427, grime: 0.2, scale: 1, metalness: 0.2, roughness: 0.8, seed: 85 }),
    wood: textured({ color: 0x7a5a38, panels: 2, grime: 0.4, scale: 1.5, metalness: 0, roughness: 0.9, seed: 87 }),
    glow: Object.assign(new THREE.MeshStandardMaterial({ color: 0x0c2b33, emissive: CYAN, emissiveIntensity: 1.4, roughness: 0.4 }), {
      userData: { glow: { layer: "lights" } }
    })
  };
}

const inArc = (degrees, [from, to]) => (((degrees - from) % 360) + 360) % 360 <= to - from;
const inAnyArc = (degrees, arcs) => arcs.some((arc) => inArc(degrees, arc));
const lerp = (a, b, t) => a + (b - a) * Math.min(1, Math.max(0, t));

/** The floor height at (x, z): level at the border, sloping into the basin, with the trench under the ring. */
function floorHeight(x, z, { trench = true } = {}) {
  const edge = HALF - Math.max(Math.abs(x), Math.abs(z));
  let y = lerp(GROUND, DECK, (edge - 0.75) / 1.5);
  if (trench && Math.abs(x) <= TRENCH_X && z >= TRENCH_Z[0] && z <= TRENCH_Z[1]) {
    // A sheer north wall and a sloped south one, which keeps the ring's lowest point in view.
    y = Math.min(y, lerp(TRENCH, DECK, (z - (TRENCH_Z[1] - 1.5)) / 1.5));
  }
  return y;
}

/** The floor as one height-field mesh, sampled finely enough that the trench walls stay crisp. */
function floor(root, material, options) {
  const step = 0.125;
  const n = Math.round((HALF * 2) / step);
  const geometry = new THREE.PlaneGeometry(HALF * 2, HALF * 2, n, n);
  geometry.rotateX(-Math.PI / 2);
  const position = geometry.attributes.position;
  for (let i = 0; i < position.count; i++) position.setY(i, floorHeight(position.getX(i), position.getZ(i), options));
  geometry.computeVertexNormals();
  part(root, geometry, material);
  // A kerb along the border, so the slab has an edge rather than a paper-thin rim.
  for (const [w, d, x, z] of [[HALF * 2, 0.2, 0, -HALF + 0.1], [HALF * 2, 0.2, 0, HALF - 0.1], [0.2, HALF * 2, -HALF + 0.1, 0], [0.2, HALF * 2, HALF - 0.1, 0]]) {
    part(root, new THREE.BoxGeometry(w, 0.3, d), material, [x, GROUND - 0.14, z]);
  }
}

/** An annular sector standing in the x-y plane, `depth` thick along z, centred on z = 0. */
function sector(r0, r1, a0, a1, depth, curveSegments = 4) {
  const shape = new THREE.Shape();
  shape.absarc(0, 0, r1, a0, a1, false);
  shape.absarc(0, 0, r0, a1, a0, true);
  const geometry = new THREE.ExtrudeGeometry(shape, { depth, bevelEnabled: false, curveSegments });
  geometry.translate(0, 0, -depth / 2);
  return geometry;
}

function ringPoint(degrees, radius, z = 0) {
  const a = degrees * DEG;
  return new THREE.Vector3(Math.cos(a) * radius, RING.cy + Math.sin(a) * radius, RING_Z + z);
}

/**
 * The ring over `arcs`: 36 segments, each a steel outer casing with a grille panel on both faces,
 * around a dark tungsten core that projects a little at the inner edge. Finished, it gets clamp
 * housings with status lights and a glowing emitter line along the inner edge.
 */
function ring(root, m, arcs, finished) {
  const count = 36;
  const step = TAU / count;
  for (let i = 0; i < count; i++) {
    const a0 = i * step;
    if (!inAnyArc(((a0 + step / 2) / DEG) % 360, arcs)) continue;
    const gap = 0.006;
    part(root, sector(RING.mid, RING.outer, a0 + gap, a0 + step - gap, RING_DEPTH), m.steel, [0, RING.cy, RING_Z]);
    part(root, sector(RING.inner, RING.mid, a0 + gap, a0 + step - gap, RING_DEPTH * 0.8), m.tungsten, [0, RING.cy, RING_Z]);
    for (const face of [-1, 1]) {
      part(root, sector(RING.mid + 0.08, RING.outer - 0.08, a0 + 0.03, a0 + step - 0.03, 0.04), m.grating, [0, RING.cy, RING_Z + face * (RING_DEPTH / 2 + 0.01)]);
    }
  }
  if (!finished) return;
  for (const face of [-1, 1]) {
    part(root, sector(RING.inner + 0.04, RING.inner + 0.1, 0, TAU, 0.03, 96), m.glow, [0, RING.cy, RING_Z + face * (RING_DEPTH * 0.4 + 0.015)]);
  }
  for (let i = 0; i < CLAMPS; i++) clamp(root, m, 90 + i * (360 / CLAMPS));
}

/** A clamp housing wrapped over the ring's outer edge, with a light bar on each face. */
function clamp(root, m, degrees) {
  const group = new THREE.Group();
  const centre = ringPoint(degrees, RING.outer - 0.05);
  group.position.copy(centre);
  group.rotation.z = (degrees - 90) * DEG;
  root.add(group);
  part(group, new THREE.BoxGeometry(0.7, 0.36, RING_DEPTH + 0.16), m.plate, [0, 0.08, 0]);
  part(group, new THREE.BoxGeometry(0.5, 0.06, RING_DEPTH + 0.2), m.tungsten, [0, 0.28, 0]);
  for (const face of [-1, 1]) {
    part(group, new THREE.BoxGeometry(0.42, 0.08, 0.03), m.glow, [0, 0.02, face * (RING_DEPTH / 2 + 0.095)]);
  }
}

/** A ventilator: a round steel frame with a dark hub and swept blades, facing along `normal`. */
function fan(root, m, position, normal, radius) {
  const group = new THREE.Group();
  group.position.set(...position);
  group.lookAt(new THREE.Vector3(...position).add(new THREE.Vector3(...normal)));
  root.add(group);
  const frame = new THREE.TorusGeometry(radius, radius * 0.12, 6, 24);
  part(group, frame, m.plate);
  part(group, new THREE.CircleGeometry(radius, 24), m.rubber, [0, 0, -0.02]);
  part(group, new THREE.CylinderGeometry(radius * 0.22, radius * 0.22, 0.08, 12), m.steel, [0, 0, 0.02], [Math.PI / 2, 0, 0]);
  for (let i = 0; i < 5; i++) {
    const blade = part(group, new THREE.BoxGeometry(radius * 0.75, radius * 0.26, 0.02), m.plate, [0, 0, 0.01]);
    const a = (i / 5) * TAU;
    blade.position.set(Math.cos(a) * radius * 0.5, Math.sin(a) * radius * 0.5, 0.01);
    blade.rotation.set(0.5, 0, a);
  }
  for (let i = -2; i <= 2; i++) {
    part(group, new THREE.BoxGeometry(radius * 2, 0.025, 0.025), m.steel, [0, i * radius * 0.38, 0.06]);
  }
}

/**
 * The support towers at the ring's flanks, housing its electronics and cooling: a bare steel lattice
 * (level 1), clad in panels with grilles (2), then finished with fans, a roof cooling unit, clamp arms
 * gripping the ring, and status lights (3).
 */
function towers(root, m, level) {
  if (!level) return;
  const { x: cx, width, depth, top } = TOWER;
  const bottom = TRENCH;
  const height = top - bottom;
  for (const side of [-1, 1]) {
    const x = side * cx;
    if (level === 1) {
      for (const dx of [-1, 1]) for (const dz of [-1, 1]) {
        part(root, new THREE.BoxGeometry(0.14, height, 0.14), m.steel, [x + dx * (width / 2 - 0.07), bottom + height / 2, RING_Z + dz * (depth / 2 - 0.07)]);
      }
      for (let y = 0.6; y < top; y += 1.2) {
        for (const dz of [-1, 1]) part(root, new THREE.BoxGeometry(width, 0.1, 0.1), m.steel, [x, y, RING_Z + dz * (depth / 2 - 0.07)]);
        for (const dx of [-1, 1]) part(root, new THREE.BoxGeometry(0.1, 0.1, depth), m.steel, [x + dx * (width / 2 - 0.07), y, RING_Z]);
      }
      continue;
    }
    part(root, new THREE.BoxGeometry(width, height, depth), m.steel, [x, bottom + height / 2, RING_Z]);
    part(root, new THREE.BoxGeometry(width + 0.1, 0.16, depth + 0.1), m.plate, [x, top + 0.08, RING_Z]);
    // Grilles on the faces towards the camera and the opening.
    for (let y = 0.7; y < top - 0.6; y += 1.15) {
      part(root, new THREE.BoxGeometry(width - 0.3, 0.7, 0.04), m.grating, [x, y, RING_Z + depth / 2 + 0.02]);
    }
    part(root, new THREE.BoxGeometry(0.04, top - 1.6, depth - 0.5), m.grating, [x - side * (width / 2 + 0.02), (top + 0.4) / 2 + 0.4, RING_Z]);
    if (level < 3) {
      housing(root, m, side, level);
      continue;
    }
    // Two ventilators on the south face, a roof cooling unit with fans facing up, and clamp arms.
    housing(root, m, side, level);
    for (const y of [1.1, 2.9]) fan(root, m, [x, y, RING_Z + depth / 2 + 0.06], [0, 0, 1], 0.45);
    part(root, new THREE.BoxGeometry(width - 0.1, 0.4, depth - 0.3), m.plate, [x, top + 0.36, RING_Z]);
    for (const dz of [-0.6, 0.6]) fan(root, m, [x, top + 0.58, RING_Z + dz], [0, 1, 0], 0.42);
    for (const dz of [-0.35, 0.35]) {
      part(root, new THREE.BoxGeometry(0.5, 0.5, 0.3), m.tungsten, [side * (RING.outer + 0.15), RING.cy, RING_Z + dz]);
    }
    for (const dz of [-1, 1]) {
      part(root, new THREE.BoxGeometry(width - 0.5, 0.08, 0.03), m.glow, [x, top - 0.35, RING_Z + dz * (depth / 2 + 0.03)]);
    }
  }
}

/**
 * The machinery housing that fills the lower corner between a tower and the ring (`side` -1 west, 1
 * east): a steel casing whose inner edge follows the ring's outer curve from just below its axis
 * down into the trench, so ring and tower read as one machine. Finished (level 3), its front carries
 * an inset tungsten panel, conduits curving with the ring, hydraulic rams bracing the ring, a small
 * fan, a grille, and a status light.
 */
function housing(root, m, side, level) {
  const inner = TOWER.x - TOWER.width / 2 + 0.05;
  const bottom = DECK - 0.4;
  const R = RING.outer + 0.02;
  const low = Math.asin((bottom - RING.cy) / R);
  const high = Math.asin(1.0 / R);
  const outline = (inset) => {
    const shape = new THREE.Shape();
    shape.moveTo(side * (inner - inset), RING.cy + 1.0 - inset);
    shape.lineTo(side * (inner - inset), bottom + inset);
    const steps = 16;
    for (let i = 0; i <= steps; i++) {
      const a = low + (high - low) * (i / steps);
      shape.lineTo(side * Math.cos(a) * (R + inset), RING.cy + Math.sin(a) * (R + inset));
    }
    return shape;
  };
  const depth = TOWER.depth + 0.2;
  const slab = (shape, d, material, z) => {
    const geometry = new THREE.ExtrudeGeometry(shape, { depth: d, bevelEnabled: false });
    geometry.translate(0, 0, -d / 2);
    return part(root, geometry, material, [0, 0, z]);
  };
  slab(outline(0), depth, m.steel, RING_Z);
  if (level < 3) return;
  const front = RING_Z + depth / 2;
  slab(outline(0.12), 0.08, m.plate, front + 0.04);
  // Ribs across the casing's front, stepping down with the curve.
  for (let y = DECK + 0.2; y < RING.cy + 0.9; y += 0.45) {
    const circleX = Math.sqrt(Math.max(0, R * R - (y - RING.cy) ** 2));
    const from = Math.max(circleX + 0.15, 0) ;
    if (inner - 0.15 - from < 0.2) continue;
    part(root, new THREE.BoxGeometry(inner - 0.15 - from, 0.06, 0.06), m.tungsten, [side * (from + inner - 0.15) / 2, y, front + 0.1]);
  }
  const ringAt = (deg, r, z) => [side * Math.cos(deg * DEG) * r, RING.cy + Math.sin(deg * DEG) * r, z];
  // Conduits following the ring's curve.
  for (const [r, z] of [[R + 0.18, front + 0.12], [R + 0.32, front + 0.12], [R + 0.18, front - depth - 0.02]]) {
    const points = [];
    for (let deg = 10; deg >= -30; deg -= 2) points.push(ringAt(deg, r, z));
    points.push([side * (inner - 0.1), points[points.length - 1][1] - 0.3, z]);
    tube(root, points, 0.045, m.rubber, 32);
  }
  // Hydraulic rams from the casing to clamp points on the ring.
  for (const deg of [4, -10, -24]) {
    const from = new THREE.Vector3(side * (inner - 0.1), RING.cy + Math.sin(deg * DEG) * R - 0.5, front + 0.18);
    const to = new THREE.Vector3(...ringAt(deg, RING.outer - 0.1, front + 0.18));
    const mid = from.clone().lerp(to, 0.55);
    beam(root, from, mid, 0.09, m.plate, 10);
    beam(root, mid, to, 0.05, m.steel, 10);
    part(root, new THREE.BoxGeometry(0.22, 0.22, 0.22), m.tungsten, [to.x, to.y, to.z]);
  }
  const panelX = side * (inner - 0.45);
  fan(root, m, [panelX, DECK + 0.75, front + 0.14], [0, 0, 1], 0.3);
  part(root, new THREE.BoxGeometry(0.5, 0.3, 0.03), m.grating, [panelX, DECK + 1.45, front + 0.11]);
  part(root, new THREE.BoxGeometry(0.3, 0.06, 0.03), m.glow, [panelX, DECK + 1.8, front + 0.11]);
}

/** The steel bridges that carry the lanes over the trench, with rails when `tracks` is set. */
function bridges(root, m) {
  const length = TRENCH_Z[1] - TRENCH_Z[0] + 0.4;
  const z = (TRENCH_Z[0] + TRENCH_Z[1]) / 2;
  for (const x of LANES) {
    for (const dx of [-0.75, 0.75]) part(root, new THREE.BoxGeometry(0.22, 0.45, length), m.plate, [x + dx, DECK - 0.2, z]);
    part(root, new THREE.BoxGeometry(1.9, 0.05, length), m.grating, [x, DECK + 0.03, z]);
    for (const dx of [-0.95, 0.95]) {
      for (let post = TRENCH_Z[0]; post <= TRENCH_Z[1] + 0.01; post += (TRENCH_Z[1] - TRENCH_Z[0]) / 3) {
        part(root, new THREE.BoxGeometry(0.05, 0.5, 0.05), m.hazard, [x + dx, DECK + 0.3, post]);
      }
      part(root, new THREE.BoxGeometry(0.05, 0.05, length), m.hazard, [x + dx, DECK + 0.55, z]);
    }
  }
}

/** Rails down each lane, following the floor: sleepers and two steel rails. */
function tracks(root, m) {
  const step = 0.5;
  for (const x of LANES) {
    for (let z = -HALF + 0.25; z < HALF; z += step) {
      const y = floorHeight(x, z, { trench: false });
      part(root, new THREE.BoxGeometry(1.8, 0.07, 0.22), m.raw, [x, y + 0.08, z]);
    }
    for (const dx of [-0.72, 0.72]) {
      const points = [];
      for (let z = -HALF; z <= HALF + 0.001; z += 0.25) points.push([x + dx, floorHeight(x, z, { trench: false }) + 0.17, z]);
      tube(root, points, 0.05, m.steel, 112);
    }
  }
}

/** Floor lights at the corners. */
function markings(root, m, lit) {
  if (!lit) return;
  for (const sx of [-1, 1]) for (const sz of [-1, 1]) {
    const x = sx * (HALF - 0.4), z = sz * (HALF - 0.4);
    part(root, new THREE.BoxGeometry(0.4, 0.18, 0.4), m.plate, [x, GROUND + 0.09, z]);
    part(root, new THREE.BoxGeometry(0.28, 0.05, 0.28), m.glow, [x, GROUND + 0.2, z]);
  }
}

/** A control cabinet at the front left, beside the west tower. */
function services(root, m) {
  const [x, z] = [-5.4, 6.1];
  part(root, new THREE.BoxGeometry(1.4, 1.5, 0.8), m.plate, [x, GROUND + 0.75, z]);
  part(root, new THREE.BoxGeometry(1.0, 0.5, 0.03), m.grating, [x, GROUND + 1.0, z + 0.41]);
  part(root, new THREE.BoxGeometry(0.6, 0.06, 0.03), m.glow, [x, GROUND + 1.35, z + 0.41]);
  fan(root, m, [x + 0.45, GROUND + 0.45, z + 0.42], [0, 0, 1], 0.2);
  // A cable tray from the cabinet into the tower's foot.
  part(root, new THREE.BoxGeometry(0.3, 0.12, z - 0.4 - (RING_Z + TOWER.depth / 2)), m.grating, [x, GROUND + 0.06, (z - 0.4 + RING_Z + TOWER.depth / 2) / 2]);
}

/** Raw-concrete formwork, stacked steel, and a crane while the gate is built. */
function worksite(root, m, rand, spec) {
  const stacks = [[4.6, 5.4], [-5.2, -5.0], [5.0, -5.0]].slice(0, spec.stacks ?? 0);
  for (const [x, z] of stacks) {
    part(root, new THREE.BoxGeometry(1.5, 0.14, 1.1), m.wood, [x, GROUND + 0.07, z]);
    for (let i = 0; i < 3; i++) {
      const beamMesh = part(root, new THREE.BoxGeometry(1.4, 0.2, 0.28), m.steel, [x, GROUND + 0.24 + Math.floor(i / 3) * 0.2, z - 0.35 + i * 0.35]);
      beamMesh.rotation.y = (rand() - 0.5) * 0.08;
    }
    part(root, new THREE.BoxGeometry(1.2, 0.5, 0.9), m.tungsten, [x, GROUND + 0.6, z]);
  }
  if (spec.level === 0) {
    // Formwork boards along the trench.
    for (const z of TRENCH_Z) part(root, new THREE.BoxGeometry(TRENCH_X * 2, 0.4, 0.08), m.wood, [0, DECK + 0.15, z]);
  }
  if (spec.scaffold) {
    // Scaffolding around the unfinished top of the ring.
    for (const x of [-1.6, 1.6]) for (const dz of [-0.8, 0.8]) {
      part(root, new THREE.BoxGeometry(0.07, RING.cy + RING.outer - DECK, 0.07), m.steel, [x, (RING.cy + RING.outer + DECK) / 2, RING_Z + dz]);
    }
    for (let y = 1; y < RING.cy + RING.outer; y += 1.4) {
      for (const dz of [-0.8, 0.8]) part(root, new THREE.BoxGeometry(3.3, 0.06, 0.06), m.steel, [0, y, RING_Z + dz]);
    }
    part(root, new THREE.BoxGeometry(3.4, 0.08, 1.7), m.wood, [0, RING.cy + RING.outer - 0.9, RING_Z]);
  }
  crane(root, m, spec.crane);
}

/** A lattice crane at the front left: just the mast at first, then with a boom over the ring. */
function crane(root, m, kind) {
  if (!kind) return;
  const x = -5.6;
  const z = 3.9;
  const boomY = RING.cy + RING.outer + 0.8;
  part(root, new THREE.BoxGeometry(0.9, 0.3, 0.9), m.hazard, [x, GROUND + 0.15, z]);
  for (const dx of [-0.2, 0.2]) for (const dz of [-0.2, 0.2]) {
    beam(root, new THREE.Vector3(x + dx, GROUND, z + dz), new THREE.Vector3(x + dx, boomY, z + dz), 0.035, m.hazard, 6);
  }
  for (let y = GROUND + 0.5; y < boomY; y += 0.6) {
    part(root, new THREE.BoxGeometry(0.44, 0.04, 0.44), m.hazard, [x, y, z]);
  }
  if (kind !== "boom") return;
  const tip = new THREE.Vector3(1.5, boomY + 0.2, RING_Z);
  beam(root, new THREE.Vector3(x, boomY, z), tip, 0.08, m.hazard);
  beam(root, new THREE.Vector3(x, boomY, z), new THREE.Vector3(x + 0.8, boomY - 0.1, z + 0.6), 0.08, m.hazard);
  part(root, new THREE.BoxGeometry(0.6, 0.5, 0.6), m.plate, [x, boomY + 0.3, z]);
  const along = (0.4 - x) / (tip.x - x);
  const hangZ = z + along * (tip.z - z);
  const hangTop = boomY + 0.2 * along;
  beam(root, new THREE.Vector3(0.4, hangTop, hangZ), new THREE.Vector3(0.4, RING.cy + RING.outer + 0.35, hangZ), 0.02, m.rubber, 4);
  part(root, new THREE.BoxGeometry(0.9, 0.3, RING_DEPTH), m.steel, [0.4, RING.cy + RING.outer + 0.2, hangZ]);
}

// How far parts lean in towards the centre line per tile of height, as a fraction of their distance from it.
const LEAN = 0.0055;

/**
 * Fakes the slight perspective of vanilla building renders, which an orthographic camera lacks:
 * every vertex moves towards the x = 0 plane in proportion to its height, so the towers' and ring's
 * vertical sides lean in and show a sliver of their outer faces instead of reading as flat cut-outs.
 * Transforms are baked into each geometry first, so the lean is in model space.
 */
function lean(root) {
  root.updateMatrixWorld(true);
  const meshes = [];
  root.traverse((object) => { if (object.isMesh) meshes.push(object); });
  for (const mesh of meshes) {
    const geometry = mesh.geometry.clone();
    geometry.applyMatrix4(mesh.matrixWorld);
    const position = geometry.attributes.position;
    for (let i = 0; i < position.count; i++) {
      const y = position.getY(i);
      if (y > 0) position.setX(i, position.getX(i) * (1 - LEAN * y));
    }
    geometry.computeBoundingSphere();
    mesh.geometry = geometry;
    mesh.removeFromParent();
    mesh.position.set(0, 0, 0);
    mesh.rotation.set(0, 0, 0);
    mesh.scale.set(1, 1, 1);
    root.add(mesh);
  }
}

/**
 * Builds the gate in `state` ("site", "stage1", "stage2", or "complete"). `tracks` lays rails along
 * both lanes, for the gate once its train station is activated.
 */
export async function build({ state = "complete", tracks: withTracks = false } = {}) {
  const spec = STATES[state];
  if (!spec) throw new Error(`unknown Stargate state ${state}`);
  const root = new THREE.Group();
  const rand = random(spec.seed);
  const m = await materials();
  floor(root, spec.level === 0 ? m.raw : m.concrete);
  ring(root, m, spec.ring, state === "complete");
  towers(root, m, spec.towers);
  // The portal is left empty for now: no bridges over the trench until train passage needs them.
  if (withTracks) bridges(root, m);
  markings(root, m, state === "complete");
  if (state === "complete") services(root, m);
  else worksite(root, m, rand, spec);
  if (withTracks) tracks(root, m);
  lean(root);
  // The models are lit from the north-west like the rest of the game, which leaves the south face
  // the camera sees in shade; a gentle fill from the south-west keeps the faces readable.
  const fill = new THREE.DirectionalLight(0xffeedd, 0.7);
  fill.position.set(-4, 6, 10);
  root.add(fill);
  return root;
}
