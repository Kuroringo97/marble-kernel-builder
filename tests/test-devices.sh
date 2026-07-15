#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

assert_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "${haystack}" != *"${needle}"* ]]; then
    echo "FAIL: expected to find '${needle}' in output" >&2
    echo "${haystack}" >&2
    exit 1
  fi
}

assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  if [[ "${haystack}" == *"${needle}"* ]]; then
    echo "FAIL: did not expect '${needle}' in output" >&2
    echo "${haystack}" >&2
    exit 1
  fi
}

# devices.json shape
python3 - config/devices.json <<'PY'
import json
import re
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    devices = json.load(fh)

assert "marble" in devices and "mondrian" in devices, "marble and mondrian entries required"
assert devices["marble"]["codenames"] == ["marble", "marblein"], "marble codenames drifted"
assert devices["mondrian"]["codenames"] == ["mondrian"], "mondrian codenames drifted"
for name, meta in devices.items():
    for key in ("display", "codenames", "kernel_title", "zip_token", "backup_slug"):
        assert meta.get(key), f"{name} missing {key}"
    assert re.fullmatch(r"[a-z0-9._-]+", meta["zip_token"]), f"{name} zip_token invalid"
    assert re.fullmatch(r"[a-z0-9._-]+", meta["backup_slug"]), f"{name} backup_slug invalid"
PY

# Hermetic fixture (no release/ state)
mkdir -p "${tmp_dir}/config" "${tmp_dir}/scripts" "${tmp_dir}/ak3"
cp config/kernel-sources.json config/devices.json config/marble.env "${tmp_dir}/config/"
cp scripts/resolve-kernel-source.sh scripts/validate-inputs.sh \
  scripts/package-anykernel.sh scripts/write-build-info-json.sh "${tmp_dir}/scripts/"
cp ak3/anykernel.sh "${tmp_dir}/ak3/"

# mondrian + lineageos resolves with the mondrian fragment
out="$(
  cd "${tmp_dir}"
  rm -rf release
  mkdir -p release
  DEVICE=mondrian KERNEL_SOURCE=lineageos SOURCE_REF='' bash scripts/resolve-kernel-source.sh >/dev/null
  cat release/kernel-source.env
)"
assert_contains "${out}" "vendor/mondrian_GKI.config"
assert_not_contains "${out}" "marble_GKI"
assert_contains "${out}" "DEVICE=mondrian"
assert_contains "${out}" "PACKAGE_FAMILY=LOS"

# default device keeps the exact marble fragment chain
out="$(
  cd "${tmp_dir}"
  rm -rf release
  mkdir -p release
  KERNEL_SOURCE=lineageos SOURCE_REF='' bash scripts/resolve-kernel-source.sh >/dev/null
  cat release/kernel-source.env
)"
assert_contains "${out}" 'CONFIG_FRAGMENTS=vendor/waipio_GKI.config\ vendor/xiaomi_GKI.config\ vendor/marble_GKI.config\ vendor/debugfs.config'
assert_contains "${out}" "DEVICE=marble"

# unsupported device/preset combos must fail at resolve time
for combo in "mondrian melt" "mondrian evolution-x" "mondrian pablo" "not-a-device lineageos"; do
  read -r bad_device bad_source <<<"${combo}"
  if (cd "${tmp_dir}" && rm -rf release && mkdir -p release &&
    DEVICE="${bad_device}" KERNEL_SOURCE="${bad_source}" SOURCE_REF='' \
      bash scripts/resolve-kernel-source.sh >/dev/null 2>&1); then
    echo "FAIL: resolve should reject DEVICE=${bad_device} KERNEL_SOURCE=${bad_source}" >&2
    exit 1
  fi
done

# validate-inputs enforces the same policy
(cd "${tmp_dir}" && DEVICE=mondrian KERNEL_SOURCE=lineageos SOURCE_REPO=o/r SOURCE_REF=main MANAGER=none \
  bash scripts/validate-inputs.sh >/dev/null)
if (cd "${tmp_dir}" && DEVICE=mondrian KERNEL_SOURCE=melt SOURCE_REPO=o/r SOURCE_REF=main MANAGER=none \
  bash scripts/validate-inputs.sh >/dev/null 2>&1); then
  echo "FAIL: validate-inputs should reject mondrian + melt" >&2
  exit 1
fi
if (cd "${tmp_dir}" && DEVICE=not-a-device SOURCE_REPO=o/r SOURCE_REF=main MANAGER=none \
  bash scripts/validate-inputs.sh >/dev/null 2>&1); then
  echo "FAIL: validate-inputs should reject unknown device" >&2
  exit 1
