# OPTIX — Windows Performance & Game Optimization Suite

# 🤖 СДЕЛАНО С ПОМОЩЬЮ ИСКУССТВЕННОГО ИНТЕЛЛЕКТА 🤖

```
   ███╗   ███╗ █████╗ ██████╗ ███████╗
   ████╗ ████║██╔══██╗██╔══██╗██╔════╝
   ██╔████╔██║███████║██║  ██║█████╗
   ██║╚██╔╝██║██╔══██║██║  ██║██╔══╝
   ██║ ╚═╝ ██║██║  ██║██████╔╝███████╗
   ╚═╝     ╚═╝╚═╝  ╚═╝╚═════╝ ╚══════╝

    ██╗    ██╗██╗████████╗██╗  ██╗
    ██║    ██║██║╚══██╔══╝██║  ██║
    ██║ █╗ ██║██║   ██║   ███████║
    ██║███╗██║██║   ██║   ██╔══██║
    ╚███╔███╔╝██║   ██║   ██║  ██║
     ╚══╝╚══╝ ╚═╝   ╚═╝   ╚═╝  ╚═╝

       █████╗ ██╗
      ██╔══██╗██║
      ███████║██║
      ██╔══██║██║
      ██║  ██║██║
      ╚═╝  ╚═╝╚═╝
```

**⚠️ ЭТОТ ПРОЕКТ НА 99.9% ПОСТРОЕН С ПОМОЩЬЮ ИИ.**
**Автор — не программист, а человек, который руководил ИИ-ассистентами.**

**OPTIX** is a PowerShell-based toolkit for Windows that helps you clean up
junk files, manage running processes, stop background services for gaming,
and play a few small built-in mini-games — all from a single animated
terminal interface.

It is a fully portable project: no installer, no admin tools beyond the
one-time UAC prompt, and no external dependencies.

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
  and the Recycle Bin.
- **Process Manager** — interactive list of every running process with
  filters for critical, system, and Microsoft processes. Lets you add
  selected processes to a blacklist (kill on Game Mode entry), a
  whitelist (never touch), or a restartable list (kill and restart
  automatically).
- **Customization** — 12 color themes, 4 animated color effects
  (wave, pulse, flow, rainbow), custom RGB override, ASCII background
  animations for the games, and a choice of boot screens.
- **Mini-games** — Snake, Dinosaur, and a small "Claude-crab" shooter
  game, each with multiple skins.

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
Optixscript/
├── optimization_script.ps1   — main script
├── run_optix.bat             — launcher (handles admin rights + logging)
├── fix_encoding.ps1          — fixes Russian text in older terminals
├── README.md                 — this file
└── config/
    ├── settings.json         — themes, characters, current selections
    ├── blacklist.txt         — processes to kill in Game Mode
    ├── whitelist.txt         — processes to never touch
    ├── restartable.txt       — processes to kill and restart later
    ├── services.txt          — Windows services to stop in Game Mode
    ├── critical.txt          — processes that must never be killed
    └── terminals/            — PowerShell scripts for the "terminals"
                                boot animation effect
```

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

## License

This project is provided as-is, for personal use. Since 99.9% of it was
generated by AI, I am honestly not sure what the most accurate license
to attach would be — treat it as MIT-style: do whatever you want, but
please don't blame me if it eats your homework.
