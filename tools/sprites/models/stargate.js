// Stargate: a 14x14 modern gate, a segmented steel ring between two support towers, standing in a
// concrete basin. The geometry lives in lib/stargate-parts.js, shared with the construction stages.
// Layers: main and shadow, glow-lights (status lights, additive), and glow-veil: the active portal's
// light, VEIL_FRAMES frames looping once (64 ticks in game; see stargate/prototypes/entities.lua),
// and glow-passage, the veil's reaction to a traveller, played once over it by scripts/transfer.lua.
//
// People and vehicles walk through the gate, behind the ring as well as in front, so the floor is a
// layer of its own: the gate's integration patch, drawn under everything. Everything else (main,
// glow-lights, glow-lights-red) is drawn by a companion entity standing on the ring's line
// (stargate/prototypes/entities.lua, bte-stargate-body), so Factorio draws characters behind the
// ring under it and characters in front of it over it. In main the floor is an occluder, so it still
// hides the ring's lower arc where the trench's lip covers it.
//
// The ring's upper arc, everything above TOP, is also drawn alone (top), with its own lights
// (glow-lights-high, glow-lights-red-high), by a second companion on an elevated render layer
// (bte-stargate-top), as Space Age draws elevated rails: over spidertron bodies, which draw over
// every ordinary object. glow-lights and glow-lights-red hold only the lights below TOP, so no light
// is drawn twice. TOP is the ring's centre, so the upper half is elevated; anyone in front of the
// ring close enough to reach that height on screen is already in the portal zone.
import * as THREE from "three";
import { frost } from "../lib/frost.js";
import { build, drawPassage, drawSplash, drawVeil, drawVeilTransition, RING, TRACK_LANES } from "../lib/stargate-parts.js";

// The ring's centre height: the upper half of the ring is the elevated part.
const TOP = RING.cy;
const floorOccluder = new THREE.MeshBasicMaterial({ colorWrite: false });
const topClip = [new THREE.Plane(new THREE.Vector3(0, 1, 0), -TOP)];
const lowClip = [new THREE.Plane(new THREE.Vector3(0, -1, 0), TOP)];
// The lights in each pass: cyan or red, below or above TOP.
const LIGHTS = {
  null: { color: 0x2fd2ff, clip: lowClip },
  alarm: { color: 0xff2a1a, clip: lowClip },
  high: { color: 0x2fd2ff, clip: topClip },
  "alarm-high": { color: 0xff2a1a, clip: topClip },
  top: { color: 0x000000, clip: topClip },
  // Cyan lit lamps tagged for a layer of their own (the station's light layers below).
  cyan: { color: 0x2fd2ff, clip: lowClip }
};
// The lamps are dark in main and top: their colour comes only from the glow layers drawn over them,
// since red light added over a lamp baked cyan would read white. The null pass's lamps still feed
// glow-lights, through userData.glow's colour; the other passes are tagged glow layers of their own.
const LAMP_GLOW = { layer: "lights", color: 0x2fd2ff, scale: 1.4 };
const lightMaterials = {};
// The veil's passes: below TOP, or above it ("-high").
const VEILS = ["active", "active-high", "opening", "opening-high", "closing", "closing-high"];
function lightMaterial(source, name) {
  const spec = LIGHTS[name];
  const dark = name === "null" || name === "top";
  return lightMaterials[name] ??= Object.assign(source.clone(), {
    // A dark lamp is matte too: a glossy one reflects the sky as a white highlight.
    ...(dark ? { color: new THREE.Color(0x15191c), roughness: 1, metalness: 0, envMapIntensity: 0 } : {}),
    emissive: new THREE.Color(dark ? 0x000000 : spec.color),
    clippingPlanes: spec.clip,
    userData: name === "null" ? { glow: LAMP_GLOW } : { tag: name === "top" ? "top" : "light" }
  });
}

const VEIL_FRAMES = 16;
// The portal forming (120 ticks) and collapsing (72 ticks), played once by scripts/gate.lua.
const OPENING_FRAMES = 30;
const CLOSING_FRAMES = 18;
// The passage plays once over two loops (128 ticks in game, scripts/transfer.lua TRANSIT_TICKS).
const PASSAGE_FRAMES = 32;
const SPLASH_FRAMES = 32;

