#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODS_DIR="${FACTORIO_MODS_DIR:-$HOME/Library/Application Support/factorio/mods}"
ALL_MODS=(spacelab warp-drive)

if [[ $# -eq 0 ]]; then
  set -- "${ALL_MODS[@]}"
fi

for mod in "$@"; do
  if [[ ! -f "$ROOT_DIR/$mod/info.json" ]]; then
    printf 'Unknown mod: %s (expected one of: %s)\n' "$mod" "${ALL_MODS[*]}" >&2
    exit 1
  fi
done

python3 - "$MODS_DIR" "${@/#/$ROOT_DIR/}" <<'PY'
import json
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

mods_dir = Path(sys.argv[1]).expanduser()
excluded_names = {".git", ".claude", ".DS_Store", "tests"}


def ignore(_directory, names):
    return {name for name in names if name in excluded_names or name.endswith(".zip")}


mods_dir.mkdir(parents=True, exist_ok=True)

for mod_root in map(Path, sys.argv[2:]):
    info = json.loads((mod_root / "info.json").read_text())
    mod_dir_name = f"{info['name']}_{info['version']}"
    zip_path = mods_dir / f"{mod_dir_name}.zip"

    with tempfile.TemporaryDirectory() as temp_dir:
        temp_root = Path(temp_dir)
        staged_mod = temp_root / mod_dir_name
        shutil.copytree(mod_root, staged_mod, ignore=ignore)
        if zip_path.exists():
            zip_path.unlink()

        with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
            for path in sorted(staged_mod.rglob("*")):
                if path.is_file():
                    archive.write(path, path.relative_to(temp_root))

    print(f"Installed {zip_path}")
PY
