#!/usr/bin/env bash
set -euo pipefail

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
SUSFS_MANAGER_PATCH="${SUSFS_MANAGER_PATCH:-auto}"

if [[ "${ENABLE_SUSFS}" != "true" ]]; then
  echo "SUSFS disabled"
  exit 0
fi

source config/marble.env
source release/resolved-refs.env

if [[ -z "${susfs_commit}" || -z "${susfs_kernel_branch}" ]]; then
  echo "::error::SUSFS resolution missing commit or kernel branch"
  exit 1
fi

work_root="$(pwd)"
susfs_dir="${work_root}/susfs4ksu"
git clone "${SUSFS_REPO}" "${susfs_dir}"
git -C "${susfs_dir}" checkout "${susfs_commit}"

patch_root="${susfs_dir}/kernel_patches"
if [[ ! -d "${patch_root}" ]]; then
  echo "::error::Missing SUSFS patch directory: ${patch_root}"
  exit 1
fi

pushd "${KERNEL_DIR}" >/dev/null
patch_suffix="${susfs_kernel_branch#gki-}"
main_patch="${patch_root}/50_add_susfs_in_gki-${patch_suffix}.patch"
if [[ -f "${main_patch}" ]]; then
  patch -p1 < "${main_patch}"
else
  echo "::error::Missing main SUSFS kernel patch for ${susfs_kernel_branch}"
  exit 1
fi

rsync -a "${susfs_dir}/kernel_patches/fs/" fs/
rsync -a "${susfs_dir}/kernel_patches/include/" include/

manager_dir=""
for candidate in KernelSU KernelSU-Next SukiSU-Ultra drivers/kernelsu; do
  if [[ -d "${candidate}" ]]; then
    manager_dir="${candidate}"
    break
  fi
done

if [[ -z "${manager_dir}" ]]; then
  echo "::error::Could not find manager source directory for SUSFS integration"
  exit 1
fi

manager_patch="${patch_root}/KernelSU/10_enable_susfs_for_ksu.patch"
apply_manager_patch="${SUSFS_MANAGER_PATCH}"
if [[ "${apply_manager_patch}" == "auto" ]]; then
  apply_manager_patch="force"
  if [[ "${manager_ref,,}" == *susfs* ]]; then
    apply_manager_patch="skip"
  fi
fi

if [[ "${apply_manager_patch}" == "skip" ]]; then
  echo "Skipping SUSFS manager patch for ${manager_repo}@${manager_ref}"
elif [[ -f "${manager_patch}" ]]; then
  pushd "${manager_dir}" >/dev/null
  patch -p1 < "${manager_patch}"
  popd >/dev/null
fi

popd >/dev/null
echo "SUSFS applied from ${susfs_commit}"
