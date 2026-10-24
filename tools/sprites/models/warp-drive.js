// Warp Drive: an 8x8 platform-only drive core, the size of the space platform hub. Units are tiles;
// x east, y up, z south.
//
// A tall core column on a round dais: a quartz glass tube between two heavy injector caps, caged by
// six dark structural ribs. Inside, five segmented magnetic rings float around a needle-thin
// core. Glass conduits arc from both caps to four field projectors in the corners, and insulated
// liquid-helium lines run from four manifold pumps into the lower cap.
//
// The hull (`main`, one static frame) never moves. Everything that changes with the drive's state
// is an overlay the game swaps at runtime (warp-drive/scripts/visuals.lua):
// - interior-<state>: the glass tube, rings, nozzles, and core thread, cut by the ribs in front.
// - glow-<state>: additive light: core plasma, ring nodes, conduits, projectors, and deck glow.
// - lamps: status lamps, always on (drawn by the animation companion).
// States (variants):
// - standby: rings motionless in alignment, a black core thread in a faint icy halo.
// - detecting: the charging animation in neon green, while the experimental drive detects
//   tachyons. The game speeds it up and brightens it with detector power.
// - charging: alternate rings counter-rotate, injectors fire into a pulsing cobalt-white plasma
//   column, and the tube's interior seems to stretch into infinite depth. The game speeds this up
//   and brightens it as the warp reserve fills.
// - activation: a one-shot 1.5 s pulse, timed with warp-activation.ogg: the rings snap into
//   alignment, the core implodes and flashes, a shockwave leaves the column, and the conduits flare.
//   The rings then spin up to their warp speed.
// - warp: alternate rings counter-rotate at the speed of a full charge, blue and violet waves
//   cascade down the column around flickering filaments, and the conduits carry azure plasma to
//   the projectors.
import * as THREE from "three";
import { random, textured } from "../lib/textures.js";
import { beam, part, tube } from "../lib/geometry.js";

const TAU = Math.PI * 2;
// One building loop is LOOP frames; game speeds are in warp-drive/scripts/visuals.lua.
const LOOP = 32;
const ACTIVATION_FRAMES = 30;
// The activation lasts 90 ticks (1.5 s); a loop of LOOP frames lasts 64 ticks at 0.5 frames per tick.
const ACTIVATION_SPAN = 90 / 64;
const STATES = ["standby", "detecting", "charging", "activation", "warp"];
// Ring turn per loop, in segments: charging at its base speed (the game plays it from half to double
// speed), and warp, which matches a full charge.
const CHARGING_TURN = 2;
const WARP_TURN = 4;
// The activation's rings start spinning up at this fraction of it.
const SPIN_UP_FROM = 0.45;

const HALF = 3.9; // half the deck's width, the collision box's edge
const BASE = 0.11; // top of the deck plate
const DAIS = 0.43; // top of the dais
const CAP_BOTTOM = 0.89; // top of the lower injector cap
const TUBE_BOTTOM = 1.07;
const TUBE_TOP = 4.89;
const TUBE_RADIUS = 1.07;
const RIB_RADIUS = 1.18;
const RIBS = 6;
const CAP_RADIUS = 1.38;
const RINGS = 5;
const RING_Y = 1.58;
const RING_STEP = 0.69;
const RING_RADIUS = 0.73;
const SEGMENTS = 16;
const SEGMENT = TAU / SEGMENTS;
const CORE_BOTTOM = 1.42;
const CORE_TOP = 4.53;
const CORE_MID = (CORE_BOTTOM + CORE_TOP) / 2;
const PROJECTOR = 2.8; // corner projector offset on each axis
// The activation's shockwave fades at the building's 4-tile edge, where the game's rings take over
// (warp-drive/scripts/shockwaves.lua).
const SHOCK_REACH = 3.91;
const DIAGONALS = [[-1, -1], [1, -1], [-1, 1], [1, 1]];
// The round core (dais, caps, column, rings, cooling ring, and their light) is squashed front to
// back to this fraction. The renderer keeps ground tiles square so the footprint matches the
// game's grid, which would otherwise draw every flat circle as a circle; vanilla art draws them as
// ovals about this tall. Duplicated in growth-facility.js and warp-field.js (the shockwave ring).
const ROUND_DEPTH = 0.78;

const COLORS = {
  icy: 0x9fe8ff,
  white: 0xe4ecff,
  cobalt: 0x5b84ff,
  deep: 0x2b4cff,
  azure: 0x39b8ff,
  electric: 0x3d7dff,
  violet: 0x8a5cff,
  // Tachyon detection.
  mint: 0xe2ffe8,
  neon: 0x39ff7a,
  emerald: 0x0bb34a,
  lime: 0x9dff3d
};
// The charging animation's colours, shared by tachyon detection in neon green.
const PALETTES = {
  charging: { core: COLORS.white, mid: COLORS.cobalt, deep: COLORS.deep, tunnel: COLORS.violet, accent: COLORS.cobalt },
  detecting: { core: COLORS.mint, mid: COLORS.neon, deep: COLORS.emerald, tunnel: COLORS.lime, accent: COLORS.neon }
};

const smoothstep = (a, b, x) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};
const mix = (a, b, t) => a + (b - a) * t;
/** A bump that rises over [a, b] and falls over [c, d]. */
const pulse = (a, b, c, d, x) => smoothstep(a, b, x) * (1 - smoothstep(c, d, x));

/** A canvas texture from `fn(u, v)` returning [r, g, b] in 0–1 (u and v run 0–1). */
function canvasTexture(width, height, fn, repeat = false) {
  const image = new ImageData(width, height);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const [r, g, b] = fn((x + 0.5) / width, 1 - (y + 0.5) / height);
      image.data.set([r * 255, g * 255, b * 255, 255], (y * width + x) * 4);
    }
  }
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  canvas.getContext("2d").putImageData(image, 0, 0);
  const texture = new THREE.CanvasTexture(canvas);
  if (repeat) texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  return texture;
}

