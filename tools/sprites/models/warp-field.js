// Warp field effects: sprites the Warp Drive spreads across the ship and the space around it.
// Not a building: every layer is additive light in neutral white, which the game tints per use,
// and nothing is drawn in the main or shadow layers. Units are tiles on the deck plane.
//
// - shockwave: one frame, a ring of light with a soft wake inside it. scripts/shockwaves.lua grows
//   it from the drive, carrying the building's activation shockwave across the whole platform and
//   sweeping the asteroids away.
// - nebula: the life of one subspace cloud in NEBULA_FRAMES frames: it billows out around a bright
//   core, veined with flickering filaments, then thins away. Warp lightning uses it as its cloud.
// - anomaly: ANOMALY_SHAPES unrelated frames, each a large, soft, irregular cloud with faint wisps.
//   Background anomalies (warp-drive/scripts/anomalies.lua) show one shape per layer, scaled up
//   several times, and crossfade, turn, and swell them at runtime, so the frames are shapes to pick from rather than an animation.
//   They are painted on a smaller plane than the other layers to keep the sheet small; the game
//   scales them up, which their softness hides.
// - streak: STREAK_SHAPES variants of one subspace streak, STREAK_LENGTH tiles long, its bright
//   head at the south end and its tail fading north, in a soft glow. Each shape is one row of
//   STREAK_FRAMES frames: it brightens over the first two, then holds, so a streak particle
//   playing its row once over its life fades in instead of appearing at full brightness.
import * as THREE from "three";
import { noise } from "../lib/textures.js";
import { part } from "../lib/geometry.js";

const SIZE = 16; // the deck plane, in tiles
const TEXTURE = 1024; // texture pixels across the plane
const NOISE = 512; // tileable noise samples across the plane
const RING = 7; // shockwave radius in tiles
// The shockwave is an oval, squashed front to back like the drive's round core (warp-drive.js).
const ROUND_DEPTH = 0.78;
const NEBULA_FRAMES = 8;
const ANOMALY_SHAPES = 6;
const ANOMALY_SIZE = 8; // the anomaly plane, in tiles
const ANOMALY_TEXTURE = 512;
const STREAK_SHAPES = 4;
const STREAK_LENGTH = 12;
const STREAK_FRAMES = 8;
const STREAK_FADE_IN = [0.3, 0.65];

const smoothstep = (a, b, x) => {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a)));
  return t * t * (3 - 2 * t);
};
const mix = (a, b, t) => a + (b - a) * t;
/** A bump that rises over [a, b] and falls over [c, d]. */
const pulse = (a, b, c, d, x) => smoothstep(a, b, x) * (1 - smoothstep(c, d, x));

/** Bilinear lookup into a tileable NOISE² field at deck position (x, y) in tiles. */
function sampler(field) {
  return (x, y) => {
    const gx = (((x / SIZE + 0.5) % 1) + 1) % 1 * NOISE;
    const gy = (((y / SIZE + 0.5) % 1) + 1) % 1 * NOISE;
    const x0 = Math.floor(gx), y0 = Math.floor(gy);
    const fx = gx - x0, fy = gy - y0;
    const x1 = (x0 + 1) % NOISE, y1 = (y0 + 1) % NOISE;
    const top = mix(field[y0 * NOISE + x0], field[y0 * NOISE + x1], fx);
    const bottom = mix(field[y1 * NOISE + x0], field[y1 * NOISE + x1], fx);
    return mix(top, bottom, fy);
  };
}

/** Paints `fn(x, y)` (plane tiles from the centre, brightness 0–1) into a canvas texture. */
function paint(canvas, fn, size = SIZE) {
  const pixels = canvas.width;
  const image = new ImageData(pixels, pixels);
  for (let row = 0; row < pixels; row++) {
    for (let column = 0; column < pixels; column++) {
      const x = ((column + 0.5) / pixels - 0.5) * size;
      const y = ((row + 0.5) / pixels - 0.5) * size;
      const v = Math.round(Math.min(1, Math.max(0, fn(x, y))) * 255);
      image.data.set([v, v, v, 255], (row * pixels + column) * 4);
    }
  }
  canvas.getContext("2d").putImageData(image, 0, 0);
}

function canvasTexture(pixels = TEXTURE) {
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = pixels;
  const texture = new THREE.CanvasTexture(canvas);
  // Painted values are display brightness; without this the sRGB output would lift faint ones.
  texture.colorSpace = THREE.SRGBColorSpace;
  return { canvas, texture };
}

/** A glowing deck-level plane whose emitted light is the texture. */
function plane(root, tag, texture, size = SIZE) {
  const material = new THREE.MeshStandardMaterial({ color: 0x000000, emissive: 0xffffff, emissiveMap: texture });
  material.userData.tag = tag;
  return part(root, new THREE.PlaneGeometry(size, size), material, [0, 0.02, 0], [-Math.PI / 2, 0, 0]);
}

