// Renders a models/<name>.js building into Factorio sprite sheets inside the browser.
//
// Projection: an orthographic camera looks down from the south at `elevation` degrees (60 by
// default), and the image is stretched vertically so the ground plane keeps exactly TILE pixels
// per tile on both axes. That keeps a building's footprint aligned with Factorio's square tile
// grid, while vertical parts rise by cot(elevation) tiles per tile of height (0.58 at 60°).
//
// Transparency: lit layers are rendered once over black and once over white. Over black a pixel
// is a·c, over white a·c + (1 − a), so their difference gives the alpha and the black render
// gives the colour. This keeps glass, antialiased edges, and soft shadows exact.
//
// Layers, matching how vanilla Space Age buildings are drawn:
// - main: the lit building, every frame.
// - mask-<name>: meshes whose material has `userData.mask = name`, lit and cut out by everything
//   in front of them. Rendered near-neutral so the game can tint them per recipe.
// - glow-<name>: meshes whose material has `userData.glow = {layer: name, color?, scale?}`, as
//   flat emitted light for `blend_mode = "additive"` and `draw_as_glow`. Stored with alpha equal to
//   the brightest channel, so dark pixels are transparent and Factorio crops them away; after
//   Factorio premultiplies on load, each pixel adds exactly the rendered light.
// - extra layers from the model's `layers`: {name, tag (or tags), variant, frames, span, preview}.
//   Each renders meshes whose material's `userData.tag` is one of its tags, cut out by every
//   opaque mesh in front of them, with `setVariant(root, variant)` active, over `span` animation
//   loops in `frames` frames, so a layer can animate slower than the building. Every other layer
//   is rendered with `setVariant(root, null)`. `preview` is passed through to the preview page, and
//   `mute` (0–1) reduces the layer's saturation and contrast by that fraction; a material's
//   `userData.mute` overrides it for that part. Parts with different amounts are rendered in
//   separate passes (the others hiding them by depth only), muted, and composited. `blur` (pixels
//   of the sheet), `alpha` (opacity factor), and `shade` (brightness factor) then soften the
//   result, for contents seen through a glowing liquid.
//   Meshes whose material has `userData.cutsLayers` hide these layers wherever they are drawn,
//   regardless of depth, for parts such as lids that tagged contents must never overlap.
//   With `glow: true` the layer instead captures the tagged meshes' emitted light like a glow-*
//   layer (emissive colour, intensity, and emissive and alpha maps), for an additive overlay.
// - shadow: the sun shadow alone, from frame 0, for `draw_as_shadow`, with the model's
//   `shadowVariant` (default none) active.
import * as THREE from "three";
import { RoomEnvironment } from "three/addons/environments/RoomEnvironment.js";

// Factorio draws high-resolution sprites at `scale = 0.5`, which is 64 image pixels per tile.
const TILE = 64;
const SUPERSAMPLE = 2;
// Vanilla art is lit from the west and slightly north, so shadows fall east and a little south.
const SUN = new THREE.Vector3(-1, 1, -0.25).normalize();
const SUN_INTENSITY = 2.3;
// A ring of soft shadowed sky lights is an inexpensive ambient occlusion: it darkens creases and
// the ground under overhangs the way Factorio's baked renders do. Each costs a texture unit
// (WebGL guarantees 16), so keep it small next to the sun and the material maps.
const SKY_LIGHTS = 6;
const SKY_INTENSITY = 1.2;
const SHADOW_OPACITY = 0.75;
const GLASS_SHADOW = 0.35;
const MAX_SHEET = 8192;
const MAX_LINE = 8;

