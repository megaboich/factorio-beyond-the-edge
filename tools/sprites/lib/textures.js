// Procedural, tileable surface textures in the worn industrial style of Factorio's baked renders:
// panel seams with lit bevels, rivets, hazard stripes, floor grating, grime, rust, and scratches.
import * as THREE from "three";

export function random(seed) {
  let state = (Math.floor(Math.abs(seed) * 9973) % 2147483646) + 1;
  return () => (state = (state * 16807) % 2147483647) / 2147483647;
}

const smooth = (t) => t * t * (3 - 2 * t);
const smoothstep = (a, b, x) => smooth(Math.min(1, Math.max(0, (x - a) / (b - a))));

/** Tileable fractal value noise in [0, 1]: `size`² samples, `cells` lattice cells per side at the coarsest octave. */
export function noise(size, seed, cells = 4, octaves = 4) {
  const out = new Float32Array(size * size);
  const rand = random(seed);
  let amplitude = 1;
  let total = 0;
  for (let octave = 0; octave < octaves; octave++) {
    const n = cells << octave;
    const grid = Float32Array.from({ length: n * n }, rand);
    for (let y = 0; y < size; y++) {
      const gy = (y / size) * n;
      const y0 = Math.floor(gy);
      const fy = smooth(gy - y0);
      const y1 = (y0 + 1) % n;
      for (let x = 0; x < size; x++) {
        const gx = (x / size) * n;
        const x0 = Math.floor(gx);
        const fx = smooth(gx - x0);
        const x1 = (x0 + 1) % n;
        const top = grid[y0 * n + x0] + (grid[y0 * n + x1] - grid[y0 * n + x0]) * fx;
        const bottom = grid[y1 * n + x0] + (grid[y1 * n + x1] - grid[y1 * n + x0]) * fx;
        out[y * size + x] += amplitude * (top + (bottom - top) * fy);
      }
    }
    total += amplitude;
    amplitude *= 0.5;
  }
  for (let i = 0; i < out.length; i++) out[i] /= total;
  return out;
}

const cache = new Map();

/**
 * Paints a tileable worn surface and returns matching colour, roughness, and bump textures.
 * `panels` splits it into an n×n plate grid with dark seams and top-left-lit bevels, `rivets`
 * adds corner rivets, `stripes` paints worn hazard stripes, `holes` makes an n×n floor grating,
 * and `grime`, `rust`, and `scratches` (0–1) weather it.
 */
