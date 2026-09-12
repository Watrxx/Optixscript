# Changelog

All notable changes to OPTIX will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project attempts to follow [Semantic Versioning](https://semver.org/).

The two folders in this repository (`Optixscript/` and `Optixscript10/`)
currently contain identical code; the changelog applies to both.

## [Unreleased]

- Publish the project to GitHub.
- Clean up the duplicate copy (keep only `Optixscript10`).

## [1.0.0] - 2026-09-12

### Added

- Game Mode: terminate non-critical processes and stop background
  services, restore everything on exit.
- Normal Mode: full restore of processes and services saved by Game Mode.
- Junk Cleanup: user TEMP, system TEMP, Prefetch, DNS cache, Recycle Bin,
  Windows Update cache, Windows logs, error reports, recent files,
  thumbnail cache, and `cleanmgr` integration.
- Process Manager with blacklist / whitelist / restartable lists and
  protection for critical system processes.
- Customization: 12 color themes, 4 animated color effects (wave, pulse,
  flow, rainbow), custom RGB, ASCII background animations, and multiple
  boot screens.
- Mini-games: Snake, Dinosaur, and Claude-crab shooter, each with skins.
- Interface languages: EN, RU, DE, FR, ES, IT, PL, PT, TR, NL, AR, JA,
  KO, ZH, HI.
- Launcher `run_optix.bat` with admin handling, logging and post-run menu.
- `fix_encoding.ps1` to normalize UTF-8 with BOM for PowerShell 5.1.