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
  local rate
  rate="$(grep -Ei 'hit rate|Hits:' "${f}" | head -n1 | sed -E 's/^[^:]*:[[:space:]]*//')"
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
