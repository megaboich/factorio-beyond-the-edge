#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODS_DIR="${FACTORIO_MODS_DIR:-$HOME/Library/Application Support/factorio/mods}"

python3 - "$ROOT_DIR" "$MODS_DIR" <<'PY'
import json
import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

root = Path(sys.argv[1])
mods_dir = Path(sys.argv[2]).expanduser()
info = json.loads((root / "info.json").read_text())
mod_dir_name = f"{info['name']}_{info['version']}"
zip_path = mods_dir / f"{mod_dir_name}.zip"
excluded_names = {".git", ".claude", "tests"}

with tempfile.TemporaryDirectory() as temp_dir:
    temp_root = Path(temp_dir)
    staged_mod = temp_root / mod_dir_name

    def ignore(_directory, names):
        return {name for name in names if name in excluded_names or name.endswith(".zip")}

    shutil.copytree(root, staged_mod, ignore=ignore)
    mods_dir.mkdir(parents=True, exist_ok=True)
    if zip_path.exists():
        zip_path.unlink()

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED) as archive:
        for path in staged_mod.rglob("*"):
            if path.is_file():
                archive.write(path, path.relative_to(temp_root))

print(f"Installed {zip_path}")
PY
