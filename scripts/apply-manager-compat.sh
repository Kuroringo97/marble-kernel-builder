#!/usr/bin/env bash
set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
RESOLVED_REFS_FILE="${RESOLVED_REFS_FILE:-release/resolved-refs.env}"

source "${RESOLVED_REFS_FILE}"

if [[ "${manager:-}" != "kernelsu-next" ||
      "${manager_repo:-}" != "KernelSU-Next/KernelSU-Next" ||
      "${manager_ref:-}" != "legacy-susfs" ]]; then
  echo "No manager compatibility patch required"
  exit 0
fi

manager_dir="${KERNEL_DIR}/KernelSU-Next"
patch_file="patches/managers/ksun-legacy-susfs-sepolicy-declarations.patch"

if [[ ! -d "${manager_dir}" ]]; then
  echo "::error::Missing official KernelSU-Next source at ${manager_dir}"
  exit 1
fi

patch --batch --forward -d "${manager_dir}" -p1 < "${patch_file}"
echo "Applied Marble compatibility patch for official KernelSU-Next legacy-susfs"
