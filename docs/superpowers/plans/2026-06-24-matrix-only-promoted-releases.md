# Matrix-Only Promoted Releases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the separate single-build/release path with one matrix build workflow and a protected, manually approved workflow that promotes an existing successful build to a ZIP-only draft release.

**Architecture:** Keep `build-core.yml` as the reusable read-only build engine and `build-matrix.yml` as the only public build entrypoint. Add a focused promotion validator plus `promote-release.yml`, which downloads artifacts from a successful main-branch matrix run after GitHub Environment approval, verifies them, recreates the combined summary, and uploads only flashable ZIPs to one draft release.

**Tech Stack:** GitHub Actions YAML, Bash, GitHub CLI/API, `actions/download-artifact`, existing summary scripts and shell regression tests.

---

### Task 1: Add red tests for the approved behavior

**Files:**
- Create: `tests/test-package-naming.sh`
- Create: `tests/test-promote-release.sh`
- Modify: `tests/test-matrix-summary.sh`
- Modify: `tests/test-workflow-policy.sh`

- [ ] **Step 1: Add filename behavior tests**

Test `scripts/package-anykernel.sh` without network packaging by adding a `PACKAGE_NAME_ONLY=true` mode. Cover build-name sanitization, version-code fallback, commit fallback, SUSFS/NoSUSFS, and NoRoot. Expected names include:

```text
AK3_Marble-HyperOS_KSUNext-v3.2.0-code33203_SUSFS-v2.2.0_r9.zip
AK3_Marble-HyperOS_SukiSUUltra-v4.1.3-b88403d2-code40813_SUSFS-v2.2.0_r9.zip
AK3_Marble-HyperOS_ReSukiSU-88e7f51-code34990_NoSUSFS_r9.zip
AK3_Marble-HyperOS_NoRoot_NoSUSFS_r9.zip
```

- [ ] **Step 2: Add promotion validation tests**

Create fixture artifact directories and run `scripts/prepare-promoted-release.sh`. Assert valid artifacts produce a ZIP manifest and combined notes; checksum mismatch, missing metadata, duplicate ZIP names, and an empty directory fail. Assert the manifest contains only `.zip` paths.

- [ ] **Step 3: Update workflow and summary policy tests**

Require `build-marble.yml` and `release-core.yml` to be absent, `build-matrix.yml` to have no `make_release` or release job, `promote-release.yml` to use `release-approval` with least privilege and cross-run download inputs, the draft release to use only a generated ZIP manifest, and summaries to say `Official Xiaomi stock HyperOS only`.

- [ ] **Step 4: Run tests and verify red state**

Run:

```bash
bash tests/test-package-naming.sh
bash tests/test-promote-release.sh
bash tests/test-workflow-policy.sh
bash tests/test-matrix-summary.sh
```

Expected: FAIL because the new naming mode, promotion script/workflow, and matrix-only policy do not exist yet.

### Task 2: Implement deterministic HyperOS ZIP naming

**Files:**
- Modify: `config/marble.env`
- Modify: `scripts/package-anykernel.sh`
- Modify: `tests/test-build-info-json.sh`

- [ ] **Step 1: Add a single ROM-family constant**

Add `SUPPORTED_ROM_LABEL=HyperOS`.

- [ ] **Step 2: Implement filename normalization**

Choose the filename version using build-log name/tag, resolved tag, then short commit. Strip `@...`, normalize unsafe characters to hyphens, trim separators, prefer build-log numeric code over pre-build code, and omit absent fields. Add `PACKAGE_NAME_ONLY=true` to print the computed name and exit before checking the Image or fetching AnyKernel3.

- [ ] **Step 3: Run naming tests**

Run `bash tests/test-package-naming.sh`.

Expected: PASS.

### Task 3: Make matrix the only build entrypoint

**Files:**
- Delete: `.github/workflows/build-marble.yml`
- Delete: `.github/workflows/release-core.yml`
- Modify: `.github/workflows/build-matrix.yml`
- Modify: `tests/test-manager-policy.sh`
- Modify: `tests/test-workflow-policy.sh`

- [ ] **Step 1: Remove obsolete entrypoints**

Delete the single wrapper and same-run reusable release workflow.

- [ ] **Step 2: Simplify the matrix workflow**

Rename its display name to `Build Marble Kernel`, remove `make_release`, remove the release job, and retain setup, build fan-out, separate artifacts, and aggregate summary. Selecting one checkbox remains the single-manager path.

- [ ] **Step 3: Update policy tests**

Remove references to deleted workflows and explicitly reject their return. Keep the reusable build, pinned actions, concurrency, data-driven matrix generation, and combined summary requirements.

- [ ] **Step 4: Run workflow policy tests**

Run `bash tests/test-manager-policy.sh && bash tests/test-workflow-policy.sh`.

Expected: promotion checks may remain red; matrix-only checks pass.

### Task 4: Add protected cross-run promotion

**Files:**
- Create: `scripts/prepare-promoted-release.sh`
- Create: `.github/workflows/promote-release.yml`
- Modify: `tests/test-promote-release.sh`
- Modify: `tests/test-workflow-policy.sh`

