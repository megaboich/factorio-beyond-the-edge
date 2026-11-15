// Shared geometry for the Stargate models: the modern, human-built gate. A cast concrete platform
// sunk into a shallow basin, a segmented steel ring with a dark tungsten core, two steel support
// towers with ventilator fans and grilles, cable trays, hazard markings, and cyan status lights.
// Units are tiles; x east, y up, z south. The platform's border is level with the ground (y = 0).
//
// Layout across the 14 tiles (east-west): four tiles of platform, a rail lane (2), a two-tile gap, a
// second rail lane (2), and four more tiles; the lanes are centred two tiles either side of the centre.
// The floor slopes from the border down into a basin (DECK) so the ring can stand lower, and a trench
// across the platform under the ring (TRENCH) holds its lower arc, so the whole ring stays visible
// while its opening at deck level is wide enough for a train on either lane. The `tracks` option sets
// station-mode track into the floor along the lanes, ending at the trench's lip.
//
// One build covers every state of the gate (STATES below):
//   site      the finished floor, the control cabinet, the front east capacitor rack, and the bottom
//             of the ring (8 tiles wide), inside hazard tape round the perimeter
//   stage1-5  each adds to the last: more ring, the machinery housings, the clad towers,
//             the west and east capacitor banks, then the towers' fans and a whole ring
//   complete  the finished gate: clamps and lights on the ring, lights on, markings; the tape is gone
// Nothing but the finished gate lights up: before that its lamps are dark.
// Lit parts carry `userData.glow = {layer: "lights"}`, exported as `glow-lights`; the earlier states have none.
// Their material is also tagged "light", so the finished model can re-render them red (glow-lights-red).
// The finished gate also holds the veil, the active portal's light (tag "veil", see veil() and drawVeil()).
import * as THREE from "three";
import { factorioTexture, textured } from "./textures.js";
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
const CLAMPS = 12;
const CYAN = 0x2fd2ff;

