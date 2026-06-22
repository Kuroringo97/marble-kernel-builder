#!/usr/bin/env bash
set -euo pipefail

source config/marble.env

KERNEL_DIR="${KERNEL_DIR:-kernel-source}"
MANAGER="${MANAGER:-none}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
BUILD_SCOPE="${BUILD_SCOPE:-image-only}"

release_dir="${KERNEL_DIR}/${RELEASE_DIR}"
build_info="${release_dir}/build-info.txt"
zip_env="${release_dir}/zip-name.env"
summary="${release_dir}/summary.md"

if [[ ! -f "${build_info}" || ! -f "${zip_env}" ]]; then
  echo "::error::Missing build metadata for summary generation"
  exit 1
fi

source "${zip_env}"

get_info() {
  local key="$1"
  grep -m1 "^${key}=" "${build_info}" | cut -d= -f2- || true
}

short_commit() {
  local value="$1"
  if [[ -z "${value}" || "${value}" == "unknown" ]]; then
    echo "unknown"
  else
    echo "${value:0:8}"
  fi
}

source_repo="$(get_info source_repo)"
source_ref="$(get_info source_ref)"
source_commit="$(get_info source_commit)"
workflow_run="$(get_info workflow_run)"
manager_name="$(get_info manager)"
manager_repo="$(get_info manager_repo)"
manager_ref="$(get_info manager_ref)"
manager_commit="$(get_info manager_commit)"
susfs_version="$(get_info susfs_version)"
susfs_branch="$(get_info susfs_kernel_branch)"
susfs_ref="$(get_info susfs_ref)"
susfs_commit="$(get_info susfs_commit)"
susfs_reported="$(get_info susfs_reported_version)"
zip_sha="$(sha256sum "${release_dir}/${zip_name}" | awk '{print $1}')"
image_sha="$(sha256sum "${release_dir}/Image" | awk '{print $1}')"
zip_size="$(du -h "${release_dir}/${zip_name}" | awk '{print $1}')"
build_date="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
build_id="${GITHUB_RUN_ID:-}"
if [[ -z "${build_id}" && -n "${workflow_run}" ]]; then
  build_id="${workflow_run##*/}"
fi

manager_display="${manager_name}"
case "${manager_name}" in
  none) manager_display="No manager" ;;
  kernelsu) manager_display="KernelSU" ;;
  kernelsu-next) manager_display="KernelSU-Next" ;;
  sukisu-ultra) manager_display="SukiSU Ultra" ;;
  resukisu) manager_display="ReSukiSU" ;;
esac

title_manager="${manager_display}"
if [[ "${manager_name}" == "none" ]]; then
  title_manager="No Root Manager"
fi
title_suffix=""
if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  title_suffix=" & SUSFS ${susfs_reported:-${susfs_version}}"
fi

manager_summary="${manager_display}"
case "${manager_name}" in
  none) manager_summary="No root manager integrated" ;;
  kernelsu) manager_summary="KernelSU - kernel-level root solution" ;;
  kernelsu-next) manager_summary="KernelSU-Next - next-generation kernel-level root solution" ;;
  sukisu-ultra) manager_summary="SukiSU Ultra - KernelSU-based root solution" ;;
  resukisu) manager_summary="ReSukiSU - KernelSU-based root solution" ;;
esac

manager_app_name="${manager_display}"
manager_app_url=""
case "${manager_name}" in
  kernelsu) manager_app_url="https://github.com/tiann/KernelSU/releases" ;;
  kernelsu-next) manager_app_url="https://github.com/KernelSU-Next/KernelSU-Next/releases" ;;
  sukisu-ultra) manager_app_url="https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases" ;;
  resukisu) manager_app_url="https://github.com/ReSukiSU/ReSukiSU" ;;
esac

