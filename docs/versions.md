# Verified Defaults

Checked on 2026-06-22.

| Component | Repo | Default Ref | Version / Commit |
|---|---|---|---|
| Kernel source | `Pzqqt/android_kernel_xiaomi_marble` | `melt-rebase` | Poco F5 / marble source |
| Android kernel Clang | `https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86` | `master-kernel-build-2021` | `clang-r416183b`, matching `build.config.common` |
| SUSFS | `https://gitlab.com/simonpunk/susfs4ksu.git` | `gki-android12-5.10` | `SUSFS_VERSION v2.2.0`, commit `aee962343bc49469a5427a0e6987e6a70fe88ba3` |
| SUSFS older preset | `https://gitlab.com/simonpunk/susfs4ksu.git` | commit `86114db0c49f20fa7857b8b559f3ab87cbc2d00d` | `SUSFS_VERSION v2.1.0`; WildKernels GKI r4 gki-android12-5.10 pin |
| KernelSU | `tiann/KernelSU` | `main` | latest release `v3.2.4` |
| KernelSU-Next | `KernelSU-Next/KernelSU-Next` | `dev` | latest release `v3.2.0` |
| KernelSU-Next Wild pin | `pershoot/KernelSU-Next` | commit `f1b64f440f3cd170e2a86d7816bef26fbdee1caa` | WildKernels GKI r4 KernelSU-Next pin |
| KernelSU-Next SUSFS branch | `pershoot/KernelSU-Next` | `dev-susfs` | manager branch with SUSFS integration |
| SukiSU Ultra | `SukiSU-Ultra/SukiSU-Ultra` | `main` | latest release `v4.1.3` |
| ReSukiSU | `ReSukiSU/ReSukiSU` | `main` | no GitHub release found; `kernel/setup.sh` exists |

The workflow resolves branch, tag, and commit inputs to exact commits at run time and records them in `release/build-info.txt`. For SUSFS, the user chooses `susfs_version=v2.2.0`, `susfs_version=v2.1.0`, or `susfs_version=custom`. Custom mode uses `susfs_ref` and verifies `susfs_expected_version` when provided. `susfs_manager_patch=auto` applies the generic manager patch for normal refs and skips it for refs containing `susfs`, so branches such as `pershoot/KernelSU-Next@dev-susfs` can use their built-in manager integration.
