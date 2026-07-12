# LOS smoke checklist

## CI (image-only)

Workflow: **Build Marble Kernel**

| Input | Value |
|-------|--------|
| `kernel_source` | `lineageos` |
| `toolchain` | `auto` (resolves to `llvm-22.1.8`) |
| `lto` | `thin` |
| `build_scope` | `image-only` |
| `build_kernelsu_next` | `true` |
| `enable_susfs` | `true` (or `false` first for baseline) |
| other managers | `false` |

**Expect:**

- Green build job
- ZIP name like `AK3_marble_LOS_lineageos_ksunext-..._susfs-v2.2.0_rN.zip`
- Text-only banner inside the ZIP with Family `LOS`

Record run URL:

```text
run: (paste)
date:
result: pass | fail
```

## Device (manual)

1. Matching LOS-based ROM on `marble` / `marblein`
2. Backup boot
3. Flash ZIP via Kernel Flasher / Recovery
4. Install manager APK matching the build
5. If SUSFS: install userspace module
6. Record boot OK / fail below

```text
ROM:
manager:
susfs module:
boot: pass | fail
notes:
```

Do **not** claim LOS product readiness until device boot is recorded.
