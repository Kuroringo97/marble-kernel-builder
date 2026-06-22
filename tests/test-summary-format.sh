#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

release_dir="${tmp_dir}/release"
mkdir -p "${release_dir}"
printf 'image\n' > "${release_dir}/Image"
printf 'zip\n' > "${release_dir}/test.zip"
cat > "${release_dir}/zip-name.env" <<'ENV'
zip_name=test.zip
ENV
cat > "${release_dir}/build-info.txt" <<'INFO'
source_repo=mohdakil2426/android_kernel_xiaomi_marble
source_ref=melt-rebase
source_commit=3673961d444b5e2b879be97a161241243d543bd2
workflow_run=https://github.com/mohdakil2426/marble-kernel-builder/actions/runs/1
manager=kernelsu-next
manager_repo=pershoot/KernelSU-Next
manager_ref=dev-susfs
manager_commit=5a8a604a9078c2fbfb50e2b0cba87b3a6f4da1c2
manager_setup_path=kernel/setup.sh
enable_susfs=true
susfs_version=v2.2.0
susfs_kernel_branch=gki-android12-5.10
susfs_ref=4003ecf2d01c6d13fa8edf6c4f2607365738dc3d
susfs_commit=4003ecf2d01c6d13fa8edf6c4f2607365738dc3d
susfs_reported_version=v2.2.0
INFO

KERNEL_DIR="${tmp_dir}" MANAGER=kernelsu-next ENABLE_SUSFS=true BUILD_SCOPE=image-only \
  bash scripts/generate-build-summary.sh >/dev/null

summary="${release_dir}/summary.md"

required_patterns=(
  '^#  Marble Kernel with KernelSU-Next & SUSFS v2.2.0$'
  '^> Build Date: '
  '^>  Build ID: `'
  '^>  Workflow: '
  '^\* \* \*$'
  '^##  Build Configuration$'
  '^###  SUSFS Branch Mapping$'
  '^## ✨ Features & Capabilities$'
  '^###  Root Management$'
  '^### 🛡️ Security & Privacy$'
  '^##  Manager Applications$'
  '^### Official Manager$'
  '^### Required Module$'
  '^### Recommended Flasher$'
  '^##  Installation Instructions$'
  '^### Prerequisites$'
  '^### Via Kernel Flasher$'
  '^##  Changelog$'
  '^### This Release$'
  '^### Previous Releases$'
  '^##  Credits$'
  'pershoot/KernelSU-Next'
  'Poco F5 / Redmi Note 12 Turbo'
  'Flash the ZIP to the active slot'
  '⚡ Built with ❤️ by the community'
)

for pattern in "${required_patterns[@]}"; do
  if ! grep -Eq "${pattern}" "${summary}"; then
    echo "FAIL: summary missing pattern: ${pattern}" >&2
    exit 1
  fi
done

blocked_patterns=(
  'Built Devices'
  'Baseband Guard'
  'BBG'
  'Ptrace Leak Fix'
  'Unicode Fix'
  'Performance & Networking'
  'System Features'
  'Community Managers'
)

for pattern in "${blocked_patterns[@]}"; do
  if grep -q "${pattern}" "${summary}"; then
    echo "FAIL: summary contains blocked pattern: ${pattern}" >&2
    exit 1
  fi
done

echo "Summary format tests passed"
