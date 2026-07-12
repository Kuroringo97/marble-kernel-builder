#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

core=.github/workflows/build-core.yml
preflight=.github/workflows/preflight.yml
matrix=.github/workflows/build-matrix.yml
promote=.github/workflows/promote-release.yml
[[ -f "${core}" ]] || {
  echo "FAIL: reusable build workflow is missing" >&2
  exit 1
}

required_core_patterns=(
  'workflow_call:'
  'contents: read'
  'actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0'
  'actions/cache@55cc8345863c7cc4c66a329aec7e433d2d1c52a9'
  'actions/cache/restore@55cc8345863c7cc4c66a329aec7e433d2d1c52a9'
  'actions/cache/save@55cc8345863c7cc4c66a329aec7e433d2d1c52a9'
  'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a'
  'actions/attest@281a49d4cbb0a72c9575a50d18f6deb515a11deb'
  'persist-credentials: false'
  'git clone --filter=blob:none --no-checkout --depth=1'
  'sparse-checkout set "${ANDROID_CLANG_VERSION}"'
  'ANDROID_CLANG_REF_COMMIT'
  'LLVM_22_1_8_SHA256'
  'inputs.toolchain'
  'compression-level: 0'
  'retention-days: 30'
  'marble-builder-ccache-v2-'
  'runner_image_version='
  'ccache_hit='
  'publish_step_summary'
  'Read manager build metadata'
  'Write build-info JSON'
  'Generate artifact attestation'
  'name=marble-flash-${{ inputs.artifact_label }}-${BUILD_SCOPE}-r${GITHUB_RUN_NUMBER}'
)

for pattern in "${required_core_patterns[@]}"; do
  grep -Fq "${pattern}" "${core}" || {
    echo "FAIL: build-core missing pattern: ${pattern}" >&2
    exit 1
  }
done

if grep -Eq 'debug_artifacts|marble-debug-|Upload debug artifacts|retention-days: 7' "${core}"; then
  echo "FAIL: debug artifact upload path must stay removed" >&2
  exit 1
fi

grep -Fq 'CCACHE_COMPILERCHECK=content' scripts/build-kernel.sh || {
  echo "FAIL: ccache compiler validation is not content-based" >&2
  exit 1
}

grep -Fq 'ccache -M 2G' scripts/build-kernel.sh || {
  echo "FAIL: ccache maximum is not 2 GiB" >&2
  exit 1
}

[[ -f scripts/lib/summary-common.sh ]] || {
  echo "FAIL: shared summary helper library is missing" >&2
  exit 1
}

grep -Fq 'source scripts/lib/summary-common.sh' scripts/generate-build-summary.sh || {
  echo "FAIL: single summary does not use shared summary helpers" >&2
  exit 1
}

grep -Fq 'source scripts/lib/summary-common.sh' scripts/generate-matrix-summary.sh || {
  echo "FAIL: matrix summary does not use shared summary helpers" >&2
  exit 1
}

if grep -Fq 'CCACHE_COMPILERCHECK=none' scripts/build-kernel.sh; then
  echo "FAIL: unsafe ccache compiler checking remains enabled" >&2
  exit 1
fi

[[ ! -e .github/workflows/build-marble.yml ]] || {
  echo "FAIL: obsolete single-build workflow must be removed" >&2
  exit 1
}

[[ ! -e .github/workflows/release-core.yml ]] || {
  echo "FAIL: obsolete same-run release workflow must be removed" >&2
  exit 1
}

wrapper="${matrix}"
grep -Fq 'uses: ./.github/workflows/build-core.yml' "${wrapper}" || {
  echo "FAIL: ${wrapper} does not call the reusable build workflow" >&2
  exit 1
}
if grep -Eq 'apt-get|actions/cache(@|/)' "${wrapper}"; then
  echo "FAIL: ${wrapper} still duplicates core build setup" >&2
  exit 1
fi
if grep -Fq 'debug_artifacts' "${wrapper}"; then
  echo "FAIL: ${wrapper} still exposes debug artifact input" >&2
  exit 1
fi
grep -Fq 'concurrency:' "${wrapper}" || {
  echo "FAIL: ${wrapper} does not guard duplicate workflow runs with concurrency" >&2
  exit 1
}

grep -Fq 'toolchain:' "${matrix}" || {
  echo "FAIL: matrix workflow does not expose the toolchain selector" >&2
  exit 1
}

grep -Fq 'default: android-r416183b' "${matrix}" || {
  echo "FAIL: matrix workflow must keep Android r416183b as the default toolchain" >&2
  exit 1
}

