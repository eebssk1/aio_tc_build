---
description: "Workspace instructions for aio_tc_build: toolchain build scripts, CI targets, and common commands."
---

# aio_tc_build Workspace Instructions

This repository builds multiple toolchain flavors through shell scripts and GitHub Actions. The main development entrypoint is `./exec.sh <target>`, and CI is defined in `.github/workflows/build.yml`.

## What this repo does
- Builds toolchains for Linux native, MinGW, ARM, and musl targets.
- Uses shell wrapper scripts in the repository root to select the correct target pipeline.
- Relies on external repositories checked out in CI: `m_binutils` and `m_gcc`.

## Primary commands
- `./exec.sh <target>`
  - Central entrypoint for all build targets.
  - Example targets: `linux-native`, `linux-native-legacy`, `mingw64-win`, `mingw64-win-ms`, `mingw64-cross`, `mingw64-cross-ms`, `mingw64-legacy-cross`, `mingw64-legacy-cross-ms`, `arm64-cross`, `arm32-cross`, `musl-cross`.
- `./swap.sh`
  - CI-only helper that configures swap and host container settings for the Debian container environment.
- `./logtar.sh`
  - Packaging utility that creates tarballs for `config.log` and build outputs after a build run.

## Key files and scripts
- `exec.sh` — selects and runs target-specific build scripts.
- `swap.sh` — container swap/host environment setup used in CI.
- `logtar.sh` — collects logs and packaging outputs.
- `pre.sh` — pre-build initialization executed before each target.
- Target scripts:
  - `native.sh`, `native_l.sh`
  - `mingw64-n.sh`, `mingw64-ms2.sh`, `mingw64.sh`
  - `arm.sh`, `musl.sh`

## CI behavior
- CI runs in a Debian container (`ghcr.io/eebssk1/bbk/debian-bookworm:latest`) for Linux and cross targets.
- It also runs a Windows-hosted MSYS2 job for `mingw64-msys2` and `mingw64-msys2-ms` targets.
- Build outputs are uploaded as artifacts matching `*native.tb2` and `*cross*.tb2`.
- `./exec.sh` is the single build driver in CI.

## Guidelines for code changes
- Preserve the `exec.sh` target mapping and the shell-based target scripts.
- Keep CI workflow targets in sync with repository build scripts.
- Avoid changing artifact naming or packaging behavior without updating `.github/workflows/build.yml`.
- Use `README.md` only for repository summary; build logic belongs in shell scripts and CI.

## When to use this instruction
Use these notes when working on build automation, target selection, cross-compilation support, or CI changes.