window.renderSprite = async function (name, options = {}) {
  const model = (await import(`./models/${name}.js`)).default;
  const elevation = THREE.MathUtils.degToRad(options.elevation ?? model.elevation ?? 60);
  const frameCount = options.frames ?? model.frames ?? 1;
  const sin = Math.sin(elevation);
  const cos = Math.cos(elevation);
  const [tilesX, tilesZ] = model.tiles;

  // Canvas centred on the entity origin, wide enough for the model and its shadow.
  const shadowReach = model.height * Math.max(Math.abs(SUN.x), Math.abs(SUN.z)) / SUN.y;
  const halfW = Math.ceil(tilesX / 2 + Math.max(shadowReach, model.height) + 1);
  const halfH = Math.ceil(tilesZ / 2 + Math.max(shadowReach, model.height * cos / sin) + 1);
  const W = halfW * 2 * TILE;
  const H = halfH * 2 * TILE;

  const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true, stencil: true });
  renderer.setPixelRatio(1);
  renderer.setSize(W * SUPERSAMPLE, H * SUPERSAMPLE, false);
  renderer.shadowMap.enabled = true;
  // Models may clip parts with material.clippingPlanes, such as specimens kept inside their tanks.
  renderer.localClippingEnabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  // Shadow maps are refreshed once per pose rather than on every one of a frame's renders.
  renderer.shadowMap.autoUpdate = false;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;

  const camera = new THREE.OrthographicCamera(-halfW, halfW, halfH * sin, -halfH * sin, 1, 500);
  camera.position.set(0, 100 * sin, 100 * cos);
  camera.lookAt(0, 0, 0);

  const scene = new THREE.Scene();
  scene.environment = new THREE.PMREMGenerator(renderer).fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environmentIntensity = 0.35;
  scene.add(new THREE.HemisphereLight(0xdfe8ff, 0x3a3630, 0.25));
  const reach = Math.max(halfW, halfH) + 4;
  const shadowed = (light, size, radius) => {
    light.castShadow = true;
    Object.assign(light.shadow.camera, { left: -reach, right: reach, top: reach, bottom: -reach, near: 1, far: 200 });
    light.shadow.mapSize.set(size, size);
    light.shadow.bias = -0.0004;
    light.shadow.normalBias = 0.02;
    light.shadow.radius = radius;
    scene.add(light, light.target);
    return light;
  };
  const sun = shadowed(new THREE.DirectionalLight(0xfff2dc, SUN_INTENSITY), 4096, 3);
  sun.position.copy(SUN).multiplyScalar(60);
  const sky = [];
  for (let i = 0; i < SKY_LIGHTS; i++) {
    const azimuth = (i / SKY_LIGHTS) * Math.PI * 2 + 0.4;
    const light = shadowed(new THREE.DirectionalLight(0xd4e0ff, SKY_INTENSITY / SKY_LIGHTS), 2048, 10);
    light.position.set(Math.cos(azimuth) * 0.9, 1, Math.sin(azimuth) * 0.9).multiplyScalar(60);
    sky.push(light);
  }

  const ground = new THREE.Mesh(new THREE.PlaneGeometry(reach * 4, reach * 4),
    new THREE.ShadowMaterial({ opacity: SHADOW_OPACITY }));
  ground.rotation.x = -Math.PI / 2;
  ground.receiveShadow = true;
  ground.visible = false;
  scene.add(ground);

  const root = await model.build(THREE);
  scene.add(root);
  // Extra-layer cutting: `cutsLayers` meshes become stencil masks drawn first, ignoring depth, and
  // tagged materials only draw where the mask is unset. Outside extra-layer passes the stencil is
  // never written, so the test always passes.
  const stencilMask = new THREE.MeshBasicMaterial({
    colorWrite: false, depthWrite: false, depthTest: false, stencilWrite: true, stencilRef: 1,
    stencilFunc: THREE.AlwaysStencilFunc, stencilZPass: THREE.ReplaceStencilOp
  });
  root.traverse((object) => {
    if (object.isMesh && object.material.userData.cutsLayers) object.renderOrder = -10;
  });
  // Applied when a layer is rendered, since models may swap tagged materials in setVariant().
  const cutByMask = (material) => Object.assign(material, {
    stencilWrite: true, stencilRef: 1, stencilFunc: THREE.NotEqualStencilFunc,
    stencilFail: THREE.KeepStencilOp, stencilZFail: THREE.KeepStencilOp, stencilZPass: THREE.KeepStencilOp
  });
  const meshes = [];
  const masks = new Set();
  const glows = new Set();
  root.traverse((object) => {
    if (!object.isMesh) return;
    meshes.push(object);
    object.castShadow = !object.material.transparent;
    object.receiveShadow = true;
    const data = object.material.userData;
    if (data.mask) masks.add(data.mask);
    if (data.glow) glows.add(data.glow.layer);
  });

  const work = document.createElement("canvas");
  work.width = W;
  work.height = H;
  const ctx = work.getContext("2d", { willReadFrequently: true });
  ctx.imageSmoothingQuality = "high";

  function read(color) {
    renderer.setClearColor(color, 1);
    renderer.render(scene, camera);
    ctx.clearRect(0, 0, W, H);
    ctx.drawImage(renderer.domElement, 0, 0, W, H);
    return ctx.getImageData(0, 0, W, H).data;
  }

  function captureAlpha() {
    const black = read(0x000000);
    const white = read(0xffffff);
    const image = new ImageData(W, H);
    for (let i = 0; i < black.length; i += 4) {
      const d = white[i] - black[i] + white[i + 1] - black[i + 1] + white[i + 2] - black[i + 2];
      const a = Math.min(1, Math.max(0, 1 - d / 765));
      if (a < 1 / 255) continue;
      for (let k = 0; k < 3; k++) image.data[i + k] = Math.min(255, Math.round(black[i + k] / a));
      image.data[i + 3] = Math.round(a * 255);
    }
    return image;
  }

  // Emitted light only, stored as (colour / alpha, alpha) with alpha = the brightest channel.
  function captureGlow() {
    const data = read(0x000000);
    const image = new ImageData(W, H);
    for (let i = 0; i < data.length; i += 4) {
      const peak = Math.max(data[i], data[i + 1], data[i + 2]);
      if (peak < 2) continue;
      for (let k = 0; k < 3; k++) image.data[i + k] = Math.round((data[i + k] * 255) / peak);
      image.data[i + 3] = peak;
    }
    return image;
  }

  /** Temporarily replaces each mesh's material: `choose` returns a material, null to hide, or undefined to keep. */
  function swap(choose, capture) {
    const saved = meshes.map((mesh) => [mesh, mesh.material, mesh.visible, mesh.renderOrder]);
    for (const mesh of meshes) {
      const source = mesh.material;
      const replacement = choose(source);
      if (replacement === null) mesh.visible = false;
      else if (replacement) mesh.material = replacement === occluder ? occluderFor(source) : replacement;
      // Occluders write no colour, so they must fill the depth buffer before anything they hide
      // is drawn; otherwise parts drawn earlier stay visible in front of them.
      if (replacement === occluder) mesh.renderOrder = -20;
    }
    try {
      return capture();
    } finally {
      for (const [mesh, material, visible, renderOrder] of saved) {
        mesh.material = material;
        mesh.visible = visible;
        mesh.renderOrder = renderOrder;
      }
    }
  }

  // Writes depth but no colour, so it hides what is behind it and leaves the pixel transparent.
  const occluder = new THREE.MeshBasicMaterial({ colorWrite: false });
  // Clipped parts hide only what is left of them, so their occluder keeps their clipping planes.
  const clippedOccluders = new Map();
  function occluderFor(source) {
    if (!source.clippingPlanes?.length) return occluder;
    if (!clippedOccluders.has(source)) {
      clippedOccluders.set(source, new THREE.MeshBasicMaterial({ colorWrite: false, clippingPlanes: source.clippingPlanes }));
    }
    return clippedOccluders.get(source);
  }
  const black = new THREE.MeshBasicMaterial({ color: 0x000000 });
  const glowMaterials = new Map();
  function glowMaterial(source) {
    let material = glowMaterials.get(source);
    if (!material) {
      material = new THREE.MeshBasicMaterial({ toneMapped: false });
      glowMaterials.set(source, material);
    }
    // Extra glow layers also capture tagged materials without `userData.glow`, by their emissive.
    const glow = source.userData.glow ?? {};
    const color = glow.color !== undefined ? new THREE.Color(glow.color) : source.emissive?.clone() ?? new THREE.Color(0);
    material.color.copy(color).multiplyScalar((source.emissiveIntensity ?? 1) * (glow.scale ?? 1));
    material.map = source.emissiveMap ?? null;
    material.alphaMap = source.alphaMap ?? null;
    material.transparent = source.transparent;
    material.opacity = source.transparent ? source.opacity : 1;
    material.depthWrite = source.depthWrite;
    material.side = source.side;
    return material;
  }

  const pose = (t) => {
    model.animate?.(root, t);
    renderer.shadowMap.needsUpdate = true;
  };

  const setVariant = (name) => model.setVariant?.(root, name);
  const layers = { main: [] };
  for (const mask of masks) layers[`mask-${mask}`] = [];
  for (const glow of glows) layers[`glow-${glow}`] = [];
  setVariant(null);
  for (let f = 0; f < frameCount; f++) {
    pose(f / frameCount);
    layers.main.push(crop(captureAlpha(), W, H));
    for (const mask of masks) {
      layers[`mask-${mask}`].push(crop(swap((m) => (m.userData.mask === mask ? undefined : m.transparent ? null : occluder), captureAlpha), W, H));
    }
    for (const glow of glows) {
      layers[`glow-${glow}`].push(crop(swap((m) => (m.userData.glow?.layer === glow ? glowMaterial(m) : m.transparent ? null : black), captureGlow), W, H));
    }
  }

  for (const layer of model.layers ?? []) {
    setVariant(layer.variant ?? null);
    layers[layer.name] = [];
    const tags = layer.tags ?? [layer.tag];
    const tagged = (m) => tags.includes(m.userData.tag);
    const muteOf = (m) => m.userData.mute ?? layer.mute ?? 0;
    for (let f = 0; f < layer.frames; f++) {
      pose((f / layer.frames) * (layer.span ?? 1));
      if (layer.glow) {
        layers[layer.name].push(crop(swap((m) => (tagged(m) ? glowMaterial(m) : m.transparent ? null : black), captureGlow), W, H));
        continue;
      }
      const amounts = new Set();
      root.traverseVisible((o) => o.isMesh && tagged(o.material) && amounts.add(muteOf(o.material)));
      let image = null;
      for (const amount of amounts) {
        const pass = mute(amount, swap((m) => (tagged(m)
          ? (muteOf(m) === amount ? void cutByMask(m) : m.transparent ? null : occluder)
          : m.userData.cutsLayers ? stencilMask : m.transparent ? null : occluder), captureAlpha));
        image = image ? over(pass, image) : pass;
      }
      if (image && (layer.blur || layer.alpha !== undefined || layer.shade !== undefined)) image = soften(image, layer);
      layers[layer.name].push(image ? crop(image, W, H) : null);
    }
  }
  setVariant(model.shadowVariant ?? null);

  // Shadow pass: only the sun, and the model stays in the shadow map but writes no colour, so
  // only the shadow it casts onto the ground plane remains. Glass casts nothing in the lit
  // passes; here it is added as a lighter shadow, GLASS_SHADOW of a solid one.
  pose(0);
  for (const light of sky) light.visible = false;
  ground.visible = true;
  const caster = new THREE.MeshBasicMaterial({ colorWrite: false, depthWrite: false });
  const solid = swap((m) => (m.transparent ? null : caster), captureAlpha);
  for (const mesh of meshes) mesh.castShadow = true;
  renderer.shadowMap.needsUpdate = true;
  const withGlass = swap(() => caster, captureAlpha);
  for (const mesh of meshes) mesh.castShadow = !mesh.material.transparent;
  for (let i = 3; i < solid.data.length; i += 4) {
    solid.data[i] = Math.max(solid.data[i], Math.round(withGlass.data[i] * GLASS_SHADOW));
  }
  layers.shadow = [crop(solid, W, H)];
  setVariant(null);

  const sheets = {};
  for (const [layer, crops] of Object.entries(layers)) {
    const result = sheet(crops, W, H);
    const extra = (model.layers ?? []).find((l) => l.name === layer);
    if (result && extra) Object.assign(result, { span: extra.span ?? 1, preview: { ...(extra.glow ? { blend: "additive" } : {}), ...extra.preview } });
    if (result) sheets[layer] = result;
  }
  renderer.dispose();
  const { tiles, references = [], export: exportPath = null, fps = 12, variants = [], variantColors = {}, loop = frameCount, labels = {}, night = true } = model;
  return { sheets, model: { tiles, references, variants, variantColors, exportPath, fps, loop, labels, night } };
};