grep -Fq 'llvm-22.1.8' "${matrix}" || {
  echo "FAIL: matrix workflow does not expose LLVM 22.1.8 as an experimental option" >&2
  exit 1
}

grep -Fq 'toolchain: ${{ inputs.toolchain }}' "${matrix}" || {
  echo "FAIL: matrix workflow does not pass the selected toolchain to build-core" >&2
  exit 1
}

required_toolchain_patterns=(
  'Restore LLVM 22.1.8'
  'Fetch LLVM 22.1.8'
  'sha256sum -c -'
  'LLVM_22_1_8_URL'
  'LLVM_22_1_8_SHA256'
  'ACTIVE_TOOLCHAIN_VERSION'
  'ACTIVE_TOOLCHAIN_ID'
  'ACTIVE_TOOLCHAIN_DIGEST'
)
for pattern in "${required_toolchain_patterns[@]}"; do
  grep -Fq -- "${pattern}" "${core}" || {
    echo "FAIL: build-core missing toolchain pattern: ${pattern}" >&2
    exit 1
  }
done

grep -Fq 'create_draft_release:' "${matrix}" || {
  echo "FAIL: matrix workflow does not expose the draft release input" >&2
  exit 1
}

grep -Fq 'create_draft_release: true' "${matrix}" && {
  echo "FAIL: draft release input must default to false" >&2
  exit 1
}

grep -Fq 'name: Create ZIP-only draft release' "${matrix}" || {
  echo "FAIL: matrix workflow does not create releases from successful same-run artifacts" >&2
  exit 1
}

required_matrix_release_patterns=(
  'inputs.create_draft_release == true'
  "needs.build.result == 'success'"
  "needs.aggregate-summary.result == 'success'"
  'contents: write'
  'bash scripts/prepare-promoted-release.sh'
  'mapfile -t release_assets < release-assets.txt'
  'gh release create "${tag}" "${release_assets[@]}"'
  '--draft'
  '--target "${GITHUB_SHA}"'
)
for pattern in "${required_matrix_release_patterns[@]}"; do
  grep -Fq -- "${pattern}" "${matrix}" || {
    echo "FAIL: matrix release job missing pattern: ${pattern}" >&2
    exit 1
  }
done

if grep -Eq 'make_release|environment: release-approval|build_run_id|run-id:|github-token:' "${matrix}"; then
  echo "FAIL: matrix release flow must not use old promotion inputs or environment deployments" >&2
  exit 1
fi

grep -Fq 'bash scripts/generate-build-matrix.sh' .github/workflows/build-matrix.yml || {
  echo "FAIL: matrix workflow is not using the data-driven matrix generator" >&2
  exit 1
}

grep -Fq 'actions/checkout@9c091bb21b7c1c1d1991bb908d89e4e9dddfe3e0' \
  .github/workflows/build-matrix.yml || {
  echo "FAIL: matrix setup checkout is not pinned" >&2
  exit 1
}

grep -Fq 'for test_script in tests/test-*.sh' .github/workflows/build-matrix.yml || {
  echo "FAIL: matrix policy tests are not run before fan-out" >&2
  exit 1
}

grep -Fq 'publish_step_summary: false' .github/workflows/build-matrix.yml || {
  echo "FAIL: matrix child jobs should not publish separate job summaries" >&2
  exit 1
}

grep -Fq 'Generate combined matrix summary' .github/workflows/build-matrix.yml || {
  echo "FAIL: matrix workflow does not generate a combined summary" >&2
  exit 1
}

grep -Fq 'pattern: marble-flash-*-r${{ github.run_number }}' .github/workflows/build-matrix.yml || {
  echo "FAIL: matrix workflow does not download all matrix flash artifacts by pattern" >&2
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

[[ -f "${preflight}" ]] || {
  echo "FAIL: preflight workflow is missing" >&2
  exit 1
}

for pattern in 'bash tests/test-*.sh' 'bash -n scripts/*.sh scripts/lib/*.sh tests/*.sh' 'actionlint' 'shellcheck -e SC1090,SC1091,SC2016,SC2153,SC2154'; do
  grep -Fq "${pattern}" "${preflight}" || {
    echo "FAIL: preflight workflow missing pattern: ${pattern}" >&2
    exit 1
  }
done

[[ ! -e "${promote}" ]] || {
  echo "FAIL: separate promote workflow must be removed for same-run draft releases" >&2
  exit 1
}

if grep -Fq 'contents: write' "${core}"; then
  echo "FAIL: build-core.yml should stay read-only; release writes belong in build-matrix.yml release job" >&2
  exit 1
fi

echo "Workflow policy tests passed"