{
  echo "#  Marble Kernel with ${title_manager}${title_suffix}"
  echo
  echo "> Build Date: ${build_date}"
  echo ">  Build ID: \`${build_id:-unknown}\`"
  echo ">  Workflow: ${workflow_run}"
  echo
  echo "* * *"
  echo
  echo "##  Build Configuration"
  echo
  echo "| Component | Version/Setting |"
  echo "|---|---|"
  echo "| Device | Poco F5 / Redmi Note 12 Turbo (\`marble\`, \`marblein\`) |"
  echo "| Kernel Base | \`android12-5.10\` |"
  echo "| Build Scope | \`${BUILD_SCOPE}\` |"
  echo "| Source | \`${source_repo}@${source_ref}\` (\`$(short_commit "${source_commit}")\`) |"
  echo "| Kernel Manager | \`${manager_display}\` |"
  if [[ "${manager_name}" == "none" ]]; then
    echo "| Manager Source | Not integrated |"
  else
    echo "| Manager Source | \`${manager_repo}@${manager_ref}\` (\`$(short_commit "${manager_commit}")\`) |"
  fi
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "| SUSFS Version | \`${susfs_reported:-${susfs_version}}\` |"
  else
    echo "| SUSFS Version | Disabled |"
  fi
  echo "| Clean Build | No, ccache is enabled when available |"
  echo "| Compiler | Android clang-r416183b |"
  echo
  echo "###  SUSFS Branch Mapping"
  echo
  echo "| Kernel Version | SUSFS Branch | SUSFS Commit |"
  echo "|---|---|---|"
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "| \`android12-5.10\` | \`${susfs_branch}\` | \`$(short_commit "${susfs_commit}")\` |"
  else
    echo "| \`android12-5.10\` | Not enabled | Not enabled |"
  fi
  echo
  echo "* * *"
  echo
  echo "## ✨ Features & Capabilities"
  echo
  echo "###  Root Management"
  echo
  if [[ "${manager_name}" == "none" ]]; then
    echo "- No root manager integrated. This mode is only for baseline vanilla kernel builds and troubleshooting."
  else
    echo "- ${manager_summary}"
    echo "- Manager source: \`${manager_repo}@${manager_ref}\`"
    if [[ "${manager_name}" == "kernelsu" ]]; then
      echo "- SUSFS policy: official KernelSU builds stay non-SUSFS in this builder."
    elif [[ "${manager_name}" == "kernelsu-next" && "${ENABLE_SUSFS}" == "true" ]]; then
      echo "- SUSFS policy: normal KernelSU-Next builds use official \`dev\`; SUSFS builds use \`pershoot/KernelSU-Next@dev-susfs\`."
    fi
  fi
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "- SUSFS \`${susfs_reported:-${susfs_version}}\` - advanced hiding features"
    echo "- SUSFS userspace module is required on-device to configure hiding rules"
  else
    echo "- SUSFS is disabled for this build."
  fi
  echo
  echo "### 🛡️ Security & Privacy"
  echo
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "- ✅ SUS_PATH - Hide suspicious paths"
    echo "- ✅ SUS_MOUNT - Hide mount points"
    echo "- ✅ SUS_KSTAT - Spoof kernel statistics"
    echo "- ✅ SPOOF_UNAME - Kernel version spoofing"
    echo "- ✅ SPOOF_CMDLINE - Boot parameters spoofing"
    echo "- ✅ OPEN_REDIRECT - File access redirection"
    echo "- ✅ SUS_MAP - Memory mapping protection"
  else
    echo "- SUSFS hiding features are not enabled in this build."
  fi
  echo
  echo "* * *"
  echo
  echo "##  Manager Applications"
  echo
  echo "### Official Manager"
  echo
  if [[ -n "${manager_app_url}" ]]; then
    echo "- ${manager_app_name}: ${manager_app_url}"
  else
    echo "- No manager app is needed for \`manager=none\` builds."
  fi
  echo
  echo "### Required Module"
  echo
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "- KSU SUSFS Module: https://github.com/sidex15/susfs4ksu-module/releases"
  else
    echo "- No SUSFS module is required for this non-SUSFS build."
  fi
  echo
  echo "### Recommended Flasher"
  echo
  echo "- Kernel Flasher: https://github.com/fatalcoder524/KernelFlasher/releases"
  echo
  echo "* * *"
  echo
  echo "##  Installation Instructions"
  echo
  echo "### Prerequisites"
  echo
  echo "- Unlocked bootloader"
  echo "- Poco F5 / Redmi Note 12 Turbo only: \`marble\` or \`marblein\`"
  echo "- Stock \`boot.img\` from the same ROM/firmware for recovery"
  echo "- Matching manager app for this build: \`${manager_display}\`"
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "- Matching KSU SUSFS module for \`${susfs_reported:-${susfs_version}}\`"
  fi
  echo
  echo "### Via Kernel Flasher"
  echo
  echo "1. Download \`${zip_name}\` and \`${zip_name}.sha256\`."
  echo "2. Confirm the device codename is \`marble\` or \`marblein\`."
  echo "3. Keep the stock \`boot.img\` from the same ROM/firmware before flashing."
  echo "4. Flash the ZIP to the active slot with Kernel Flasher."
  echo "5. The installer backs up the current active boot image to \`/sdcard/marble-kernel-backup\` before writing."
  echo "6. Install/open the matching manager application if this is a root-manager build."
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "7. Install the KSU SUSFS module, configure hiding rules, then reboot."
  else
    echo "7. Reboot and verify the kernel is running before using daily."
  fi
  echo
  echo "> Bootloop recovery: flash the stock \`boot.img\` from the same ROM/firmware back to the active slot. On A/B slot issues, flash the correct stock boot image to the affected slot or both slots."
  echo
  echo "### Artifacts"
  echo
  echo "| File | Details |"
  echo "|---|---|"
  echo "| \`${zip_name}\` | Flashable AnyKernel3 zip, ${zip_size} |"
  echo "| \`${zip_name}.sha256\` | SHA256 checksum file |"
  echo "| \`build-info.txt\` | Exact resolved refs and workflow metadata |"
  echo
  echo "### Checksums"
  echo
  echo "| Artifact | SHA256 |"
  echo "|---|---|"
  echo "| Image | \`${image_sha}\` |"
  echo "| ${zip_name} | \`${zip_sha}\` |"
  echo
  echo "* * *"
  echo
  echo "##  Changelog"
  echo
  echo "### This Release"
  echo
  echo "- Built Marble AnyKernel3 package for \`${manager_display}\`."
  if [[ "${ENABLE_SUSFS}" == "true" ]]; then
    echo "- Applied SUSFS \`${susfs_reported:-${susfs_version}}\` for \`${susfs_branch}\`."
    echo "- Verified manager-side SUSFS support and final \`CONFIG_KSU_SUSFS=y\`."
  else
    echo "- Built without SUSFS."
  fi
  echo "- Audited flashable zip structure and generated SHA256 checksums."
  echo
  echo "### Previous Releases"
  echo
  echo "See the GitHub Actions run history and repository releases."
  echo
  echo "* * *"
  echo
  echo "##  Credits"
  echo
  echo "- Xiaomi/Poco kernel source maintainers"
  echo "- AnyKernel3 by osm0sis"
  echo "- KernelSU / KernelSU-Next / SukiSU Ultra / ReSukiSU maintainers"
  echo "- susfs4ksu by simonpunk and related contributors"
  echo "- Reference projects documented in \`docs/research/reference-projects-analysis.md\`"
  echo
  echo "* * *"
  echo
  echo "⚡ Built with ❤️ by the community"
} > "${summary}"

cat "${summary}"
