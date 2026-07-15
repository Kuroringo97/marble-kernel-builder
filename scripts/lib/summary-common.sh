#!/usr/bin/env bash

summary_get_info() {
  local file="$1"
  local key="$2"
  grep -m1 "^${key}=" "${file}" | cut -d= -f2- || true
}

short_commit() {
  local value="$1"
  if [[ -z "${value}" || "${value}" == "unknown" ]]; then
    echo "unknown"
  else
    echo "${value:0:7}"
  fi
}

# Encode a string for use in shields.io badge path segments.
# spaces → _   |   # → %23   |   - → -- (shields.io convention for literal dash)
badge_encode() {
  echo "$1" | sed 's/ /_/g; s/#/%23/g; s/-/--/g'
}

# Device helpers: empty/marble fall back to the historical marble literals so
# existing artifacts and summaries stay byte-identical.
badge_encode_device() {
  echo "$1" | sed 's/ /_/g; s/#/%23/g; s/-/--/g; s,/,%2F,g; s/|/%7C/g'
}

summary_codenames_join() {
  local codenames="${1:-}" sep="${2:- · }"
  local -a names
  read -r -a names <<<"${codenames}"
  local out="" c
  for c in "${names[@]}"; do
    [[ -n "${out}" ]] && out+="${sep}"
    out+="\`${c}\`"
  done
  printf '%s\n' "${out}"
}

summary_device_heading() {
  case "${1:-}" in
    ""|marble) echo "Marble Kernel" ;;
    *) echo "${1^} Kernel" ;;
  esac
}

summary_device_cap() {
  case "${1:-}" in
    ""|marble) echo "Marble" ;;
    *) echo "${1^}" ;;
  esac
}

summary_device_subtitle() {
  local device="${1:-}" display="${2:-}"
  case "${device}" in
    ""|marble) echo "Poco F5 · Redmi Note 12 Turbo" ;;
    *) display="${display:-${device}}"; echo "${display// \/ / · }" ;;
  esac
}

summary_device_row() {
  local device="${1:-}" display="${2:-}" codenames="${3:-}"
  case "${device}" in
    ""|marble) printf 'Poco F5 (`marblein`) · Redmi Note 12 Turbo (`marble`)\n' ;;
    *) printf '%s (%s)\n' "${display:-${device}}" "$(summary_codenames_join "${codenames:-${device}}" ", ")" ;;
  esac
}

summary_device_prereq_line() {
  local device="${1:-}" display="${2:-}" codenames="${3:-}"
  case "${device}" in
    ""|marble) printf 'Poco F5 (`marblein`) or Redmi Note 12 Turbo (`marble`)\n' ;;
    *) printf '%s (%s)\n' "${display:-${device}}" "$(summary_codenames_join "${codenames:-${device}}" ", ")" ;;
  esac
}

summary_device_warning_line() {
  local device="${1:-}" display="${2:-}" codenames="${3:-}"
  case "${device}" in
    ""|marble) printf '**Poco F5** (`marblein`) or **Redmi Note 12 Turbo** (`marble`)\n' ;;
    *) printf '**%s** (%s)\n' "${display:-${device}}" "$(summary_codenames_join "${codenames:-${device}}" ", ")" ;;
  esac
}

summary_device_codenames_inline() {
  local device="${1:-}" codenames="${2:-}"
  case "${device}" in
    ""|marble) printf '`marble` · `marblein`\n' ;;
    *) summary_codenames_join "${codenames:-${device}}" " · " ;;
  esac
}

summary_device_codenames_slash() {
  local device="${1:-}" codenames="${2:-}"
  case "${device}" in
    ""|marble) printf '`marble` / `marblein`\n' ;;
    *) summary_codenames_join "${codenames:-${device}}" " / " ;;
  esac
}

summary_device_backup_dir() {
  local device="${1:-marble}"
  echo "/sdcard/${device:-marble}-kernel-backup"
}

summary_device_badge_url() {
  local device="${1:-}" display="${2:-}" codenames="${3:-}"
  case "${device}" in
    ""|marble)
      echo "https://img.shields.io/badge/Poco_F5_%2F_Note_12_Turbo-marble_%7C_marblein-EF5350?style=for-the-badge"
      ;;
    *)
      local label joined msg
      label="$(badge_encode_device "${display:-${device}}")"
      joined="${codenames:-${device}}"
      msg="$(badge_encode_device "${joined// / | }")"
      echo "https://img.shields.io/badge/${label}-${msg}-EF5350?style=for-the-badge"
      ;;
  esac
}

summary_device_badge_url_compact() {
  local device="${1:-}" display="${2:-}"
  case "${device}" in
    ""|marble) echo "https://img.shields.io/badge/Device-Poco_F5_%2F_RN12_Turbo-EF5350" ;;
    *) echo "https://img.shields.io/badge/Device-$(badge_encode_device "${display:-${device}}")-EF5350" ;;
  esac
}

