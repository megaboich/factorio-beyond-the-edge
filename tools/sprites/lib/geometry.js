// Geometry helpers shared by models. Units are tiles; x east, y up, z south.
import * as THREE from "three";

/**
 * Projects UVs from each vertex's local position along its dominant normal axis, so a texture
 * covers `scale` tiles per repeat on every part regardless of the part's size. Cylinder walls
 * get wrapped UVs instead, which avoids seams where the dominant axis flips.
 */
export function worldUV(geometry, scale) {
  const position = geometry.attributes.position;
  const normal = geometry.attributes.normal;
  const uv = new Float32Array(position.count * 2);
  const wrapped = geometry.type === "CylinderGeometry" || geometry.type === "TubeGeometry";
  for (let i = 0; i < position.count; i++) {
    const x = position.getX(i), y = position.getY(i), z = position.getZ(i);
    const nx = Math.abs(normal.getX(i)), ny = Math.abs(normal.getY(i)), nz = Math.abs(normal.getZ(i));
    let u, v;
    if (ny >= nx && ny >= nz) [u, v] = [x, z];
    else if (wrapped) [u, v] = [Math.atan2(x, z) * Math.hypot(x, z), y];
    else if (nx >= nz) [u, v] = [z, y];
    else [u, v] = [x, y];
    uv[i * 2] = u / scale;
    uv[i * 2 + 1] = v / scale;
  }
  geometry.setAttribute("uv", new THREE.BufferAttribute(uv, 2));
  return geometry;
}

/** Adds a mesh to `parent`, with world-scaled UVs when the material is textured. */
export function part(parent, geometry, material, position = [0, 0, 0], rotation = null) {
  if (material.map || material.bumpMap) worldUV(geometry, material.userData.uvScale ?? 2);
  const mesh = new THREE.Mesh(geometry, material);
  mesh.position.set(...position);
  if (rotation) mesh.rotation.set(...rotation);
  parent.add(mesh);
  return mesh;
}

/** A straight round bar from `from` to `to` (THREE.Vector3). */
export function beam(parent, from, to, radius, material, segments = 8) {
  const geometry = new THREE.CylinderGeometry(radius, radius, from.distanceTo(to), segments);
  geometry.rotateX(Math.PI / 2);
  const mesh = part(parent, geometry, material, [(from.x + to.x) / 2, (from.y + to.y) / 2, (from.z + to.z) / 2]);
  // lookAt() takes a world position, while `to` is in the parent's space.
  parent.updateWorldMatrix(true, false);
  mesh.lookAt(parent.localToWorld(to.clone()));
  return mesh;
}

/** A smooth pipe or cable through `points` ([x, y, z] arrays). */
export function tube(parent, points, radius, material, segments = 32) {
  const curve = new THREE.CatmullRomCurve3(points.map((p) => new THREE.Vector3(...p)));
  return part(parent, new THREE.TubeGeometry(curve, segments, radius, 8), material);
}

/** Converts smooth vertex normals to per-face normals, for faceted prisms and pyramids. */
export function faceted(geometry) {
  const flat = geometry.toNonIndexed();
  flat.computeVertexNormals();
  return flat;
}
