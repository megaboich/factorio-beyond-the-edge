// Frost for the Stargate's frozen pictures (Aquilo, unheated), after vanilla's frozen overlays: the
// machinery (ring, towers, housings, cans, cabinet) is crusted in pale ice with gaps, which the
// scene's light shades like the rest of the building, and the concrete floor only chills and holds
// a few drifts. Every material gets a frosted twin whose fragment shader lays the ice in world space,
// so it lies on whatever faces up after lib/stargate-parts.js has leaned the geometry, and its lamps
// go dark.
import * as THREE from "three";

const NOISE = /* glsl */ `
varying vec3 vFrostP;
varying vec3 vFrostN;
float frostCover;
float frostHash(vec3 p) { return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453); }
float frostNoise(vec3 p) {
  vec3 i = floor(p), f = fract(p);
  f = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(mix(frostHash(i), frostHash(i + vec3(1, 0, 0)), f.x), mix(frostHash(i + vec3(0, 1, 0)), frostHash(i + vec3(1, 1, 0)), f.x), f.y),
    mix(mix(frostHash(i + vec3(0, 0, 1)), frostHash(i + vec3(1, 0, 1)), f.x), mix(frostHash(i + vec3(0, 1, 1)), frostHash(i + vec3(1, 1, 1)), f.x), f.y),
    f.z);
}
`;

// How much of a surface the ice covers: machinery, and the floor.
export const MACHINE = 0.55;
export const FLOOR = 0.22;

const frosted = new Map();

/** The frosted twin of `source` with `amount` of it iced, made once and kept, with the same clipping and userData. */
export function frostMaterial(source, amount = MACHINE) {
  let byAmount = frosted.get(source);
  if (!byAmount) frosted.set(source, byAmount = new Map());
  let material = byAmount.get(amount);
  if (material) return material;
  material = source.clone();
  material.userData = { ...source.userData };
  if ("emissive" in material) material.emissive = new THREE.Color(0);
  const a = amount.toFixed(3);
  material.onBeforeCompile = (shader) => {
    shader.vertexShader = shader.vertexShader
      .replace("#include <common>", "#include <common>\nvarying vec3 vFrostP;\nvarying vec3 vFrostN;")
      .replace("#include <project_vertex>", `#include <project_vertex>
        vFrostP = (modelMatrix * vec4(transformed, 1.0)).xyz;
        vFrostN = normalize(mat3(modelMatrix) * objectNormal);`);
    shader.fragmentShader = shader.fragmentShader
      .replace("#include <common>", "#include <common>\n" + NOISE)
      .replace("#include <color_fragment>", `#include <color_fragment>
        {
          vec3 n = normalize(vFrostN);
          float up = smoothstep(0.2, 0.9, n.y);
          // Machinery: ice in sheets with small gaps. Floor: broad soft drifts over a thin rime.
          float fine = 0.5 * frostNoise(vFrostP * 3.0) + 0.3 * frostNoise(vFrostP * 8.0) + 0.2 * frostNoise(vFrostP * 22.0);
          float broad = 0.6 * frostNoise(vFrostP * 0.9) + 0.4 * frostNoise(vFrostP * 2.6);
          float machine = smoothstep(0.42, 0.6, fine + ${a} + 0.12 * up - 0.5) * 0.85;
          float drifts = smoothstep(0.64, 0.67, broad + 0.22 * (fine - 0.5)) * 0.9 + 0.1;
          frostCover = ${a} > 0.5 ? machine : drifts;
          // Uncovered metal and concrete chill to a bluer grey. The ice is a mid blue-white, so the
          // lighting after this shades it, white where the sun falls and blue-grey in shade, as vanilla's is.
          float lum = dot(diffuseColor.rgb, vec3(0.3, 0.55, 0.15));
          vec3 cold = mix(diffuseColor.rgb, vec3(lum), 0.45) * vec3(0.9, 1.0, 1.15);
          // Bare metal between the ice is rimed to a cold grey, never near-black, which read as mould.
          if (${a} > 0.5) cold = mix(cold, vec3(0.24, 0.27, 0.3), 0.75);
          vec3 ice = (${a} > 0.5 ? vec3(0.2, 0.25, 0.3) : vec3(0.36, 0.43, 0.5)) * (0.9 + 0.2 * frostNoise(vFrostP * 40.0));
          diffuseColor.rgb = mix(cold, ice, frostCover);
        }`)
      .replace("#include <roughnessmap_fragment>", "#include <roughnessmap_fragment>\nroughnessFactor = mix(roughnessFactor, 0.6, frostCover);")
      .replace("#include <metalnessmap_fragment>", "#include <metalnessmap_fragment>\nmetalnessFactor = mix(metalnessFactor, 0.0, frostCover);")
      .replace("#include <emissivemap_fragment>", "#include <emissivemap_fragment>\ntotalEmissiveRadiance = vec3(0.0);");
  };
  material.customProgramCacheKey = () => `bte-frost-${a}`;
  byAmount.set(amount, material);
  return material;
}

/** Frosts every visible mesh's current material (the floor lightly), tagging each `tag` when given. */
export function frost(root, tag) {
  root.traverse((mesh) => {
    if (!mesh.isMesh || !mesh.visible) return;
    mesh.userData.unfrozen ??= mesh.material;
    const material = frostMaterial(mesh.material, mesh.userData.floor ? FLOOR : MACHINE);
    if (tag) material.userData.tag = tag;
    mesh.material = material;
  });
}

/**
 * setVariant for the construction site and stages: their one extra layer, `frozen`, is the whole
 * building frosted; every other pass sees it as built.
 */
export const FROZEN_LAYER = { name: "frozen", tag: "frozen", variant: "frozen", frames: 1 };
export function frozenVariant(root, name) {
  root.traverse((mesh) => {
    if (mesh.isMesh && mesh.userData.unfrozen) mesh.material = mesh.userData.unfrozen;
  });
  if (name === "frozen") frost(root, "frozen");
}
