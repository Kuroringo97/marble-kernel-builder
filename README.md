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
| `manager` | `none` | `none`, `kernelsu`, `kernelsu-next`, `sukisu-ultra`, `resukisu`, `custom` |
| `manager_ref` | empty | Override manager branch, tag, or commit |
| `enable_susfs` | `false` | Apply SUSFS patches |
| `susfs_version` | `v2.2.0` | SUSFS preset: `v2.2.0`, `v2.1.0`, or `custom` |
| `susfs_kernel_branch` | `gki-android12-5.10` | SUSFS patch family for Marble's 5.10 kernel |
| `susfs_ref` | empty | SUSFS branch, tag, or commit; required only for `custom` |
| `susfs_expected_version` | empty | Optional custom ref guard, for example `v2.1.0` |
| `susfs_manager_patch` | `auto` | `auto`, `force`, or `skip`; use `skip` for manager branches that already include SUSFS |
| `build_scope` | `image-only` | `image-only` or `full` |
| `enable_ccache` | `true` | Restore and save ccache |
| `debug_artifacts` | `false` | Upload debug files on successful builds; failed runs upload available debug files automatically |
| `make_release` | `false` | Create a draft GitHub release |

## Artifact Layout

Default successful build artifact:

```text
marble-flashable-<manager>-<scope>-<run>
├─ Marble-<manager>-<scope>-dev-<run>.zip
├─ Marble-<manager>-<scope>-dev-<run>.zip.sha256
└─ build-info.txt
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
| SUSFS default | `gki-android12-5.10` | `v2.2.0` |
| SUSFS older preset | `86114db0c49f20fa7857b8b559f3ab87cbc2d00d` | `v2.1.0`, WildKernels GKI r4 gki-android12-5.10 pin |
| KernelSU | `main` | latest release `v3.2.4` |
| KernelSU-Next | `dev` | latest release `v3.2.0` |
| SukiSU Ultra | `main` | latest release `v4.1.3` |
| ReSukiSU | `main` | no release found |
| Android kernel Clang | `clang-r416183b` | declared by `build.config.common` |

## Safe Build Order

1. `manager=none`, `enable_susfs=false`, `build_scope=image-only`
2. `manager=none`, `enable_susfs=false`, `build_scope=full`
3. `manager=kernelsu`, `enable_susfs=false`, `build_scope=image-only`
4. `manager=kernelsu-next`, `enable_susfs=false`, `build_scope=image-only`
5. `manager=sukisu-ultra`, `enable_susfs=false`, `build_scope=image-only`
6. Add `enable_susfs=true` only after the matching manager build succeeds.

For a Wild-style SUSFS manager branch, use `manager=custom`, `custom_manager_repo=pershoot/KernelSU-Next`, `custom_manager_ref=dev-susfs`, `custom_setup_path=kernel/setup.sh`, `enable_susfs=true`, `susfs_version=v2.1.0`, and `susfs_manager_patch=auto`.

## Flashing Warning

Artifacts are experimental until boot-tested on the device. Back up your current boot image before flashing any AnyKernel3 zip.