export function surface(options) {
  const key = JSON.stringify(options);
  if (cache.has(key)) return cache.get(key);
  const {
    size = 512, color = 0x808080, panels = 0, rivets = false, stripes = false, holes = 0,
    rust = 0, grime = 0.35, scratches = 0.3, variation = 0.16, roughness = 0.5, seed = 1
  } = options;
  const broad = noise(size, seed, 3, 5);
  const fine = noise(size, seed + 11, 32, 2);
  const dirt = noise(size, seed + 23, 5, 5);
  const corrosion = noise(size, seed + 37, 4, 6);
  const rand = random(seed + 51);
  const plates = Math.max(1, panels);
  const plateShade = Array.from({ length: plates * plates }, () => 1 + (rand() - 0.5) * 0.14);
  const base = [(color >> 16) & 255, (color >> 8) & 255, color & 255];
  const cell = size / plates;
  const pitch = holes ? size / holes : 0;
  const colorData = new ImageData(size, size);
  const roughData = new ImageData(size, size);
  const bumpData = new ImageData(size, size);

  for (let y = 0; y < size; y++) {
    for (let x = 0; x < size; x++) {
      const i = y * size + x;
      let rgb = base;
      let shade = 1 + (broad[i] - 0.5) * 2 * variation + (fine[i] - 0.5) * 0.1;
      let rough = roughness + (fine[i] - 0.5) * 0.1;
      let bump = 0.5 + (fine[i] - 0.5) * 0.12;

      if (stripes) {
        const band = Math.floor((x + y) / (size / 8)) % 2;
        const worn = smoothstep(0.6, 0.72, dirt[i] * 0.7 + fine[i] * 0.3);
        const paint = band === 0 ? [222, 165, 30] : [36, 34, 31];
        rgb = paint.map((c, k) => c + (base[k] - c) * worn);
        rough += worn * 0.1;
      }
      if (panels) {
        const px = x % cell;
        const py = y % cell;
        const edge = Math.min(px, py, cell - 1 - px, cell - 1 - py);
        shade *= plateShade[Math.floor(y / cell) * plates + Math.floor(x / cell)];
        if (edge < 1.5) {
          shade *= 0.35;
          bump = 0.15;
          rough += 0.25;
        } else if (edge < 4.5) {
          shade *= px < 4.5 || py < 4.5 ? 1.14 : 0.8;
          bump = 0.62;
        }
        if (rivets) {
          const inset = 10;
          for (const [cx, cy] of [[inset, inset], [cell - inset, inset], [inset, cell - inset], [cell - inset, cell - inset]]) {
            const dx = px - cx;
            const dy = py - cy;
            if (dx * dx + dy * dy < 11) {
              shade *= dx + dy < 0 ? 1.3 : 0.7;
              bump = 0.9;
            }
          }
        }
      }
      if (holes) {
        const hx = x % pitch;
        const hy = y % pitch;
        const margin = pitch * 0.2;
        if (hx > margin && hx < pitch - margin && hy > margin && hy < pitch - margin) {
          shade *= 0.15;
          bump = 0.02;
          rough = 0.95;
        } else {
          const bar = Math.min(Math.abs(hx - margin), Math.abs(hy - margin));
          if (bar < 1.5) shade *= 1.15;
          bump = 0.7;
        }
      }

      const g = smoothstep(0.45, 0.78, dirt[i]) * grime;
      shade *= 1 - g * 0.6;
      rough += g * 0.3;
      let out = rgb;
      if (rust > 0) {
        const r = smoothstep(1 - rust * 0.55, 1 - rust * 0.55 + 0.15, corrosion[i]);
        const tone = 0.7 + fine[i] * 0.6;
        out = rgb.map((c, k) => c + ([112, 62, 32][k] * tone - c) * r);
        rough += r * 0.35;
        bump += r * 0.1 * (fine[i] - 0.3);
      }
      const p = i * 4;
      for (let k = 0; k < 3; k++) colorData.data[p + k] = out[k] * shade;
      colorData.data[p + 3] = 255;
      const rv = Math.min(1, Math.max(0.04, rough)) * 255;
      roughData.data.set([rv, rv, rv, 255], p);
      const bv = Math.min(1, Math.max(0, bump)) * 255;
      bumpData.data.set([bv, bv, bv, 255], p);
    }
  }

  const canvas = (data) => {
    const c = document.createElement("canvas");
    c.width = c.height = size;
    c.getContext("2d").putImageData(data, 0, 0);
    return c;
  };
  const colorCanvas = canvas(colorData);
  const roughCanvas = canvas(roughData);
  if (scratches > 0) {
    const cctx = colorCanvas.getContext("2d");
    const rctx = roughCanvas.getContext("2d");
    for (let n = 0; n < scratches * 160; n++) {
      const x = rand() * size;
      const y = rand() * size;
      const angle = rand() * Math.PI;
      const length = 6 + rand() * 30;
      for (const [ctx, style] of [[cctx, "rgba(255,255,255,0.10)"], [rctx, "rgba(0,0,0,0.25)"]]) {
        ctx.strokeStyle = style;
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x + Math.cos(angle) * length, y + Math.sin(angle) * length);
        ctx.stroke();
      }
    }
  }
  const texture = (c, srgb) => {
    const t = new THREE.CanvasTexture(c);
    t.wrapS = t.wrapT = THREE.RepeatWrapping;
    t.anisotropy = 8;
    if (srgb) t.colorSpace = THREE.SRGBColorSpace;
    return t;
  };
  const result = { map: texture(colorCanvas, true), roughnessMap: texture(roughCanvas), bumpMap: texture(canvas(bumpData)) };
  cache.set(key, result);
  return result;
}

/**
 * A MeshStandardMaterial wearing `surface(options)`. `scale` is how many tiles one texture
 * repeat covers; geometry built with geometry.js `part()` gets world-scaled UVs to match.
 */
export function textured({ scale = 2, metalness = 0.6, bump = 1, ...options }) {
  const s = surface(options);
  const material = new THREE.MeshStandardMaterial({
    map: s.map, roughnessMap: s.roughnessMap, bumpMap: s.bumpMap, bumpScale: bump, metalness, roughness: 1
  });
  material.userData.uvScale = scale;
  return material;
}

/**
 * Tileable soft cloud noise for murky fluid, as a greyscale texture from `low` to `high`.
 * Scrolling it by whole repeats per animation loop keeps the loop seamless.
 */
export function clouds(seed, low = 0.4, high = 1, size = 256) {
  const values = noise(size, seed, 3, 5);
  const image = new ImageData(size, size);
  for (let i = 0; i < values.length; i++) {
    const v = Math.round((low + (high - low) * smoothstep(0.25, 0.75, values[i])) * 255);
    image.data.set([v, v, v, 255], i * 4);
  }
  const canvas = document.createElement("canvas");
  canvas.width = canvas.height = size;
  canvas.getContext("2d").putImageData(image, 0, 0);
  const texture = new THREE.CanvasTexture(canvas);
  texture.wrapS = texture.wrapT = THREE.RepeatWrapping;
  return texture;
}
