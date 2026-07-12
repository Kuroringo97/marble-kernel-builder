# Verified Defaults

Checked on 2026-06-23.

| Component | Repo | Default Ref | Version / Commit |
|---|---|---|---|
| Kernel source | `Pzqqt/android_kernel_xiaomi_marble` | `melt-rebase` | Poco F5 / marble source |
| Android kernel Clang | `https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86` | `master-kernel-build-2021` | commit `6e3223f76384455acde43affde3df0ea9df66c0d`; sparse path `clang-r416183b`, matching `build.config.common` |
| LLVM experimental | `https://github.com/llvm/llvm-project/releases/download/llvmorg-22.1.8/LLVM-22.1.8-Linux-X64.tar.xz` | `llvmorg-22.1.8` | SHA-256 `df0e1ecf16caf3489a272a5eea4eec9b0d82878f6477fa309504f918a0006384`; selectable with `toolchain=llvm-22.1.8` |
| AnyKernel3 | `osm0sis/AnyKernel3` | commit `dca9dc370838d919d56c1f59ec78b27a14a72c68` | Immutable packaging template |
| SUSFS | `https://gitlab.com/simonpunk/susfs4ksu.git` | commit `4003ecf2d01c6d13fa8edf6c4f2607365738dc3d` | `SUSFS_VERSION v2.2.0`; CI-proven with KernelSU-Next/pershoot, official SukiSU Ultra, and ReSukiSU |
| SUSFS older preset | `https://gitlab.com/simonpunk/susfs4ksu.git` | commit `86114db0c49f20fa7857b8b559f3ab87cbc2d00d` | `SUSFS_VERSION v2.1.0`; WildKernels GKI r4 gki-android12-5.10 pin |
| KernelSU | `tiann/KernelSU` | `main` | Official source; non-SUSFS builds only |
| KernelSU-Next | `KernelSU-Next/KernelSU-Next` | `dev` | Official non-SUSFS ref |
| KernelSU-Next + SUSFS | `pershoot/KernelSU-Next` | `dev-susfs` | Fork branch based on official `dev` with SUSFS integration; CI-proven on Marble run `27937351021` |
| SukiSU Ultra | `SukiSU-Ultra/SukiSU-Ultra` | `main` | Official non-SUSFS ref |
| SukiSU Ultra + SUSFS | `SukiSU-Ultra/SukiSU-Ultra` | `builtin` | Official branch with manager-side SUSFS support |
| ReSukiSU | `ReSukiSU/ReSukiSU` | `main` | Official branch with manager-side SUSFS support |

The workflow resolves branch, tag, and commit inputs to exact commits at run time and records them in `release/build-info.txt`. For SUSFS, the user chooses `susfs_version=v2.2.0`, `susfs_version=v2.1.0`, or `susfs_version=custom`. Custom mode uses `susfs_ref` and verifies `susfs_expected_version` when provided.

Builds support official Xiaomi stock HyperOS only on Poco F5 (`marblein`) and Redmi Note 12 Turbo (`marble`). Manager artifacts use `AK3_Marble-HyperOS_<Manager>-<version>-code<code>_<SUSFS>_r<run>.zip`; enabling `create_draft_release` on the matrix workflow can turn that successful run into a ZIP-only draft release without rebuilding.

Manager repositories are allowlisted for normal builds. KernelSU-Next is official `KernelSU-Next/KernelSU-Next@dev` when SUSFS is disabled; when SUSFS is enabled, the workflow intentionally switches only that manager to `pershoot/KernelSU-Next@dev-susfs` because current official KernelSU-Next SUSFS paths are not Marble-compatible. Supported SUSFS paths apply only the kernel-side SUSFS patch/files and verify final Kconfig values. Official KernelSU + SUSFS remains rejected until a compatible integration exists.

The default Android compiler is retrieved with Git partial clone and sparse checkout, not a generated archive. The workflow verifies the remote branch resolves to the pinned commit before checking out `clang-r416183b`. This is intentional because repeated downloads of the official generated Gitiles archive produced different whole-archive SHA-256 values even though the underlying Git commit was unchanged.

LLVM 22.1.8 is experimental for Marble. It is not the Android 12 / 5.10 default compiler; use it for test builds first and keep `android-r416183b` for release-safe builds until compile and boot behavior is verified.