/**
 * Mutes an image in place: each channel moves `amount` of the way to the pixel's luminance
 * (less saturation), then `amount` of the way to mid-grey (less contrast). Alpha is unchanged.
 */
function mute(amount, image) {
  if (!amount) return image;
  const d = image.data;
  for (let i = 0; i < d.length; i += 4) {
    if (d[i + 3] === 0) continue;
    const l = 0.299 * d[i] + 0.587 * d[i + 1] + 0.114 * d[i + 2];
    for (let k = 0; k < 3; k++) {
      const c = d[i + k] + (l - d[i + k]) * amount;
      d[i + k] = Math.round(c + (128 - c) * amount);
    }
  }
  return image;
}

/** Blurs an image by `blur` pixels, then scales its colour by `shade` and its opacity by `alpha`. */
function soften(image, { blur = 0, alpha = 1, shade = 1 }) {
  const source = document.createElement("canvas");
  source.width = image.width;
  source.height = image.height;
  source.getContext("2d").putImageData(image, 0, 0);
  const target = document.createElement("canvas");
  target.width = image.width;
  target.height = image.height;
  const ctx = target.getContext("2d", { willReadFrequently: true });
  ctx.filter = blur ? `blur(${blur}px)` : "none";
  ctx.drawImage(source, 0, 0);
  const out = ctx.getImageData(0, 0, image.width, image.height);
  const d = out.data;
  for (let i = 0; i < d.length; i += 4) {
    for (let k = 0; k < 3; k++) d[i + k] = Math.round(d[i + k] * shade);
    d[i + 3] = Math.round(d[i + 3] * alpha);
  }
  return out;
}