// The gate's own variants (null, the companions' layers, the station's, and the veil's); the
// frozen ones are these, frosted (setVariant).
function setBase(root, name) {
  root.userData.variant = name;
    // Restore every mesh, then cut the floor out of main or isolate it for the floor layer.
    root.traverse((mesh) => {
      if (!mesh.isMesh) return;
      mesh.userData.original ??= mesh.material;
      mesh.material = mesh.userData.original;
      mesh.visible = true;
      mesh.renderOrder = 0;
      const floor = mesh.userData.floor;
      const light = mesh.material === root.userData.lights;
      const track = mesh.userData.track;
      const body = String(name).startsWith("body-");
      // A station's lights: "lights-<mode>" cyan, "alarm-<mode>" red.
      const station = /^(lights|alarm)-(single|double)$/.exec(String(name));
      const chevrons = mesh.userData.chevrons;
      if (chevrons !== undefined) {
        // Only in its own layer: flat on the floor, it hides nothing in the building.
        mesh.visible = name === `chevrons-${chevrons}`;
        if (mesh.visible) mesh.material = mesh.userData.railMaterial ??= Object.assign(mesh.material.clone(), { userData: { tag: "rails" } });
      } else if (String(name).startsWith("chevrons-")) {
        mesh.visible = false;
      } else if (track !== undefined) {
        // Shown in its own layer, and untagged in the building's and the lights', where it hides them.
        const mode = String(name).startsWith("rails-") ? String(name).slice(6) : body ? String(name).slice(5) : station?.[2];
        mesh.visible = (TRACK_LANES[mode] ?? []).includes(track);
        if (mesh.visible && !body && !station) mesh.material = mesh.userData.railMaterial ??= Object.assign(mesh.material.clone(), { userData: { tag: "rails" } });
      } else if (String(name).startsWith("rails-")) {
        // The track's own layer: nothing else, so no part of the building shadows it.
        mesh.visible = false;
      } else if (station) {
        if (light) mesh.material = lightMaterial(mesh.material, station[1] === "lights" ? "cyan" : "alarm");
      } else if (body) {
        // main, as the null pass draws it, but tagged; the floor stays an untagged occluder.
        if (!floor && mesh.material.userData.tag !== "veil") {
          const source = light ? lightMaterial(mesh.material, "null") : mesh.material;
          mesh.material = mesh.userData.bodyMaterial ??= Object.assign(source.clone(), { userData: { tag: "body" } });
        }
      } else if (name === null && floor) {
        mesh.material = floorOccluder;
        mesh.renderOrder = -20;
      } else if (name === "floor") {
        if (floor) mesh.material = mesh.userData.floorMaterial ??= Object.assign(mesh.material.clone(), { userData: { tag: "floor" } });
        else mesh.visible = false;
      } else if (name === "top") {
        if (floor) mesh.visible = false;
        else if (light) mesh.material = lightMaterial(mesh.material, "top");
        else mesh.material = mesh.userData.topMaterial ??= Object.assign(mesh.material.clone(), { clippingPlanes: topClip, userData: { tag: "top" } });
      } else if (light && LIGHTS[String(name)]) {
        mesh.material = lightMaterial(mesh.material, String(name));
      }
    });
    // A station gate's building is cut wherever the veil's disc lies on screen, so the open veil
    // shows its whole oval over the track and the ring's lower arc alike, whichever the game draws
    // first (render.js `cutsLayers`).
    const station = /^body-(single|double)$/.test(String(name));
    root.traverse((object) => {
      if (!object.isMesh || object.userData.original?.userData.tag !== "veil") return;
      object.visible = VEILS.includes(name) || name === "passage" || name === "splash" || station;
      if (station) {
        object.material = object.userData.cutMaterial ??= Object.assign(object.material.clone(), { userData: { cutsLayers: true } });
        object.renderOrder = -10;
      }
    });
    // The passage is drawn whole, by script.
    root.userData.veil.material.clippingPlanes = !VEILS.includes(name) ? null : name.endsWith("-high") ? topClip : lowClip;
}

