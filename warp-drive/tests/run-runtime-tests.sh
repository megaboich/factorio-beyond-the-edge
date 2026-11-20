#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$ROOT_DIR/.." && pwd)"
FACTORIO_BIN="${FACTORIO_BIN:-/Applications/factorio.app/Contents/MacOS/factorio}"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/bte-warp-drive-tests.XXXXXX")"
BUILD_MODS="$TEST_ROOT/build-mods"
BASIC_MODS="$TEST_ROOT/basic-mods"
PLATFORM_MODS="$TEST_ROOT/platform-mods"
RELAY_MODS="$TEST_ROOT/relay-mods"
LOCAL_MODS="$TEST_ROOT/local-mods"
API_MODS="$TEST_ROOT/api-mods"
BOOST_MODS="$TEST_ROOT/boost-mods"

cleanup() {
  if [[ "${KEEP_TEST_ARTIFACTS:-0}" == "1" ]]; then
    printf 'Test artifacts: %s\n' "$TEST_ROOT"
  else
    rm -rf "$TEST_ROOT"
  fi
}
trap cleanup EXIT

export FACTORIO_BIN
RUN="$REPO_DIR/tests/factorio.sh"

mkdir "$BUILD_MODS" "$BASIC_MODS" "$PLATFORM_MODS" "$RELAY_MODS" "$LOCAL_MODS" "$API_MODS"
FACTORIO_MODS_DIR="$BUILD_MODS" "$REPO_DIR/make.sh" warp-drive

PACKAGE="$(printf '%s\n' "$BUILD_MODS"/bte-warp-drive_*.zip)"
if [[ ! -f "$PACKAGE" ]]; then
  printf 'Warp Drive package was not created\n' >&2
  exit 1
fi
if unzip -Z1 "$PACKAGE" | grep -q '/tests/'; then
  printf 'Packaged mod unexpectedly contains tests/\n' >&2
  exit 1
fi

cp "$PACKAGE" "$BASIC_MODS/"
"$RUN" run 120 "$BASIC_MODS"/*
printf 'WARP_TEST_PASS: fresh-save smoke test\n'

cp "$PACKAGE" "$PLATFORM_MODS/"
cp -R "$ROOT_DIR/tests/mods/aaa-bte-warp-drive-speed-test" "$PLATFORM_MODS/"
cp -R "$ROOT_DIR/tests/mods/bte-warp-drive-runtime-test" "$PLATFORM_MODS/"
"$RUN" run 3800 "$PLATFORM_MODS"/* | tee "$TEST_ROOT/platform.log"

if ! grep -q 'WARP_TEST_PASS: detector, duplicate, warp visuals, asteroid suppression, ramp, speed grace, reserve, warnings, lockout, circuit condition, revocation, and relocation paths completed' "$TEST_ROOT/platform.log"; then
  printf 'Platform runtime test did not emit its pass marker\n' >&2
  exit 1
fi

# Guards the undocumented API and vanilla prototype facts control.lua relies on, so a
# Factorio update that changes a unit or a prototype shape fails here with a precise
# message instead of silently changing balance.
cp "$PACKAGE" "$API_MODS/"
cp -R "$ROOT_DIR/tests/mods/bte-warp-drive-api-invariants-test" "$API_MODS/"
"$RUN" run 320 "$API_MODS"/* | tee "$TEST_ROOT/api.log"

if ! grep -qE 'WARP_TEST_PASS: .*invariants hold' "$TEST_ROOT/api.log"; then
  printf 'API invariants test did not emit its pass marker\n' >&2
  exit 1
fi

# Keep the local-branch fixture's tiny laboratory load ahead of the 1 GW detector request.
# This changes only the local test run and avoids adding generation that would alter detector power.
run_branch_test() {
  local mods_dir="$1"
  local label="$2"
  local marker="$3"
  shift 3
  cp "$PACKAGE" "$mods_dir/"
  cp -R "$ROOT_DIR/tests/mods/aaa-bte-warp-drive-branch-helper" "$mods_dir/"
  cp -R "$ROOT_DIR/tests/mods/bte-warp-drive-branch-test" "$mods_dir/"
  for extra in "$@"; do
    cp -R "$ROOT_DIR/tests/mods/$extra" "$mods_dir/"
  done
  "$RUN" run 1830 "$mods_dir"/* 2>&1 | tee "$TEST_ROOT/$label.log"
  if ! grep -q "$marker" "$TEST_ROOT/$label.log"; then
    printf '%s research branch test did not emit its pass marker\n' "$label" >&2
    exit 1
  fi
}

run_branch_test "$RELAY_MODS" relay \
  'WARP_TEST_PASS: relay research branch accelerated planetary laboratories with 10x transfer loss'
run_branch_test "$LOCAL_MODS" local \
  'WARP_TEST_PASS: local research branch accelerated platform laboratories only' \
  bte-warp-drive-space-science-test

# After Practical research each idle drive's detector boosts any research in every laboratory the
# force owns, and several drives add up. The second run makes the drives' platforms select the
# local research branch, which must not narrow the boost.
run_boost_test() {
  local mods_dir="$1"
  local label="$2"
  shift 2
  mkdir "$mods_dir"
  cp "$PACKAGE" "$mods_dir/"
  cp -R "$ROOT_DIR/tests/mods/bte-warp-drive-boost-test" "$mods_dir/"
  for extra in "$@"; do
    cp -R "$ROOT_DIR/tests/mods/$extra" "$mods_dir/"
  done
  "$RUN" run 860 "$mods_dir"/* 2>&1 | tee "$TEST_ROOT/$label.log"
  if ! grep -q 'WARP_TEST_PASS: Tachyon Science Boost' "$TEST_ROOT/$label.log"; then
    printf '%s Tachyon Science Boost test did not emit its pass marker\n' "$label" >&2
    exit 1
  fi
}

run_boost_test "$BOOST_MODS" boost-relay
run_boost_test "$TEST_ROOT/boost-local-mods" boost-local bte-warp-drive-space-science-test

printf 'WARP_TEST_PASS: all runtime tests\n'