/**
 * One background anomaly shape: a soft cloud stretched and turned at random, its outline torn by
 * domain-warped noise, its body in uneven billows with a dim glow underneath, and faint wisps.
 */
function paintAnomaly(anomaly, fields, shape) {
  const [early, late, veins] = fields;
  const rand = (k) => {
    const v = Math.sin(shape * 127.1 + k * 311.7) * 43758.5453;
    return v - Math.floor(v);
  };
  const ox = rand(3) * SIZE, oy = rand(4) * SIZE;
  // Three stretched, turned lobes around the centre make each outline different.
  const lobes = [0, 1, 2].map((k) => {
    const angle = rand(10 + k) * Math.PI;
    const place = rand(20 + k) * Math.PI * 2;
    const offset = k === 0 ? 0 : 0.5 + 0.7 * rand(30 + k);
    return {
      x: Math.cos(place) * offset, y: Math.sin(place) * offset,
      cos: Math.cos(angle), sin: Math.sin(angle),
      radius: 1.9 + 0.9 * rand(40 + k), stretch: 0.5 + 0.4 * rand(50 + k)
    };
  });
  paint(anomaly.canvas, (x, y) => {
    const warp = early(x * 0.8 + ox, y * 0.8 + oy) - 0.5;
    let mask = 0;
    for (const lobe of lobes) {
      const dx = x - lobe.x, dy = y - lobe.y;
      const u = (dx * lobe.cos + dy * lobe.sin) / lobe.radius;
      const v = (dy * lobe.cos - dx * lobe.sin) / (lobe.radius * lobe.stretch);
      mask = Math.max(mask, 1 - smoothstep(0.25, 1.05, Math.hypot(u, v) + 1.6 * warp));
    }
    mask *= 1 - smoothstep(3.3, 3.95, Math.max(Math.abs(x), Math.abs(y)));
    const n = late(x * 1.2 + ox + 3 * warp, y * 1.2 + oy - 3 * warp);
    const billows = smoothstep(0.38, 0.72, n) * mask;
    const ridge = 1 - Math.abs(2 * veins(x * 1.6 + oy, y * 1.6 + ox) - 1);
    const wisps = smoothstep(0.86, 0.97, ridge) * mask * smoothstep(0.4, 0.6, n);
    return 0.62 * billows + 0.22 * mask ** 1.5 + 0.18 * wisps;
  }, ANOMALY_SIZE);
  anomaly.texture.needsUpdate = true;
}

/**
 * One streak shape: a thin core line that brightens towards its head at the south end, with a
 * small bloom there, inside a wider, dimmer glow; the tail fades out to the north.
 * 0: a clean, sharp line. 1: a broader, softer one. 2: a line with a faint parallel twin.
 * 3: a line whose brightness ripples in beads along its length.
 */
function paintStreak(streak, fields, shape, gain) {
  const [, , veins] = fields;
  const half = STREAK_LENGTH / 2;
  const core = [0.035, 0.06, 0.035, 0.045][shape];
  const glow = [0.16, 0.28, 0.18, 0.2][shape];
  const line = (x, y, offset, width) => Math.exp(-(((x - offset) / width) ** 2));
  paint(streak.canvas, (x, y) => {
    if (Math.abs(x) > 1 || Math.abs(y) > half + 0.6) return 0;
    // 0 at the tail (north end), 1 at the head (south end).
    const f = (y + half) / STREAK_LENGTH;
    const along = smoothstep(0, 1, f) ** 1.6 * (1 - smoothstep(1, 1.04, f));
    const ripple = shape === 3 ? 0.72 + 0.28 * Math.cos(f * 30 + 6 * veins(0, y * 0.4)) : 1;
    // A slight wobble keeps the core from looking ruled.
    const wobble = 0.02 * (veins(3, y * 0.5) - 0.5);
    let value = along * ripple * (line(x, 0, wobble, core) + 0.35 * line(x, 0, wobble, glow));
    if (shape === 2) value += 0.45 * along * line(x, 0, 0.16 + wobble, core);
    const head = Math.hypot(x / 0.22, (y - half + 0.25) / 0.5);
    return gain * (1.3 * value + 0.6 * Math.exp(-head * head));
  });
  streak.texture.needsUpdate = true;
}