/** Composites `top` over `bottom` (straight alpha) into a new image. */
function over(top, bottom) {
  const out = new ImageData(top.width, top.height);
  const t = top.data, b = bottom.data, o = out.data;
  for (let i = 0; i < o.length; i += 4) {
    const at = t[i + 3] / 255, ab = b[i + 3] / 255;
    const a = at + ab * (1 - at);
    if (a <= 0) continue;
    for (let k = 0; k < 3; k++) o[i + k] = Math.round((t[i + k] * at + b[i + k] * ab * (1 - at)) / a);
    o[i + 3] = Math.round(a * 255);
  }
  return out;
}

/** Trims an image to its visible pixels; frames are kept cropped so long animations fit in memory. */
function crop(image, W, H) {
  let x0 = W, y0 = H, x1 = -1, y1 = -1;
  for (let y = 0; y < H; y++) {
    for (let x = 0; x < W; x++) {
      if (image.data[(y * W + x) * 4 + 3] === 0) continue;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
    }
  }
  if (x1 < 0) return null;
  const width = x1 - x0 + 1;
  const height = y1 - y0 + 1;
  const out = new ImageData(width, height);
  for (let row = 0; row < height; row++) {
    const start = ((y0 + row) * W + x0) * 4;
    out.data.set(image.data.subarray(start, start + width * 4), row * width * 4);
  }
  return { x0, y0, image: out };
}