- [ ] **Step 1: Implement artifact preparation**

The script receives `MATRIX_ARTIFACTS_DIR`, `MATRIX_SUMMARY`, `RELEASE_ASSETS_FILE`, and `BUILD_SCOPE`. For each artifact it requires `build-info.txt`, `build-info.json`, `zip-name.env`, one ZIP, and its `.sha256`; verifies `sha256sum --check`; prevents duplicate ZIP names; calls `generate-matrix-summary.sh`; and writes one absolute ZIP path per line to the manifest.

- [ ] **Step 2: Implement the promotion workflow**

Create manual input `build_run_id`. The protected job uses `environment: release-approval` with `actions: read` and `contents: write`. Validate the input and target run with `gh api`, require `main`, `success`, and `.github/workflows/build-matrix.yml`, then check out the target `head_sha`. Download artifacts with the pinned action using `github-token`, `repository`, `run-id`, and a pattern derived from the target `run_number`. Prepare assets, reject an existing tag/release, and call `gh release create --draft --target <head_sha> --notes-file matrix-summary.md` with only the manifest ZIP array.

- [ ] **Step 3: Run promotion and workflow tests**

Run `bash tests/test-promote-release.sh && bash tests/test-workflow-policy.sh`.

Expected: PASS.

### Task 5: Add stock HyperOS compatibility messaging

**Files:**
- Modify: `scripts/generate-build-summary.sh`
- Modify: `scripts/generate-matrix-summary.sh`
- Modify: `tests/test-summary-format.sh`
- Modify: `tests/test-matrix-summary.sh`
- Modify: `README.md`
- Modify: `docs/versions.md`

- [ ] **Step 1: Update summaries without changing their style**

Add `Official Xiaomi stock HyperOS only` to configuration and prerequisites. Explicitly say MIUI, AOSP, and custom ROMs are unsupported. Preserve the existing manager, SUSFS, installation, artifact, checksum, and credits layouts.

- [ ] **Step 2: Rewrite README workflow/release/naming sections**

Document one build workflow, one promotion workflow, environment approval, 30-day artifact promotion window, separate Actions artifacts, one combined draft release, ZIP-only release assets, and the new filename format.

- [ ] **Step 3: Run summary tests**

Run `bash tests/test-summary-format.sh && bash tests/test-matrix-summary.sh`.

Expected: PASS.

### Task 6: Update project memory and run complete local verification

**Files:**
- Modify: `C:/Users/akila/OneDrive/Desktop/MarbleKernel/memory-bank/projectbrief.md`
- Modify: `C:/Users/akila/OneDrive/Desktop/MarbleKernel/memory-bank/productContext.md`
- Modify: `C:/Users/akila/OneDrive/Desktop/MarbleKernel/memory-bank/activeContext.md`
- Modify: `C:/Users/akila/OneDrive/Desktop/MarbleKernel/memory-bank/systemPatterns.md`
- Modify: `C:/Users/akila/OneDrive/Desktop/MarbleKernel/memory-bank/techContext.md`
- Modify: `C:/Users/akila/OneDrive/Desktop/MarbleKernel/memory-bank/progress.md`

- [ ] **Step 1: Update all Memory Bank files**

Record matrix-only architecture, protected promotion, ZIP-only draft assets, naming rules, stock HyperOS support, and verification state without deleting historical evidence.

- [ ] **Step 2: Run complete local verification**

Run:

```bash
bash -n scripts/*.sh scripts/lib/*.sh tests/*.sh
for test_script in tests/test-*.sh; do bash "$test_script"; done
shellcheck -e SC1090,SC1091,SC2016,SC2153,SC2154 scripts/*.sh scripts/lib/*.sh tests/*.sh
actionlint
git diff --check
```

Expected: all commands exit 0.

- [ ] **Step 3: Review the complete diff**

Review correctness, simplicity, architecture, security, and performance. Resolve all required findings, then rerun the full verification set.

### Task 7: Configure GitHub and verify the real release path

**Files:**
- GitHub repository environment: `release-approval`

- [ ] **Step 1: Commit and push main**

Commit focused implementation changes and push `main` to `origin` after fresh local verification.

- [ ] **Step 2: Configure the protected environment**

Use the GitHub API to create/update `release-approval` with the authenticated repository owner as required reviewer and `prevent_self_review: false`. Read the environment back and verify the reviewer configuration.

- [ ] **Step 3: Verify preflight**

Wait for the pushed preflight run and inspect logs if it fails.

- [ ] **Step 4: Run a real matrix build**

Dispatch a representative stock configuration on `main`, wait for completion, and verify the combined summary, separate manager artifacts, new ZIP names, metadata, checksum, and attestation.

- [ ] **Step 5: Promote the successful build**

Dispatch `promote-release.yml` with the build run ID. Approve the `release-approval` deployment through GitHub, wait for completion, then inspect the draft release. It must contain one combined summary and only clean flashable ZIP assets.

- [ ] **Step 6: Final repository verification**

Confirm `main` is clean and matches `origin/main`, both workflows passed, the environment remains protected, and the release is draft rather than public.