export default {
  tiles: [SIZE, SIZE],
  height: 0.1,
  elevation: 50,
  frames: 1,
  fps: 13, // the nebula's eight frames over a 36-tick lightning strike
  export: "warp-drive/graphics/entity/warp-field/warp-field",
  variants: ["shockwave", "nebula", "anomaly", "streak"],
  labels: { variant: "Effect", idle: "Nothing (main and shadow are empty)" },
  layers: [
    { name: "shockwave", tag: "shockwave", glow: true, variant: "shockwave", frames: 1, preview: { variant: "shockwave" } },
    { name: "nebula", tag: "nebula", glow: true, variant: "nebula", frames: NEBULA_FRAMES, preview: { variant: "nebula" } },
    { name: "anomaly", tag: "anomaly", glow: true, variant: "anomaly", frames: ANOMALY_SHAPES, preview: { variant: "anomaly" } },
    { name: "streak", tag: "streak", glow: true, variant: "streak", frames: STREAK_SHAPES * STREAK_FRAMES, preview: { variant: "streak" } }
  ],

  build() {
    const root = new THREE.Group();

    // The ring: a sharp leading edge, a wake that fades towards the centre, and an uneven glow
    // along its length so it reads as energy rather than a drawn circle.
    const ring = canvasTexture();
    const unevenness = sampler(noise(NOISE, 31, 6, 4));
    paint(ring.canvas, (x, y) => {
      const r = Math.hypot(x, y / ROUND_DEPTH);
      const edge = Math.exp(-(((r - RING) / 0.4) ** 2));
      const wake = r < RING ? 0.6 * Math.exp(-(RING - r) / 1.3) : 0;
      return (edge + wake) * (0.65 + 0.7 * unevenness(x * 1.5, y * 1.5)) * (1 - smoothstep(RING + 0.8, RING + 0.98, r));
    });
    const shockwave = plane(root, "shockwave", ring.texture);

    const nebula = canvasTexture();
    const cloud = plane(root, "nebula", nebula.texture);

    const anomaly = canvasTexture(ANOMALY_TEXTURE);
    const anomalyPlane = plane(root, "anomaly", anomaly.texture, ANOMALY_SIZE);

    const streak = canvasTexture();
    const streakPlane = plane(root, "streak", streak.texture);

    root.userData = {
      streak,
      streakPlane,
      shockwave,
      cloud,
      nebula,
      anomaly,
      anomalyPlane,
      fields: [noise(NOISE, 101, 3, 6), noise(NOISE, 202, 3, 6), noise(NOISE, 303, 4, 3)].map(sampler)
    };
    return root;
  },

  setVariant(root, name) {
    root.userData.shockwave.visible = name === "shockwave";
    root.userData.cloud.visible = name === "nebula";
    root.userData.anomalyPlane.visible = name === "anomaly";
    root.userData.streakPlane.visible = name === "streak";
  },

  // `t` runs from 0 to 1 over the layer: the nebula's whole life, or one anomaly shape per frame.
  animate(root, t) {
    const { cloud, nebula, fields, anomaly, anomalyPlane, streak, streakPlane } = root.userData;
    if (streakPlane.visible) {
      const frame = Math.round(t * STREAK_SHAPES * STREAK_FRAMES);
      const step = frame % STREAK_FRAMES;
      paintStreak(streak, fields, Math.floor(frame / STREAK_FRAMES), STREAK_FADE_IN[step] ?? 1);
      return;
    }
    if (anomalyPlane.visible) {
      paintAnomaly(anomaly, fields, Math.round(t * ANOMALY_SHAPES));
      return;
    }
    if (!cloud.visible) return;
    const [early, late, veins] = fields;
    const p = t + 0.5 / NEBULA_FRAMES;
    const reach = 3 + 3.5 * smoothstep(0, 0.45, p);
    const threshold = 0.36 + 0.18 * smoothstep(0.4, 1, p);
    const core = 0.75 * pulse(0, 0.12, 0.25, 0.75, p);
    // Filaments are ridges of a third field, shifted every frame so they flicker, and broken into
    // segments by the cloud's own density.
    const shift = Math.round(p * NEBULA_FRAMES) * 3.7;
    paint(nebula.canvas, (x, y) => {
      const r = Math.hypot(x, y);
      const n = mix(early(x, y), late(x * 0.9 + 1.3, y * 0.9 - 0.7), p);
      const lobes = early(x * 0.35 + 4, y * 0.35 - 2);
      const outline = 1 - smoothstep(reach * 0.3, reach, r + (n - 0.5) * 6 + (lobes - 0.5) * 6);
      const density = smoothstep(threshold, threshold + 0.3, n) * outline;
      const ridge = 1 - Math.abs(2 * veins(x * 1.3 + shift, y * 1.3 - shift) - 1);
      const segments = smoothstep(0.5, 0.62, late(x * 2.2 - shift, y * 2.2));
      const filament = smoothstep(0.955, 0.99, ridge) * segments * outline * (1 - smoothstep(0.55, 0.95, p));
      const glow = core * Math.exp(-((r / (0.8 + 0.15 * reach)) ** 2));
      return 1.1 * density * (1 - 0.6 * smoothstep(0.5, 1, p)) + glow + 0.8 * filament;
    });
    nebula.texture.needsUpdate = true;
  }
};
