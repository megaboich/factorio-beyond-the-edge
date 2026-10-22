// Records README GIFs from a rendered preview: one full animation cycle per variant (the longest
// span among that variant's own layers), on the preview's real space platform floor, cropped to
// the building, its shadow, and its overlays.
//
//   node render.mjs growth-facility           (the preview must exist first)
//   node gif.mjs growth-facility --out=../../spacelab/docs
//     [--scale=0.5] (of the high-resolution sprite size) [--step=2] (building frames per GIF
//     frame; the GIF still plays at game speed) [--variants=a,b]
//
// Writes <out>/<name>-<variant>.gif. Needs ffmpeg (palette and encoding) and gifsicle
// (optimisation) on PATH.
import { chromium } from "playwright-core";
import { execFileSync } from "node:child_process";
import { mkdirSync, mkdtempSync, rmSync, statSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const args = process.argv.slice(2);
const opt = Object.fromEntries(args.filter((a) => a.startsWith("--")).map((a) => {
  const [key, value = "true"] = a.slice(2).split("=");
  return [key, value];
}));
const name = args.find((a) => !a.startsWith("--"));
if (!name || !opt.out) {
  console.error("usage: node gif.mjs <model> --out=<dir> [--scale=0.5] [--step=2] [--variants=a,b]");
  process.exit(2);
}
const out = resolve(opt.out);
const scale = Number(opt.scale ?? 0.5);
const step = Number(opt.step ?? 2);

// The preview loads its sheets over file://, which Chrome treats as cross-origin and would refuse to
// export from a canvas without this flag.
const browser = await chromium.launch({ channel: opt.channel ?? "chrome", headless: true, args: ["--allow-file-access-from-files"] });
const work = mkdtempSync(join(tmpdir(), "bte-gif-"));
try {
  const page = await browser.newPage({ viewport: { width: 2400, height: 1400 } });
  await page.goto(`${pathToFileURL(join(HERE, "out", `${name}-preview.html`)).href}?frame=0`);
  await page.waitForFunction(() => window.previewReady === true, null, { timeout: 60000 });
  const { variants, fps, periods, rect } = await page.evaluate(() => {
    const meta = window.SPRITE_META;
    const { W, H, TILE, periods } = window.previewInfo;
    // The building, its shadow, and every overlay, plus a small margin of floor.
    let x0 = W, y0 = H, x1 = 0, y1 = 0;
    for (const s of Object.values(meta.sheets)) {
      const cx = W / 2 + s.shift[0] * TILE;
      const cy = H / 2 + s.shift[1] * TILE;
      x0 = Math.min(x0, cx - s.width / 2);
      x1 = Math.max(x1, cx + s.width / 2);
      y0 = Math.min(y0, cy - s.height / 2);
      y1 = Math.max(y1, cy + s.height / 2);
    }
    const margin = 12;
    x0 = Math.max(0, Math.floor(x0 - margin));
    y0 = Math.max(0, Math.floor(y0 - margin));
    x1 = Math.min(W, Math.ceil(x1 + margin));
    y1 = Math.min(H, Math.ceil(y1 + margin));
    return { variants: meta.variants ?? [], fps: meta.fps ?? 12, periods, rect: [x0, y0, x1 - x0, y1 - y0] };
  });
  const chosen = opt.variants ? opt.variants.split(",") : variants;
  mkdirSync(out, { recursive: true });

  for (const variant of chosen) {
    const frames = join(work, variant);
    mkdirSync(frames, { recursive: true });
    const count = Math.ceil(periods[variant] / step);
    for (let i = 0; i < count; i++) {
      const dataURL = await page.evaluate(([v, f, [x, y, w, h], s]) => {
        window.showFrame(v, f);
        const panel = document.getElementById("panel-0");
        const canvas = document.createElement("canvas");
        canvas.width = Math.round(w * s);
        canvas.height = Math.round(h * s);
        const ctx = canvas.getContext("2d");
        ctx.imageSmoothingQuality = "high";
        ctx.drawImage(panel, x, y, w, h, 0, 0, canvas.width, canvas.height);
        return canvas.toDataURL("image/png");
      }, [variant, i * step, rect, scale]);
      writeFileSync(join(frames, `f${String(i).padStart(4, "0")}.png`), Buffer.from(dataURL.split(",")[1], "base64"));
    }
    const gif = join(out, `${name}-${variant}.gif`);
    // One shared palette per GIF; only changed rectangles are re-encoded between frames.
    execFileSync("ffmpeg", ["-v", "error", "-y", "-framerate", `${fps}/${step}`, "-i", join(frames, "f%04d.png"),
      "-vf", "split[a][b];[a]palettegen=max_colors=192:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle",
      "-loop", "0", gif]);
    execFileSync("gifsicle", ["-b", "-O3", "--lossy=30", gif]);
    console.log(`${gif}: ${count} frames, ${(statSync(gif).size / 1e6).toFixed(1)} MB`);
  }
} finally {
  await browser.close();
  rmSync(work, { recursive: true, force: true });
}
