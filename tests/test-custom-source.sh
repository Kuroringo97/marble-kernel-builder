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

mkdir -p "${tmp_dir}/config" "${tmp_dir}/scripts"
cp config/kernel-sources.json config/devices.json "${tmp_dir}/config/"
cp scripts/resolve-kernel-source.sh scripts/validate-inputs.sh "${tmp_dir}/scripts/"

resolve_env() {
  (
    cd "${tmp_dir}"
    rm -rf release
    mkdir -p release
    env "$@" bash scripts/resolve-kernel-source.sh >/dev/null
    cat release/kernel-source.env
  )
}

# URL forms normalize to owner/repo
for override in \
  'owner/repo' \
  'https://github.com/owner/repo' \
  'https://github.com/owner/repo.git' \
  'https://github.com/owner/repo/' \
  'git@github.com:owner/repo.git'
do
  out="$(resolve_env KERNEL_SOURCE=lineageos SOURCE_REF=16 SOURCE_REPO_OVERRIDE="${override}")"
  assert_contains "${out}" "SOURCE_REPO=owner/repo"
  assert_contains "${out}" "SOURCE_REF=16"
done

# invalid overrides rejected
for bad in \
  'https://gitlab.com/owner/repo' \
  'https://github.com/owner/repo/tree/16' \
  'owner' \
  'owner/repo/extra'
do
  if (cd "${tmp_dir}" && rm -rf release && mkdir -p release &&
    env KERNEL_SOURCE=lineageos SOURCE_REPO_OVERRIDE="${bad}" \
      bash scripts/resolve-kernel-source.sh >/dev/null 2>&1); then
    echo "FAIL: resolve should reject SOURCE_REPO_OVERRIDE=${bad}" >&2
    exit 1
  fi
done

# override without ref checks out the repo default branch (empty ref)
out="$(resolve_env KERNEL_SOURCE=lineageos SOURCE_REF='' SOURCE_REPO_OVERRIDE=owner/repo)"
assert_contains "${out}" "SOURCE_REPO=owner/repo"
assert_contains "${out}" "SOURCE_REF=''"

# override keeps device fragment substitution and device gating
out="$(resolve_env DEVICE=mondrian KERNEL_SOURCE=lineageos SOURCE_REF='' SOURCE_REPO_OVERRIDE=owner/repo)"
assert_contains "${out}" "vendor/mondrian_GKI.config"
assert_not_contains "${out}" "marble_GKI"
if (cd "${tmp_dir}" && rm -rf release && mkdir -p release &&
  env DEVICE=mondrian KERNEL_SOURCE=melt SOURCE_REPO_OVERRIDE=owner/repo \
    bash scripts/resolve-kernel-source.sh >/dev/null 2>&1); then
  echo "FAIL: device gating must still apply with a custom repo" >&2
  exit 1
fi

# empty override is byte-identical to no override
base="$(resolve_env KERNEL_SOURCE=lineageos SOURCE_REF='')"
with_empty="$(resolve_env KERNEL_SOURCE=lineageos SOURCE_REF='' SOURCE_REPO_OVERRIDE='')"
if [[ "${base}" != "${with_empty}" ]]; then
  echo "FAIL: empty SOURCE_REPO_OVERRIDE must not change preset resolution" >&2
  diff <(printf '%s\n' "${base}") <(printf '%s\n' "${with_empty}") >&2 || true
  exit 1
fi

# validate-inputs: empty SOURCE_REF allowed only with an override
(cd "${tmp_dir}" && env SOURCE_REPO=owner/repo SOURCE_REF='' SOURCE_REPO_OVERRIDE=owner/repo MANAGER=none \
  bash scripts/validate-inputs.sh >/dev/null)
if (cd "${tmp_dir}" && env SOURCE_REPO=owner/repo SOURCE_REF='' MANAGER=none \
  bash scripts/validate-inputs.sh >/dev/null 2>&1); then
  echo "FAIL: empty SOURCE_REF without override must be rejected" >&2
  exit 1
fi

echo "Custom kernel source tests passed"