/** Lays cropped frames out as a Factorio sheet over their common bounds. */
function sheet(crops, W, H) {
  const present = crops.filter(Boolean);
  if (!present.length) return null;
  const pad = 2;
  let x0 = Math.max(0, Math.min(...present.map((c) => c.x0)) - pad);
  let y0 = Math.max(0, Math.min(...present.map((c) => c.y0)) - pad);
  const x1 = Math.min(W - 1, Math.max(...present.map((c) => c.x0 + c.image.width - 1)) + pad);
  const y1 = Math.min(H - 1, Math.max(...present.map((c) => c.y0 + c.image.height - 1)) + pad);
  const width = x1 - x0 + 1;
  const height = y1 - y0 + 1;
  const lineLength = Math.max(1, Math.min(crops.length, MAX_LINE, Math.floor(MAX_SHEET / width)));
  const rows = Math.ceil(crops.length / lineLength);
  const canvas = document.createElement("canvas");
  canvas.width = width * lineLength;
  canvas.height = height * rows;
  const ctx = canvas.getContext("2d");
  crops.forEach((c, i) => {
    if (!c) return;
    ctx.putImageData(c.image, (i % lineLength) * width + c.x0 - x0, Math.floor(i / lineLength) * height + c.y0 - y0);
  });
  return {
    dataURL: canvas.toDataURL("image/png"),
    width,
    height,
    frame_count: crops.length,
    line_length: lineLength,
    // Factorio `shift` is in tiles: the offset from the entity centre to the frame centre.
    shift: [(x0 + width / 2 - W / 2) / TILE, (y0 + height / 2 - H / 2) / TILE]
  };
}

window.modelType = async (name) => (await import(`./models/${name}.js`)).default.type ?? "sprite";
window.rendererReady = true;

// Icons: models with `type: "icon"`. Each mipmap size (`model.sizes`, by default 64, 32, 16, 8 px)
// is rendered on its own with a plain orthographic camera fitted to the model, then laid side by
// side in one strip, the layout Factorio reads as an icon with custom mipmaps.
const ICON_SIZES = [64, 32, 16, 8];
const ICON_SUPERSAMPLE = 8;