manager_display() {
  case "$1" in
    none)          echo "No Manager" ;;
    kernelsu)      echo "KernelSU" ;;
    kernelsu-next) echo "KernelSU-Next" ;;
    sukisu-ultra)  echo "SukiSU Ultra" ;;
    resukisu)      echo "ReSukiSU" ;;
    *)             echo "$1" ;;
  esac
}

manager_app_url() {
  case "$1" in
    kernelsu)      echo "https://github.com/tiann/KernelSU/releases" ;;
    kernelsu-next) echo "https://github.com/KernelSU-Next/KernelSU-Next/releases" ;;
    sukisu-ultra)  echo "https://github.com/SukiSU-Ultra/SukiSU-Ultra/releases" ;;
    resukisu)      echo "https://github.com/ReSukiSU/ReSukiSU" ;;
    *)             echo "" ;;
  esac
}

summary_susfs_module_note() {
  cat <<'EOF'
### SUSFS userspace module

If this build includes **SUSFS**, flash the kernel ZIP **and** install a compatible SUSFS userspace module for your manager (for example [sidex15/susfs4ksu-module](https://github.com/sidex15/susfs4ksu-module/releases)). Kernel patches alone are not enough for full hide functionality.
EOF
}

summary_format_ccache_hits() {
  local f="${1:-}"
  if [[ -z "${f}" || ! -f "${f}" ]]; then
    echo "n/a"
    return
  fi
  # Prefer the indented "Hits:" line under Cacheable calls (modern ccache -s).
  local rate
  rate="$(grep -E '^[[:space:]]+Hits:' "${f}" | head -n1 | sed -E 's/^[^:]*:[[:space:]]*//')"
  if [[ -z "${rate}" ]]; then
    rate="$(grep -Ei 'hit rate|Hits:' "${f}" | head -n1 | sed -E 's/^[^:]*:[[:space:]]*//')"
  fi
  echo "${rate:-see ccache-stats.txt}"
}

summary_quality_label() {
  local kernel_source="${1:-melt}"
  if [[ "${kernel_source}" == "melt" ]]; then
    echo "melt-stable-candidate"
  else
    echo "los-experimental"
  fi
}

# Markers wrap CI-only cache details so release notes can strip them.
SUMMARY_CACHE_START='<!-- marble-ci-cache-start -->'
SUMMARY_CACHE_END='<!-- marble-ci-cache-end -->'

# Emit a cache section to stdout (for CI/artifacts only — stripped before GitHub Release notes).
# Args: ccache_hit thinlto_hit [path_to_ccache-stats.txt]
# Mirrors default `ccache -s` text from the artifact when the stats file exists.
summary_emit_cache_section() {
  local ccache_hit="${1:-unknown}"
  local thinlto_hit="${2:-n/a}"
  local stats_file="${3:-}"

  echo "${SUMMARY_CACHE_START}"
  echo "## 💾 Cache"
  echo
  echo "> CI diagnostics only — this section is **not** included in GitHub Release notes."
  echo
  echo "| | |"
  echo "|:---|:---|"
  echo "| 📦 **Actions ccache hit** | \`${ccache_hit}\` |"
  echo "| 🧵 **Actions ThinLTO hit** | \`${thinlto_hit}\` |"
  echo
  echo "### ccache -s"
  echo
  echo '```text'
  if [[ -n "${stats_file}" && -f "${stats_file}" ]]; then
    cat "${stats_file}"
  else
    echo "(ccache-stats.txt not available)"
  fi
  echo '```'
  echo
  echo "${SUMMARY_CACHE_END}"
}

# Strip CI-only cache section markers from a markdown file.
# Usage: summary_strip_cache_section input.md [output.md]
# If output omitted, prints to stdout.
summary_strip_cache_section() {
  local input="${1:-}"
  local output="${2:-}"
  if [[ -z "${input}" || ! -f "${input}" ]]; then
    echo "::error::summary_strip_cache_section: missing input ${input}" >&2
    return 1
  fi
  local stripped
  stripped="$(
    awk -v start="${SUMMARY_CACHE_START}" -v end="${SUMMARY_CACHE_END}" '
      $0 == start { skip=1; next }
      $0 == end { skip=0; next }
      !skip { print }
    ' "${input}"
  )"
  # Drop extra blank lines left where the section was removed (collapse 3+ → 2).
  stripped="$(printf '%s\n' "${stripped}" | awk 'BEGIN{b=0} /^$/{b++; if(b<=2) print; next} {b=0; print}')"
  if [[ -n "${output}" ]]; then
    printf '%s\n' "${stripped}" > "${output}"
  else
    printf '%s\n' "${stripped}"
  fi
}