export default {
  tiles: [8, 8],
  height: 7,
  elevation: 50,
  frames: 1,
  loop: LOOP,
  // A LOOP-frame loop lasts 64 ticks in game: 30 frames per second.
  fps: 30,
  export: "warp-drive/graphics/entity/warp-drive/warp-drive",
  variants: STATES,
  labels: { variant: "State", idle: "Placement preview" },
  shadowVariant: "shadow",
  layers: [
    { name: "lamps", tag: "lamp", glow: true, frames: LOOP, span: 2, preview: {} },
    { name: "interior-standby", tag: "interior", variant: "standby", frames: 1, preview: { variant: "standby" } },
    { name: "glow-standby", tags: ["interior", "energy"], glow: true, variant: "standby", frames: LOOP, span: 2, preview: { variant: "standby" } },
    { name: "interior-detecting", tag: "interior", variant: "detecting", frames: LOOP, preview: { variant: "detecting" } },
    { name: "glow-detecting", tags: ["interior", "energy"], glow: true, variant: "detecting", frames: LOOP, preview: { variant: "detecting" } },
    { name: "interior-charging", tag: "interior", variant: "charging", frames: LOOP, preview: { variant: "charging" } },
    { name: "glow-charging", tags: ["interior", "energy"], glow: true, variant: "charging", frames: LOOP, preview: { variant: "charging" } },
    { name: "interior-activation", tag: "interior", variant: "activation", frames: ACTIVATION_FRAMES, span: ACTIVATION_SPAN, preview: { variant: "activation" } },
    { name: "glow-activation", tags: ["interior", "energy"], glow: true, variant: "activation", frames: ACTIVATION_FRAMES, span: ACTIVATION_SPAN, preview: { variant: "activation" } },
    { name: "interior-warp", tag: "interior", variant: "warp", frames: LOOP, preview: { variant: "warp" } },
    { name: "glow-warp", tags: ["interior", "energy"], glow: true, variant: "warp", frames: LOOP, preview: { variant: "warp" } }
  ],
  references: [
    {
      label: "Vanilla Fusion Reactor (6x6), for style",
      tiles: [6, 6],
      layers: [
        { file: "factorio:space-age/graphics/entity/fusion-reactor/fusion-reactor-shadow.png", width: 542, height: 346, shift: [40 / 32, 9.5 / 32], blend: "shadow" },
        { file: "factorio:space-age/graphics/entity/fusion-reactor/fusion-reactor-main.png", width: 444, height: 456, shift: [1 / 32, -5.5 / 32], blend: "normal" },
        { file: "factorio:space-age/graphics/entity/fusion-reactor/fusion-reactor-glow.png", width: 396, height: 428, shift: [1.5 / 32, -11 / 32], blend: "additive" }
      ]
    }
  ],

  build() {
    const root = new THREE.Group();
    const state = {
      variant: null, lamps: [], rings: [], energy: [], interior: [], effects: {}, conduits: [], projectors: [], pools: []
    };
    root.userData = state;
    const rand = random(7);

    const m = {
      deck: textured({ color: 0x4b4f54, panels: 3, rivets: true, grime: 0.55, rust: 0.12, scratches: 0.5, scale: 3, metalness: 0.55, roughness: 0.6, seed: 31 }),
      cap: textured({ color: 0x5f656c, panels: 2, rivets: true, grime: 0.5, rust: 0.1, scratches: 0.4, scale: 1.4, metalness: 0.6, roughness: 0.5, seed: 33 }),
      plate: textured({ color: 0x7c8085, panels: 2, rivets: true, grime: 0.5, rust: 0.15, scratches: 0.4, scale: 1.6, metalness: 0.5, roughness: 0.55, seed: 35 }),
      // Dark, matte titanium-tungsten for the structural ribs.
      rib: textured({ color: 0x2a2d32, panels: 1, rivets: true, grime: 0.4, scratches: 0.3, scale: 0.9, metalness: 0.35, roughness: 0.85, seed: 37 }),
      dark: textured({ color: 0x383c41, panels: 1, rivets: true, grime: 0.5, rust: 0.2, scale: 1.2, metalness: 0.6, roughness: 0.55, seed: 39 }),
      trim: textured({ color: 0x9aa0a6, grime: 0.35, scratches: 0.5, scale: 1, metalness: 0.75, roughness: 0.4, seed: 41 }),
      hazard: textured({ color: 0x55585b, stripes: true, grime: 0.55, scale: 1.2, metalness: 0.3, roughness: 0.6, seed: 43 }),
      grating: textured({ color: 0x46494d, holes: 20, grime: 0.5, rust: 0.1, scale: 1.4, metalness: 0.6, roughness: 0.5, seed: 45 }),
      // White insulated liquid-helium lines, lightly frosted.
      frost: textured({ color: 0xd7e0e6, panels: 1, grime: 0.3, scratches: 0.2, variation: 0.08, scale: 0.8, metalness: 0.15, roughness: 0.7, seed: 47 }),
      pipe: textured({ color: 0x7d8288, grime: 0.35, scratches: 0.4, rust: 0.08, scale: 0.8, metalness: 0.8, roughness: 0.35, seed: 49 }),
      crystal: new THREE.MeshStandardMaterial({ color: 0x1a2f52, roughness: 0.15, metalness: 0.3, envMapIntensity: 2 }),
      cable: new THREE.MeshStandardMaterial({ color: 0x1d1f21, roughness: 0.7 })
    };
    const glass = (color, opacity, order) => {
      const material = new THREE.MeshStandardMaterial({ color, roughness: 0.05, metalness: 0, transparent: true, opacity, depthWrite: false, envMapIntensity: 2.2 });
      material.userData.renderOrder = order;
      return material;
    };
    const tagged = (material, tag) => {
      material.userData.tag = tag;
      return material;
    };

    // Soft-light textures. Shells around the axis fade towards their silhouette (cylinder u = 0
    // faces south, the camera), and towards their ends; discs fade from the centre.
    const shellAlpha = canvasTexture(128, 64, (u, v) => {
      const a = Math.pow(Math.max(0, Math.cos(u * TAU)), 0.9) * smoothstep(0, 0.12, v) * smoothstep(0, 0.12, 1 - v);
      return [a, a, a];
    });
    const radial = canvasTexture(64, 64, (u, v) => {
      const d = Math.min(1, Math.hypot(u - 0.5, v - 0.5) * 2);
      const a = Math.pow(1 - d, 2);
      return [a, a, a];
    });
    // Cascade bands: bright electric-blue fronts with violet wakes, repeating vertically.
    const bands = canvasTexture(8, 128, (u, v) => {
      const s = (v * 3) % 1;
      const front = Math.pow(1 - s, 6);
      const wake = Math.pow(1 - s, 1.6) * 0.45;
      const blue = new THREE.Color(COLORS.electric);
      const violet = new THREE.Color(COLORS.violet);
      return [blue.r * front + violet.r * wake + 0.08, blue.g * front + violet.g * wake + 0.06, blue.b * front + violet.b * wake + 0.18];
    }, true);
    // Pulses along a conduit: u runs along its length.
    const flow = canvasTexture(128, 8, (u) => {
      const s = (u * 2) % 1;
      const a = 0.25 + 0.75 * Math.pow(Math.max(0, Math.sin(s * Math.PI)), 8);
      return [a, a, a];
    }, true);
    // A pressure wave: a bright rim that fades towards the centre of a flat disc.
    const wave = canvasTexture(128, 128, (u, v) => {
      const d = Math.hypot(u - 0.5, v - 0.5) * 2;
      const a = smoothstep(0.7, 0.94, d) * (1 - smoothstep(0.94, 1, d));
      return [a, a, a];
    });

    /** An additive-only light material: glow layers capture it, every lit layer hides it. */
    const energy = ({ color = COLORS.icy, opacity = 1, map = null, alpha = null, side = THREE.FrontSide } = {}) => {
      const material = new THREE.MeshStandardMaterial({
        color: 0x000000, emissive: color, emissiveIntensity: 1, emissiveMap: map, alphaMap: alpha,
        transparent: true, opacity, depthWrite: false, side, roughness: 1, metalness: 0
      });
      return tagged(material, "energy");
    };
    /** A lit part of the overlays: drawn by the interior layers and, if emissive, the glow layers. */
    const interior = (material) => {
      state.interior.push(material);
      return tagged(material, "interior");
    };
    /** A small light that blinks `cycles` times per two loops (the lamp layer's span). */
    const lamp = (parent, geometry, color, position, { cycles = 1, phase = 0, duty = 0.5, on = 3, off = 0.1 } = {}) => {
      const material = tagged(new THREE.MeshStandardMaterial({ color: 0x1c1c1c, emissive: color, emissiveIntensity: off, roughness: 0.3 }), "lamp");
      state.lamps.push({ material, cycles, phase, duty, on, off });
      return part(parent, geometry, material, position);
    };
    /** A flat glowing disc on the deck, for light spilling from the core. */
    const pool = (radius, y) => {
      const mesh = part(root, new THREE.CircleGeometry(radius, 48), energy({ alpha: radial }), [0, y, 0], [-Math.PI / 2, 0, 0]);
      state.pools.push(mesh);
      return mesh;
    };
    /** A camera-facing soft glow disc (the camera looks down at the model's elevation). */
    const halo = (parent, radius, position) => part(parent, new THREE.CircleGeometry(radius, 32), energy({ alpha: radial }), position, [-THREE.MathUtils.degToRad(50), 0, 0]);
    /** A soft vertical light shell around the core axis. */
    const shell = (parent, radius, bottom, top, options = {}) =>
      part(parent, new THREE.CylinderGeometry(radius, radius, top - bottom, 48, 1, true), energy({ alpha: shellAlpha, ...options }), [0, (bottom + top) / 2, 0]);

    // Deck: a chamfered square plate with hazard edging.
    const h = HALF;
    const c = 0.71;
    const outline = new THREE.Shape();
    outline.moveTo(-h + c, -h);
    for (const [x, y] of [[h - c, -h], [h, -h + c], [h, h - c], [h - c, h], [-h + c, h], [-h, h - c], [-h, -h + c]]) outline.lineTo(x, y);
    outline.closePath();
    part(root, new THREE.ExtrudeGeometry(outline, { depth: BASE, bevelEnabled: false }).rotateX(-Math.PI / 2), m.deck);
    for (const [x, z, w, d] of [[0, h - 0.16, 2 * (h - c) - 0.27, 0.18], [0, -h + 0.16, 2 * (h - c) - 0.27, 0.18], [h - 0.16, 0, 0.18, 2 * (h - c) - 0.27], [-h + 0.16, 0, 0.18, 2 * (h - c) - 0.27]]) {
      part(root, new THREE.BoxGeometry(w, 0.03, d), m.hazard, [x, BASE + 0.015, z]);
    }

    // Children added between these marks form the round core; the deck, corner projectors,
    // conduits, and circuit terminal keep their grid positions.
    const round = [];
    let roundFrom = root.children.length;

    // Dais: two round steps with a hazard band and a grating ring.
    part(root, new THREE.CylinderGeometry(2.76, 2.8, 0.16, 64), m.cap, [0, BASE + 0.08, 0]);
    part(root, new THREE.CylinderGeometry(2.81, 2.81, 0.06, 64), m.hazard, [0, BASE + 0.12, 0]);
    part(root, new THREE.CylinderGeometry(2.31, 2.36, DAIS - BASE - 0.16, 64), m.plate, [0, (BASE + 0.16 + DAIS) / 2, 0]);
    part(root, new THREE.CylinderGeometry(2.27, 2.27, 0.02, 64), m.grating, [0, DAIS + 0.01, 0]);

    // Lower injector cap with buttresses, and a lamp strip facing the camera.
    part(root, new THREE.CylinderGeometry(CAP_RADIUS + 0.07, CAP_RADIUS + 0.18, CAP_BOTTOM - DAIS, 64), m.cap, [0, (DAIS + CAP_BOTTOM) / 2, 0]);
    part(root, new THREE.TorusGeometry(CAP_RADIUS + 0.09, 0.05, 8, 64).rotateX(Math.PI / 2), m.trim, [0, CAP_BOTTOM, 0]);
    part(root, new THREE.CylinderGeometry(TUBE_RADIUS + 0.11, TUBE_RADIUS + 0.2, TUBE_BOTTOM - CAP_BOTTOM, 64), m.dark, [0, (CAP_BOTTOM + TUBE_BOTTOM) / 2, 0]);
    for (let i = 0; i < 8; i++) {
      const a = Math.PI / 8 + (i * TAU) / 8;
      const r = CAP_RADIUS + 0.36;
      part(root, new THREE.BoxGeometry(0.21, 0.49, 0.55), m.dark, [Math.sin(a) * r, DAIS + 0.24, Math.cos(a) * r]).rotation.y = a;
      part(root, new THREE.BoxGeometry(0.25, 0.05, 0.59), m.trim, [Math.sin(a) * r, DAIS + 0.51, Math.cos(a) * r]).rotation.y = a;
    }
    for (let k = 0; k < 5; k++) {
      const a = -0.36 + k * 0.18;
      lamp(root, new THREE.BoxGeometry(0.09, 0.06, 0.04), [0x60e0ff, 0x60e0ff, 0x7dff9a, 0x60e0ff, 0x60e0ff][k],
        [Math.sin(a) * (CAP_RADIUS + 0.14), DAIS + 0.37, Math.cos(a) * (CAP_RADIUS + 0.14)], { cycles: 4, phase: k * 0.13, duty: 0.7, on: 1.6, off: 0.5 }).rotation.y = a;
    }

    // Structural ribs, turned half a step so the camera looks into the core between two of them.
    for (let i = 0; i < RIBS; i++) {
      const a = Math.PI / RIBS + (i * TAU) / RIBS;
      const at = (r, y) => [Math.sin(a) * r, y, Math.cos(a) * r];
      part(root, new THREE.BoxGeometry(0.13, TUBE_TOP + 0.18 - CAP_BOTTOM, 0.21), m.rib, at(RIB_RADIUS, (CAP_BOTTOM + TUBE_TOP + 0.18) / 2)).rotation.y = a;
      part(root, new THREE.BoxGeometry(0.19, TUBE_TOP - 0.09 - CAP_BOTTOM - 0.18, 0.04), m.rib, at(RIB_RADIUS + 0.12, (CAP_BOTTOM + 0.18 + TUBE_TOP - 0.09) / 2)).rotation.y = a;
      for (const y of [CAP_BOTTOM + 0.11, TUBE_TOP + 0.04]) part(root, new THREE.BoxGeometry(0.27, 0.14, 0.36), m.dark, at(RIB_RADIUS + 0.05, y)).rotation.y = a;
    }

    // Upper injector cap, crown, and beacon mast.
    const capTop = TUBE_TOP + 0.55;
    part(root, new THREE.CylinderGeometry(TUBE_RADIUS + 0.11, TUBE_RADIUS + 0.2, 0.18, 64), m.dark, [0, TUBE_TOP + 0.09, 0]);
    part(root, new THREE.CylinderGeometry(CAP_RADIUS, CAP_RADIUS + 0.07, capTop - TUBE_TOP - 0.18, 64), m.cap, [0, (TUBE_TOP + 0.18 + capTop) / 2, 0]);
    part(root, new THREE.TorusGeometry(CAP_RADIUS + 0.05, 0.05, 8, 64).rotateX(Math.PI / 2), m.trim, [0, TUBE_TOP + 0.18, 0]);
    part(root, new THREE.CylinderGeometry(0.93, CAP_RADIUS, 0.27, 64), m.plate, [0, capTop + 0.13, 0]);
    part(root, new THREE.CylinderGeometry(0.53, 0.59, 0.37, 32), m.dark, [0, capTop + 0.45, 0]);
    part(root, new THREE.SphereGeometry(0.53, 32, 12, 0, TAU, 0, Math.PI / 2).scale(1, 0.45, 1), m.trim, [0, capTop + 0.64, 0]);
    for (let i = 0; i < RIBS; i++) {
      const a = Math.PI / RIBS + (i * TAU) / RIBS;
      part(root, new THREE.BoxGeometry(0.18, capTop - TUBE_TOP - 0.09, 0.2), m.rib, [Math.sin(a) * (CAP_RADIUS + 0.05), (TUBE_TOP + 0.18 + capTop) / 2, Math.cos(a) * (CAP_RADIUS + 0.05)]).rotation.y = a;
    }
    part(root, new THREE.TorusGeometry(1.16, 0.04, 8, 64).rotateX(Math.PI / 2), m.hazard, [0, capTop + 0.08, 0]);
    for (let i = 0; i < 4; i++) {
      const a = (i * TAU) / 4;
      const at = (r, y) => [Math.sin(a) * r, y, Math.cos(a) * r];
      tube(root, [at(0.55, capTop + 0.4), at(0.8, capTop + 0.31), at(1.11, capTop + 0.14), at(1.33, capTop - 0.04)], 0.05, m.frost, 16);
      part(root, new THREE.BoxGeometry(0.27, 0.11, 0.2), m.dark, at(1.02, capTop + 0.19)).rotation.y = a;
      // Heavy flanged ports on the diagonals, where the upper conduits leave the cap.
      const d = a + Math.PI / 4;
      const port = [Math.sin(d) * (CAP_RADIUS - 0.02), TUBE_TOP + 0.4, Math.cos(d) * (CAP_RADIUS - 0.02)];
      part(root, new THREE.CylinderGeometry(0.21, 0.23, 0.2, 20), m.trim, port, [Math.PI / 2, d, 0]).rotation.order = "YXZ";
    }
    part(root, new THREE.CylinderGeometry(0.04, 0.04, 0.44, 8), m.pipe, [0, capTop + 0.89, 0]);
    lamp(root, new THREE.SphereGeometry(0.07, 16, 8), 0xff3020, [0, capTop + 1.14, 0], { cycles: 2, duty: 0.2, on: 4 });

    round.push([roundFrom, root.children.length]);

    // Field projectors in the corners: a squat base, a coiled column, and an emitter crystal.
    for (const [sx, sz] of DIAGONALS) {
      const x = sx * PROJECTOR;
      const z = sz * PROJECTOR;
      part(root, new THREE.BoxGeometry(1.02, 0.27, 1.02), m.cap, [x, BASE + 0.13, z]);
      part(root, new THREE.BoxGeometry(1.07, 0.05, 1.07), m.hazard, [x, BASE + 0.24, z]);
      part(root, new THREE.CylinderGeometry(0.3, 0.37, 1.33, 24), m.plate, [x, BASE + 0.27 + 0.67, z]);
      for (const y of [0.8, 1.02, 1.24]) part(root, new THREE.TorusGeometry(0.33, 0.04, 8, 24).rotateX(Math.PI / 2), m.pipe, [x, BASE + y, z]);
      part(root, new THREE.CylinderGeometry(0.44, 0.37, 0.2, 24), m.dark, [x, BASE + 1.7, z]);
      part(root, new THREE.TorusGeometry(0.41, 0.04, 8, 24).rotateX(Math.PI / 2), m.trim, [x, BASE + 1.8, z]);
      part(root, new THREE.OctahedronGeometry(0.27, 0).scale(1, 1.45, 1), m.crystal, [x, BASE + 2.13, z]);
      lamp(root, new THREE.BoxGeometry(0.08, 0.05, 0.03), 0x7dff9a, [x, BASE + 0.13, z + 0.52], { cycles: 1, phase: (sx + sz + 2) * 0.12, duty: 0.8, on: 1.6, off: 0.4 });
      const glowShell = part(root, new THREE.OctahedronGeometry(0.3, 0).scale(1, 1.45, 1), energy({ opacity: 0.55 }), [x, BASE + 2.13, z]);
      const glowHalo = halo(root, 0.76, [x, BASE + 2.13, z]);
      state.projectors.push({ shell: glowShell, halo: glowHalo, phase: rand() });
    }

    // Conduits: glass pipes from both caps out to the projectors, each with a dark liner and an
    // energy core the glow layers light up.
    const conduitGlass = glass(0xbfe0ff, 0.28, 5);
    const conduitEnergy = energy({ color: COLORS.azure, map: flow });
    for (const [sx, sz] of DIAGONALS) {
      const d = [sx / Math.SQRT2, sz / Math.SQRT2];
      const at = (r, y) => [d[0] * r, y, d[1] * r];
      const corner = PROJECTOR * Math.SQRT2;
      // Each conduit leaves the squashed core and ends at an unsquashed projector, so its points
      // ease from ROUND_DEPTH to full depth along the way.
      const ease = (points) => points.map(([x, y, z], i) => [x, y, z * (ROUND_DEPTH + (1 - ROUND_DEPTH) * (i / (points.length - 1)))]);
      const paths = [
        ease([at(CAP_RADIUS + 0.02, TUBE_TOP + 0.4), at(2.27, TUBE_TOP + 0.31), at(3.16, TUBE_TOP - 0.62), at(corner - 0.04, BASE + 1.91)]),
        ease([at(CAP_RADIUS + 0.11, DAIS + 0.36), at(2.22, DAIS + 0.28), at(2.98, DAIS + 0.27), at(corner - 0.4, BASE + 0.53)])
      ];
      for (const [k, points] of paths.entries()) {
        const radius = k === 0 ? 0.14 : 0.12;
        tube(root, points, radius, conduitGlass, 40);
        tube(root, points, 0.035, m.cable, 40);
        state.conduits.push(tube(root, points, 0.065, conduitEnergy, 40));
        for (const p of [points[0], points[points.length - 1]]) {
          part(root, new THREE.SphereGeometry(radius + 0.04, 16, 8), m.trim, p);
        }
      }
    }
    state.conduitEnergy = conduitEnergy;

    roundFrom = root.children.length;
    // Liquid-helium cooling: a ring main around the dais, four manifold pumps, and feeds into the
    // lower cap.
    part(root, new THREE.TorusGeometry(2.95, 0.06, 8, 96).rotateX(Math.PI / 2), m.frost, [0, BASE + 0.27, 0]);
    for (let i = 0; i < 4; i++) {
      const a = (i * TAU) / 4;
      const g = new THREE.Group();
      g.position.set(Math.sin(a) * 3.29, BASE, Math.cos(a) * 3.29);
      g.rotation.y = a;
      root.add(g);
      part(g, new THREE.BoxGeometry(0.84, 0.37, 0.55), m.dark, [0, 0.19, 0]);
      part(g, new THREE.BoxGeometry(0.89, 0.04, 0.59), m.trim, [0, 0.39, 0]);
      part(g, new THREE.CylinderGeometry(0.17, 0.17, 0.55, 20), m.frost, [-0.16, 0.59, 0], [0, 0, Math.PI / 2]);
      part(g, new THREE.CylinderGeometry(0.19, 0.19, 0.07, 20), m.pipe, [0.13, 0.59, 0], [0, 0, Math.PI / 2]);
      part(g, new THREE.CylinderGeometry(0.15, 0.15, 0.44, 20), m.frost, [0.27, 0.63, 0]);
      part(g, new THREE.SphereGeometry(0.15, 20, 8, 0, TAU, 0, Math.PI / 2), m.frost, [0.27, 0.85, 0]);
      lamp(g, new THREE.BoxGeometry(0.11, 0.05, 0.03), 0x60e0ff, [-0.22, 0.27, 0.28], { cycles: 6, phase: i * 0.21, duty: 0.5, on: 2 });
      tube(root, [
        [Math.sin(a) * 3.07, BASE + 0.55, Math.cos(a) * 3.07], [Math.sin(a) * 2.62, BASE + 0.62, Math.cos(a) * 2.62],
        [Math.sin(a) * 2.0, DAIS + 0.36, Math.cos(a) * 2.0], [Math.sin(a) * (CAP_RADIUS + 0.11), DAIS + 0.4, Math.cos(a) * (CAP_RADIUS + 0.11)]
      ], 0.06, m.frost, 24);
    }

    round.push([roundFrom, root.children.length]);

    // Circuit terminal south-west of the dais; its insulator tips carry the circuit wires
    // (red east, green west: warp-drive/prototypes/entities.lua).
    part(root, new THREE.BoxGeometry(0.44, 0.44, 0.3), m.dark, [-1.38, BASE + 0.22, 3.33]);
    part(root, new THREE.BoxGeometry(0.48, 0.04, 0.34), m.trim, [-1.38, BASE + 0.46, 3.33]);
    for (const [x, color] of [[-1.29, 0xc0392b], [-1.47, 0x2e9e4f]]) {
      part(root, new THREE.CylinderGeometry(0.03, 0.04, 0.27, 10), m.pipe, [x, BASE + 0.62, 3.33]);
      part(root, new THREE.SphereGeometry(0.04, 12, 8), new THREE.MeshStandardMaterial({ color, roughness: 0.4 }), [x, BASE + 0.76, 3.33]);
    }
    lamp(root, new THREE.BoxGeometry(0.07, 0.04, 0.03), 0xffb020, [-1.38, BASE + 0.27, 3.49], { cycles: 3, duty: 0.4 });

    roundFrom = root.children.length;
    // Overlay contents. The quartz tube with glare streaks.
    const quartz = interior(glass(0xcfe8ff, 0.2, 4));
    part(root, new THREE.CylinderGeometry(TUBE_RADIUS, TUBE_RADIUS, TUBE_TOP - TUBE_BOTTOM, 64, 1, true), quartz, [0, (TUBE_BOTTOM + TUBE_TOP) / 2, 0]);
    const glare = interior(new THREE.MeshBasicMaterial({ color: 0xffffff, transparent: true, opacity: 0.22, depthWrite: false, side: THREE.DoubleSide }));
    glare.userData.renderOrder = 6;
    for (const [start, width] of [[-0.62, 0.16], [-0.38, 0.05], [0.5, 0.05]]) {
      part(root, new THREE.CylinderGeometry(TUBE_RADIUS + 0.01, TUBE_RADIUS + 0.01, (TUBE_TOP - TUBE_BOTTOM) * 0.9, 6, 1, true, start, width), glare, [0, (TUBE_BOTTOM + TUBE_TOP) / 2, 0]);
    }

    // Injector nozzles at both ends of the collision chamber, and the core thread between them.
    const nozzle = interior(m.trim.clone());
    part(root, new THREE.CylinderGeometry(0.06, 0.3, CORE_BOTTOM - TUBE_BOTTOM, 24), nozzle, [0, (TUBE_BOTTOM + CORE_BOTTOM) / 2, 0]);
    part(root, new THREE.CylinderGeometry(0.3, 0.06, TUBE_TOP - CORE_TOP, 24), nozzle, [0, (CORE_TOP + TUBE_TOP) / 2, 0]);
    const thread = part(root, new THREE.CylinderGeometry(0.03, 0.03, CORE_TOP - CORE_BOTTOM, 12), interior(new THREE.MeshStandardMaterial({ color: 0x030405, roughness: 0.15, metalness: 0.2 })), [0, CORE_MID, 0]);
    state.thread = thread;

    // Magnetic rings: SEGMENTS identical coil segments, each with a clamp and a node lamp at its
    // end, so turning a ring by whole segments repeats seamlessly.
    const copper = interior(new THREE.MeshStandardMaterial({ color: 0xa0623a, metalness: 0.9, roughness: 0.38 }));
    const clamp = interior(new THREE.MeshStandardMaterial({ color: 0x3a3f46, metalness: 0.7, roughness: 0.5 }));
    const node = interior(new THREE.MeshStandardMaterial({ color: 0x182030, emissive: COLORS.icy, emissiveIntensity: 0.4, roughness: 0.3 }));
    state.node = node;
    const segment = new THREE.TorusGeometry(RING_RADIUS, 0.08, 10, 8, SEGMENT * 0.86).rotateX(Math.PI / 2).scale(1, 0.85, 1);
    for (let k = 0; k < RINGS; k++) {
      const ring = new THREE.Group();
      ring.position.y = RING_Y + k * RING_STEP;
      root.add(ring);
      for (let s = 0; s < SEGMENTS; s++) {
        const holder = new THREE.Group();
        holder.rotation.y = s * SEGMENT;
        ring.add(holder);
        part(holder, segment.clone(), copper);
        const mid = SEGMENT * 0.43;
        part(holder, new THREE.BoxGeometry(0.07, 0.16, 0.22), clamp, [Math.cos(mid) * RING_RADIUS, 0, -Math.sin(mid) * RING_RADIUS]).rotation.y = mid;
        const end = SEGMENT * 0.93;
        part(holder, new THREE.BoxGeometry(0.04, 0.11, 0.18), node, [Math.cos(end) * RING_RADIUS, 0, -Math.sin(end) * RING_RADIUS]).rotation.y = end;
      }
      // Alternate rings counter-rotate while charging and in warp; offsets spread their snap at
      // activation.
      state.rings.push({ ring, direction: k % 2 ? -1 : 1, y: ring.position.y, scatter: (rand() - 0.5) * 3 });
    }

    // Energy effects, shown per state by setVariant().
    const fx = state.effects;
    fx.halo = [[0.06, 1.4], [0.13, 0.55], [0.23, 0.22]].map(([r, intensity]) => ({ mesh: shell(root, r, CORE_BOTTOM, CORE_TOP), intensity }));
    fx.plasma = [[0.1, COLORS.white], [0.18, COLORS.cobalt], [0.3, COLORS.deep], [0.46, COLORS.deep]].map(([r, color]) => ({ mesh: shell(root, r, CORE_BOTTOM - 0.09, CORE_TOP + 0.09, { color }), r }));
    fx.jets = [[TUBE_BOTTOM + 0.27, 1], [TUBE_TOP - 0.27, -1]].map(([y, dir]) => {
      const length = 0.89;
      const geometry = new THREE.ConeGeometry(0.14, length, 16, 1, true).translate(0, -length / 2, 0);
      if (dir > 0) geometry.rotateX(Math.PI);
      return { mesh: part(root, geometry, energy({ color: COLORS.white, opacity: 0.7, side: THREE.DoubleSide }), [0, y, 0]), dir };
    });
    fx.jetHalos = [CORE_BOTTOM, CORE_TOP].map((y) => halo(root, 0.49, [0, y, 0]));
    // The spatial lens: camera-facing rings that shrink towards a vanishing point at the core.
    fx.tunnel = Array.from({ length: 6 }, () => part(root, new THREE.TorusGeometry(1, 0.03, 6, 64), energy({ color: COLORS.violet }), [0, CORE_MID, 0], [-THREE.MathUtils.degToRad(50), 0, 0]));
    fx.column = shell(root, 0.11, CORE_BOTTOM - 0.04, CORE_TOP + 0.04, { color: COLORS.white });
    fx.cascade = [[0.23, 1.0], [0.43, 0.6], [0.66, 0.3]].map(([r, intensity], k) => {
      const map = bands.clone();
      map.repeat.set(1, 2 - (k % 2) * 0.5);
      return { mesh: shell(root, r, CORE_BOTTOM - 0.09, CORE_TOP + 0.09, { color: 0xffffff, map }), map, intensity };
    });
    // Filaments are posed per frame by replacing their geometry; the meshes exist from the start so
    // render.js sees them when it swaps materials for each layer.
    fx.lightningMaterial = energy({ color: 0xd8d0ff });
    fx.bolts = Array.from({ length: 3 }, () => {
      const bolt = part(root, new THREE.BufferGeometry(), fx.lightningMaterial);
      bolt.renderOrder = 7;
      return bolt;
    });
    fx.flash = halo(root, 1.96, [0, CORE_MID, 0]);
    fx.shock = part(root, new THREE.CircleGeometry(1, 64), energy({ color: COLORS.white, alpha: wave, side: THREE.DoubleSide }), [0, CORE_MID, 0], [-Math.PI / 2, 0, 0]);
    pool(3.82, BASE + 0.01);
    pool(2.31, DAIS + 0.025);
    pool(CAP_RADIUS, CAP_BOTTOM + 0.01);
    round.push([roundFrom, root.children.length]);

    // Move the round core into a squashed group; rings keep turning inside it, so they sweep ovals.
    const core = new THREE.Group();
    core.scale.z = ROUND_DEPTH;
    const children = [...root.children];
    for (const [from, to] of round) for (const child of children.slice(from, to)) core.add(child);
    root.add(core);

    root.traverse((object) => {
      if (!object.isMesh) return;
      if (object.material.userData.renderOrder) object.renderOrder = object.material.userData.renderOrder;
      if (object.material.userData.tag === "energy") state.energy.push(object);
    });
    return root;
  },

  /**
   * Shows one state's overlay contents, `"shadow"` (the solid interior, for the shadow pass), or
   * just the hull (`null`).
   */
  setVariant(root, name) {
    const state = root.userData;
    state.variant = name;
    const inside = name !== null;
    root.traverse((object) => {
      if (!object.isMesh) return;
      const tag = object.material.userData.tag;
      if (tag === "interior") object.visible = inside;
      if (tag === "energy") object.visible = inside && name !== "shadow";
    });
  },

  // `t` counts loops: 0 to 2 for standby and the lamps, 0 to 1 while charging and in warp, and 0 to
  // ACTIVATION_SPAN for the activation. Looping states use whole cycles per span.
  animate(root, t) {
    const state = root.userData;
    const { variant, lamps, rings, effects: fx, node, conduitEnergy, projectors, pools } = state;
    for (const lamp of lamps) {
      lamp.material.emissiveIntensity = ((t / 2) * lamp.cycles + lamp.phase) % 1 < lamp.duty ? lamp.on : lamp.off;
    }
    if (!variant || variant === "shadow") {
      // The shadow shows the rings aligned, however the last rendered state left them.
      for (const ring of rings) ring.ring.rotation.y = 0;
      return;
    }

    const set = (mesh, color, intensity, opacity = mesh.material.opacity) => {
      mesh.visible = intensity > 0.002;
      mesh.material.emissive.set(color);
      mesh.material.emissiveIntensity = intensity;
      mesh.material.opacity = opacity;
    };
    const hide = (...meshes) => meshes.forEach((mesh) => (mesh.visible = false));
    hide(...fx.halo.map((e) => e.mesh), ...fx.plasma.map((e) => e.mesh), ...fx.jets.map((e) => e.mesh), ...fx.jetHalos,
      ...fx.tunnel, ...fx.cascade.map((e) => e.mesh), fx.column, fx.flash, fx.shock, ...fx.bolts);
    state.thread.visible = true;

    // Per-state levels, filled in below.
    let ringAngle = () => 0;
    let nodeColor = COLORS.icy;
    let nodeLevel = () => 0.4;
    let conduit = { color: COLORS.azure, level: 0, cycles: 0 };
    let projector = { color: COLORS.icy, level: 0.12 };
    let poolLevel = { color: COLORS.icy, level: 0.12 };

    const plasma = (scale, intensity, white = 0, palette = PALETTES.charging) => fx.plasma.forEach(({ mesh, r }, k) => {
      mesh.scale.set(scale, 1, scale);
      const color = new THREE.Color([palette.core, palette.mid, palette.deep, palette.deep][k]).lerp(new THREE.Color(0xffffff), white);
      set(mesh, color, intensity * [1.6, 0.9, 0.5, 0.25][k]);
    });
    const cascade = (level, speed = 2) => fx.cascade.forEach(({ mesh, map, intensity }, k) => {
      map.offset.y = (t * speed) % 1;
      set(mesh, 0xffffff, level * intensity * 3);
    });
    const lightning = (count, level, seed) => {
      const r = random(seed);
      for (const [n, bolt] of fx.bolts.entries()) {
        if (n >= count) break;
        const points = [];
        const angle = r() * TAU;
        for (let j = 0; j <= 12; j++) {
          const f = j / 12;
          const reach = 0.07 + 0.2 * Math.sin(f * Math.PI);
          const a = angle + (r() - 0.5) * 1.6;
          points.push([Math.sin(a) * reach * r(), mix(CORE_BOTTOM, CORE_TOP, f), Math.cos(a) * reach * r()]);
        }
        bolt.geometry.dispose();
        bolt.geometry = new THREE.TubeGeometry(new THREE.CatmullRomCurve3(points.map((p) => new THREE.Vector3(...p))), 48, 0.016, 6);
        bolt.visible = true;
      }
      fx.lightningMaterial.emissiveIntensity = level;
    };

    if (variant === "standby") {
      // A stasis-locked thread in a faint icy halo that breathes once over the two-loop span.
      const breath = 0.85 + 0.15 * Math.sin(Math.PI * t);
      fx.halo.forEach(({ mesh, intensity }) => set(mesh, COLORS.icy, intensity * breath));
      nodeLevel = () => 0.35;
      projector = { color: COLORS.icy, level: 0.18 * breath };
      poolLevel = { color: COLORS.icy, level: 0.18 * breath };
    } else if (variant === "charging" || variant === "detecting") {
      // Alternate rings counter-rotate, faster as the game speeds this up.
      const palette = PALETTES[variant];
      ringAngle = (ring) => ring.direction * t * CHARGING_TURN * SEGMENT;
      const beat = 0.5 + 0.5 * Math.sin(TAU * 2 * t);
      plasma(1 + 0.18 * beat, 0.8 + 0.4 * beat, 0, palette);
      fx.jets.forEach(({ mesh }, k) => {
        mesh.scale.set(1, 0.45 + 0.2 * Math.sin(TAU * (4 * t + k * 0.5)) ** 2, 1);
        set(mesh, palette.core, 1.4, 0.7);
      });
      fx.jetHalos.forEach((mesh) => set(mesh, palette.accent, 0.9 + 0.4 * beat, 0.9));
      // Infinite depth: each ring halves in size per loop and the next takes its place.
      fx.tunnel.forEach((mesh, k) => {
        const depth = k + t;
        const size = 0.89 * Math.pow(0.55, depth);
        mesh.scale.set(size, size * 1.45, size);
        set(mesh, palette.tunnel, 0.9 * smoothstep(0, 0.6, depth) * (1 - smoothstep(4, 5.5, depth)));
      });
      nodeColor = palette.accent;
      nodeLevel = (ring) => 1.1 + 0.6 * Math.max(0, Math.sin(TAU * (2 * t + ring.y * 0.39)));
      conduit = { color: palette.accent, level: 0.35, cycles: 1 };
      projector = { color: palette.accent, level: 0.45 + 0.15 * beat };
      poolLevel = { color: palette.accent, level: 0.45 + 0.15 * beat };
    } else if (variant === "activation") {
      const p = t / ACTIVATION_SPAN;
      // Harmonic locking: the rings snap into alignment in the first tenth of a second, then, from
      // the flare on, spin up evenly to their warp speed (WARP_TURN segments per loop).
      const spin = Math.max(0, t - SPIN_UP_FROM * ACTIVATION_SPAN);
      const spinUp = (WARP_TURN * spin * spin) / (2 * (1 - SPIN_UP_FROM) * ACTIVATION_SPAN);
      ringAngle = (ring) => ring.scatter * SEGMENT * (1 - smoothstep(0, 0.07, p)) + ring.direction * spinUp * SEGMENT;
      // The core draws in (the sound's suction at 0.54 s), then flashes and settles into warp.
      const flash = pulse(0.33, 0.37, 0.4, 0.62, p);
      const draw = smoothstep(0.1, 0.33, p) * (1 - smoothstep(0.33, 0.36, p));
      plasma(mix(1.1, 0.55, draw) + 0.9 * flash, (1.1 + 1.2 * draw + 1.4 * flash) * (1 - smoothstep(0.55, 0.85, p)), 0.7 * flash);
      state.thread.visible = p < 0.35;
      set(fx.flash, 0xffffff, 1.4 * flash, 0.9);
      set(fx.column, COLORS.white, 3 * flash + 1.6 * smoothstep(0.6, 1, p));
      const spread = smoothstep(0.35, 0.8, p);
      fx.shock.scale.setScalar(mix(1.07, SHOCK_REACH, spread));
      set(fx.shock, COLORS.azure, p > 0.35 ? 2.2 * (1 - spread) : 0, 1);
      cascade(smoothstep(0.55, 0.95, p));
      if (p > 0.6) lightning(2, 2 * smoothstep(0.6, 0.95, p), 900 + Math.round(p * ACTIVATION_FRAMES));
      fx.halo.forEach(({ mesh, intensity }) => set(mesh, COLORS.icy, intensity * (1 - smoothstep(0.2, 0.35, p))));
      nodeColor = p < 0.36 ? COLORS.cobalt : COLORS.violet;
      nodeLevel = () => 1.3 + 4 * flash + 0.6 * smoothstep(0.6, 1, p);
      const flare = pulse(0.36, 0.42, 0.5, 0.95, p);
      conduit = { color: COLORS.azure, level: 0.4 + 3.2 * flare + 1.1 * smoothstep(0.6, 1, p), cycles: 3, shift: -p * 3 };
      projector = { color: COLORS.azure, level: 0.5 + 2.5 * pulse(0.4, 0.46, 0.5, 0.9, p) + 0.8 * smoothstep(0.6, 1, p) };
      poolLevel = { color: COLORS.azure, level: 0.45 + 1.4 * flash + 0.3 * smoothstep(0.6, 1, p) };
    } else if (variant === "warp") {
      // Alternate rings counter-rotate at the speed of a full charge; cascading waves run down the
      // column twice per loop around flickering filaments.
      ringAngle = (ring) => ring.direction * t * WARP_TURN * SEGMENT;
      state.thread.visible = false;
      cascade(1);
      set(fx.column, COLORS.white, 1.6 + 0.3 * Math.sin(TAU * 4 * t));
      lightning(3, 2.2, 500 + Math.round(t * LOOP));
      nodeColor = COLORS.violet;
      nodeLevel = (ring) => 1.6 + 1.2 * Math.pow(0.5 + 0.5 * Math.cos(TAU * (2 * t + ring.y / 1.24)), 3);
      conduit = { color: COLORS.azure, level: 1.5, cycles: 2 };
      projector = { color: COLORS.azure, level: 1.3 };
      poolLevel = { color: COLORS.violet, level: 0.75 };
    }

    for (const ring of rings) ring.ring.rotation.y = ringAngle(ring);
    // Every ring shares the node material, so the brightest ring sets it; per-ring levels average.
    node.emissive.set(nodeColor);
    node.emissiveIntensity = rings.reduce((sum, ring) => sum + nodeLevel(ring), 0) / rings.length;
    conduitEnergy.emissive.set(conduit.color);
    conduitEnergy.emissiveIntensity = conduit.level;
    conduitEnergy.emissiveMap.offset.x = conduit.shift ?? -t * conduit.cycles;
    for (const mesh of state.conduits) mesh.visible = conduit.level > 0;
    for (const { shell, halo, phase } of projectors) {
      const flicker = variant === "warp" ? 0.85 + 0.15 * Math.sin(TAU * (4 * t + phase)) : 1;
      set(shell, projector.color, projector.level * flicker * 1.3, 0.55);
      set(halo, projector.color, projector.level * flicker * 0.7, 1);
    }
    for (const mesh of pools) set(mesh, poolLevel.color, poolLevel.level, 1);
  }
};
