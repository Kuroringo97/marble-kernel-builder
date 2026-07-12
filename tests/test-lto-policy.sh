#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

expect_validation_success() {
  local lto="$1"
  SOURCE_REPO=mohdakil2426/android_kernel_xiaomi_marble \
  SOURCE_REF=melt-rebase \
  MANAGER=none \
  ENABLE_SUSFS=false \
  BUILD_SCOPE=image-only \
  LTO="${lto}" \
  bash scripts/validate-inputs.sh >/dev/null || fail "validation rejected LTO=${lto}"
}

for lto in none thin full; do
  expect_validation_success "${lto}"
done

if SOURCE_REPO=mohdakil2426/android_kernel_xiaomi_marble \
   SOURCE_REF=melt-rebase \
   MANAGER=none \
   ENABLE_SUSFS=false \
   BUILD_SCOPE=image-only \
   LTO=fat \
   bash scripts/validate-inputs.sh >/dev/null 2>&1; then
  fail "validation accepted invalid LTO=fat"
fi

# Unset LTO must still pass (defaults to thin)
unset LTO || true
SOURCE_REPO=mohdakil2426/android_kernel_xiaomi_marble \
SOURCE_REF=melt-rebase \
MANAGER=none \
ENABLE_SUSFS=false \
BUILD_SCOPE=image-only \
bash scripts/validate-inputs.sh >/dev/null || fail "validation failed when LTO is unset"

echo "LTO policy tests passed"