export default {
  tiles: [14, 14],
  height: 10,
  elevation: 50,
  frames: 1,
  loop: VEIL_FRAMES,
  fps: 16,
  variants: ["active", "opening", "closing", "passage", "alarm", "frozen"],
  labels: { variant: "State", idle: "Idle" },
  layers: [
    // The floor goes under everything (the gate's integration patch); top over the building.
    { name: "floor", tag: "floor", variant: "floor", frames: 1, preview: { building: true, order: -3 } },
    { name: "top", tag: "top", variant: "top", frames: 1, preview: { building: true } },
    { name: "glow-lights-high", tag: "light", glow: true, variant: "high", frames: 1 },
    { name: "glow-lights-red-high", tag: "light", glow: true, variant: "alarm-high", frames: 1, preview: { variant: "alarm" } },
    // The veil in two parts, split at TOP like the ring (two companions in game).
    { name: "glow-veil", tag: "veil", glow: true, variant: "active", frames: VEIL_FRAMES, preview: { variant: "active" } },
    { name: "glow-veil-high", tag: "veil", glow: true, variant: "active-high", frames: VEIL_FRAMES, preview: { variant: "active" } },
    // Opening and closing, each split at TOP like the veil.
    { name: "glow-opening", tag: "veil", glow: true, variant: "opening", frames: OPENING_FRAMES, preview: { variant: "opening" } },
    { name: "glow-opening-high", tag: "veil", glow: true, variant: "opening-high", frames: OPENING_FRAMES, preview: { variant: "opening" } },
    { name: "glow-closing", tag: "veil", glow: true, variant: "closing", frames: CLOSING_FRAMES, preview: { variant: "closing" } },
    { name: "glow-closing-high", tag: "veil", glow: true, variant: "closing-high", frames: CLOSING_FRAMES, preview: { variant: "closing" } },
    // The status lights in red, which scripts/gate.lua shows instead of glow-lights while the gate lacks power.
    { name: "glow-lights-red", tag: "light", glow: true, variant: "alarm", frames: 1, preview: { variant: "alarm" } },
    // Station-mode track, one picture per layout, drawn by a companion just above the floor
    // (stargate/scripts/railway.lua); hidden from every other layer.
    { name: "rails-single", tag: "rails", variant: "rails-single", frames: 1 },
    { name: "rails-double", tag: "rails", variant: "rails-double", frames: 1 },
    // The two-track station's direction chevrons, one picture per layout, drawn over its track.
    { name: "chevrons-right", tag: "rails", variant: "chevrons-right", frames: 1 },
    { name: "chevrons-left", tag: "rails", variant: "chevrons-left", frames: 1 },
    // The building with the track cut out where it passes over the ring's lower arc into the ring,
    // so the track (drawn under the building) shows there: main for a station gate.
    { name: "main-single", tag: "body", variant: "body-single", frames: 1 },
    { name: "main-double", tag: "body", variant: "body-double", frames: 1 },
    // The status lights below TOP, cyan and red, with the track in front of them hiding them.
    { name: "glow-lights-single", tag: "light", glow: true, variant: "lights-single", frames: 1 },
    { name: "glow-lights-double", tag: "light", glow: true, variant: "lights-double", frames: 1 },
    { name: "glow-lights-red-single", tag: "light", glow: true, variant: "alarm-single", frames: 1 },
    { name: "glow-lights-red-double", tag: "light", glow: true, variant: "alarm-double", frames: 1 },
    // One train carriage passing the veil, drawn by scripts/railway.lua at its lane, 32 frames at 2 ticks.
    { name: "glow-splash", tag: "veil", glow: true, variant: "splash", frames: SPLASH_FRAMES, span: 0.5 },
    // Drawn over the veil by script while someone passes through.
    { name: "glow-passage", tag: "veil", glow: true, variant: "passage", frames: PASSAGE_FRAMES, span: 2, preview: { variant: "passage" } },
    // Frozen (Aquilo, unheated; lib/frost.js): the building with and without each station's track
    // cut, the upper arc, and the floor, all frosted, with dark lamps and no veil. scripts/gate.lua
    // shows these instead of the others while the gate is frozen.
    { name: "main-frozen", tag: "body", variant: "frozen:body-", frames: 1, preview: { variant: "frozen" } },
    { name: "main-single-frozen", tag: "body", variant: "frozen:body-single", frames: 1 },
    { name: "main-double-frozen", tag: "body", variant: "frozen:body-double", frames: 1 },
    { name: "top-frozen", tag: "top", variant: "frozen:top", frames: 1, preview: { variant: "frozen" } },
    { name: "floor-frozen", tag: "floor", variant: "frozen:floor", frames: 1, preview: { variant: "frozen", order: -2 } }
  ],
  export: "stargate/graphics/entity/stargate/stargate",
  // The gate's sounds in the preview: opening and closing as the veil comes and goes, and a trip
  // during the passage, leaving at its start and arriving (at the partner, in game) halfway.
  sounds: {
    states: [{ variants: ["active", "opening", "passage"], enter: "repo:stargate/resources/audio/stargate-open.ogg", leave: "repo:stargate/resources/audio/stargate-close.ogg" }],
    cues: [
      { variant: "passage", at: 0, file: "repo:stargate/resources/audio/stargate-depart.ogg" },
      { variant: "passage", at: 0.5, file: "repo:stargate/resources/audio/stargate-arrive.ogg" }
    ]
  },
  // Nauvis grass around the gate in the preview, with the construction stages beside it; render
  // stargate-site and stargate-stage1 to stargate-stage5 before this model.
  // grass-1.png holds sixteen 4x4-tile variants in the row at y = 320.
  ground: { file: "factorio:base/graphics/terrain/grass-1.png", y: 320, size: 256, count: 16 },
  references: [
    { model: "stargate-site", label: "Construction site (first phase)" },
    { model: "stargate-stage1", label: "Phase 2" },
    { model: "stargate-stage2", label: "Phase 3" },
    { model: "stargate-stage3", label: "Phase 4" },
    { model: "stargate-stage4", label: "Phase 5" },
    { model: "stargate-stage5", label: "Phase 6" },
    {
      label: "Vanilla Fusion Reactor (6x6), for scale",
      tiles: [6, 6],
      layers: [
        { file: "factorio:space-age/graphics/entity/fusion-reactor/fusion-reactor-shadow.png", width: 542, height: 346, shift: [40 / 32, 9.5 / 32], blend: "shadow" },
        { file: "factorio:space-age/graphics/entity/fusion-reactor/fusion-reactor-main.png", width: 444, height: 456, shift: [1 / 32, -5.5 / 32], blend: "normal" },
        { file: "factorio:space-age/graphics/entity/fusion-reactor/fusion-reactor-glow.png", width: 396, height: 428, shift: [1.5 / 32, -11 / 32], blend: "additive" }
      ]
    }
  ],

  build() {
    return build({ state: "complete", tracks: [...TRACK_LANES.single, ...TRACK_LANES.double] });
  },

  setVariant(root, name) {
    const frozen = /^frozen:(.*)$/.exec(String(name));
    setBase(root, frozen ? frozen[1] : name);
    if (!frozen) return;
    // A frozen gate never opens, so no veil, and no veil-shaped cut in a station's building.
    root.traverse((object) => {
      if (object.isMesh && object.userData.original?.userData.tag === "veil") object.visible = false;
    });
    frost(root);
  },

  animate(root, t) {
    const variant = String(root.userData.variant);
    if (variant === "passage") drawPassage(root, t / 2);
    else if (variant === "splash") drawSplash(root, t * 2);
    else if (variant.startsWith("opening")) drawVeilTransition(root, t * OPENING_FRAMES / (OPENING_FRAMES - 1), false);
    else if (variant.startsWith("closing")) drawVeilTransition(root, t * CLOSING_FRAMES / (CLOSING_FRAMES - 1), true);
    else drawVeil(root, t % 1);
  }
};
