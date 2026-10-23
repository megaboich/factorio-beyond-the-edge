// Plays rendered sprite sheets the way Factorio layers them, next to reference art.
// Opened as out/<name>-preview.html, which loads <name>.meta.js (window.SPRITE_META) first.
// Layers may span several building loops (`span`), so the clock counts building frames over the
// longest span of the variant's own layers (or of the shared ones when it has none). A loop is the
// main sheet's frame count unless the model sets `loop` (for a static main sheet under animated
// layers). A layer's `preview.variant` shows it only for that variant (as the running recipe does
// in game), `preview.tint: "variant"` multiplies it by the variant's colour, and
// `preview.blend: "additive"` draws it as light. `preview.slider: "Label"` adds a slider that scales
// the layer's strength from 0 to 3, starting at `preview.gain` (default 1), for tuning glows. The
// model's `labels` rename the variant picker ({variant, idle}), and `night: false` drops the night
// panel for buildings that are only ever seen in daylight.
// "Use real background" (on by default) lays space platform floor tiles under every panel instead
// of the plain tile grid and footprint outline.
// "No recipe" shows the idle building as the game does with no recipe set: no variant layers, no
// tinted or glow layers, and the building frozen on its first frame.
// URL options: ?frame=n freezes one building frame, ?variant=name picks the variant (none for no
// recipe), ?fps=n sets the speed, ?grid starts with the plain grid.
// window.showFrame(variant, frame) draws one frame for scripted capture (tools/sprites/gif.mjs);
// window.previewInfo.periods gives each variant's cycle length in building frames.
(function () {
  const meta = window.SPRITE_META;
  const TILE = 64;
  const params = new URLSearchParams(location.search);
  const frozen = params.has("frame") ? Number(params.get("frame")) : null;
  const variantNames = meta.variants || [];
  const requested = params.get("variant");
  let variant = requested === "none" ? "" : requested || variantNames[0] || "";
  let fps = Number(params.get("fps") || meta.fps || 12);
  let playing = frozen === null;
  let frame = frozen || 0;
  let realBackground = !params.has("grid") && Boolean(meta.background);

  const load = (src) => new Promise((resolve, reject) => {
    const image = new Image();
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error(`cannot load ${src}`));
    image.src = src;
  });

  // Draw order as in game: shadow, building, model layers (in model order), then light glows.
  const names = Object.keys(meta.sheets);
  // A layer's `preview.order` overrides its place, for layers the game draws over its glows.
  const order = (layer) => meta.sheets[layer].preview?.order ?? (layer === "shadow" ? -2 : layer === "main" ? -1 : layer.startsWith("glow-") ? 1000 : names.indexOf(layer));
  const loop = meta.loop || meta.sheets.main.frame_count;
  const generated = names
    .sort((a, b) => order(a) - order(b))
    .map((layer) => ({
      ...meta.sheets[layer],
      layer,
      url: `${meta.name}-${layer}.png`,
      blend: layer === "shadow" ? "shadow" : layer.startsWith("glow-") || meta.sheets[layer].preview?.blend === "additive" ? "additive" : "normal",
      variant: meta.sheets[layer].preview?.variant,
      tintByVariant: meta.sheets[layer].preview?.tint === "variant",
      slider: meta.sheets[layer].preview?.slider,
      gain: meta.sheets[layer].preview?.gain ?? 1,
      // Model layers are drawn with draw_as_glow in game, so they stay fully lit at night.
      glow: Boolean(meta.sheets[layer].preview),
      // Drawn only while a recipe runs: recipe layers and working lights.
      needsRecipe: Boolean(meta.sheets[layer].preview) || layer.startsWith("glow-")
    }));
  // A variant's own layers set its cycle (so a one-shot plays once); otherwise every shared layer.
  const periodOf = (name) => {
    const own = generated.filter((layer) => layer.variant === name);
    const layers = own.length ? own : generated.filter((layer) => !layer.variant);
    return Math.round(loop * Math.max(1, ...layers.map((layer) => layer.span || 1)));
  };
  const periods = Object.fromEntries([...variantNames, ""].map((name) => [name, periodOf(name)]));
  const period = () => periods[variant] ?? periodOf(variant);
  const labels = { variant: "Recipe", idle: "No recipe", ...meta.labels };
  const panels = [
    { label: "Generated, day", night: false, tiles: meta.tiles, layers: generated },
    ...(meta.night === false ? [] : [{ label: "Generated, night", night: true, tiles: meta.tiles, layers: generated }]),
    ...meta.references.map((ref) => ({ label: ref.label, night: false, tiles: ref.tiles, layers: ref.layers }))
  ];

  let extentX = 0;
  let extentY = 0;
  for (const panel of panels) {
    for (const layer of panel.layers) {
      extentX = Math.max(extentX, Math.abs(layer.shift[0]) * TILE + layer.width / 2);
      extentY = Math.max(extentY, Math.abs(layer.shift[1]) * TILE + layer.height / 2);
    }
  }
  const W = Math.ceil(extentX / TILE + 0.5) * 2 * TILE;
  const H = Math.ceil(extentY / TILE + 0.5) * 2 * TILE;

  document.body.innerHTML = `
    <header>
      <h1>${meta.name}</h1>
      <label>${labels.variant} <select id="variant">${variantNames.map((n) => `<option ${n === variant ? "selected" : ""}>${n}</option>`).join("")}<option value="" ${variant === "" ? "selected" : ""}>${labels.idle}</option></select></label>
      <label>Speed <input id="fps" type="range" min="2" max="60" value="${fps}"> <span id="fps-value">${fps}</span> fps</label>
      <label><input id="real" type="checkbox" ${realBackground ? "checked" : ""} ${meta.background ? "" : "disabled"}> Use real background</label>
      <button id="play">${playing ? "Pause" : "Play"}</button>
      <span id="frame"></span>
      ${generated.filter((l) => l.slider).map((l) => `<label>${l.slider} <input id="gain-${l.layer}" type="range" min="0" max="3" step="0.05" value="${l.gain}"> <span id="gain-${l.layer}-value">${l.gain.toFixed(2)}</span></label>`).join("")}
    </header>
    <main>${panels.map((p, i) => `<figure><canvas id="panel-${i}" width="${W}" height="${H}"></canvas><figcaption>${p.label}</figcaption></figure>`).join("")}</main>`;
  const $ = (id) => document.getElementById(id);
  if (variantNames.length) $("variant").onchange = (e) => {
    variant = e.target.value;
    frame %= period();
  };
  $("fps").oninput = (e) => {
    fps = Number(e.target.value);
    $("fps-value").textContent = fps;
  };
  for (const layer of generated.filter((l) => l.slider)) {
    $(`gain-${layer.layer}`).oninput = (e) => {
      layer.gain = Number(e.target.value);
      $(`gain-${layer.layer}-value`).textContent = layer.gain.toFixed(2);
      draw();
    };
  }
  $("real").onchange = (e) => {
    realBackground = e.target.checked;
    draw();
  };
  $("play").onclick = () => {
    playing = !playing;
    $("play").textContent = playing ? "Pause" : "Play";
  };

  const scratch = document.createElement("canvas");
  const lit = document.createElement("canvas");
  lit.width = W;
  lit.height = H;

  /**
   * A W×H canvas of space platform floor. Tiles are aligned to the game grid around the entity
   * centre: an odd footprint centres on a tile, an even one on a tile corner. Two-tile pieces fill
   * about three quarters of the floor, as the game's tile variants do.
   */
  const floors = new Map();
  function floor(tiles) {
    const odd = tiles[0] % 2 === 1;
    if (floors.has(odd)) return floors.get(odd);
    const canvas = document.createElement("canvas");
    canvas.width = W;
    canvas.height = H;
    const ctx = canvas.getContext("2d");
    const origin = W / 2 - (odd ? TILE / 2 : 0);
    const columns = Math.ceil(W / TILE) + 2;
    const rows = Math.ceil(H / TILE) + 2;
    const x0 = origin - Math.ceil(origin / TILE + 1) * TILE;
    const y0 = H / 2 - (odd ? TILE / 2 : 0) - Math.ceil((H / 2) / TILE + 1) * TILE;
    let seed = 12345;
    const random = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
    const used = new Set();
    const { small, large, variants } = meta.background;
    for (let row = 0; row < rows; row++) {
      for (let col = 0; col < columns; col++) {
        if (used.has(`${col},${row}`)) continue;
        const v = Math.floor(random() * variants);
        const fits = ![[1, 0], [0, 1], [1, 1]].some(([dx, dy]) => used.has(`${col + dx},${row + dy}`));
        if (fits && random() < 0.75) {
          for (const [dx, dy] of [[0, 0], [1, 0], [0, 1], [1, 1]]) used.add(`${col + dx},${row + dy}`);
          ctx.drawImage(large, v * TILE * 2, 0, TILE * 2, TILE * 2, x0 + col * TILE, y0 + row * TILE, TILE * 2, TILE * 2);
        } else {
          used.add(`${col},${row}`);
          ctx.drawImage(small, v * TILE, 0, TILE, TILE, x0 + col * TILE, y0 + row * TILE, TILE, TILE);
        }
      }
    }
    floors.set(odd, canvas);
    return canvas;
  }

  /** The sheet position of a layer's frame at building frame `index`, honouring its span. */
  function source(layer, index) {
    const n = layer.frame_count || 1;
    const k = Math.floor((index * n) / ((layer.span || 1) * loop)) % n;
    const line = layer.line_length || 1;
    return [(k % line) * layer.width, Math.floor(k / line) * layer.height];
  }

  function rgb(color) {
    return `rgb(${color.map((c) => Math.round(c * 255)).join(",")})`;
  }

  function place(ctx, layer, index) {
    let [sx, sy] = source(layer, index);
    let image = layer.image;
    const tint = layer.tintByVariant && meta.variantColors?.[variant];
    if (tint) {
      scratch.width = layer.width;
      scratch.height = layer.height;
      const s = scratch.getContext("2d");
      s.drawImage(image, sx, sy, layer.width, layer.height, 0, 0, layer.width, layer.height);
      s.globalCompositeOperation = "multiply";
      s.fillStyle = rgb(tint);
      s.fillRect(0, 0, layer.width, layer.height);
      s.globalCompositeOperation = "destination-in";
      s.drawImage(image, sx, sy, layer.width, layer.height, 0, 0, layer.width, layer.height);
      [image, sx, sy] = [scratch, 0, 0];
    }
    ctx.globalCompositeOperation = layer.blend === "additive" ? "lighter" : "source-over";
    // A slider's gain above 1 adds the light again; the remainder is drawn at partial strength.
    const gain = layer.slider ? layer.gain : 1;
    for (let pass = 0; pass < Math.ceil(gain); pass++) {
      ctx.globalAlpha = Math.min(1, gain - pass);
      ctx.drawImage(image, sx, sy, layer.width, layer.height,
        W / 2 + layer.shift[0] * TILE - layer.width / 2, H / 2 + layer.shift[1] * TILE - layer.height / 2,
        layer.width, layer.height);
    }
    ctx.globalAlpha = 1;
    ctx.globalCompositeOperation = "source-over";
  }

  function draw() {
    for (const [i, panel] of panels.entries()) {
      const ctx = $(`panel-${i}`).getContext("2d");
      if (realBackground) {
        ctx.drawImage(floor(panel.tiles), 0, 0);
        if (panel.night) {
          ctx.fillStyle = "rgba(4,6,12,0.72)";
          ctx.fillRect(0, 0, W, H);
        }
      } else {
        ctx.fillStyle = panel.night ? "#16181b" : "#4b4f55";
        ctx.fillRect(0, 0, W, H);
        ctx.strokeStyle = panel.night ? "rgba(255,255,255,0.04)" : "rgba(255,255,255,0.10)";
        ctx.lineWidth = 1;
        for (let x = (W / 2) % TILE; x < W; x += TILE) ctx.strokeRect(x + 0.5, -1, 0, H + 2);
        for (let y = (H / 2) % TILE; y < H; y += TILE) ctx.strokeRect(-1, y + 0.5, W + 2, 0);
      }
      const idle = !variant && variantNames.length > 0;
      const shown = panel.layers.filter((layer) => (!layer.variant || layer.variant === variant) && !(idle && layer.needsRecipe));
      const at = idle && panel.layers === generated ? 0 : frame;

      if (panel.night) {
        // Night: the lit layers are darkened and only glow layers keep their full strength.
        const l = lit.getContext("2d");
        l.clearRect(0, 0, W, H);
        for (const layer of shown) if (layer.blend === "normal" && !layer.glow) place(l, layer, at);
        l.globalCompositeOperation = "source-atop";
        l.fillStyle = "rgba(4,6,12,0.72)";
        l.fillRect(0, 0, W, H);
        l.globalCompositeOperation = "source-over";
        ctx.drawImage(lit, 0, 0);
        for (const layer of shown) if (layer.glow || layer.blend === "additive") place(ctx, layer, at);
      } else {
        for (const layer of shown) place(ctx, layer, at);
      }

      if (!realBackground) {
        const [tx, tz] = panel.tiles;
        ctx.strokeStyle = "rgba(255,196,0,0.6)";
        ctx.setLineDash([6, 4]);
        ctx.strokeRect(W / 2 - (tx * TILE) / 2 + 0.5, H / 2 - (tz * TILE) / 2 + 0.5, tx * TILE, tz * TILE);
        ctx.setLineDash([]);
      }
    }
    $("frame").textContent = `frame ${(frame % loop) + 1} / ${loop}, loop ${Math.floor(frame / loop) + 1} / ${+(period() / loop).toFixed(2)}`;
  }

  const backgroundImages = meta.background
    ? Promise.all([load(meta.background.small), load(meta.background.large)]).then(([small, large]) => Object.assign(meta.background, { small, large }))
    : Promise.resolve();
  Promise.all([backgroundImages, ...panels.flatMap((p) => p.layers).map(async (layer) => (layer.image = await load(layer.url)))])
    .then(() => {
      draw();
      window.showFrame = (name, index) => {
        variant = name;
        frame = index;
        draw();
      };
      window.previewInfo = { W, H, TILE, loop, period: period(), periods };
      window.previewReady = true;
      let last = performance.now();
      const tick = (now) => {
        if (playing && now - last >= 1000 / fps) {
          last = now;
          frame = (frame + 1) % period();
          draw();
        }
        requestAnimationFrame(tick);
      };
      requestAnimationFrame(tick);
    })
    .catch((error) => {
      document.body.insertAdjacentHTML("beforeend", `<pre class="error">${error.message}</pre>`);
      window.previewReady = true;
    });
})();