fi

# zip naming
assert_name() {
  local expected="$1"
  shift
  local actual
  actual="$(cd "${tmp_dir}" && env PACKAGE_NAME_ONLY=true GITHUB_RUN_NUMBER=9 "$@" bash scripts/package-anykernel.sh)"
  if [[ "${actual}" != "${expected}" ]]; then
    echo "FAIL: expected ${expected}, got ${actual}" >&2
    exit 1
  fi
}

assert_name 'AK3_mondrian_LOS_lineageos_noroot_r9.zip' \
  DEVICE=mondrian KERNEL_SOURCE=lineageos ROM_FAMILY=los MANAGER=none
assert_name 'AK3_marble_LOS_lineageos_noroot_r9.zip' \
  DEVICE=marble KERNEL_SOURCE=lineageos ROM_FAMILY=los MANAGER=none
assert_name 'AK3_marble_LOS_lineageos_noroot_r9.zip' \
  KERNEL_SOURCE=lineageos ROM_FAMILY=los MANAGER=none
assert_name 'AK3_mondrian_LOS_lineageos_ksunext-v3.2.0-code33203_susfs-v2.2.0_r9.zip' \
  DEVICE=mondrian KERNEL_SOURCE=lineageos ROM_FAMILY=los \
  MANAGER=kernelsu-next ENABLE_SUSFS=true \
  manager_build_version_name='v3.2.0' manager_build_version_code=33203 \
  susfs_reported_version=v2.2.0

# banner
banner="$(cd "${tmp_dir}" && env PACKAGE_BANNER_ONLY=true DEVICE=mondrian KERNEL_SOURCE=lineageos \
  ROM_FAMILY=los MANAGER=none bash scripts/package-anykernel.sh)"
assert_contains "${banner}" "Mondrian Kernel"
assert_contains "${banner}" "Device   : Poco F5 Pro / Redmi K60"
assert_contains "${banner}" "Codename : mondrian"
assert_not_contains "${banner}" "marble"

# AnyKernel3 script render: marble must stay byte-identical
rendered="$(cd "${tmp_dir}" && env PACKAGE_AK3_PROPS_ONLY=true KERNEL_SOURCE=lineageos \
  ROM_FAMILY=los MANAGER=none bash scripts/package-anykernel.sh)"
if ! printf '%s\n' "${rendered}" | diff -q - "${repo_root}/ak3/anykernel.sh" >/dev/null; then
  echo "FAIL: default AK3 render must be byte-identical to ak3/anykernel.sh" >&2
  printf '%s\n' "${rendered}" | diff - "${repo_root}/ak3/anykernel.sh" >&2 || true
  exit 1
fi

# AnyKernel3 script render: mondrian single-codename gate
rendered="$(cd "${tmp_dir}" && env PACKAGE_AK3_PROPS_ONLY=true DEVICE=mondrian KERNEL_SOURCE=lineageos \
  ROM_FAMILY=los MANAGER=none bash scripts/package-anykernel.sh)"
assert_contains "${rendered}" "kernel.string=Mondrian Kernel for Poco F5 Pro / Redmi K60"
assert_contains "${rendered}" "device.name1=mondrian"
assert_not_contains "${rendered}" "device.name2"
assert_not_contains "${rendered}" "marble"
assert_contains "${rendered}" "/sdcard/mondrian-kernel-backup"
assert_contains "${rendered}" "boot-mondrian-"
assert_contains "${rendered}" "Supported devices: mondrian"

# build-info JSON carries the device object
(
  cd "${tmp_dir}"
  mkdir -p kernel-source/release
  cat > kernel-source/release/build-info.txt <<'EOF'
device=mondrian
device_display=Poco F5 Pro / Redmi K60
device_codenames=mondrian
source_repo=LineageOS/android_kernel_xiaomi_sm8450
EOF
  cat > kernel-source/release/zip-name.env <<'EOF'
zip_name=AK3_mondrian_LOS_lineageos_noroot_r9.zip
zip_sha256=0000000000000000000000000000000000000000000000000000000000000000
EOF
  bash scripts/write-build-info-json.sh >/dev/null
  python3 - kernel-source/release/build-info.json <<'PY'
import json
import sys

with open(sys.argv[1], encoding="utf-8") as fh:
    data = json.load(fh)
assert data["device"]["name"] == "mondrian", data["device"]
assert data["device"]["display"] == "Poco F5 Pro / Redmi K60", data["device"]
assert data["device"]["codenames"] == ["mondrian"], data["device"]
PY
)

echo "Device support tests passed"
