#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${repo_root}"

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

mkdir -p "${tmp_dir}/kernel/KernelSU-Next/kernel/selinux"
cat > "${tmp_dir}/kernel/KernelSU-Next/kernel/selinux/sepolicy.h" <<'EOF'
#ifndef __KSU_H_SEPOLICY
#define __KSU_H_SEPOLICY

#include <linux/types.h>

#include "ss/policydb.h"

// Operation on types
bool ksu_type(struct policydb *db, const char *name, const char *attr);
bool ksu_attribute(struct policydb *db, const char *name);
EOF

cat > "${tmp_dir}/resolved.env" <<'EOF'
manager=kernelsu-next
manager_repo=KernelSU-Next/KernelSU-Next
manager_ref=legacy-susfs
EOF

KERNEL_DIR="${tmp_dir}/kernel" \
RESOLVED_REFS_FILE="${tmp_dir}/resolved.env" \
bash scripts/apply-manager-compat.sh

header="${tmp_dir}/kernel/KernelSU-Next/kernel/selinux/sepolicy.h"
grep -q '^struct selinux_policy;$' "${header}"
grep -q '^struct selinux_policy \*ksu_dup_sepolicy' "${header}"
grep -q '^void ksu_destroy_sepolicy' "${header}"

echo "Manager compatibility tests passed"