// Ring arcs are lists of [from, to] in degrees, counter-clockwise from east (90 is the top, 270 the
// bottom); the site's [225, 315] spans the outer edge 8 tiles across. `towers` is 0 none, 1 bare
// frames, 2 clad, 3 finished; `housing` is 0 none, 2 bare casing, 3 finished. `banks` lists the
// capacitor groups in place: the front east rack, and the west and east banks along the back walls.
const STATES = {
  site: { towers: 0, housing: 0, ring: [[225, 315]], banks: ["front"] },
  stage1: { towers: 0, housing: 2, ring: [[205, 335]], banks: ["front"] },
  stage2: { towers: 2, housing: 2, ring: [[180, 360]], banks: ["front"] },
  stage3: { towers: 2, housing: 2, ring: [[150, 390]], banks: ["front", "west"] },
  stage4: { towers: 2, housing: 3, ring: [[115, 425]], banks: ["front", "west", "east"] },
  stage5: { towers: 3, housing: 3, ring: [[0, 360]], banks: ["front", "west", "east"] },
  complete: { towers: 3, housing: 3, ring: [[0, 360]], banks: ["front", "west", "east"] }
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
    ceramic: textured({ color: 0xd9d4c8, grime: 0.25, scratches: 0.15, scale: 1, metalness: 0.05, roughness: 0.35, seed: 89 }),
    // Station-mode track, after the game's rails: brown-grey ballast, dark wooden sleepers, bright rails.
    // Station-mode track (laneTrack()), coloured after the game's rail sheets (rail-stone-path, -inside,
    // -ties, -backplates, -metals), and red steel after its ramps.
    // The bed under the track: riveted dark steel deck plates, with grating between the rails.
    ballast: textured({ color: 0x2c2f34, panels: 3, rivets: true, grime: 0.3, scratches: 0.4, scale: 1, metalness: 0.65, roughness: 0.45, seed: 93 }),
    ballastInner: textured({ color: 0x383c42, holes: 10, grime: 0.3, scale: 1.2, metalness: 0.6, roughness: 0.5, seed: 94 }),
    sleeper: textured({ color: 0x55585c, grime: 0.45, scratches: 0.7, scale: 0.6, metalness: 0, roughness: 0.85, seed: 95 }),
    backplate: textured({ color: 0x77736e, grime: 0.4, rust: 0.2, scale: 1, metalness: 0.5, roughness: 0.6, seed: 96 }),
    // Matte enough that no rail catches a bright reflection where the light hits it.
    rail: Object.assign(textured({ color: 0x5f9cc0, grime: 0.15, scratches: 0.3, scale: 1, metalness: 0.4, roughness: 0.7, seed: 97 }), { envMapIntensity: 0.4 }),
    redSteel: textured({ color: 0x5e221c, panels: 1, grime: 0.4, rust: 0.1, scratches: 0.35, scale: 1, metalness: 0.45, roughness: 0.55, seed: 99 }),
    frost: textured({ color: 0xa9c4cf, panels: 1, grime: 0.15, scratches: 0.2, scale: 1, metalness: 0.55, roughness: 0.3, seed: 91 }),
    glow: Object.assign(new THREE.MeshStandardMaterial({ color: 0x0c2b33, emissive: CYAN, emissiveIntensity: 1.4, roughness: 0.4 }), {
      userData: { glow: { layer: "lights" }, tag: "light" }
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
  part(root, geometry, material).userData.floor = true;
  // A kerb along the border, so the slab has an edge rather than a paper-thin rim.
  for (const [w, d, x, z] of [[HALF * 2, 0.2, 0, -HALF + 0.1], [HALF * 2, 0.2, 0, HALF - 0.1], [0.2, HALF * 2, -HALF + 0.1, 0], [0.2, HALF * 2, HALF - 0.1, 0]]) {
    part(root, new THREE.BoxGeometry(w, 0.3, d), material, [x, GROUND - 0.14, z]).userData.floor = true;
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
    if (level < 3) continue;
    // Two ventilators on the south face, a roof cooling unit with fans facing up, and clamp arms.
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

// Station-mode track (stargate/scripts/railway.lua): one lane on the centre line, or two either side.
export const TRACK_LANES = { single: [0], double: [-2, 2] };
// Where the track stops: an eighth of a tile into the ring's front face. It runs over the ring's
// lower arc, which lies in the trench below it.
const TRACK_END = RING_Z + RING_DEPTH / 2 - 0.125;
// Half the rail gauge, from the game's rail-metals sheet (36 px from the centre at 64 px a tile).
const GAUGE = 0.5625;

// The track's height on its ramp: level with the ground at the gate's edge, rising gently to
// RAMP_TOP at the ring, so it crosses the basin and the ring's lower arc above them.
const RAMP_TOP = DECK + 0.05;
const trackHeight = (z) => lerp(GROUND, RAMP_TOP, Math.min(1, (HALF - z) / (HALF - TRACK_END)));
// Where the track ends behind the ring: level at RAMP_TOP through the ring and on behind it, far
// enough that the ring's upper part hides its end on screen.
const TRACK_FAR = RING_Z - 5.406;

/**
 * Track along lane `x` after the game's rail ramps, tagged `userData.track = x`: a riveted steel deck
 * with grating between the rails, edge lips and cyan marker studs, ties,
 * backplates, and rails sized and coloured after the game's rail sheets, carried by red steel trusses along both sides over a
 * dark recessed core, from the gate's south edge, where red foot blocks anchor the ramp and the game's
 * rails join it, over the basin and the ring's lower arc into the ring.
 */
function laneTrack(root, m, x) {
  // Its own layer is rendered with the building hidden (models/stargate.js), so the track shades only
  // itself and both lanes look alike: in game the gate's shadow layer falls over it anyway.
  const add = (mesh) => { mesh.userData.track = x; return mesh; };
  const step = 0.25;
  const base = (z) => Math.min(floorHeight(x, z), trackHeight(z)) - 0.05;
  for (let z = TRACK_FAR; z < HALF - 0.001; z += step) {
    const zc = z + step / 2;
    const top = trackHeight(zc);
    // The core under the track, set back between the trusses so it reads as shadowed structure.
    add(part(root, new THREE.BoxGeometry(1.7, top - base(zc), step + 0.01), m.tungsten, [x, (top + base(zc)) / 2, zc]));
  }
  // The track, measured from the game's straight rail sheets at 64 px a tile: ballast 2.06 tiles
  // wide with a raised inner bed 1.15 wide, ties 1.5 long and 0.16 thick every 0.406, backplates and
  // rail heads 0.5625 either side of the centre.
  const along = (top, w, h, material) => {
    for (let z = TRACK_FAR; z < HALF - 0.001; z += step) {
      const zc = z + step / 2;
      add(part(root, new THREE.BoxGeometry(w, h, step + 0.01), material, [x, trackHeight(zc) + top - h / 2, zc]));
    }
  };
  along(0.05, 2.06, 0.05, m.ballast);
  along(0.08, 1.15, 0.05, m.ballastInner);
  // Steel lips along the deck's edges, with a cyan marker stud every tile.
  for (const side of [-1, 1]) {
    const lip = [];
    for (let z = TRACK_FAR; z <= HALF + 0.001; z += 0.25) lip.push([x + side * 0.98, trackHeight(z) + 0.07, z]);
    add(tube(root, lip, 0.04, m.plate, 48));
    for (let z = HALF - 0.5; z > TRACK_FAR + 0.3; z -= 1) {
      add(part(root, new THREE.BoxGeometry(0.08, 0.03, 0.14), m.glow, [x + side * 0.86, trackHeight(z) + 0.065, z]));
    }
  }
  // From the gate's edge inwards, the first tie flush with it; tall enough to read as blocks with
  // shaded sides.
  for (let z = HALF - 0.08; z > TRACK_FAR + 0.08; z -= 0.406) {
    add(part(root, new THREE.BoxGeometry(1.5, 0.1, 0.16), m.sleeper, [x, trackHeight(z) + 0.1, z]));
  }
  for (const dx of [-GAUGE, GAUGE]) {
    const plates = [], heads = [];
    // Run a little past the edge: raised above the deck, they would otherwise end short of it on screen.
    for (let z = TRACK_FAR; z <= HALF + 0.21; z += 0.25) {
      plates.push([x + dx, trackHeight(z) + 0.13, z]);
      heads.push([x + dx, trackHeight(z) + 0.17, z]);
    }
    add(tube(root, plates, 0.07, m.backplate, 64));
    add(tube(root, heads, 0.035, m.rail, 64));
  }
  // The side trusses: a top chord level with the ballast, a bottom chord on the floor, posts every
  // tile, and a diagonal in each bay. Off while trying the track without them.
  const TRUSSES = false;
  for (const dx of TRUSSES ? [-1, 1] : []) {
    const sx = x + dx;
    const chord = (y) => {
      const points = [];
      for (let z = TRACK_FAR; z <= HALF - 0.6 + 0.001; z += 0.25) points.push([sx, y(z), z]);
      add(tube(root, points, 0.07, m.redSteel, 48));
    };
    chord((z) => trackHeight(z) + 0.06);
    chord((z) => base(z) + 0.12);
    for (let z = HALF - 0.6; z > TRACK_END + 0.2; z -= 1) {
      add(part(root, new THREE.BoxGeometry(0.12, trackHeight(z) - base(z), 0.12), m.redSteel, [sx, (trackHeight(z) + base(z)) / 2, z]));
      const z2 = Math.max(TRACK_END, z - 1);
      add(beam(root, new THREE.Vector3(sx, base(z) + 0.12, z), new THREE.Vector3(sx, trackHeight(z2) + 0.06, z2), 0.04, m.redSteel, 6));
    }
    // The foot block anchoring the ramp at the gate's edge.
    const z = HALF - 0.45;
    add(part(root, new THREE.BoxGeometry(0.34, 0.42, 0.7), m.redSteel, [sx + dx * 0.05, GROUND + 0.21, z]));
    add(part(root, new THREE.BoxGeometry(0.44, 0.08, 0.8), m.plate, [sx + dx * 0.05, GROUND + 0.04, z]));
    add(part(root, new THREE.BoxGeometry(0.2, 0.12, 0.2), m.tungsten, [sx + dx * 0.05, GROUND + 0.48, z + 0.1]));
  }
}

// Direction chevrons for a two-track station: low steel plates on the concrete either side of each
// lane, pointing the way its trains run. Tagged `userData.chevrons` with the layout they belong to:
// "right" has trains leave on the east lane (x = +2) and arrive on the west, "left" the reverse
// (stargate/scripts/railway.lua LAYOUTS).
const CHEVRON = { offset: 1.32, arm: 0.3, width: 0.08, height: 0.07, rows: [6.45, 5.45, 4.6] };
function chevrons(root, m) {
  for (const layout of ["right", "left"]) {
    for (const lane of TRACK_LANES.double) {
      const departs = (lane > 0) === (layout === "right");
      // North (-z, into the ring) on the departure lane, south on the arrival lane.
      const dir = departs ? -1 : 1;
      for (const side of [-1, 1]) for (const z of CHEVRON.rows) {
        const x = lane + side * CHEVRON.offset;
        const y = floorHeight(x, z) + CHEVRON.height / 2;
        for (const s of [-1, 1]) {
          // Each arm runs from the tip back and out to one side at 45 degrees, centred on the row so
          // chevrons pointing either way line up.
          const h = CHEVRON.arm / Math.SQRT2 / 2;
          const mesh = part(root, new THREE.BoxGeometry(CHEVRON.arm, CHEVRON.height, CHEVRON.width), m.plate,
            [x + s * h, y, z], [0, s * dir * Math.PI / 4, 0]);
          mesh.userData.chevrons = layout;
        }
      }
    }
  }
}

function tracks(root, m, lanes) {
  for (const x of lanes) laneTrack(root, m, x);
  if (lanes.some((x) => TRACK_LANES.double.includes(x))) chevrons(root, m);
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

/**
 * One superconducting capacitor can standing at (x, z) on `base`: a steel body with a tungsten foot
 * collar and cryostat ribs, a lit charge band, a ceramic insulator stack on top, and a terminal cap.
 */
function capacitorCan(root, m, x, z, base, height) {
  const r = 0.3;
  part(root, new THREE.CylinderGeometry(r + 0.05, r + 0.08, 0.18, 16), m.tungsten, [x, base + 0.09, z]);
  part(root, new THREE.CylinderGeometry(r, r, height, 16), m.steel, [x, base + height / 2, z]);
  for (const f of [0.3, 0.55]) {
    part(root, new THREE.CylinderGeometry(r + 0.025, r + 0.025, 0.05, 16), m.plate, [x, base + height * f, z]);
  }
  part(root, new THREE.CylinderGeometry(r + 0.012, r + 0.012, 0.1, 16), m.glow, [x, base + height * 0.8, z]);
  part(root, new THREE.CylinderGeometry(r * 0.75, r, 0.08, 16), m.plate, [x, base + height + 0.04, z]);
  // The insulator: a stack of ceramic sheds under a steel terminal.
  for (let i = 0; i < 3; i++) {
    part(root, new THREE.CylinderGeometry(0.15, 0.17, 0.06, 12), m.ceramic, [x, base + height + 0.12 + i * 0.09, z]);
  }
  part(root, new THREE.CylinderGeometry(0.06, 0.06, 0.32, 8), m.ceramic, [x, base + height + 0.2, z]);
  part(root, new THREE.CylinderGeometry(0.08, 0.08, 0.06, 8), m.steel, [x, base + height + 0.39, z]);
  return base + height + 0.42;
}

/**
 * The gate's power bank (docs/power.md): superconducting capacitor cans in rows along the west and
 * east walls, behind the towers, and a lower rack in the front east corner. Each row stands on a
 * steel plinth over a grated cable trench, carries a copper-dark busbar along its terminals into
 * the tower, and has frosted coolant lines from a cryo cooler at its north end. The lanes and the
 * apron in front of the ring stay clear, so vehicles and walkers are not hidden.
 */
function capacitors(root, m, banks, wired = true) {
  const towerNorth = RING_Z - TOWER.depth / 2;
  for (const side of [-1, 1]) {
    if (!banks.includes(side < 0 ? "west" : "east")) continue;
    // The back bank: two rows of four cans between the north wall and the tower.
    const rows = [4.75, 6.05];
    const zs = [-5.0, -3.7, -2.4, -1.1];
    const plinthX = (rows[0] + rows[1]) / 2;
    part(root, new THREE.BoxGeometry(2.3, 0.22, 5.6), m.plate, [side * plinthX, GROUND + 0.11, -3.3]);
    part(root, new THREE.BoxGeometry(0.5, 0.04, 5.4), m.grating, [side * plinthX, GROUND + 0.24, -3.3]);
    for (const x of rows) {
      let top = 0;
      for (const z of zs) top = capacitorCan(root, m, side * x, z, GROUND + 0.22, 1.2);
      // The busbar along the row's terminals, dropping into the tower's north face.
      part(root, new THREE.BoxGeometry(0.1, 0.07, zs[zs.length - 1] - zs[0] + 0.3), m.tungsten, [side * x, top + 0.01, (zs[0] + zs[zs.length - 1]) / 2]);
      tube(root, [[side * x, top, zs[zs.length - 1] + 0.1], [side * x, top + 0.05, towerNorth - 0.35], [side * x, top + 0.3, towerNorth - 0.05]], 0.055, m.tungsten, 16);
    }
    // A cross busbar tying the rows, and a cryo cooler at the north end with frosted coolant lines.
    part(root, new THREE.BoxGeometry(rows[1] - rows[0] + 0.1, 0.07, 0.1), m.tungsten, [side * plinthX, GROUND + 1.86, zs[0] - 0.05]);
    const cooler = [side * plinthX, -6.1];
    part(root, new THREE.BoxGeometry(2.1, 0.6, 0.7), m.plate, [cooler[0], GROUND + 0.3, cooler[1]]);
    fan(root, m, [cooler[0], GROUND + 0.63, cooler[1]], [0, 1, 0], 0.3);
    for (const x of rows) {
      const lx = side * (x + (x === rows[0] ? 0.38 : -0.38));
      tube(root, [[lx, GROUND + 0.45, cooler[1] + 0.35], [lx, GROUND + 0.45, zs[0]], [lx, GROUND + 0.45, zs[zs.length - 1]], [lx, GROUND + 0.9, towerNorth - 0.1]], 0.07, m.frost, 24);
    }
    part(root, new THREE.BoxGeometry(0.5, 0.06, 0.03), m.glow, [cooler[0], GROUND + 0.45, cooler[1] + 0.36]);
  }
  // The front east corner: a low rack of four cans, opposite the control cabinet.
  if (!banks.includes("front")) return;
  const x0 = 5.4, z0 = 5.0;
  part(root, new THREE.BoxGeometry(1.5, 0.2, 2.6), m.plate, [x0, GROUND + 0.1, z0 + 0.65]);
  for (const dx of [-0.38, 0.38]) for (const dz of [0, 1.3]) capacitorCan(root, m, x0 + dx, z0 + dz, GROUND + 0.2, 0.9);
  part(root, new THREE.BoxGeometry(0.9, 0.07, 0.1), m.tungsten, [x0, GROUND + 1.52, z0]);
  part(root, new THREE.BoxGeometry(0.9, 0.07, 0.1), m.tungsten, [x0, GROUND + 1.52, z0 + 1.3]);
  // Its cable into the east tower, once the tower stands.
  if (wired) tube(root, [[x0, GROUND + 1.52, z0 - 0.05], [x0 + 0.5, GROUND + 1.3, RING_Z + TOWER.depth / 2 + 0.2], [6.3, 1.6, RING_Z + TOWER.depth / 2]], 0.05, m.tungsten, 16);
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

/** Yellow and black hazard tape on short posts round the platform's edge while the gate is built. */
function tape(root, m) {
  const edge = HALF - 0.15;
  const posts = [];
  for (let i = -HALF; i <= HALF; i += 2) {
    const t = Math.max(-edge, Math.min(edge, i));
    posts.push([t, -edge], [t, edge], [-edge, t], [edge, t]);
  }
  for (const [x, z] of posts) part(root, new THREE.BoxGeometry(0.08, 0.6, 0.08), m.rubber, [x, GROUND + 0.3, z]);
  for (const sz of [-1, 1]) part(root, new THREE.BoxGeometry(edge * 2, 0.12, 0.02), m.hazard, [0, GROUND + 0.48, sz * edge]);
  for (const sx of [-1, 1]) part(root, new THREE.BoxGeometry(0.02, 0.12, edge * 2), m.hazard, [sx * edge, GROUND + 0.48, 0]);
}

const VEIL_SIZE = 256;

/**
 * The active portal: a disc filling the ring's opening, lit by a canvas texture that drawVeil()
 * repaints per frame. Hidden until the model shows its active variant; an additive light only.
 */
function veil(root) {
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = VEIL_SIZE;
  const texture = new THREE.CanvasTexture(canvas);
  texture.colorSpace = THREE.SRGBColorSpace;
  const material = new THREE.MeshStandardMaterial({
    color: 0x000000, emissive: 0xffffff, emissiveIntensity: 1.6, emissiveMap: texture,
    transparent: true, depthWrite: false, side: THREE.DoubleSide, roughness: 1, metalness: 0
  });
  material.userData.tag = "veil";
  const mesh = part(root, new THREE.CircleGeometry(RING.inner + 0.05, 96), material, [0, RING.cy, RING_Z + 0.02]);
  mesh.visible = false;
  root.userData.veil = { canvas, texture, material };
}

/**
 * Paints the veil at `t` (0 to 1 over one loop): a deep blue pool brightening towards the rim, with
 * rings rippling out from the centre and a slow swirl. Every term repeats a whole number of times
 * per loop, so the animation loops seamlessly.
 */
export function drawVeil(root, t) {
  drawVeilShape(root, t, () => ({ reach: 1, alpha: 1, flash: 0, surge: 0 }));
}

// The veil's brightness at (x, y) of the unit disc, `t` (0 to 1) into its loop.
function veilValue(x, y, t) {
  const wave = (v) => Math.sin(v * TAU);
  const r = Math.hypot(x, y);
  const a = Math.atan2(y, x) / TAU;
  let v = 0.35 + 0.45 * r ** 3;
  v += 0.16 * wave(5 * r - 2 * t) * (1 - r * 0.6);
  v += 0.08 * wave(11 * r - 3 * t + 0.3 * wave(3 * a + t));
  v += 0.1 * wave(3 * a + 2.5 * r - t) * r;
  v += 0.05 * wave(7 * a - 4 * r + 2 * t);
  v += 0.35 * Math.max(0, 1 - r * 4) * (0.6 + 0.4 * wave(t));
  return v;
}

/**
 * The portal forming or collapsing, played once by scripts/gate.lua: `t` runs 0 to 1. Opening
 * (2.2 s) starts with a flash at the centre, then a burst overshoots out of the middle and settles
 * as the veil spreads to the rim; closing (1.2 s) shrinks and fades it to nothing. Same timings as
 * stargate-showcase.html.
 */
export function drawVeilTransition(root, t, closing) {
  drawVeilShape(root, t, (t) => {
    if (closing) {
      const since = t * 1.2;
      const k = Math.max(0, 1 - t);
      return { reach: k ** 0.6, alpha: k, flash: since < 0.2 ? (0.2 - since) * 2 : 0, surge: 0 };
    }
    const since = t * 2.2;
    const reach = Math.min(1, Math.max(0, (since - 0.35) / 0.9));
    const flash = since < 0.35 ? since / 0.35 : Math.max(0, 1 - (since - 0.35) / 1.2);
    const surge = since > 0.3 && since < 1.4 ? Math.sin((since - 0.3) / 1.1 * Math.PI) : 0;
    return { reach: Math.max(reach, surge * 0.6), alpha: 0.4 + 0.6 * reach, flash, surge };
  });
}

function drawVeilShape(root, t, look) {
  const { canvas, texture } = root.userData.veil;
  const ctx = canvas.getContext("2d");
  const image = ctx.createImageData(VEIL_SIZE, VEIL_SIZE);
  const { reach, alpha, flash, surge } = look(t);
  for (let py = 0; py < VEIL_SIZE; py++) {
    for (let px = 0; px < VEIL_SIZE; px++) {
      const x = (px + 0.5) / VEIL_SIZE * 2 - 1;
      const y = (py + 0.5) / VEIL_SIZE * 2 - 1;
      const r = Math.hypot(x, y);
      let v = 0;
      if (reach > 0) {
        // A soft edge: the veil fades in over the outer quarter of its reach (a full veil keeps its
        // hard rim, below), so a growing or shrinking veil has no sharp, pixelated border.
        const soft = reach >= 1 ? 0 : 0.25 * reach + 0.05;
        const edge = soft ? Math.min(1, Math.max(0, (reach - r) / soft)) : r < 1 ? 1 : 0;
        const fade = edge * edge * (3 - 2 * edge);
        if (fade > 0) v = veilValue(x / Math.max(reach, 0.01), y / Math.max(reach, 0.01), t) * alpha * fade;
        // The burst's leading edge, a broad glow brightest at the front.
        v += surge * 0.5 * Math.exp(-(((reach - r) * 4) ** 2));
      }
      // The flash, a light at the centre that fills the ring.
      v += flash * 1.1 * Math.exp(-r * r * 5);
      v = Math.max(0, Math.min(1.2, v));
      const rim = Math.max(0, Math.min(1, (1 - r) * 40));
      const i = (py * VEIL_SIZE + px) * 4;
      image.data[i] = Math.min(255, 255 * (0.08 * v + 0.7 * Math.max(0, v - 0.75)));
      image.data[i + 1] = Math.min(255, 255 * (0.45 * v + 0.5 * Math.max(0, v - 0.7)));
      image.data[i + 2] = Math.min(255, 255 * (0.95 * v));
      image.data[i + 3] = 255 * rim;
    }
  }
  ctx.putImageData(image, 0, 0);
  texture.needsUpdate = true;
}

/**
 * The veil's reaction to someone passing through, drawn over it as extra light: a flash where the
 * traveller entered (low and central, at body height), then waves running out across the whole veil
 * and fading, with the veil swelling brighter as they pass. `t` runs 0 to 1 once; nothing loops.
 */
export function drawPassage(root, t) {
  const { canvas, texture } = root.userData.veil;
  const ctx = canvas.getContext("2d");
  const image = ctx.createImageData(VEIL_SIZE, VEIL_SIZE);
  // The entry point in canvas coordinates (y down): about 0.8 tiles above the ground, 2.8 below the axis.
  const oy = 0.43;
  const fade = Math.min(1, t * 12) * (1 - t) ** 1.5;
  for (let py = 0; py < VEIL_SIZE; py++) {
    for (let px = 0; px < VEIL_SIZE; px++) {
      const x = (px + 0.5) / VEIL_SIZE * 2 - 1;
      const y = (py + 0.5) / VEIL_SIZE * 2 - 1;
      const r = Math.hypot(x, y);
      if (r > 1) continue;
      const d = Math.hypot(x, (y - oy) * 1.1);
      const front = t * 2.4;
      // Wave crests behind the expanding front, strongest just behind it.
      const behind = front - d;
      let v = 0;
      if (behind > 0) {
        // Broad, rounded crests, and a front that fades in rather than starting at full strength:
        // a hard step there read as a pixelated ring.
        const crest = (0.5 + 0.5 * Math.cos((behind * 7) * TAU / 2.2)) ** 2;
        const lead = Math.min(1, behind / 0.2);
        v += crest * lead * lead * (3 - 2 * lead) * Math.exp(-behind * 1.6) * 1.1;
      }
      // The flash at the entry point, and a general swell of the whole veil.
      v += Math.exp(-d * d * 30) * Math.max(0, 1 - t * 3) * 2.2;
      v += 0.18 * Math.sin(Math.min(1, t * 1.5) * Math.PI);
      v *= fade + Math.exp(-d * d * 30) * Math.max(0, 1 - t * 3);
      const rim = Math.max(0, Math.min(1, (1 - r) * 40));
      // A soft ceiling instead of a clamp, so the brightest parts do not flatten into hard patches.
      v = 1.4 * Math.tanh(v / 1.4) * rim;
      const i = (py * VEIL_SIZE + px) * 4;
      image.data[i] = Math.min(255, 255 * (0.35 * v + 0.6 * Math.max(0, v - 0.6)));
      image.data[i + 1] = Math.min(255, 255 * (0.75 * v));
      image.data[i + 2] = Math.min(255, 255 * v);
      image.data[i + 3] = 255;
    }
  }
  ctx.putImageData(image, 0, 0);
  texture.needsUpdate = true;
}

/**
 * One train carriage passing the veil, drawn over it as extra light: a carriage-sized glow low on the
 * centre line (the gate draws it at each lane, scripts/railway.lua) that flares as the carriage
 * meets the veil and spreads into one ring as it fades, hiding the moment the carriage vanishes or
 * appears. `t` runs 0 to 1 once; everything outside the splash stays dark.
 */
export function drawSplash(root, t) {
  const { canvas, texture } = root.userData.veil;
  const ctx = canvas.getContext("2d");
  const image = ctx.createImageData(VEIL_SIZE, VEIL_SIZE);
  // A carriage behind the veil, about to vanish or just appeared, fills its lane's column of the
  // veil on screen from the deck nearly to the ring's top (5.2 tiles long, 1.6 high, seen at 50
  // degrees), so the glow covers that column, wider than the carriage (unit disc, y down),
  // centred a quarter of a carriage below the veil's centre, where the change shows most.
  const oy = 0.39;
  const flare = Math.exp(-(((t - 0.25) / 0.16) ** 2));
  const ring = t * 0.32;
  const fade = (1 - t) ** 1.4;
  for (let py = 0; py < VEIL_SIZE; py++) {
    for (let px = 0; px < VEIL_SIZE; px++) {
      const x = (px + 0.5) / VEIL_SIZE * 2 - 1;
      const y = (py + 0.5) / VEIL_SIZE * 2 - 1;
      // A tall soft column whose light thins out gradually instead of ending at a visible edge.
      const d = Math.hypot(x / 0.5, (y - oy) / 1.8);
      const body = Math.exp(-d * d * 1.5);
      let v = body * (0.15 + 0.5 * flare);
      v += Math.exp(-(((d * 0.2 - ring) / 0.08) ** 2)) * 0.45 * fade * Math.min(1, t * 6) * Math.min(1, body * 4);
      v *= fade;
      // Inside the veil only, as the carriage vanishes and appears only there, fading out over the
      // veil's outer quarter rather than cut at its rim.
      const edge = Math.max(0, Math.min(1, (1 - Math.hypot(x, y)) / 0.25));
      v = 1.4 * Math.tanh(v / 1.4) * edge * edge * (3 - 2 * edge);
      const i = (py * VEIL_SIZE + px) * 4;
      image.data[i] = Math.min(255, 255 * (0.35 * v + 0.6 * Math.max(0, v - 0.6)));
      image.data[i + 1] = Math.min(255, 255 * (0.75 * v));
      image.data[i + 2] = Math.min(255, 255 * v);
      image.data[i + 3] = 255;
    }
  }
  ctx.putImageData(image, 0, 0);
  texture.needsUpdate = true;
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
 * Builds the gate in `state` ("site", "stage1" to "stage5", or "complete"). `tracks` lists the lanes
 * (x offsets) to lay station-mode track along, each tagged with its lane (laneTrack()).
 */
export async function build({ state = "complete", tracks: lanes = null } = {}) {
  const spec = STATES[state];
  if (!spec) throw new Error(`unknown Stargate state ${state}`);
  const root = new THREE.Group();
  const finished = state === "complete";
  const lit = await materials();
  // Unfinished, the lamps are dark and export no glow layer.
  const m = finished ? lit : { ...lit, glow: lit.rubber };
  floor(root, m.concrete);
  ring(root, m, spec.ring, finished);
  for (const side of [-1, 1]) if (spec.housing) housing(root, m, side, spec.housing);
  towers(root, m, spec.towers);
  markings(root, m, finished);
  services(root, m);
  capacitors(root, m, spec.banks, spec.towers > 0);
  if (finished) {
    veil(root);
    root.userData.lights = m.glow;
  }
  else tape(root, m);
  if (lanes) tracks(root, m, lanes);
  lean(root);
  // The models are lit from the north-west like the rest of the game, which leaves the south face
  // the camera sees in shade; a gentle fill from the south-west keeps the faces readable.
  const fill = new THREE.DirectionalLight(0xffeedd, 0.7);
  fill.position.set(-4, 6, 10);
  root.add(fill);
  return root;
}
