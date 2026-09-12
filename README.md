# OPTIX — Windows Performance & Game Optimization Suite

[![Platform](https://img.shields.io/badge/Platform-Windows-blue)](https://www.microsoft.com/windows)
[![Language](https://img.shields.io/badge/Language-PowerShell-5391FE)](https://learn.microsoft.com/powershell/)
[![License](https://img.shields.io/badge/License-MIT-green)](#license)
[![Launcher](https://img.shields.io/badge/Launch-BAT-orange)](#how-to-run)

**OPTIX** is a PowerShell-based toolkit for Windows that helps you clean up
junk files, manage running processes, stop background services for gaming,
and play a few small built-in mini-games — all from a single animated
terminal interface.

It is a fully portable project: no installer, no admin tools beyond the
one-time UAC prompt, and no external dependencies.

> **Note about this repository:** it contains **two identical copies** of the
> OPTIX code — [`Optixscript/`](Optixscript/README.md) and
> [`Optixscript10/`](Optixscript10/README.md). Both are the same project;
> they differ only in the local `logs/` folder. Each folder is fully
> self-contained and runnable on its own. You only need **one** of them —
> `Optixscript10` is the one to keep if you clean the repo up.

## ⚠️ Important note about this project

**This project is 99.9% AI-generated.**

My name is **Watrxx**, and I do not know how to program. This is my very
first project — I built it entirely by working with large language models
(AI assistants), giving them ideas, testing what they produced, and putting
the pieces together. Every line of PowerShell, every menu, every game, and
every config file in this repository was written by an AI based on my
requests.

I reviewed, ran, and broke things many times along the way, but the actual
code, logic, and structure were created by AI, not by me. If you are a
real developer looking at this repo and wondering why some patterns look
unusual or over-engineered — that is the reason. I learned what I could,
but I am not the author of this code in any meaningful sense.

If you find bugs, please be kind. I am learning.

## What OPTIX does

- **Game Mode** — kills non-critical running processes and stops a list
  of background Windows services to free up CPU and RAM, then restores
  everything when you exit Game Mode.
- **Normal Mode** — safely restores processes and services that were
  stopped while in Game Mode.
- **Junk Cleanup** — clears user TEMP, system TEMP, Prefetch, DNS cache,
  Recycle Bin, Windows Update cache, Windows logs, error reports, recent
  files, thumbnail cache, and can even run `cleanmgr` on all drives.
- **Process Manager** — interactive list of every running process with
  filters for critical, system, and Microsoft processes. Lets you add
  selected processes to a blacklist (kill on Game Mode entry), a
  whitelist (never touch), or a restartable list (kill and restart
  automatically).
- **Customization** — 12 color themes, 4 animated color effects
  (wave, pulse, flow, rainbow), custom RGB override, ASCII background
  animations for the games, boot screens (including a "terminals" marker
  effect), and 15 interface languages (EN, RU, DE, FR, ES, IT, PL, PT,
  TR, NL, AR, JA, KO, ZH, HI).
- **Mini-games** — Snake, Dinosaur, and a small "Claude-crab" shooter
  game, each with multiple skins.

## Requirements

- Windows 7 / 8 / 10 / 11
- Windows PowerShell 5.1 (built into Windows)
- Administrator rights (essential for Game Mode and Junk Cleanup)

## How to run

1. Right-click `run_optix.bat` and choose **Run as administrator**.
   (The script will also offer to relaunch itself with admin rights if
   you forget.)
2. Wait for the loading animation to finish.
3. Use the arrow keys (or `v` / `^`) to navigate, `Enter` to confirm,
   `Esc` to go back.
4. After the script finishes, the menu will offer to open the log,
   restart OPTIX, clean old logs, or just exit.

If `run_optix.bat` is missing, OPTIX will detect that and give you the
option to open the project folder in Explorer or recreate the file from
a built-in default.

## Project structure

```
Optixscript/                 <- repository root
├── README.md                <- this file
├── LICENSE
├── .gitignore
├── CONTRIBUTING.md
├── SECURITY.md
├── CHANGELOG.md
├── CODE_OF_CONDUCT.md
├── .github/
│   ├── ISSUE_TEMPLATE/      <- bug report & feature request templates
│   └── PULL_REQUEST_TEMPLATE.md
├── Optixscript/             <- full OPTIX copy #1
│   ├── optimization_script.ps1   — main script (the whole app)
│   ├── run_optix.bat             — launcher (admin rights + logging)
│   ├── fix_encoding.ps1          — fixes Russian text in older terminals
│   ├── README.md                 — per-copy README
│   ├── config/
│   │   ├── settings.json         — themes, characters, current selections
│   │   ├── blacklist.txt         — processes to kill in Game Mode
│   │   ├── whitelist.txt         — processes to never touch
│   │   ├── restartable.txt       — processes to kill and restart later
│   │   ├── services.txt          — Windows services to stop in Game Mode
│   │   ├── critical.txt          — processes that must never be killed
│   │   ├── lang/                 — 15 interface language files
│   │   └── terminals/            — PowerShell scripts for the "terminals"
│   │                               boot animation effect
│   └── logs/                     — runtime logs (ignored by git)
└── Optixscript10/            <- full OPTIX copy #2 (identical code)
    └── (same structure as above)
```

## Logging

Every run writes a timestamped log into the local `logs/` folder
(`last_run.log` plus a dated file per run). Logs are ignored by git and
are not part of the published code.

## Customizing

Everything lives in `config/settings.json`. Changes are picked up on the
next start.

**Add a color theme** — add an object to `color_palettes`:
```json
"my_theme": { "base_r": 0, "base_g": 0, "base_b": 0, "factor_r": 255, "factor_g": 255, "factor_b": 255 }
```
`base_*` is the starting color, `factor_*` is how far it travels at the
peak of the wave.

**Add a character skin** — add an array of same-length strings to
`game_styles.claude_crab.styles` or `game_styles.dinosaur.styles`, or
an object `{ "head", "body", "food", "color" }` to
`game_styles.snake.styles`. The new skin will appear in the Style menu.

## Publishing this repo to GitHub

The repository is already set up for GitHub — just follow these steps:

1. Create an empty repository on GitHub (no README, no LICENSE — use
   the files from this repo).
2. In the terminal inside this folder:
   ```
   git init
   git add .
   git commit -m "Initial release of OPTIX"
   git branch -M main
   git remote add origin https://github.com/YOUR_USERNAME/optixscript.git
   git push -u origin main
   ```
3. Open the repository page and enjoy.

Before publishing, consider deleting one of the two duplicate copies
(`Optixscript/` or `Optixscript10/`) — they are identical, and keeping
only one makes the repository much cleaner.

## License

This project is licensed under the [MIT License](LICENSE) — do whatever
you want with it, but please don't blame us if it eats your homework.