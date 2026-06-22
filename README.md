# Marble Kernel Builder

Reusable GitHub Actions builder for Poco F5 / Redmi Note 12 Turbo (`marble`, `marblein`) kernel variants.

## Repository Model

- `mohdakil2426/android_kernel_xiaomi_marble` is the clean source fork.
- `mohdakil2426/marble-kernel-builder` contains workflows, scripts, configs, and docs.

The builder checks out the source fork in GitHub Actions, patches only the temporary CI workspace, builds, packages, and uploads artifacts. The source fork remains clean.

## Workflow Inputs

| Input | Default | Meaning |
|---|---|---|
| `source_repo` | `mohdakil2426/android_kernel_xiaomi_marble` | Kernel source repo |
| `source_ref` | `melt-rebase` | Source branch, tag, or commit |
| `manager` | `none` | `none`, `kernelsu`, `kernelsu-next`, `sukisu-ultra`, `resukisu` |
| `manager_ref` | empty | Override manager branch, tag, or commit |
| `enable_susfs` | `false` | Apply SUSFS patches |
| `susfs_version` | `v2.2.0` | SUSFS preset: `v2.2.0`, `v2.1.0`, or `custom` |
| `susfs_kernel_branch` | `gki-android12-5.10` | SUSFS patch family for Marble's 5.10 kernel |
| `susfs_ref` | empty | SUSFS branch, tag, or commit; required only for `custom` |
| `susfs_expected_version` | empty | Optional custom ref guard, for example `v2.1.0` |
| `build_scope` | `image-only` | `image-only` or `full` |
| `enable_ccache` | `true` | Restore and save ccache |
| `debug_artifacts` | `false` | Upload debug files on successful builds; failed runs upload available debug files automatically |
| `make_release` | `false` | Create a draft GitHub release |

## Artifact Layout

Default successful build artifact:

```text
marble-flashable-<manager>-<scope>-<run>
├─ AK3_Marble_android12-5.10_<manager>_<manager-sha>_<susfs>_<susfs-sha>_<date>_r<run>.zip
├─ AK3_Marble_android12-5.10_<manager>_<manager-sha>_<susfs>_<susfs-sha>_<date>_r<run>.zip.sha256
├─ build-info.txt
├─ summary.md
├─ zip-audit.txt
└─ ccache-stats.txt
```

Optional debug artifact, uploaded when `debug_artifacts=true` or when a run fails:

```text
marble-debug-<manager>-<scope>-<run>
├─ Image
├─ System.map
├─ vmlinux
├─ dtbs.tar.gz
├─ modules.tar.gz
└─ build.log
```

## Verified Defaults

Checked on 2026-06-22.

| Component | Default | Version |
|---|---|---|
| SUSFS default | `4003ecf2d01c6d13fa8edf6c4f2607365738dc3d` | pinned `v2.2.0` for `gki-android12-5.10` |
| SUSFS older preset | `86114db0c49f20fa7857b8b559f3ab87cbc2d00d` | `v2.1.0`, WildKernels GKI r4 gki-android12-5.10 pin |
| KernelSU | official `tiann/KernelSU@main` | SUSFS disabled until an official compatible integration exists |
| KernelSU-Next | official `dev` | SUSFS disabled after official `legacy-susfs` failed Marble compile/link verification |
| SukiSU Ultra | official `main` / `builtin` | SUSFS automatically selects `builtin` |
| ReSukiSU | official `main` | `main` includes manager-side SUSFS support |
| Android kernel Clang | `clang-r416183b` | declared by `build.config.common` |

## Safe Build Order

1. `manager=none`, `enable_susfs=false`, `build_scope=image-only`
2. `manager=none`, `enable_susfs=false`, `build_scope=full`
3. `manager=kernelsu`, `enable_susfs=false`, `build_scope=image-only`
4. `manager=kernelsu-next`, `enable_susfs=false`, `build_scope=image-only`
5. `manager=sukisu-ultra`, `enable_susfs=false`, `build_scope=image-only`
6. `manager=resukisu`, `enable_susfs=false`, `build_scope=image-only`
7. Test SUSFS with `sukisu-ultra` or `resukisu`; leave `manager_ref` empty so the workflow selects the official compatible ref.

The builder never selects a forked or custom manager repository. It also never applies the generic SUSFS manager patch to a drifting manager tree. Instead, it requires manager-side SUSFS support from the selected official ref, applies the SUSFS kernel patch/files, and verifies `CONFIG_KSU=y` plus `CONFIG_KSU_SUSFS=y` in the final build config.

## Flashing Warning

Artifacts are experimental until boot-tested on the device. The AnyKernel3 installer checks for `marble` / `marblein` and backs up the current active boot image to `/sdcard/marble-kernel-backup` before flashing. Still keep a stock `boot.img` from the same ROM/firmware outside the device before testing.
