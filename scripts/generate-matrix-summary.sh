#!/usr/bin/env bash
set -euo pipefail

source config/marble.env
source scripts/lib/summary-common.sh

MATRIX_ARTIFACTS_DIR="${MATRIX_ARTIFACTS_DIR:-matrix-artifacts}"
MATRIX_SUMMARY="${MATRIX_SUMMARY:-matrix-summary.md}"
BUILD_SCOPE="${BUILD_SCOPE:-image-only}"

if [[ ! -d "${MATRIX_ARTIFACTS_DIR}" ]]; then
  echo "::error::Matrix artifacts directory not found: ${MATRIX_ARTIFACTS_DIR}"
  exit 1
fi

artifact_dirs=()
if [[ -f "${MATRIX_ARTIFACTS_DIR}/build-info.txt" && -f "${MATRIX_ARTIFACTS_DIR}/zip-name.env" ]]; then
  artifact_dirs+=("${MATRIX_ARTIFACTS_DIR}")
fi

mapfile -t nested_artifact_dirs < <(
  find "${MATRIX_ARTIFACTS_DIR}" -mindepth 1 -maxdepth 1 -type d | sort
)
artifact_dirs+=("${nested_artifact_dirs[@]}")

valid_dirs=()
for artifact_dir in "${artifact_dirs[@]}"; do
  if [[ -f "${artifact_dir}/build-info.txt" && -f "${artifact_dir}/zip-name.env" ]]; then
    valid_dirs+=("${artifact_dir}")
  fi
done
artifact_dirs=("${valid_dirs[@]}")

if [[ "${#artifact_dirs[@]}" -eq 0 ]]; then
  echo "::error::No matrix flash artifact metadata found in ${MATRIX_ARTIFACTS_DIR}"
  exit 1
fi

get_info() {
  local file="$1"
  local key="$2"
  summary_get_info "${file}" "${key}"
}

manager_version_label() {
  local build_info="$1"
  local tag build_tag build_name build_code static_code commit
  tag="$(get_info "${build_info}" manager_tag)"
  build_tag="$(get_info "${build_info}" manager_build_tag)"
  build_name="$(get_info "${build_info}" manager_build_version_name)"
  build_code="$(get_info "${build_info}" manager_build_version_code)"
  static_code="$(get_info "${build_info}" manager_version_code)"
  commit="$(get_info "${build_info}" manager_commit)"

  local version="${build_name:-${build_tag:-${tag:-}}}"
  if [[ -z "${version}" && -n "${commit}" ]]; then
    version="$(short_commit "${commit}")"
  fi
  if [[ -n "${build_code:-${static_code}}" ]]; then
    echo "${version:-unknown} · code ${build_code:-${static_code}}"
  else
    echo "${version:-unknown}"
  fi
}

first_info="${artifact_dirs[0]}/build-info.txt"
if [[ ! -f "${first_info}" ]]; then
  echo "::error::Missing build-info.txt in ${artifact_dirs[0]}"
  exit 1
fi

source_repo="$(get_info "${first_info}" source_repo)"
source_ref="$(get_info "${first_info}" source_ref)"
source_commit="$(get_info "${first_info}" source_commit)"
workflow_run="$(get_info "${first_info}" workflow_run)"
susfs_reported="$(get_info "${first_info}" susfs_reported_version)"
susfs_version="$(get_info "${first_info}" susfs_version)"
susfs_branch="$(get_info "${first_info}" susfs_kernel_branch)"
susfs_commit="$(get_info "${first_info}" susfs_commit)"
susfs_url="$(get_info "${first_info}" susfs_url)"
android_clang_version="$(get_info "${first_info}" android_clang_version)"
android_clang_commit="$(get_info "${first_info}" android_clang_commit)"
build_date="$(date -u '+%Y-%m-%d %H:%M:%S UTC')"
run_number="${SOURCE_RUN_NUMBER:-${GITHUB_RUN_NUMBER:-}}"
susfs_display="${susfs_reported:-${susfs_version}}"

manager_count="${#artifact_dirs[@]}"
manager_badge_url="https://img.shields.io/badge/Managers-${manager_count}_builds-4CAF50?style=for-the-badge&logo=linux&logoColor=white"
susfs_badge_url="https://img.shields.io/badge/SUSFS-$(badge_encode "${susfs_display:-Mixed}")-FF6D00?style=for-the-badge&logo=gitlab&logoColor=white"
device_badge_url="https://img.shields.io/badge/Poco_F5_%2F_Note_12_Turbo-marble_%7C_marblein-EF5350?style=for-the-badge"
build_badge_url="https://img.shields.io/badge/Matrix-Passing-2088FF?style=for-the-badge&logo=githubactions&logoColor=white"

