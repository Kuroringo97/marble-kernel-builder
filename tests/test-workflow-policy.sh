#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

core=.github/workflows/build-core.yml
[[ -f "${core}" ]] || {
  echo "FAIL: reusable build workflow is missing" >&2
  exit 1
}

required_core_patterns=(
  'workflow_call:'
  'contents: read'
  'contents: write'
  'actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0'
  'actions/cache@27d5ce7f107fe9357f9df03efb73ab90386fccae'
  'actions/cache/restore@27d5ce7f107fe9357f9df03efb73ab90386fccae'
  'actions/cache/save@27d5ce7f107fe9357f9df03efb73ab90386fccae'
  'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a'
  'actions/download-artifact@3e5f45b2cfb9172054b4087a40e8e0b5a5461e7c'
  'persist-credentials: false'
  'git clone --filter=blob:none --no-checkout --depth=1'
  'sparse-checkout set "${ANDROID_CLANG_VERSION}"'
  'ANDROID_CLANG_REF_COMMIT'
  'compression-level: 0'
  'retention-days: 30'
  'retention-days: 7'
  'marble-builder-ccache-v2-'
  'runner_image_version='
  'ccache_hit='
)

for pattern in "${required_core_patterns[@]}"; do
  grep -Fq "${pattern}" "${core}" || {
    echo "FAIL: build-core missing pattern: ${pattern}" >&2
    exit 1
  }
done

grep -Fq 'CCACHE_COMPILERCHECK=content' scripts/build-kernel.sh || {
  echo "FAIL: ccache compiler validation is not content-based" >&2
  exit 1
}

grep -Fq 'ccache -M 2G' scripts/build-kernel.sh || {
  echo "FAIL: ccache maximum is not 2 GiB" >&2
  exit 1
}

if grep -Fq 'CCACHE_COMPILERCHECK=none' scripts/build-kernel.sh; then
  echo "FAIL: unsafe ccache compiler checking remains enabled" >&2
  exit 1
fi

for wrapper in .github/workflows/build-marble.yml .github/workflows/build-matrix.yml; do
  grep -Fq 'uses: ./.github/workflows/build-core.yml' "${wrapper}" || {
    echo "FAIL: ${wrapper} does not call the reusable build workflow" >&2
    exit 1
  }
  if grep -Eq 'apt-get|actions/cache(@|/)' "${wrapper}"; then
    echo "FAIL: ${wrapper} still duplicates core build setup" >&2
    exit 1
  fi
done

grep -Fq 'actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0' \
  .github/workflows/build-matrix.yml || {
  echo "FAIL: matrix setup checkout is not pinned" >&2
  exit 1
}

grep -Fq 'for test_script in tests/test-*.sh' .github/workflows/build-matrix.yml || {
  echo "FAIL: matrix policy tests are not run before fan-out" >&2
  exit 1
}

[[ -f .github/dependabot.yml ]] || {
  echo "FAIL: Dependabot configuration is missing" >&2
  exit 1
}
grep -Fq 'package-ecosystem: github-actions' .github/dependabot.yml || {
  echo "FAIL: Dependabot does not track GitHub Actions" >&2
  exit 1
}

echo "Workflow policy tests passed"
