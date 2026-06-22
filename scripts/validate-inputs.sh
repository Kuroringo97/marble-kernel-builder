#!/usr/bin/env bash
set -euo pipefail

MANAGER="${MANAGER:-none}"
ENABLE_SUSFS="${ENABLE_SUSFS:-false}"
BUILD_SCOPE="${BUILD_SCOPE:-image-only}"
SOURCE_REPO="${SOURCE_REPO:-}"
SOURCE_REF="${SOURCE_REF:-}"
SUSFS_VERSION="${SUSFS_VERSION:-v2.2.0}"
SUSFS_KERNEL_BRANCH="${SUSFS_KERNEL_BRANCH:-gki-android12-5.10}"
SUSFS_REF="${SUSFS_REF:-}"
SUSFS_EXPECTED_VERSION="${SUSFS_EXPECTED_VERSION:-}"
MANAGER_REF="${MANAGER_REF:-}"

case "${MANAGER}" in
  none|kernelsu|kernelsu-next|sukisu-ultra|resukisu) ;;
  *) echo "::error::Unsupported manager: ${MANAGER}"; exit 1 ;;
esac

case "${ENABLE_SUSFS}" in
  true|false) ;;
  *) echo "::error::ENABLE_SUSFS must be true or false, got ${ENABLE_SUSFS}"; exit 1 ;;
esac

case "${BUILD_SCOPE}" in
  image-only|full) ;;
  *) echo "::error::BUILD_SCOPE must be image-only or full, got ${BUILD_SCOPE}"; exit 1 ;;
esac

if [[ -z "${SOURCE_REPO}" || ! "${SOURCE_REPO}" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "::error::SOURCE_REPO must look like owner/repo, got ${SOURCE_REPO}"
  exit 1
fi

if [[ -z "${SOURCE_REF}" || ! "${SOURCE_REF}" =~ ^[A-Za-z0-9._/-]+$ ]]; then
  echo "::error::SOURCE_REF contains invalid characters: ${SOURCE_REF}"
  exit 1
fi

if [[ "${ENABLE_SUSFS}" == "true" && "${MANAGER}" == "none" ]]; then
  echo "::error::SUSFS requires a manager. Choose kernelsu, kernelsu-next, sukisu-ultra, resukisu, or custom."
  exit 1
fi

case "${SUSFS_VERSION}" in
  v2.2.0|v2.1.0|custom) ;;
  *) echo "::error::SUSFS_VERSION must be v2.2.0, v2.1.0, or custom, got ${SUSFS_VERSION}"; exit 1 ;;
esac

if [[ "${ENABLE_SUSFS}" == "true" ]]; then
  case "${MANAGER}" in
    kernelsu)
      echo "::error::Official tiann/KernelSU does not currently provide a SUSFS-integrated ref compatible with this builder. Disable SUSFS or choose another official manager."
      exit 1
      ;;
    kernelsu-next)
      echo "::error::Official KernelSU-Next + SUSFS is not compatible with the Marble kernel. Disable SUSFS or choose SukiSU Ultra/ReSukiSU."
      exit 1
      ;;
    sukisu-ultra)
      [[ -z "${MANAGER_REF}" || "${MANAGER_REF}" == "builtin" ]] || { echo "::error::SukiSU Ultra + SUSFS requires official ref builtin"; exit 1; }
      ;;
    resukisu)
      [[ -z "${MANAGER_REF}" || "${MANAGER_REF}" == "main" ]] || { echo "::error::ReSukiSU + SUSFS requires official ref main"; exit 1; }
      ;;
  esac
  if [[ "${SUSFS_KERNEL_BRANCH}" != "gki-android12-5.10" ]]; then
    echo "::error::Marble requires SUSFS_KERNEL_BRANCH=gki-android12-5.10, got ${SUSFS_KERNEL_BRANCH}"
    exit 1
  fi
  if [[ "${SUSFS_VERSION}" == "custom" && -z "${SUSFS_REF}" ]]; then
    echo "::error::custom SUSFS_VERSION requires SUSFS_REF as branch/tag/commit"
    exit 1
  fi
  if [[ -n "${SUSFS_REF}" && ! "${SUSFS_REF}" =~ ^[A-Za-z0-9._/-]+$ ]]; then
    echo "::error::SUSFS_REF contains invalid characters: ${SUSFS_REF}"
    exit 1
  fi
  if [[ -n "${SUSFS_EXPECTED_VERSION}" && ! "${SUSFS_EXPECTED_VERSION}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "::error::SUSFS_EXPECTED_VERSION must look like v2.2.0, got ${SUSFS_EXPECTED_VERSION}"
    exit 1
  fi
fi

echo "Input validation passed"