window.renderIcon = async function (name, options = {}) {
  const model = (await import(`./models/${name}.js`)).default;
  const elevation = THREE.MathUtils.degToRad(options.elevation ?? model.elevation ?? 50);
  const root = await model.build(THREE);
  const scene = new THREE.Scene();
  scene.add(root);
  const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
  renderer.setPixelRatio(1);
  renderer.shadowMap.enabled = true;
  renderer.shadowMap.type = THREE.PCFShadowMap;
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  scene.environment = new THREE.PMREMGenerator(renderer).fromScene(new RoomEnvironment(), 0.04).texture;
  scene.environmentIntensity = 0.35;
  scene.add(new THREE.HemisphereLight(0xdfe8ff, 0x3a3630, 0.4));
  // Stronger, warmer key light than the building gets, for the contrast vanilla icons have.
  const sun = new THREE.DirectionalLight(0xfff0d8, SUN_INTENSITY * 1.4);
  sun.position.copy(SUN).multiplyScalar(60);
  sun.castShadow = true;
  Object.assign(sun.shadow.camera, { left: -10, right: 10, top: 10, bottom: -10, near: 1, far: 200 });
  sun.shadow.mapSize.set(2048, 2048);
  sun.shadow.bias = -0.0004;
  sun.shadow.normalBias = 0.02;
  scene.add(sun, sun.target);
  root.traverse((o) => {
    if (o.isMesh) {
      o.castShadow = !o.material.transparent;
      o.receiveShadow = true;
    }
  });

  // Fit a square frustum around the model's corners as the camera sees them.
  const camera = new THREE.OrthographicCamera(-1, 1, 1, -1, 1, 500);
  camera.position.set(0, 100 * Math.sin(elevation), 100 * Math.cos(elevation));
  camera.lookAt(0, 0, 0);
  camera.updateMatrixWorld();
  // Fitted to the actual vertices: a bounding box's corners stick out past rounded or hexagonal
  // shapes and would leave the icon smaller than its slot.
  root.updateMatrixWorld(true);
  let x0 = Infinity, x1 = -Infinity, y0 = Infinity, y1 = -Infinity;
  const p = new THREE.Vector3();
  root.traverse((o) => {
    if (!o.isMesh) return;
    const position = o.geometry.attributes.position;
    for (let i = 0; i < position.count; i++) {
      p.fromBufferAttribute(position, i).applyMatrix4(o.matrixWorld).applyMatrix4(camera.matrixWorldInverse);
      x0 = Math.min(x0, p.x); x1 = Math.max(x1, p.x); y0 = Math.min(y0, p.y); y1 = Math.max(y1, p.y);
    }
  });
  const half = (Math.max(x1 - x0, y1 - y0) / 2) * 1.02;
  const cx = (x0 + x1) / 2;
  const cy = (y0 + y1) / 2;
  Object.assign(camera, { left: cx - half, right: cx + half, top: cy + half, bottom: cy - half });
  camera.updateProjectionMatrix();

  const strip = document.createElement("canvas");
  const sizes = model.sizes ?? ICON_SIZES;
  strip.width = sizes.reduce((a, b) => a + b, 0);
  strip.height = sizes[0];
  let offset = 0;
  for (const size of sizes) {
    const big = size * ICON_SUPERSAMPLE;
    renderer.setSize(big, big, false);
    const read = (color) => {
      renderer.setClearColor(color, 1);
      renderer.render(scene, camera);
      const c = document.createElement("canvas");
      c.width = c.height = big;
      const ctx = c.getContext("2d", { willReadFrequently: true });
      ctx.drawImage(renderer.domElement, 0, 0);
      return ctx.getImageData(0, 0, big, big).data;
    };
    const black = read(0x000000);
    const white = read(0xffffff);
    const image = new ImageData(big, big);
    for (let i = 0; i < black.length; i += 4) {
      const d = white[i] - black[i] + white[i + 1] - black[i + 1] + white[i + 2] - black[i + 2];
      const a = Math.min(1, Math.max(0, 1 - d / 765));
      if (a < 1 / 255) continue;
      for (let k = 0; k < 3; k++) image.data[i + k] = Math.min(255, Math.round(black[i + k] / a));
      image.data[i + 3] = Math.round(a * 255);
    }
    // Halve repeatedly for a clean box-filtered downsample.
    let level = document.createElement("canvas");
    level.width = level.height = big;
    level.getContext("2d").putImageData(image, 0, 0);
    while (level.width > size) {
      const next = document.createElement("canvas");
      next.width = next.height = level.width / 2;
      const ctx = next.getContext("2d");
      ctx.imageSmoothingQuality = "high";
      ctx.drawImage(level, 0, 0, next.width, next.height);
      level = next;
    }
    strip.getContext("2d").drawImage(level, offset, 0);
    offset += size;
  }
  renderer.dispose();
  return { icon: strip.toDataURL("image/png"), sizes, references: model.references ?? [], exportPath: model.export ?? null };
};