{
  echo '<div align="center">'
  echo
  echo "# 🪨 Marble Kernel Matrix"
  echo
  echo "### Poco F5 · Redmi Note 12 Turbo"
  echo
  echo "[![Managers](${manager_badge_url})](${workflow_run})"
  echo "[![SUSFS](${susfs_badge_url})](${susfs_url:-https://gitlab.com/simonpunk/susfs4ksu})"
  echo "[![Device](${device_badge_url})](https://github.com/${source_repo})"
  echo "[![Build](${build_badge_url})](${workflow_run})"
  echo
  echo "<br>"
  echo
  echo "🕐 **${build_date}** &nbsp;·&nbsp; 🔢 **Run #${run_number:-unknown}** &nbsp;·&nbsp; 🔗 **[View Workflow](${workflow_run})**"
  echo
  echo '</div>'
  echo
  echo "---"
  echo

  echo "## ⚙️ Matrix Configuration"
  echo
  echo "| | |"
  echo "|:---|:---|"
  echo "| 📱 **Device** | Poco F5 (\`marblein\`) · Redmi Note 12 Turbo (\`marble\`) |"
  echo "| 🟠 **ROM Support** | **Official Xiaomi stock ${SUPPORTED_ROM_LABEL} only** |"
  echo "| 🧬 **Kernel Base** | \`android12-5.10\` |"
  echo "| 🛠️ **Build Scope** | \`${BUILD_SCOPE}\` |"
  echo "| 📦 **Source** | [\`${source_ref} @ $(short_commit "${source_commit}")\`](https://github.com/${source_repo}/commit/${source_commit}) |"
  echo "| 🔨 **Compiler** | \`${android_clang_version:-clang-r416183b}\` |"
  if [[ -n "${android_clang_commit}" ]]; then
    echo "| 🧷 **Compiler Commit** | \`$(short_commit "${android_clang_commit}")\` |"
  fi
  echo
  echo "---"
  echo

  echo "## 🔑 Managers"
  echo
  for artifact_dir in "${artifact_dirs[@]}"; do
    build_info="${artifact_dir}/build-info.txt"
    zip_env="${artifact_dir}/zip-name.env"
    [[ -f "${build_info}" && -f "${zip_env}" ]] || continue
    # shellcheck disable=SC1090
    source "${zip_env}"

    manager_name="$(get_info "${build_info}" manager)"
    display="$(manager_display "${manager_name}")"
    version_label="$(manager_version_label "${build_info}")"
    manager_repo="$(get_info "${build_info}" manager_repo)"
    manager_ref="$(get_info "${build_info}" manager_ref)"
    manager_commit="$(get_info "${build_info}" manager_commit)"
    build_code="$(get_info "${build_info}" manager_build_version_code)"
    static_code="$(get_info "${build_info}" manager_version_code)"
    build_name="$(get_info "${build_info}" manager_build_version_name)"
    build_tag="$(get_info "${build_info}" manager_build_tag)"
    tag="$(get_info "${build_info}" manager_tag)"
    sig_size="$(get_info "${build_info}" manager_signature_size)"
    sig_hash="$(get_info "${build_info}" manager_signature_hash)"
    supported_line="$(get_info "${build_info}" manager_supported_line)"

    echo "<details open>"
    echo "<summary><b>${display}</b> — ${version_label} · ✅ Passed</summary>"
    echo "<br>"
    echo
    echo "| | |"
    echo "|:---|:---|"
    echo "| 📁 **Repository** | [\`${manager_repo} @ ${manager_ref}\`](https://github.com/${manager_repo}) |"
    if [[ -n "${build_name}" ]]; then
      echo "| 🏷️ **Version Name** | \`${build_name}\` |"
    fi
    if [[ -n "${build_tag:-${tag}}" ]]; then
      echo "| 🔖 **Version** | \`${build_tag:-${tag}}\` |"
    fi
    if [[ -n "${build_code:-${static_code}}" ]]; then
      echo "| 🔢 **Version Code** | \`${build_code:-${static_code}}\` |"
    fi
    echo "| 🔗 **Commit** | [\`$(short_commit "${manager_commit}")\`](https://github.com/${manager_repo}/commit/${manager_commit}) |"
    if [[ -n "${sig_size}" ]]; then
      echo "| ✍️ **Signature Size** | \`${sig_size}\` |"
    fi
    if [[ -n "${sig_hash}" ]]; then
      echo "| 🧾 **Signature Hash** | \`${sig_hash}\` |"
    fi
    if [[ -n "${supported_line}" ]]; then
      echo "| 🤝 **Supported Managers** | ${supported_line//,/, } |"
    fi
    if [[ "${manager_name}" == "kernelsu-next" && "$(get_info "${build_info}" enable_susfs)" == "true" ]]; then
      echo "| 📌 **Note** | Non-SUSFS builds use official \`KernelSU-Next/KernelSU-Next@dev\` · SUSFS builds use \`pershoot/dev-susfs\` |"
    fi
    echo
    echo "</details>"
    echo
  done
  echo "---"
  echo

  echo "## 🛡️ SUSFS"
  echo
  if [[ -n "${susfs_display}" ]]; then
    echo "| | |"
    echo "|:---|:---|"
    echo "| 🏷️ **Version** | \`${susfs_display}\` |"
    echo "| 🌿 **Kernel Branch** | \`${susfs_branch}\` |"
    echo "| 🔗 **Commit** | [\`$(short_commit "${susfs_commit}")\`](${susfs_url}) |"
  else
    echo "SUSFS is not enabled for this matrix."
  fi
  echo
  echo "---"
  echo

  echo "## 📲 Installation"
  echo
  echo "<details>"
  echo "<summary><b>📋 Prerequisites</b> — expand before flashing</summary>"
  echo "<br>"
  echo
  echo "- 🔓 Unlocked bootloader"
  echo "- 📱 Poco F5 (\`marblein\`) or Redmi Note 12 Turbo (\`marble\`) **only**"
  echo "- 🟠 **Official Xiaomi stock ${SUPPORTED_ROM_LABEL} only** — MIUI, AOSP, and custom ROMs are unsupported"
  echo "- 💾 Stock \`boot.img\` from the **same ROM/firmware** stored safely outside the device"
  for artifact_dir in "${artifact_dirs[@]}"; do
    build_info="${artifact_dir}/build-info.txt"
    manager_name="$(get_info "${build_info}" manager)"
    display="$(manager_display "${manager_name}")"
    app_url="$(manager_app_url "${manager_name}")"
    if [[ "${manager_name}" != "none" && -n "${app_url}" ]]; then
      echo "- 📦 [${display} manager app](${app_url}) for the ${display} ZIP"
    fi
  done
  if [[ -n "${susfs_display}" ]]; then
    echo "- 🧩 [KSU SUSFS module](https://github.com/sidex15/susfs4ksu-module/releases) matching \`${susfs_display}\`"
  fi
  echo
  echo "</details>"
  echo
  echo "<details>"
  echo "<summary><b>⚡ Flash Steps</b></summary>"
  echo "<br>"
  echo
  echo "1. Download the ZIP for the manager you want"
  echo "2. Verify it against the SHA256 shown in this summary before flashing"
  echo "3. Flash the ZIP to the active slot via **[Kernel Flasher](https://github.com/fatalcoder524/KernelFlasher/releases)**"
  echo "4. The AnyKernel3 installer will verify your device codename and **automatically back up** your current boot image to \`/sdcard/marble-kernel-backup/\` before writing"
  echo "5. After boot — install / open the matching manager app"
  if [[ -n "${susfs_display}" ]]; then
    echo "6. Install the **KSU SUSFS module**, configure hiding rules, then reboot"
  fi
  echo
  echo "</details>"
  echo
  echo "> [!WARNING]"
  echo "> **Bootloop?** Flash the stock \`boot.img\` back to the active slot using Kernel Flasher or fastboot. Keep it accessible before flashing."
  echo
  echo "---"
  echo

  echo "## 📦 Artifacts & Checksums"
  echo
  echo "| Manager | File | Size | SHA256 |"
  echo "|:---|:---|:---:|:---|"
  for artifact_dir in "${artifact_dirs[@]}"; do
    build_info="${artifact_dir}/build-info.txt"
    zip_env="${artifact_dir}/zip-name.env"
    [[ -f "${build_info}" && -f "${zip_env}" ]] || continue
    # shellcheck disable=SC1090
    source "${zip_env}"
    manager_name="$(get_info "${build_info}" manager)"
    display="$(manager_display "${manager_name}")"
    zip_path="${artifact_dir}/${zip_name}"
    if [[ -f "${zip_path}" ]]; then
      zip_size="$(du -h "${zip_path}" | awk '{print $1}')"
      zip_sha="$(sha256sum "${zip_path}" | awk '{print $1}')"
    else
      zip_size="missing"
      zip_sha="missing"
    fi
    echo "| ${display} | \`${zip_name}\` | ${zip_size} | \`${zip_sha}\` |"
  done
  echo
  echo "---"
  echo

  echo "## 🙏 Credits"
  echo
  echo "| | |"
  echo "|:---|:---|"
  echo "| 🧑‍💻 **Kernel Source** | Pzqqt · Xiaomi/Poco kernel maintainers |"
  echo "| 📦 **AnyKernel3** | osm0sis |"
  seen_managers=""
  for artifact_dir in "${artifact_dirs[@]}"; do
    build_info="${artifact_dir}/build-info.txt"
    manager_name="$(get_info "${build_info}" manager)"
    [[ "${manager_name}" == "none" ]] && continue
    case " ${seen_managers} " in
      *" ${manager_name} "*) continue ;;
    esac
    seen_managers="${seen_managers} ${manager_name}"
    display="$(manager_display "${manager_name}")"
    echo "| 🔑 **${display}** | ${display} team |"
  done
  if [[ -n "${susfs_display}" ]]; then
    echo "| 🛡️ **SUSFS** | simonpunk and contributors |"
  fi
  echo
  echo "---"
  echo
  echo '<div align="center">'
  echo
  echo "⚡ Built with ❤️ using **GitHub Actions**"
  echo
  echo '</div>'
} > "${MATRIX_SUMMARY}"

cat "${MATRIX_SUMMARY}"
