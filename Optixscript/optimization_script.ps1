# =================================================================================================
# OPTIX - Скрипт оптимизации системы
# =================================================================================================

# --- КОДИРОВКА UTF-8 (фикс mojibake при запуске не через run_optix.bat) ---
try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
    # chcp 65001 = UTF-8 code page для старой console.exe
    & chcp.com 65001 > $null 2>&1
} catch {}

# --- ПРОВЕРКА И ПЕРЕЗАПУСК С ПРАВАМИ АДМИНИСТРАТОРА В WINDOWS TERMINAL ---
$isWinTerminal = $null -ne $env:WT_SESSION
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$wtAvailable = $null -ne (Get-Command wt.exe -ErrorAction SilentlyContinue)
$relaunchArgs = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
$wtRelaunchArgs = "-p `"Windows PowerShell`" -d `"$PSScriptRoot`" powershell.exe $relaunchArgs"

if (-not $isAdmin) {
    # БАГФИКС: раньше сюда попадали и уже-админские сессии (см. ветку ниже), из-за
    # чего UAC-запрос на повышение прав появлялся даже тогда, когда он не нужен.
    # Прав администратора ещё нет — поднимаем их через UAC.
    try {
        if ($wtAvailable) { Start-Process wt.exe $wtRelaunchArgs -Verb RunAs -ErrorAction Stop }
        else { Start-Process powershell.exe $relaunchArgs -Verb RunAs -ErrorAction Stop }
    } catch {
        Write-Host "`n   [!] Не удалось перезапустить скрипт с правами администратора." -ForegroundColor Red
        Write-Host "   Запустите файл вручную через 'Запуск от имени администратора'." -ForegroundColor Yellow
        Read-Host "`n   Нажмите Enter для выхода..."
    }
    Exit
}
elseif (-not $isWinTerminal -and $wtAvailable) {
    # Права администратора уже есть — просто переоткрываемся в Windows Terminal
    # без нового окна UAC (раньше здесь тоже вызывался -Verb RunAs).
    Start-Process wt.exe $wtRelaunchArgs
    Exit
}
# Если Windows Terminal не установлен, продолжаем работу в обычной консоли —
# раньше отсутствие wt.exe приводило к падению Start-Process и молчаливому закрытию окна.

# --- НАЧАЛЬНАЯ НАСТРОЙКА ОКНА ---
$host.UI.RawUI.BackgroundColor = "Black"
$host.UI.RawUI.ForegroundColor = "White"
$host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size(80, 28)
$host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(80, 28)
Clear-Host

# --- АНИМАЦИЯ ЗАГРУЗКИ ---
function Show-LoadingAnimation {
    param([string]$fixScriptPath, [string]$bootStyle, [int]$terminalsDuration = 3)

    # Если стиль выключен — сразу выходим
    if ($bootStyle -eq "off") {
        Clear-Host
        Write-Host "`n   $(T('loading.loading'))" -ForegroundColor Cyan
        Start-Sleep -Milliseconds 500
        return
    }

    [Console]::CursorVisible = $false

    $logo = @(
        "   _____ ____  _____   _    ____  _   _ ____  ",
        "  |_   _|  _ \| ____| / \  |  _ \| | | / ___| ",
        "    | | | |_) |  _|  / _ \ | |_) | | | \___ \ ",
        "    | | |  _ <| |___/ ___ \|  _ <| |_| |___) |",
        "    |_| |_| \_\____/_/   \_\_| \_\\___/|____/ "
    )
    $sub = "   Windows Performance & Game Optimization Suite"
    $steps = @(
        T("loading.initializing"),
        T("loading.checking_encoding"),
        T("loading.loading_config"),
        T("loading.preparing_ui"),
        T("loading.done")
    )

    # Запускаем fix_encoding.ps1 в фоновом режиме (только для full).
    # Файла может не быть — тогда просто пропускаем.
    $encodingJob = $null
    if ($bootStyle -eq "full" -and (Test-Path $fixScriptPath)) {
        $encodingJob = Start-Job -ScriptBlock {
            param($path)
            powershell.exe -NoProfile -ExecutionPolicy Bypass -File $path
        } -ArgumentList $fixScriptPath
    }

    $done = $false
    $stepIdx = 0
    $barTick = 0
    $maxTicks = 60  # ~3 секунды при 50мс
    $barWidth = 40
    $spinChars = @("|", "/", "-", "\")
    $spinIdx = 0

    while (-not $done) {
        $barFilled = [int][Math]::Min($barWidth, ($barTick / $maxTicks) * $barWidth)
        $barEmpty  = $barWidth - $barFilled
        $bar = "[" + ("#" * $barFilled) + ("-" * $barEmpty) + "]"

        $spin = $spinChars[$spinIdx % 4]
        $pct  = [Math]::Min(100, [int](($barTick / $maxTicks) * 100))
        $step = $steps[[Math]::Min($stepIdx, $steps.Length - 1)]

        [Console]::SetCursorPosition(0, 0)
        Clear-Host

        switch ($bootStyle) {
            "full" {
                foreach ($l in $logo) { Write-Host $l -ForegroundColor Cyan }
                Write-Host $sub -ForegroundColor DarkGray
                Write-Host ""
                Write-Host "   $step" -ForegroundColor Yellow
                Write-Host "   $spin Прогресс: $bar $pct%" -ForegroundColor White
                Write-Host ""
                $remaining = [int](($maxTicks - $barTick) * 0.05)
                Write-Host "   $(T('loading.loading')) ($remaining sec)" -ForegroundColor DarkCyan
            }
            "classic" {
                $sep = "   ========================================="
                Write-Host $sep -ForegroundColor Cyan
                Write-Host "   $spin Прогресс: $bar $pct%" -ForegroundColor White
                Write-Host $sep -ForegroundColor Cyan
                Write-Host ""
                Write-Host "   $step" -ForegroundColor Yellow
            }
            "minimal" {
                Write-Host "   Загрузка... $pct%  $step" -ForegroundColor Cyan
            }
            "terminals" {
                # УЛУЧШЕННЫЙ РЕЖИМ "ВИРУС": 8 летающих терминальных окошек 600x800
                # Скрипты эффектов лежат в config/terminals/*.ps1 (готовые файлы, не heredoc).
                # Длительность берётся из настройки terminals_duration (по умолчанию 3 сек).
                $scriptStartTime = Get-Date
                $terminalsDir = Join-Path $configPath "terminals"
                $scriptDuration = $terminalsDuration

                Add-Type @"
                using System;
                using System.Collections.Generic;
                using System.Runtime.InteropServices;
                public class WinAPI {
                    [DllImport("user32.dll")]
                    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);
                    [DllImport("user32.dll")]
                    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
                    [DllImport("user32.dll")]
                    public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
                    [DllImport("user32.dll")]
                    public static extern bool IsWindowVisible(IntPtr hWnd);
                    [DllImport("user32.dll")]
                    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
                    [DllImport("user32.dll")]
                    public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
                    [DllImport("user32.dll")]
                    public static extern bool IsWindow(IntPtr hWnd);
                    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
                    private const int SW_SHOW = 5;
                    private const uint WM_CLOSE = 0x0010;
                    public static bool IsWindowReady(IntPtr hWnd) {
                        if (hWnd == IntPtr.Zero) return false;
                        ShowWindow(hWnd, SW_SHOW);
                        return true;
                    }
                    // Собирает ВСЕ видимые окна верхнего уровня (не только "главные").
                    // Нужно потому, что Windows Terminal держит все вкладки/окна в
                    // одном процессе, и Process.MainWindowHandle возвращает только 1.
                    public static List<IntPtr> GetVisibleWindows() {
                        var list = new List<IntPtr>();
                        EnumWindows((h, l) => { if (IsWindowVisible(h)) list.Add(h); return true; }, IntPtr.Zero);
                        return list;
                    }
                    public static int GetProcessId(IntPtr hWnd) {
                        uint pid;
                        GetWindowThreadProcessId(hWnd, out pid);
                        return (int)pid;
                    }
                    public static bool IsAlive(IntPtr hWnd) {
                        return IsWindow(hWnd);
                    }
                    public static void SendClose(IntPtr hWnd) {
                        PostMessage(hWnd, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
                    }
                }
"@

                # Загружаем Windows.Forms для доступа к размеру экрана
                Add-Type -AssemblyName System.Windows.Forms | Out-Null

                # Список скриптов из файлов (не heredoc - он ломается на кавычках в эффектах)
                $scriptNames = @('matrix','crash','rickroll','encrypt','network','hexdump','bypass','skynet')
                $wtFound = (Get-Command wt.exe -ErrorAction SilentlyContinue).Source
                $jobs = @()

                Write-Host "`n   [!] Launching visual effects..." -ForegroundColor Yellow

                # Снимок всех видимых окон ДО запуска эффектов — чтобы потом «по дельте»
                # отличить ТОЛЬКО новые окна (свои чужие окна не трогаем).
                $existingWindows = @([WinAPI]::GetVisibleWindows())

                # Запускаем 8 окошек. Стараемся через wt.exe (Windows Terminal),
                # если его нет — через обычный powershell.exe.
                foreach ($name in $scriptNames) {
                    $scriptPath = Join-Path $terminalsDir "$name.ps1"
                    if (-not (Test-Path $scriptPath)) { continue }
                    if ($wtFound) {
                        $proc = Start-Process $wtFound -ArgumentList "powershell.exe","-NoProfile","-ExecutionPolicy","Bypass","-File",$scriptPath -PassThru -WindowStyle Normal
                    } else {
                        $proc = Start-Process powershell.exe -ArgumentList "-NoProfile","-ExecutionPolicy","Bypass","-File",$scriptPath -PassThru -WindowStyle Normal
                    }
                    if ($proc) { $jobs += $proc }
                    Start-Sleep -Milliseconds 100
                }

                # Получаем размеры экрана
                $screenW = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Width
                $screenH = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds.Height
                $winW = 600; $winH = 800
                $rand = [Random]::new()

                # Ждём инициализации окон
                Start-Sleep -Milliseconds 500

                # ВАЖНО: у wt.exe (лончера) окна нет — MainWindowHandle всегда 0,
                # а Windows Terminal держит все окна в одном процессе, поэтому
                # Get-Process/MainWindowHandle не подходит. Перечисляем ВСЕ видимые
                # окна верхнего уровня (Win32 EnumWindows) и берём только ТЕ, что
                # появились после нашего снимка и принадлежат терминалам.
                $hwnds = @()
                $prevCount = 0; $stablePolls = 0
                for ($attempt = 0; $attempt -lt 30; $attempt++) {
                    $hwnds = @()
                    foreach ($w in [WinAPI]::GetVisibleWindows()) {
                        if ($existingWindows -contains $w) { continue }
                        $procId = [WinAPI]::GetProcessId($w)
                        $procName = ''
                        try { $procName = (Get-Process -Id $procId -ErrorAction Stop).ProcessName } catch { $procName = '' }
                        if ($procName -in @('WindowsTerminal','OpenConsole','powershell','conhost')) { $hwnds += $w }
                    }
                    # Считаем найденными, когда все окна появились ИЛИ их количество
                    # перестало расти — чтобы не ждать лишнего и начать полёт раньше.
                    if ($hwnds.Count -eq $prevCount) { $stablePolls++ } else { $stablePolls = 0 }
                    $prevCount = $hwnds.Count
                    if ($hwnds.Count -ge $jobs.Count -or $stablePolls -ge 4) { break }
                    Start-Sleep -Milliseconds 150
                }
                $hwnds = @($hwnds | Select-Object -Unique)

                # Если это были обычные окна powershell.exe (wt.exe нет) — берём
                # их хэндлы напрямую из запущенных процессов.
                foreach ($p in $jobs) {
                    if ($p.MainWindowHandle -ne [IntPtr]::Zero) { $hwnds += $p.MainWindowHandle }
                }
                $hwnds = @($hwnds | Select-Object -Unique)

                # Расставляем окна случайно и инициализируем физику
                $positions = @()
                $velocities = @()
                foreach ($hwnd in $hwnds) {
                    [WinAPI]::IsWindowReady($hwnd) | Out-Null
                    Start-Sleep -Milliseconds 30
                    $x = $rand.Next(0, [Math]::Max(1, $screenW - $winW))
                    $y = $rand.Next(0, [Math]::Max(1, $screenH - $winH - 40))
                    [WinAPI]::MoveWindow($hwnd, $x, $y, $winW, $winH, $true) | Out-Null
                    $positions += @{ X = $x; Y = $y }
                    $velocities += @{
                        VX = if ($rand.Next(0,2) -eq 0) { -18 } else { 18 }
                        VY = if ($rand.Next(0,2) -eq 0) { -12 } else { 12 }
                    }
                    Start-Sleep -Milliseconds 20
                }

                # Движение с отскоком по всему экрану 8 секунд
                $endTime = (Get-Date).AddSeconds(8)
                while ((Get-Date) -lt $endTime) {
                    for ($i = 0; $i -lt $hwnds.Count; $i++) {
                        $hwnd = $hwnds[$i]

                        $positions[$i].X += $velocities[$i].VX
                        $positions[$i].Y += $velocities[$i].VY
                        if ($positions[$i].X -le 0) { $positions[$i].X = 0; $velocities[$i].VX = -$velocities[$i].VX }
                        elseif (($positions[$i].X + $winW) -ge $screenW) { $positions[$i].X = $screenW - $winW; $velocities[$i].VX = -$velocities[$i].VX }
                        if ($positions[$i].Y -le 0) { $positions[$i].Y = 0; $velocities[$i].VY = -$velocities[$i].VY }
                        elseif (($positions[$i].Y + $winH) -ge ($screenH - 40)) { $positions[$i].Y = $screenH - $winH - 40; $velocities[$i].VY = -$velocities[$i].VY }

                        [WinAPI]::MoveWindow($hwnd, $positions[$i].X, $positions[$i].Y, $winW, $winH, $true) | Out-Null
                    }
                    Start-Sleep -Milliseconds 30
                }

                # Закрываем наши окна эффектов. ВАЖНО: у Windows Terminal все окна могут жить
                # в ОДНОМ процессе (включая сам OPTIX), поэтому просто убить процесс нельзя —
                # отправляем каждому окошку WM_CLOSE, чтобы оно закрылось само.
                foreach ($hwnd in $hwnds) {
                    if ($hwnd -ne [IntPtr]::Zero) { [WinAPI]::SendClose($hwnd) }
                    Start-Sleep -Milliseconds 50
                }
                Start-Sleep -Milliseconds 300
                # Повторно закрываем те, что не закрылись с первого раза
                foreach ($hwnd in $hwnds) {
                    if (($hwnd -ne [IntPtr]::Zero) -and [WinAPI]::IsAlive($hwnd)) { [WinAPI]::SendClose($hwnd) }
                }

                # Закрываем все процессы принудительно
                foreach ($job in $jobs) {
                    if ($job -and -not $job.HasExited) { Stop-Process -Id $job.Id -Force -ErrorAction SilentlyContinue }
                }
                # Подстраховка: добиваем все wt/терминалы/powershell, запущенные после scriptStartTime
                Get-Process wt, WindowsTerminal, powershell -ErrorAction SilentlyContinue |
                    Where-Object {
                        $s = $null
                        try { $s = $_.StartTime } catch { $s = $null }
                        ($null -ne $s) -and ($s -gt $scriptStartTime) -and ($_.Id -ne $PID)
                    } |
                    Stop-Process -Force -ErrorAction SilentlyContinue
                Start-Sleep -Milliseconds 300
                Write-Host "`n   [OK] Effects finished. Launching OPTIX..." -ForegroundColor Green
                # БАГФИКС: раньше после terminals цикл while крутился дальше и снова спавнил
                # окна. Теперь сразу помечаем анимацию как завершённую и выходим.
                $done = $true
            }
        }

        $barTick++
        if ($barTick -ge ($maxTicks * 0.4)) { $stepIdx = 1 }
        if ($barTick -ge ($maxTicks * 0.55)) { $stepIdx = 2 }
        if ($barTick -ge ($maxTicks * 0.75)) { $stepIdx = 3 }
        if ($barTick -ge $maxTicks) { $stepIdx = 4; $done = $true }

        $spinIdx++
        Start-Sleep -Milliseconds 50
    }

    # Дожидаемся завершения fix_encoding (если запущен)
    if ($encodingJob) {
        $encodingJob | Wait-Job -Timeout 3 | Out-Null
        Remove-Job -Job $encodingJob -Force -ErrorAction SilentlyContinue
    }

    [Console]::CursorVisible = $true
    Clear-Host
}

# --- ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ И КОНСТАНТЫ (определяем ДО анимации, чтобы trap мог их использовать) ---
$ESC = [char]27
$scriptPath = $PSScriptRoot
$configPath = "$scriptPath\config"
$settingsFile = "$configPath\settings.json"
$blacklistFile = "$configPath\blacklist.txt"
$whitelistFile = "$configPath\whitelist.txt"
$restartableFile = "$configPath\restartable.txt"
$servicesFile = "$configPath\services.txt"
$sessionFile = "$configPath\session.json"
$gameJobName = "OptixGameModeJob"
$langDir = "$configPath\lang"

# --- СИСТЕМА ПЕРЕВОДОВ ---
# Глобальный хэш переводов. По умолчанию загружается английский,
# затем Load-Settings подменяет на язык пользователя из settings.json.
$global:lang = $null
$global:currentLang = "en"
$global:availableLangs = @()

function Get-DefaultLang {
    return @{
        "_meta" = @{ "name" = "English"; "native_name" = "English"; "code" = "en" }
        "menu" = @{ "game_mode" = "Game Mode"; "normal_mode" = "Normal Mode"; "settings" = "Settings"; "optix" = "OPTIX"; "exit" = "Exit" }
        "loading" = @{ "initializing" = "Initializing..."; "checking_encoding" = "Checking encoding..."; "loading_config" = "Loading configuration..."; "preparing_ui" = "Preparing interface..."; "done" = "Done!"; "loading" = "Loading..." }
        "settings" = @{ "main" = "Settings"; "customization" = "Interface Customization"; "cleanup" = "Junk Cleanup"; "cleanup_lists" = "Cleanup Lists (Processes)"; "mini_games" = "Mini-games"; "language" = "Language" }
        "customization" = @{ "main" = "Customization"; "color_theme" = "Color Theme"; "color_effects" = "Color Effects (wave/pulse/rainbow)"; "custom_rgb" = "Custom RGB Color"; "game_styles" = "Game Styles"; "ascii_animation" = "ASCII Animation"; "boot_screen" = "Boot Screen" }
        "colors" = @{ "select_theme" = "Select color scheme:"; "theme_saved" = "Theme 'THEME' saved!"; "theme_applied" = "Theme applied."; "themes" = @{ "purple" = "Purple"; "cyberpunk" = "Cyberpunk"; "forest" = "Forest"; "matrix" = "Matrix"; "sunset" = "Sunset"; "ocean" = "Ocean"; "fire" = "Fire"; "gold" = "Gold"; "synthwave" = "Synthwave"; "mono" = "Mono"; "blood" = "Blood"; "ice" = "Ice" } }
        "color_effects" = @{ "main" = "Color Effects"; "effect" = "Color Effect"; "speed" = "Effect Speed"; "custom_rgb" = "Custom RGB Color"; "reset_rgb" = "Reset RGB (use theme)"; "current_effect" = "Current effect"; "speed_range" = "Range 0.1..3.0, step 0.1"; "rgb_desc" = "Sets fixed color, effects disabled"; "preview" = "Preview:"; "channel_select" = "[Left/Right] channel  [Up/Down] change (step 5, Shift=20)"; "rgb_saved" = "RGB saved!"; "rgb_reset" = "RGB reset - using theme."; "speed_saved" = "Speed saved!"; "effects" = @{ "wave" = "Wave (sine wave vertically)"; "pulse" = "Pulse (breathing)"; "flow" = "Smooth flow"; "rainbow" = "Rainbow (HSL by time)" } }
        "styles" = @{ "main" = "Style Settings"; "claude_crab" = "Claude-crab Style"; "snake" = "Snake Style"; "dinosaur" = "Dinosaur Style"; "select_style" = "Select style for 'NAME':"; "style_saved" = "Style 'NAME' saved!" }
        "boot_screen" = @{ "main" = "Boot Screen"; "current_style" = "Current style"; "styles" = @{ "full" = "Full (logo + progress bar + stages)"; "classic" = "Classic (progress bar only)"; "minimal" = "Minimal (text only)"; "terminals" = "Terminals (virus effect)"; "off" = "Off (fast start)" }; "saved" = "Style 'NAME' saved!" }
        "animation" = @{ "main" = "ASCII Animation"; "select" = "Select ASCII animation (background for games):"; "saved" = "Animation 'NAME' saved!"; "effects" = @{ "off" = "Off"; "stars" = "Stars"; "wave" = "Wave"; "spiral" = "Spiral"; "matrix" = "Matrix"; "rain" = "Rain"; "pulse" = "Pulse" } }
        "games" = @{ "main" = "Mini-games"; "snake" = "Snake"; "dinosaur" = "Dinosaur"; "claude_crab" = "Claude-crab"; "score" = "Score"; "game_over" = "GAME OVER"; "your_score" = "Your score"; "press_any_key" = "Press any key to exit..." }
        "snake" = @{ "score" = "Score" }
        "dinosaur" = @{ "controls" = "Controls:"; "move" = "Left/Right or A/D: Move"; "fire" = "Space: Jump" }
        "cleanup" = @{ "main" = "Junk Cleanup"; "starting" = "Starting junk cleanup..."; "select_title" = "Select what to clean (Space - toggle, A - all, N - clear):"; "select_all" = "[A] Select all"; "select_none" = "[N] Clear selection"; "start_hint" = "[Enter] Start cleaning"; "cancel_hint" = "[Esc] Cancel"; "cancelled" = "Cleanup cancelled."; "nothing_selected" = "Nothing selected, nothing to clean."; "drives_title" = "Select drives to clean (Space - toggle, A - all, N - clear):"; "drive_skipped" = "path is on DRIVE;"; "drive_unselected" = "drive not selected"; "free_gb" = "free FREE GB"; "system_marker" = "System"; "summary_after" = "Memory after cleanup:"; "used" = "Used"; "free" = "Free"; "ram" = "RAM"; "user_temp" = "User TEMP"; "system_temp" = "System TEMP"; "prefetch" = "Prefetch"; "dns_cache" = "DNS Cache"; "recycle_bin" = "Recycle Bin"; "wu_cache" = "Windows Update Cache"; "windows_logs" = "Windows Logs"; "error_reports" = "Error Reports"; "recent" = "Recent Files"; "thumbnails" = "Thumbnail Cache"; "cleanmgr" = "Disk Cleanup (cleanmgr) - ALL drives - all categories"; "cleanmgr_start" = "Starting Disk Cleanup (cleanmgr)..."; "cleanmgr_skip" = "cleanmgr.exe not found, skipped."; "cleanmgr_categories" = "Enabled COUNT cleanmgr categories."; "cleanmgr_done" = "Disk Cleanup finished."; "cleanmgr_drive_skip" = "system drive not selected, skipped."; "skipped" = "path inaccessible, skipped."; "cleaned_files" = "files deleted"; "freed_mb" = "MB freed"; "cleared" = "cleared."; "total_deleted" = "Total deleted"; "total_freed" = "MB freed"; "press_enter" = "Press Enter to return..." }
        "process_manager" = @{ "title" = "Process Manager"; "loading" = "Loading and analyzing processes..."; "colors_legend" = "Colors: Red-Critical, DarkCyan-System, Blue-Microsoft, White-Other"; "controls" = "Controls: [Up/Down/PgUp/PgDn] Navigate | [Enter] Select | [P] Publisher"; "save_selected" = "[9] Save selected"; "exit" = "[Esc] Exit"; "critical_warning" = "WARNING"; "critical_msg" = "Process 'NAME' is critical for the system. Selecting this process for any list is blocked."; "press_enter" = "Press Enter to return..."; "save_menu" = @{ "add_to" = "Add SELECTED_COUNT selected processes to?"; "blacklist" = "Blacklist (kill)"; "whitelist" = "Whitelist (never touch)"; "restartable" = "Restartable (restore after)"; "success" = "Processes successfully added to FILENAME!"; "error_critical" = "ERROR: You are trying to add critical process 'NAME' to the kill list. This action is blocked to protect the system."; "press_enter" = "Press Enter to return..." } }
        "game_mode" = @{ "activating" = "Activating Game Mode..."; "stopping_services" = "Stopping target services..."; "service_stopped" = "Service 'NAME' stopped."; "saving_processes" = "Saving restartable processes..."; "process_found" = "Process 'NAME' found, path saved."; "nothing_to_kill" = "Nothing to terminate."; "killing_processes" = "Terminating all processes (except critical and whitelist)..."; "terminated" = "Terminated: COUNT processes."; "auto_tracking" = "Auto-tracking started."; "activated" = "Game Mode activated!"; "press_enter" = "Press Enter to return to menu..." }
        "normal_mode" = @{ "deactivating" = "Deactivating Game Mode and restoring..."; "tracking_stopped" = "Background tracking stopped."; "not_active" = "Game Mode was not active."; "restoring_processes" = "Restoring saved processes..."; "launching" = "Launching 'NAME'..."; "restoring_services" = "Restoring stopped services..."; "service_started" = "Service 'NAME' started."; "normal_restored" = "Normal mode restored."; "press_enter" = "Press Enter to return to menu..." }
        "optix" = @{ "not_found_title" = "File not found!"; "not_found_msg" = "File FILE is missing!"; "not_found_needed" = "It is required for stable operation."; "option_show" = "Show file in Explorer"; "option_create" = "Create FILE in this folder"; "option_back" = "Return to menu"; "explorer_opened" = "Explorer opened. Press Enter..."; "created" = "File created!"; "path" = "Path"; "press_enter" = "Press Enter..."; "launching" = "Launching FILE in new window. Return to menu..."; "dev_notice" = "Section 'OPTIX' is under development." }
        "common" = @{ "enter_to_return" = "Press Enter to return to menu..."; "esc_to_return" = "(Esc to return)"; "enter_save_esc_cancel" = "(Enter - save, Esc - cancel)"; "enter_confirm_esc_cancel" = "(Enter - confirm, Esc - cancel)"; "enter_next_esc_back" = "(Enter - next, Esc - back)"; "choose" = "Choose (1-4):"; "yes" = "Yes"; "no" = "No"; "ok" = "OK"; "error" = "ERROR"; "info" = "INFO"; "warning" = "WARNING" }
        "exit" = @{ "closing" = "Closing in 3 seconds..."; "thanks" = "Thank you for using OPTIX!"; "goodbye" = "Goodbye!" }
        "footer" = @{ "navigation" = "[v/^] or [arrows] - select   |   [Enter] - confirm   |   [Esc] - exit" }
        "language" = @{ "select" = "Select language:"; "saved" = "Language: NAME"; "back" = "(Esc to return)" }
    }
}

function Load-Language {
    param([string]$LangCode = "en")
    $defaultLang = Get-DefaultLang
    $global:currentLang = $LangCode
    $langFile = Join-Path $langDir "$LangCode.json"
    if (Test-Path $langFile) {
        try {
            # Явно читаем как UTF-8 — без этого Get-Content на PS 5.1 ломает
            # не-ASCII символы (русский, китайский, арабский и т.д.) в кракозябры.
            $raw = [System.IO.File]::ReadAllText($langFile, [System.Text.Encoding]::UTF8)
            $loaded = $raw | ConvertFrom-Json
            $global:lang = $loaded
            return
        } catch {
            # Файл языка повреждён — ниже сработает фолбэк на английский.
        }
    }
    # Фолбэк: дефолтный английский
    $global:lang = $defaultLang
    $global:currentLang = "en"
}

function Get-AvailableLanguages {
    if (-not (Test-Path $langDir)) { return @(@{ code = "en"; name = "English"; native_name = "English" }) }
    $langs = @()
    Get-ChildItem -Path $langDir -Filter "*.json" -File | ForEach-Object {
        try {
            $data = [System.IO.File]::ReadAllText($_.FullName, [System.Text.Encoding]::UTF8) | ConvertFrom-Json
            $langs += @{
                code = $_.BaseName
                name = if ($data._meta.name) { $data._meta.name } else { $_.BaseName }
                native_name = if ($data._meta.native_name) { $data._meta.native_name } else { $_.BaseName }
            }
        } catch {}
    }
    if ($langs.Count -eq 0) {
        $langs = @(@{ code = "en"; name = "English"; native_name = "English" })
    }
    return $langs
}

# Функция перевода: T("menu.game_mode") или T("colors.themes.purple")
function T {
    param([string]$Key)
    if ($null -eq $global:lang) {
        Load-Language -LangCode $global:currentLang
    }
    $parts = $Key.Split('.')
    $node = $global:lang
    foreach ($part in $parts) {
        if ($null -eq $node) { return $Key }
        if ($null -eq $node.PSObject -or -not $node.PSObject.Properties[$part]) { return $Key }
        $node = $node.$part
    }
    $result = [string]$node
    if ([string]::IsNullOrEmpty($result)) { return $Key }
    return $result
}

# Загружаем английский по умолчанию — потом Load-Settings подменит.
Load-Language -LangCode "en"

# --- ПАПКА ЛОГОВ (локальная папка "logs" рядом со скриптом; можно переопределить через OPTIX_LOG_PATH) ---
if ($env:OPTIX_LOG_PATH) {
    $logsPath = $env:OPTIX_LOG_PATH
} else {
    $logsPath = Join-Path $PSScriptRoot "logs"
}
if (-not (Test-Path $logsPath)) { New-Item -Path $logsPath -ItemType Directory -Force | Out-Null }
$logFile = "$logsPath\optix_$(Get-Date -Format 'yyyy-MM-dd_HH-mm-ss').log"
$lastRunLog = "$logsPath\last_run.log"

function Write-Log {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Action,
        [string]$Details = "",
        [string]$Type = "INFO"
    )
    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = "[$timestamp] [PID:$PID] [$Type] ACTION=$Action"
    if ($Details) { $line += " | $Details" }
    $line | Out-File -FilePath $logFile -Encoding utf8 -Append
    $line | Out-File -FilePath $lastRunLog -Encoding utf8 -Append
}

"[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] Script started." | Out-File -FilePath $logFile -Encoding utf8 -Append
"[$((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))] [PID:$PID] [INFO] ACTION=START | Version=1.0" | Out-File -FilePath $lastRunLog -Encoding utf8 -Append

# Глобальный обработчик ошибок — пишет в лог и в консоль.
trap {
    $errMsg = $_.Exception.Message
    $errStack = $_.ScriptStackTrace
    $errLine = $_.InvocationInfo.ScriptLineNumber
    Write-Log -Action "ERROR" -Details "Line=$errLine | Message=$errMsg | Stack=$errStack" -Type "ERROR"
    Write-Host "`n   [!] Ошибка: $errMsg" -ForegroundColor Red
    Write-Host "       Строка: $errLine" -ForegroundColor Yellow
    Write-Host "       Подробнее: $logFile" -ForegroundColor Yellow
    Read-Host "`n   Нажмите Enter для выхода..."
    Write-Log -Action "EXIT" -Details "Code=1 (Error)" -Type "EXIT"
    exit 1
}

# Читаем boot_style и terminals_duration ДО запуска анимации
$bootStyle = "full"
$terminalsDuration = 3
$earlySettingsFile = "$PSScriptRoot\config\settings.json"
if (Test-Path $earlySettingsFile) {
    try {
        $earlySettings = Get-Content $earlySettingsFile -Raw | ConvertFrom-Json
        if ($earlySettings.PSObject.Properties['boot_style']) {
            $bootStyle = $earlySettings.boot_style
        }
        if ($earlySettings.PSObject.Properties['terminals_duration']) {
            $terminalsDuration = [int]$earlySettings.terminals_duration
        }
    } catch {}
}

# Запускаем анимацию загрузки с выбранным стилем и длительностью terminals
Show-LoadingAnimation -fixScriptPath "$PSScriptRoot\fix_encoding.ps1" -bootStyle $bootStyle -terminalsDuration $terminalsDuration

# --- ФУНКЦИИ ---

function Normalize-ProcessName($name) {
    $trimmedName = $name.Trim()
    if ($trimmedName.EndsWith(".exe", [System.StringComparison]::OrdinalIgnoreCase)) {
        return $trimmedName.Substring(0, $trimmedName.Length - 4)
    }
    return $trimmedName
}

function Get-DefaultSettings {
    # Единый источник структуры настроек по умолчанию: используется и при
    # первом запуске (нет config/settings.json), и при восстановлении после
    # повреждённого файла. Проходит через тот же ConvertFrom-Json, что и обычная
    # загрузка, поэтому structure идентична обычной сессии (PSCustomObject,
    # а не Hashtable) — это важно для кода вида '...psobject.Properties.Name'.
    $json = @'
{
    "color_theme": "cyberpunk",
    "color_effect": "wave",
    "effect_speed": 0.4,
    "custom_r": -1,
    "custom_g": -1,
    "custom_b": -1,
    "boot_style": "full",
    "animation_style": "off",
    "terminals_duration": 3,
    "language": "en",
    "color_palettes": {
        "purple": {
            "base_r": 120,
            "base_g": 0,
            "base_b": 200,
            "factor_r": 135,
            "factor_g": 255,
            "factor_b": 55
        },
        "cyberpunk": {
            "base_r": 0,
            "base_g": 150,
            "base_b": 255,
            "factor_r": 255,
            "factor_g": 105,
            "factor_b": 0
        },
        "forest": {
            "base_r": 0,
            "base_g": 100,
            "base_b": 20,
            "factor_r": 150,
            "factor_g": 155,
            "factor_b": 100
        },
        "matrix": {
            "base_r": 0,
            "base_g": 40,
            "base_b": 0,
            "factor_r": 40,
            "factor_g": 215,
            "factor_b": 40
        },
        "sunset": {
            "base_r": 180,
            "base_g": 40,
            "base_b": 0,
            "factor_r": 75,
            "factor_g": 140,
            "factor_b": 120
        },
        "ocean": {
            "base_r": 0,
            "base_g": 60,
            "base_b": 120,
            "factor_r": 40,
            "factor_g": 150,
            "factor_b": 135
        },
        "fire": {
            "base_r": 150,
            "base_g": 10,
            "base_b": 0,
            "factor_r": 105,
            "factor_g": 150,
            "factor_b": 30
        },
        "gold": {
            "base_r": 90,
            "base_g": 70,
            "base_b": 0,
            "factor_r": 165,
            "factor_g": 150,
            "factor_b": 60
        },
        "synthwave": {
            "base_r": 120,
            "base_g": 0,
            "base_b": 120,
            "factor_r": 135,
            "factor_g": 80,
            "factor_b": 135
        },
        "mono": {
            "base_r": 60,
            "base_g": 60,
            "base_b": 60,
            "factor_r": 195,
            "factor_g": 195,
            "factor_b": 195
        },
        "blood": {
            "base_r": 80,
            "base_g": 0,
            "base_b": 0,
            "factor_r": 175,
            "factor_g": 40,
            "factor_b": 40
        },
        "ice": {
            "base_r": 30,
            "base_g": 80,
            "base_b": 140,
            "factor_r": 90,
            "factor_g": 150,
            "factor_b": 115
        }
    },
    "game_styles": {
        "claude_crab": {
            "current": "claude",
            "styles": {
                "claude": [
                    "▐▛███▛█   ",
                    "▝▜██████▀  ",
                    "  ▝▝ ▝▝"
                ],
                "gemini": [
                    "+++           ",
                    "         --=++++*        ",
                    "           =++"
                ],
                "gpt": [
                    " .-'''-. ",
                    "(  o o  )",
                    " '-...-' "
                ],
                "grok": [
                    " /\\_/\\ ",
                    "( o.o )",
                    " > ^ < "
                ],
                "llama": [
                    "  /\\__/\\  ",
                    " ( o  o ) ",
                    "  \\ -- /  "
                ],
                "ufo": [
                    " ______ ",
                    "(______)",
                    "   ||   "
                ]
            }
        },
        "dinosaur": {
            "current": "bunny",
            "styles": {
                "default": [
                    "   __",
                    " /o_)"
                ],
                "bunny": [
                    " ()() ",
                    " (o.o)"
                ],
                "frog": [
                    " (o.o) ",
                    "<(   )>"
                ],
                "cat": [
                    " /\\_/\\ ",
                    "( o.o )"
                ],
                "duck": [
                    "  __ ",
                    "<(o )"
                ],
                "rex": [
                    "    __  ",
                    " ___/o |",
                    "'-'   -'"
                ]
            }
        },
        "snake": {
            "current": "classic",
            "styles": {
                "classic": {
                    "head": "@",
                    "body": "#",
                    "food": "*",
                    "color": "Green"
                },
                "neon": {
                    "head": "◆",
                    "body": "◇",
                    "food": "✦",
                    "color": "Cyan"
                },
                "blocks": {
                    "head": "#",
                    "body": "▓",
                    "food": "♦",
                    "color": "Magenta"
                },
                "retro": {
                    "head": "0",
                    "body": "o",
                    "food": "+",
                    "color": "Yellow"
                }
            }
        }
    }
}
'@
    return $json | ConvertFrom-Json
}
function Load-Settings {
    if (-not (Test-Path $configPath)) { New-Item -Path $configPath -ItemType Directory | Out-Null }
    $needsSave = $false
    if (Test-Path $settingsFile) {
        try { $global:settings = [System.IO.File]::ReadAllText($settingsFile, [System.Text.Encoding]::UTF8) | ConvertFrom-Json }
        catch {
            # БАГФИКС: раньше при повреждённом JSON подставлялся куцый фолбэк без
            # game_styles, из-за чего мини-игры падали с ошибкой сразу после запуска.
            Write-Host "   [!] Файл настроек повреждён, восстанавливаю значения по умолчанию." -ForegroundColor Yellow
            $global:settings = Get-DefaultSettings
            $needsSave = $true
        }
        # БАГФИКС: при добавлении новых полей (color_effect, effect_speed, custom_*)
        # старый settings.json не содержит их — пробрасываем дефолты, чтобы код
        # не падал при обращении к отсутствующим свойствам.
        if (-not $global:settings.PSObject.Properties['color_effect']) { $global:settings | Add-Member -NotePropertyName 'color_effect' -NotePropertyValue 'wave' }
        if (-not $global:settings.PSObject.Properties['effect_speed']) { $global:settings | Add-Member -NotePropertyName 'effect_speed' -NotePropertyValue 0.4 }
        if (-not $global:settings.PSObject.Properties['custom_r'])    { $global:settings | Add-Member -NotePropertyName 'custom_r'    -NotePropertyValue -1 }
        if (-not $global:settings.PSObject.Properties['custom_g'])    { $global:settings | Add-Member -NotePropertyName 'custom_g'    -NotePropertyValue -1 }
        if (-not $global:settings.PSObject.Properties['custom_b'])    { $global:settings | Add-Member -NotePropertyName 'custom_b'    -NotePropertyValue -1 }
        if (-not $global:settings.PSObject.Properties['boot_style']) { $global:settings | Add-Member -NotePropertyName 'boot_style' -NotePropertyValue 'full' }
        if (-not $global:settings.PSObject.Properties['language']) { $global:settings | Add-Member -NotePropertyName 'language' -NotePropertyValue 'en' }
        if (-not $global:settings.PSObject.Properties['terminals_duration']) { $global:settings | Add-Member -NotePropertyName 'terminals_duration' -NotePropertyValue 3 }
        $needsSave = $true
    } else {
        # БАГФИКС: раньше при отсутствующем settings.json (первый запуск, чистая
        # копия проекта) $global:settings оставался $null и скрипт падал при первом
        # же обращении к настройкам (например, в Get-Color).
        $global:settings = Get-DefaultSettings
        $needsSave = $true
    }
    if ($needsSave) { Save-Settings }
    if (Test-Path $blacklistFile) { $global:blacklist = Get-Content $blacklistFile | Where-Object { $_ -notmatch '^\s*#' } | ForEach-Object { Normalize-ProcessName $_ } | Where-Object { $_ -ne '' } }
    if (Test-Path $whitelistFile) { $global:whitelist = Get-Content $whitelistFile | Where-Object { $_ -notmatch '^\s*#' } | ForEach-Object { Normalize-ProcessName $_ } | Where-Object { $_ -ne '' } }
    # БАГФИКС: раньше $global:criticalProcessNames нигде не инициализировался, поэтому
    # проверки "критичности" в Менеджере Процессов и фильтр в Игровом режиме
    # работали по $null — критические системные процессы не подсвечивались красным
    # и убивались как обычные (отсюда серый экран после убийства explorer/dwm).
    $criticalFile = "$configPath\critical.txt"
    if (Test-Path $criticalFile) {
        $global:criticalProcessNames = Get-Content $criticalFile | Where-Object { $_ -notmatch '^\s*#' } | ForEach-Object { Normalize-ProcessName $_ } | Where-Object { $_ -ne '' }
    } else {
        $global:criticalProcessNames = @()
    }
    if (Test-Path $servicesFile) { $global:services = Get-Content $servicesFile | Where-Object { $_ -notmatch '^\s*#' } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' } }
    if (Test-Path $restartableFile) { $global:restartable = Get-Content $restartableFile | Where-Object { $_ -notmatch '^\s*#' } | ForEach-Object { Normalize-ProcessName $_ } | Where-Object { $_ -ne '' } }
    # Загружаем язык пользователя
    $langCode = if ($global:settings.PSObject.Properties['language']) { $global:settings.language } else { "en" }
    Load-Language -LangCode $langCode
}

function Save-Settings {
    # БАГФИКС: -Depth 4 было недостаточно для вложенных массивов ASCII-арта
    # (game_styles.*.styles.*), они превращались в "System.Object[]" уже при первом
    # сохранении настроек (смена темы/стиля), и мини-игры переставали работать.
    $json = $global:settings | ConvertTo-Json -Depth 10
    # Пишем через [System.IO.File] в UTF-8 БЕЗ BOM — Out-File -Encoding utf8
    # в PS 5.1 добавляет BOM, что ломает совместимость с парсерами,
    # ожидающими чистый UTF-8, и приводит к появлению \uXXXX-escape'ов
    # в не-ASCII строках при последующих пересохранениях.
    $utf8NoBom = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllText($settingsFile, $json, $utf8NoBom)
}
function Clamp-Byte([int]$value) {
    if ($value -lt 0) { return 0 }
    if ($value -gt 255) { return 255 }
    return $value
}
function Get-Color($factor) {
    $themeName = $global:settings.color_theme; $palette = $global:settings.color_palettes.$themeName
    if ($null -eq $palette) { $fallbackThemeName = ($global:settings.color_palettes.psobject.properties.name)[0]; $palette = $global:settings.color_palettes.$fallbackThemeName; $global:settings.color_theme = $fallbackThemeName }
    # БАГФИКС: значения не ограничивались диапазоном 0-255, поэтому тема с
    # неудачно подобранными base/factor могла отправить в терминал битую
    # ANSI-последовательность (и "сломать" цвет до конца сессии).
    $r = Clamp-Byte ([int]($palette.base_r + $palette.factor_r * $factor))
    $g = Clamp-Byte ([int]($palette.base_g + $palette.factor_g * $factor))
    $b = Clamp-Byte ([int]($palette.base_b + $palette.factor_b * $factor))
    return "$r;$g;$b"
}
function Get-AnimatedColor($y, $time) {
    $effect = if ($global:settings.PSObject.Properties['color_effect']) { $global:settings.color_effect } else { "wave" }
    $speed  = if ($global:settings.PSObject.Properties['effect_speed']) { [double]$global:settings.effect_speed } else { 0.4 }
    $customR = if ($global:settings.PSObject.Properties['custom_r']) { [int]$global:settings.custom_r } else { -1 }
    $customG = if ($global:settings.PSObject.Properties['custom_g']) { [int]$global:settings.custom_g } else { -1 }
    $customB = if ($global:settings.PSObject.Properties['custom_b']) { [int]$global:settings.custom_b } else { -1 }

    # Кастомный RGB: если задан, используем только его, без эффектов.
    if ($customR -ge 0 -and $customG -ge 0 -and $customB -ge 0) {
        return "$(Clamp-Byte $customR);$(Clamp-Byte $customG);$(Clamp-Byte $customB)"
    }

    switch ($effect) {
        "rainbow" {
            # Радуга: HSL hue зависит от Y и времени, S=1, L=0.5
            $hue = (($y * 30) + ($time * 60 * $speed)) % 360
            if ($hue -lt 0) { $hue += 360 }
            $h = $hue / 60.0
            $i = [int][Math]::Floor($h)
            $f = $h - $i
            $q = 0.5 * (1 - $f)
            $t = 0.5 * (1 + (1 - $f) * -1 + $f)
            switch ($i % 6) {
                0 { $r = 1.0; $g = $t;  $b = 0.5 }
                1 { $r = $q;  $g = 1.0; $b = 0.5 }
                2 { $r = 0.5; $g = 1.0; $b = $t  }
                3 { $r = 0.5; $g = $q;  $b = 1.0 }
                4 { $r = $t;  $g = 0.5; $b = 1.0 }
                5 { $r = 1.0; $g = 0.5; $b = $q  }
            }
            return "$(Clamp-Byte ([int]($r * 255)));$(Clamp-Byte ([int]($g * 255)));$(Clamp-Byte ([int]($b * 255)))"
        }
        "pulse" {
            # Пульсация: factor пульсирует 0..1..0
            $factor = ([Math]::Sin($time * $speed * 2) + 1) / 2
            return Get-Color $factor
        }
        "flow" {
            # Плавное переливание: factor растёт по времени
            $factor = ((($time * $speed) % 1) + 1) % 1
            return Get-Color $factor
        }
        default {
            # wave: синусоида по Y и времени (по умолчанию)
            $wave = ($y * $speed) - $time
            $factor = ([Math]::Sin($wave) + 1) / 2
            return Get-Color $factor
        }
    }
}
function Show-Menu($selectedIndex, $menuItems) {
    [Console]::CursorVisible = $false; [Console]::SetCursorPosition(0, 0); $time = [Environment]::TickCount / 400.0

    # Рамка вокруг логотипа (ASCII, работает в любой кодировке/шрифте)
    $borderTop    = "  +==============================================================================+"
    $borderBottom = "  +==============================================================================+"
    $emptyLine    = "  +                                                                              +"

    # OPTIX - канонический логотип (не изменять!)
    $logoLines = @(
        '  +                                                                              +',
        '  +    /██████  /███████  /████████ /██████ /██   /██                            +',
        '  +   /██__  ██| ██__  ██|__  ██__/|_  ██_/| ██  / ██                            +',
        '  +  | ██  \ ██| ██  \ ██   | ██     | ██  |  ██/ ██/                            +',
        '  +  | ██  | ██| ███████/   | ██     | ██   \  ████/                             +',
        '  +  | ██  | ██| ██____/    | ██     | ██    >██  ██                             +',
        '  +  | ██  | ██| ██         | ██     | ██   /██/\  ██                            +',
        '  +  |  ██████/| ██         | ██    /██████| ██  \ ██                            +',
        '  +   \______/ |__/         |__/   |______/|__/  |__/                            +',
        '  +                                                                              +'
    )

    $y = 0
    $rgb = Get-AnimatedColor $y $time
    Write-Host "$ESC[38;2;${rgb}m$borderTop$ESC[0m"

    $rgb = Get-AnimatedColor ($y+1) $time
    Write-Host "$ESC[38;2;${rgb}m$emptyLine$ESC[0m"

    foreach ($line in $logoLines) {
        $y++
        $rgb = Get-AnimatedColor $y $time
        Write-Host "$ESC[38;2;${rgb}m$line$ESC[0m"
    }

    $y++
    $rgb = Get-AnimatedColor $y $time
    Write-Host "$ESC[38;2;${rgb}m$emptyLine$ESC[0m"

    # Подзаголовок
    $subtitle = "  +        Windows Performance & Game Optimization Suite                         +"
    $y++
    $rgb = Get-AnimatedColor $y $time
    Write-Host "$ESC[38;2;${rgb}m$subtitle$ESC[0m"

    $y++
    $rgb = Get-AnimatedColor $y $time
    Write-Host "$ESC[38;2;${rgb}m$borderBottom$ESC[0m"

    Write-Host ""
    $y += 2

    # Пункты меню в рамке
    $innerWidth = 73
    Write-Host "$ESC[38;2;128;128;128m  +==============================================================================+$ESC[0m"
    for ($i = 0; $i -lt $menuItems.Length; $i++) {
        $menuY = $y + $i
        $rgb = Get-AnimatedColor $menuY $time

        $name = $menuItems[$i]
        $padCount = $innerWidth - 1 - $name.Length
        if ($padCount -lt 0) { $padCount = 0 }
        $padding = ' ' * $padCount

        if ($i -eq $selectedIndex) {
            $itemText = "  + > $($name)$padding +"
            Write-Host "$ESC[38;2;255;255;255m$ESC[48;2;0;80;160m$itemText$ESC[0m"
        } else {
            $itemText = "  +   $($name)$padding +"
            Write-Host "$ESC[38;2;${rgb}m$itemText$ESC[0m"
        }
    }
    Write-Host "$ESC[38;2;128;128;128m  +==============================================================================+$ESC[0m"

    # Подсказки внизу
    $y += $menuItems.Length + 1
    $footerRgb = Get-AnimatedColor $y $time
    Write-Host ""
    Write-Host "$ESC[38;2;${footerRgb}m      $(T('footer.navigation'))$ESC[0m"
}

# --- ФУНКЦИИ РЕЖИМОВ ---

function Start-GameMode {
    Write-Log -Action "GAMEMODE_START" -Details "Entering Game Mode"
    Clear-Host; Write-Host "`n   [!] $(T('game_mode.activating'))" -ForegroundColor Yellow; Stop-GameMode -Silent
    $sessionData = @{ RestartableProcesses = @{}; StoppedServices = @() }
    Write-Host "`n   [.] $(T('game_mode.stopping_services'))"; foreach ($serviceName in $global:services) {
        $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
        if ($service -and $service.Status -eq 'Running') { Stop-Service -Name $serviceName -Force -ErrorAction SilentlyContinue; $sessionData.StoppedServices += $serviceName; Write-Host "   - $(T('game_mode.service_stopped') -replace 'NAME', $serviceName)" -ForegroundColor Cyan }
    }
    Write-Host "`n   [.] $(T('game_mode.saving_processes'))"; foreach ($procName in $global:restartable) {
        $process = Get-Process -Name $procName -ErrorAction SilentlyContinue
        if ($process) { $path = $process[0].Path; if ($path) { $sessionData.RestartableProcesses[$procName] = $path; Write-Host "   - $(T('game_mode.process_found') -replace 'NAME', $procName)" -ForegroundColor Cyan } }
    }
    $sessionData | ConvertTo-Json -Depth 3 | Out-File $sessionFile -Encoding utf8
    $allProcs = Get-Process | Where-Object { $_.Name -notin $global:whitelist -and $_.Name -notin $global:criticalProcessNames } | Select-Object -ExpandProperty Name -Unique
    if ($allProcs.Count -eq 0) { Write-Host "`n   [OK] $(T('game_mode.nothing_to_kill'))" -ForegroundColor Green }
    else {
        Write-Host "`n   [.] $(T('game_mode.killing_processes'))"
        $count = 0
        foreach ($procName in $allProcs) { taskkill /F /T /IM "$procName.exe" *> $null 2>$null; $count++ }
        Write-Host "   - $(T('game_mode.terminated') -replace 'COUNT', $count)" -ForegroundColor Green
        Write-Log -Action "GAMEMODE_KILL" -Details "Count=$count | Processes=$($allProcs -join ',')"
        $scriptBlock = { param($critical, $whitelist) while ($true) { $live = Get-Process | Where-Object { $_.Name -notin $critical -and $_.Name -notin $whitelist } | Select-Object -ExpandProperty Name -Unique; foreach ($n in $live) { taskkill /F /T /IM "$n.exe" *> $null 2>$null }; Start-Sleep -Seconds 3 } }
        Start-Job -ScriptBlock $scriptBlock -ArgumentList (,$global:criticalProcessNames), (,$global:whitelist) -Name $gameJobName | Out-Null
        Write-Host "   - $(T('game_mode.auto_tracking'))" -ForegroundColor Green
    }
    Write-Host "`n   [OK] $(T('game_mode.activated'))" -ForegroundColor Green
    Write-Log -Action "GAMEMODE_ACTIVE" -Details "ServicesStopped=$($sessionData.StoppedServices.Count) | RestartableProcs=$($sessionData.RestartableProcesses.Count)"
    Read-Host "`n   $(T('game_mode.press_enter'))"
    Write-Log -Action "GAMEMODE_EXIT" -Details "Returned to menu"
}

function Stop-GameMode {
    param ([switch]$Silent)
    Write-Log -Action "NORMAL_START" -Details "Exiting Game Mode"
    if (-not $Silent) { Clear-Host; Write-Host "`n   [!] $(T('normal_mode.deactivating'))" -ForegroundColor Yellow }
    $gameJob = Get-Job -Name $gameJobName -ErrorAction SilentlyContinue
    if ($gameJob) { Stop-Job -Job $gameJob; Remove-Job -Job $gameJob; if (-not $Silent) { Write-Host "`n   [OK] $(T('normal_mode.tracking_stopped'))" -ForegroundColor Green } }
    else { if (-not $Silent) { Write-Host "`n   [?] $(T('normal_mode.not_active'))" -ForegroundColor White } }
    if (Test-Path $sessionFile) {
        $sessionData = Get-Content $sessionFile -Raw | ConvertFrom-Json
        if ($sessionData.RestartableProcesses) {
            if (-not $Silent) { Write-Host "`n   [.] $(T('normal_mode.restoring_processes'))" }
            $restored = 0
            foreach ($entry in $sessionData.RestartableProcesses.psobject.Properties) {
                $procName = $entry.Name; $path = $entry.Value
                if (-not (Get-Process -Name $procName -ErrorAction SilentlyContinue)) { if (-not $Silent) { Write-Host "   - $(T('normal_mode.launching') -replace 'NAME', $procName)" -ForegroundColor Cyan }; Start-Process -FilePath $path -WindowStyle Minimized; $restored++ }
            }
            Write-Log -Action "RESTORE_PROCS" -Details "Restored=$restored"
        }
        if ($sessionData.StoppedServices) {
            if (-not $Silent) { Write-Host "`n   [.] $(T('normal_mode.restoring_services'))" }
            $svcRestored = 0
            foreach ($serviceName in $sessionData.StoppedServices) {
                $service = Get-Service -Name $serviceName -ErrorAction SilentlyContinue
                if ($service -and $service.Status -ne 'Running') { Start-Service -Name $serviceName -ErrorAction SilentlyContinue; if (-not $Silent) { Write-Host "   - $(T('normal_mode.service_started') -replace 'NAME', $serviceName)" -ForegroundColor Cyan }; $svcRestored++ }
            }
            Write-Log -Action "RESTORE_SERVICES" -Details "Services=$($sessionData.StoppedServices -join ',') | Restored=$svcRestored"
        }
        Remove-Item $sessionFile
    }
    Write-Log -Action "NORMAL_ACTIVE" -Details "Normal mode restored"
    if (-not $Silent) { Read-Host "`n   $(T('normal_mode.press_enter'))" }
}

function Show-OptixMenu {
    Clear-Host
    $runBat = Join-Path $PSScriptRoot "run_optix.bat"
    if (-not (Test-Path $runBat)) {
        # legacy
        Write-Host "`n" -NoNewline
        Write-Host "   [!] $(T('optix.not_found_title'))" -ForegroundColor Red
        Write-Host "   $(T('optix.not_found_needed'))" -ForegroundColor Yellow
        Write-Host "   1 - $(T('optix.option_show'))" -ForegroundColor Cyan
        Write-Host "   2 - $(T('optix.option_create') -replace 'FILE', 'run_optix.bat')" -ForegroundColor Cyan
        Write-Host "   3 - $(T('optix.option_back'))" -ForegroundColor Gray
        Write-Host ""

        while ($true) {
            $key = [Console]::ReadKey($true).Key
            if ($key -eq "D1" -or $key -eq "Oem1") {
                Start-Process explorer.exe -ArgumentList $PSScriptRoot
                Write-Host "   [OK] $(T('optix.explorer_opened'))" -ForegroundColor Green
                Read-Host
                return
            }
            if ($key -eq "D2" -or $key -eq "Oem2") {
                $defaultContent = @'
@echo off
chcp 65001 >nul 2>&1
title OPTIX
cd /d "%~dp0"

:: OPTIX - System Optimizer (Classic Runner)

echo.
echo  ====================================
echo   OPTIX - System Optimizer
echo  ====================================
echo.

:: Check PowerShell
where powershell >nul 2>&1
if errorlevel 1 (
    echo [ERROR] PowerShell not found!
    echo.
    pause
    exit /b 1
)

:: Logs in TEMP
set TEMP_LOG=%TEMP%\optix_last_run.log

:: Run OPTIX
echo [INFO] Starting OPTIX...
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0optimization_script.ps1" > "%TEMP_LOG%" 2>&1
set EXITCODE=%errorlevel%

echo.
if %EXITCODE% equ 0 (
    echo [OK] OPTIX finished successfully
) else (
    echo [ERROR] OPTIX crashed with code: %EXITCODE%
)

echo.
echo  ====================================
echo   What do you want to do?
echo  ====================================
echo   1 - Open log
echo   2 - Restart OPTIX
echo   3 - Clean old logs ^& exit
echo   4 - Just exit
echo  ====================================
echo.

choice /c 1234 /n /m "Choose (1-4): "

if errorlevel 4 goto :exit
if errorlevel 3 goto :clean
if errorlevel 2 goto :restart
if errorlevel 1 goto :openlog

:openlog
echo.
echo Opening log: %TEMP_LOG%
start "" notepad "%TEMP_LOG%"
goto :exit

:restart
echo.
echo Restarting in 2 seconds...
timeout /t 2 /nobreak >nul
call "%~dp0run_optix.bat"
goto :exit

:clean
echo.
echo Cleaning old logs from %TEMP%\OPTIX_logs ...
if exist "%TEMP%\OPTIX_logs" (
    del /q "%TEMP%\OPTIX_logs\*.*" >nul 2>&1
    echo [OK] Logs cleaned
) else (
    echo [INFO] No logs to clean
)
timeout /t 2 /nobreak >nul
goto :exit

:exit
echo.
echo Closing in 3 seconds...
timeout /t 3 >nul
exit /b %EXITCODE%
'@
                $defaultContent | Out-File -FilePath $runBat -Encoding utf8
                Write-Host "`n   [OK] $(T('optix.created'))" -ForegroundColor Green
                Write-Host "   $(T('optix.path')): $runBat" -ForegroundColor Gray
                Write-Host "   $(T('optix.press_enter'))" -ForegroundColor Gray
                Read-Host
                return
            }
            if ($key -eq "D3" -or $key -eq "Escape") {
                return
            }
        }
        return
    }

    $wtExe = (Get-Command wt.exe -ErrorAction SilentlyContinue).Source
    if ($wtExe) {
        $wtArgs = "-p `"Windows PowerShell`" -d `"$PSScriptRoot`" cmd.exe /c `"$runBat`""
        Start-Process $wtExe -ArgumentList $wtArgs | Out-Null
    } else {
        Start-Process cmd.exe -ArgumentList "/c", "`"$runBat`"" | Out-Null
    }
    Write-Host "`n   [OK] $(T('optix.launching') -replace 'FILE', 'run_optix.bat')" -ForegroundColor Green
    Start-Sleep -Milliseconds 800
    # БАГФИКС: раньше новое окно OPTIX просто открывалось поверх текущего, и оставались
    # две копии. Теперь закрываем текущий экземпляр — это настоящий RESTART.
    Stop-GameMode -Silent
    Clear-Host
    exit
}

# --- МЕНЮ И ИГРЫ ---

function Show-ProcessManager {
    Clear-Host
    Write-Host "  $(T('process_manager.loading'))"

    $processDetails = Get-Process | Where-Object { $_.Id -ne 0 } | Group-Object -Property ProcessName | ForEach-Object {
        $isPurelySystem = $true
        $company = ($_.Group | Select-Object -ExpandProperty Company -ErrorAction SilentlyContinue | Where-Object { $_ -ne $null } | Select-Object -First 1)
        foreach ($instance in $_.Group) {
            if ($instance.SessionId -ne 0) { $isPurelySystem = $false }
        }
        [PSCustomObject]@{
            Name        = $_.Name
            IsCritical  = $global:criticalProcessNames -contains $_.Name
            IsSystem    = $isPurelySystem
            IsMicrosoft = $company -like "*Microsoft*"
            Company     = $company
        }
    } | Sort-Object Name

    $selected = [System.Collections.Generic.HashSet[string]]::new()
    $currentIndex = 0
    $topIndex = 0
    $showPublisher = $false
    $criticalColor = "Red"; $systemColor = "DarkCyan"; $microsoftColor = "Blue"; $userColor = "White"

    while ($true) {
        $consoleWidth = [Console]::WindowWidth
        $headerHeight = 5
        $listHeight = [Console]::WindowHeight - $headerHeight - 1

        [Console]::SetCursorPosition(0, 0); [Console]::CursorVisible = $false

        $topBorder = "+" + ("-" * ($consoleWidth - 2)) + "+"
        $bottomBorder = "+" + ("-" * ($consoleWidth - 2)) + "+"

        $colorsLabel = T("process_manager.colors_legend")
        $controlsLabel = T("process_manager.controls")
        $saveSelLabel = T("process_manager.save_selected")
        $exitLabel = T("process_manager.exit")
        $colorLine = ("+ " + $colorsLabel).PadRight($consoleWidth - 1) + "+"
        $controlsLine1 = ("+ " + $controlsLabel).PadRight($consoleWidth - 1) + "+"
        $controlsLine2 = ("+             " + $saveSelLabel + " | " + $exitLabel).PadRight($consoleWidth - 1) + "+"

        Write-Host $topBorder -ForegroundColor Gray
        Write-Host $colorLine -ForegroundColor Gray
        Write-Host $controlsLine1 -ForegroundColor Gray
        Write-Host $controlsLine2 -ForegroundColor Gray
        Write-Host $bottomBorder -ForegroundColor Gray

        if ($currentIndex -lt $topIndex) { $topIndex = $currentIndex }
        if ($currentIndex -ge $topIndex + $listHeight) { $topIndex = $currentIndex - $listHeight + 1 }

        for ($i = $topIndex; $i -lt ($topIndex + $listHeight); $i++) {
            $lineY = $headerHeight + $i - $topIndex
            [Console]::SetCursorPosition(0, $lineY)
            Write-Host (" " * $consoleWidth) -NoNewline

            if ($i -ge $processDetails.Length) { continue }

            $proc = $processDetails[$i]
            $procName = $proc.Name

            if ($proc.IsCritical) { $color = $criticalColor }
            elseif ($proc.IsMicrosoft) { $color = $microsoftColor }
            elseif ($proc.IsSystem) { $color = $systemColor }
            else { $color = $userColor }

            $isSelected = $selected.Contains($procName)
            $prefix = if ($isSelected) { "[x]" } else { "[ ]" }

            $baseLine = " $prefix $procName"
            if ($showPublisher -and $proc.Company) {
                $baseLine += " - $($proc.Company)"
            }

            $maxDisplayLength = $consoleWidth - 1
            $displayName = if ($baseLine.Length -gt $maxDisplayLength) { $baseLine.Substring(0, $maxDisplayLength - 3) + "..." } else { $baseLine }

            [Console]::SetCursorPosition(0, $lineY)
            if ($i -eq $currentIndex) {
                Write-Host $displayName.PadRight($consoleWidth) -BackgroundColor White -ForegroundColor Black
            } else {
                Write-Host $displayName.PadRight($consoleWidth) -ForegroundColor $color
            }
        }

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { if ($currentIndex -gt 0) { $currentIndex-- } }
            "DownArrow" { if ($currentIndex -lt $processDetails.Length - 1) { $currentIndex++ } }
            "PageUp"    { $currentIndex = [Math]::Max(0, $currentIndex - $listHeight) }
            "PageDown"  { $currentIndex = [Math]::Min($processDetails.Length - 1, $currentIndex + $listHeight) }
            "P"         { $showPublisher = -not $showPublisher }
            "Enter"     {
                $proc = $processDetails[$currentIndex]
                if ($proc.IsCritical) {
                    Clear-Host
                    Write-Host "`n`n`n"
                    Write-Host "==================== $(T('process_manager.critical_warning')) ====================" -ForegroundColor Red
                    Write-Host "  $(T('process_manager.critical_msg') -replace 'NAME', $proc.Name)" -ForegroundColor Yellow
                    Write-Host "========================================================" -ForegroundColor Red
                    Read-Host "`n  $(T('process_manager.press_enter'))"
                    continue
                }

                if ($selected.Contains($proc.Name)) { $selected.Remove($proc.Name) }
                else { $selected.Add($proc.Name) }
            }
            "D9"        { if ($selected.Count -gt 0) { Show-SaveSubMenu -SelectedProcesses $selected.ToArray(); return } }
            "Escape"    { return }
        }
    }
}

function Show-SaveSubMenu {
    param($SelectedProcesses)
    $saveOptions = @()
    $saveOptions += T("process_manager.save_menu.blacklist")
    $saveOptions += T("process_manager.save_menu.whitelist")
    $saveOptions += T("process_manager.save_menu.restartable")
    $files = @($blacklistFile, $whitelistFile, $restartableFile)
    $selectedIndex = 0
    while ($true) {
        Clear-Host
        Write-Host "$(T('process_manager.save_menu.add_to') -replace 'SELECTED_COUNT', ($SelectedProcesses).Length)" -ForegroundColor Yellow
        for ($i = 0; $i -lt $saveOptions.Length; $i++) {
            $line = "  " + $(if ($i -eq $selectedIndex) { "> $($saveOptions[$i])" } else { "  $($saveOptions[$i])" })
            Write-Host $line
        }
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { $selectedIndex = ($selectedIndex - 1 + $saveOptions.Length) % $saveOptions.Length }
            "DownArrow" { $selectedIndex = ($selectedIndex + 1) % $saveOptions.Length }
            "Enter"     {
                $targetFile = $files[$selectedIndex]
                if ($targetFile -ne $whitelistFile) {
                    foreach ($proc in $SelectedProcesses) {
                        if ($global:criticalProcessNames -contains $proc) {
                            Clear-Host
                            Write-Host "`n$(T('process_manager.save_menu.error_critical') -replace 'NAME', $proc)" -ForegroundColor Red
                            Read-Host "`n$(T('process_manager.save_menu.press_enter'))"
                            return
                        }
                    }
                }
                $existing = if (Test-Path $targetFile) { Get-Content $targetFile } else { @() }
                $combined = ($existing + $SelectedProcesses) | Select-Object -Unique
                $combined | Out-File $targetFile -Encoding utf8
                Write-Host "`n$(T('process_manager.save_menu.success') -replace 'FILENAME', (Split-Path $targetFile -Leaf))" -ForegroundColor Green
                Start-Sleep -Seconds 2; return
            }
            "Escape"    { return }
        }
    }
}

function Show-ColorThemeMenu {
    $themeNames = $global:settings.color_palettes.psobject.properties.name
    $currentThemeIndex = [array]::IndexOf($themeNames, $global:settings.color_theme)
    if ($currentThemeIndex -lt 0) { $currentThemeIndex = 0 }
    $white = "$ESC[38;2;255;255;255m"; $cyan = "$ESC[38;2;0;255;255m"; $gray = "$ESC[38;2;128;128;128m"; $reset = "$ESC[0m"
    while ($true) {
        Clear-Host; Write-Host "`n   $(T('colors.select_theme'))`n" -ForegroundColor White
        for ($i = 0; $i -lt $themeNames.Length; $i++) {
            $name = $themeNames[$i]
            $displayName = T("colors.themes.$name")
            if ($displayName -eq "colors.themes.$name") { $displayName = $name }
            if ($i -eq $currentThemeIndex) { Write-Host "   > ${cyan}$($displayName.ToUpper())${white} <$reset" } else { Write-Host "     ${gray}$displayName$reset" }
        }
        Write-Host "`n`n   (Use arrows to select, Enter to confirm, Esc to exit)" -ForegroundColor Gray
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { $currentThemeIndex = ($currentThemeIndex - 1 + $themeNames.Length) % $themeNames.Length }
            "DownArrow" { $currentThemeIndex = ($currentThemeIndex + 1) % $themeNames.Length }
            "Enter"     { $global:settings.color_theme = $themeNames[$currentThemeIndex]; Save-Settings; $tn = $themeNames[$currentThemeIndex]; $tnDisplay = T("colors.themes.$tn"); if ($tnDisplay -eq "colors.themes.$tn") { $tnDisplay = $tn }; Write-Host "`n`n   $(T('colors.theme_saved') -replace 'THEME', $tnDisplay)" -ForegroundColor Green; Write-Log -Action "THEME_SET" -Details "Theme=$($themeNames[$currentThemeIndex])"; Start-Sleep -Seconds 1; return }
            "Escape"    { return }
        }
    }
}

function Get-FreeFoodSpot($snakeList, $w, $h, $rnd) {
    # БАГФИКС: раньше еда могла появиться прямо на теле змейки; теперь позиция
    # ищется среди клеток, действительно свободных от змейки.
    do {
        $x = $rnd.Next(1, $w); $y = $rnd.Next(1, $h)
        $onSnake = $false
        foreach ($seg in $snakeList) { if ($seg.X -eq $x -and $seg.Y -eq $y) { $onSnake = $true; break } }
    } while ($onSnake)
    return [pscustomobject]@{X = $x; Y = $y}
}

# Фоновая ASCII-анимация (рисуется в правом нижнем углу во время игры)
# Параметры $fieldRight/$fieldBottom — правая и нижняя границы игрового поля
# (колонка/строка, занятые рамкой или содержимым). Фон рисуется только если его
# зона целиком находится ПРАВЕЕ и НИЖЕ этих границ, т.е. вне игрового поля.
$global:bgAnimOffset = 0
function Show-GameBackground($fieldRight = -1, $fieldBottom = -1) {
    $anim = $global:settings.animation_style
    if (-not $anim -or $anim -eq "off") { return }
    $global:bgAnimOffset = ($global:bgAnimOffset + 1) % 360
    $t = $global:bgAnimOffset
    $frame = switch ($anim) {
        "stars" {
            $row1 = ""
            $row2 = ""
            $row3 = ""
            for ($i = 0; $i -lt 16; $i++) {
                $phase = ($i * 0.7) + ($t * 0.15)
                $top   = if ([Math]::Sin($phase) -gt 0.3) { "*" } else { " " }
                $mid   = if ([Math]::Cos($phase) -gt 0.3) { "." } else { " " }
                $low   = if ([Math]::Sin($phase + 1.5) -gt 0.3) { "+" } else { " " }
                $row1 += $top + " "
                $row2 += " " + $mid
                $row3 += $low + " "
            }
            @($row1, $row2, $row3)
        }
        "wave" {
            $row1 = ""
            $row2 = ""
            $row3 = ""
            for ($i = 0; $i -lt 16; $i++) {
                $a = [Math]::Sin(($i * 0.4) + ($t * 0.2))
                $b = [Math]::Sin(($i * 0.4) + ($t * 0.2) + 1.0)
                $c = [Math]::Sin(($i * 0.4) + ($t * 0.2) + 2.0)
                $row1 += if ($a -gt 0.3) { "~" } else { " " }
                $row2 += if ($b -gt 0.3) { "~" } else { " " }
                $row3 += if ($c -gt 0.3) { "~" } else { " " }
                $row1 += " "
                $row2 += " "
                $row3 += " "
            }
            @($row1, $row2, $row3)
        }
        "spiral" {
            $phase = $t % 8
            $base = @(
                @("   .   ", "  . .  ", " .   . ", ".     .", " .   . ", "  . .  ", "   .   ", "  . .  "),
                @("  ...  ", " .   . ", ".     .", ".  *  .", ".     .", " .   . ", "  ...  ", " .   . "),
                @(" ..... ", ".     .", ". *** .", ". * * .", ". *** .", ".     .", " ..... ", ".     ."),
                @("       ", "  ***  ", " *   * ", "*  *  *", " *   * ", "  ***  ", "       ", " *   * ")
            )
            $pick = $base[$phase % 4]
            @($pick[0], $pick[1], $pick[2])
        }
        "matrix" {
            $row1 = ""
            $row2 = ""
            $row3 = ""
            for ($i = 0; $i -lt 16; $i++) {
                $bit1 = if ([Math]::Sin($i + ($t * 0.1)) -gt 0) { "1" } else { "0" }
                $bit2 = if ([Math]::Sin($i + ($t * 0.1) + 1) -gt 0) { "1" } else { "0" }
                $bit3 = if ([Math]::Sin($i + ($t * 0.1) + 2) -gt 0) { "1" } else { "0" }
                $row1 += $bit1 + " "
                $row2 += $bit2 + " "
                $row3 += $bit3 + " "
            }
            @($row1, $row2, $row3)
        }
        "rain" {
            $phase = $t % 6
            $col = @("|", "|", "|", "/", "/", "/")
            $rows = @("", "", "", "", "", "", "", "")
            for ($i = 0; $i -lt 8; $i++) {
                $ch = $col[($phase + $i) % 6]
                for ($r = 0; $r -lt 8; $r++) {
                    if ($r -eq (($phase + $i) % 8)) { $rows[$r] += "$ch  " }
                    else { $rows[$r] += "   " }
                }
            }
            @($rows[0] + $rows[1] + $rows[2], $rows[3] + $rows[4] + $rows[5], $rows[6] + $rows[7])
        }
        "pulse" {
            $phase = $t % 6
            $row1 = ""
            $row2 = ""
            $row3 = ""
            $size = switch ($phase) {
                0 { "( o )" }
                1 { "< o >" }
                2 { "(o o)" }
                3 { "{o_o}" }
                4 { "(O_O)" }
                5 { "< o >" }
            }
            $row1 = "   " + $size + "       " + $size
            $row2 = " " + $size + "   " + $size + "   " + $size
            $row3 = "   " + $size + "       " + $size
            @($row1, $row2, $row3)
        }
        default { @() }
    }
    # БАГФИКС: раньше фон не стирал свой предыдущий кадр — на каждом тике в углу
    # копился "мусор" из символов прошлых кадров, а кадр рисовался прямо поверх
    # рамки игрового поля, счёта и персонажа. Теперь у фона фиксированная область
    # (ширина 20, высота 4) в правом нижнем углу, которая перед каждым кадром
    # целиком затирается пробелами, а сам кадр рисуется только внутри неё. И главное:
    # фон рисуется только ПО ВНЕ поля, у которого есть свои границы ($fieldRight/
    # $fieldBottom), поэтому ни рамка, ни счёт, ни игрок больше не затираются.
    $bgWidth = 24
    $bgHeight = 4
    $cw = [Console]::WindowWidth
    $ch = [Console]::WindowHeight
    # Если окно слишком маленькое — фон не рисуем.
    if ($cw -lt ($bgWidth + 2) -or $ch -lt ($bgHeight + 2)) { return }
    # Фон в правом нижнем углу консоли. Рисуем ТОЛЬКО если зона фона целиком
    # НИЖЕ игрового поля по вертикали (по горизонтали — справа от поля).
    # Это гарантирует, что анимация не затирает игровое содержимое.
    $startX = $cw - $bgWidth - 2
    $startY = $ch - $bgHeight - 2
    # Проверяем только по Y: startY должен быть строго ниже последней строки поля
    if ($startY -le $fieldBottom) { return }
    $savedX = [Console]::CursorLeft; $savedY = [Console]::CursorTop
    [Console]::CursorVisible = $false
    # Стирание предыдущего кадра
    for ($i = 0; $i -lt $bgHeight; $i++) {
        [Console]::SetCursorPosition($startX, $startY + $i)
        Write-Host (" " * $bgWidth) -NoNewline
    }
    # Рисование нового кадра
    for ($i = 0; $i -lt $frame.Length -and $i -lt $bgHeight - 1; $i++) {
        $y = $startY + 1 + $i
        if ($y -ge $ch - 1) { break }
        [Console]::SetCursorPosition($startX, $y)
        $line = [string]$frame[$i]
        $line = $line.PadRight($bgWidth).Substring(0, $bgWidth)
        Write-Host $line -ForegroundColor DarkCyan -NoNewline
    }
    [Console]::SetCursorPosition($savedX, $savedY)
}

function Start-SnakeGame {
    Write-Log -Action "GAME_START" -Details "Game=Snake | Style=$($global:settings.game_styles.snake.current)"
    Clear-Host; [Console]::CursorVisible = $false
    # БАГФИКС: раньше фоновая анимация рисовалась поверх рамки игрового поля и
    # счёта, оставляя следы от прошлых кадров. Теперь фон рисуется только в своей
    # отдельной зоне справа внизу и игровое поле не затрагивает.
    $width = 40; $height = 20; $score = 0

    $snakeStyle = $global:settings.game_styles.snake.styles.($global:settings.game_styles.snake.current)
    if ($null -eq $snakeStyle) { $snakeStyle = [pscustomobject]@{ head = "@"; body = "#"; food = "*"; color = "Green" } }
    $headChar = $snakeStyle.head; $bodyChar = $snakeStyle.body; $foodChar = $snakeStyle.food; $snakeColor = $snakeStyle.color

    # БАГФИКС: рамка "-...¬ / L...-" заменена на нормальную псевдографику (+++++).
    [Console]::SetCursorPosition(0, 0); Write-Host ("+" + ("-" * $width) + "+")
    for ($y = 1; $y -le $height; $y++) { [Console]::SetCursorPosition(0, $y); Write-Host "+"; [Console]::SetCursorPosition($width + 1, $y); Write-Host "+" }
    [Console]::SetCursorPosition(0, $height + 1); Write-Host ("+" + ("-" * $width) + "+")
    [Console]::SetCursorPosition($width + 5, 1); Write-Host "$(T('games.score')): $score"
    $snake = [System.Collections.Generic.List[object]]::new(); $snake.Add([pscustomobject]@{X=10; Y=10}); $snake.Add([pscustomobject]@{X=9; Y=10}); $snake.Add([pscustomobject]@{X=8; Y=10})
    $direction = [pscustomobject]@{X=1; Y=0}
    $random = New-Object Random
    $food = Get-FreeFoodSpot $snake $width $height $random
    [Console]::SetCursorPosition($food.X, $food.Y); Write-Host $foodChar -ForegroundColor Yellow
    while ($true) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true).Key
            if (($key -eq 'UpArrow' -or $key -eq 'W') -and $direction.Y -eq 0) { $direction = [pscustomobject]@{X=0; Y=-1} }
            if (($key -eq 'DownArrow' -or $key -eq 'S') -and $direction.Y -eq 0) { $direction = [pscustomobject]@{X=0; Y=1} }
            if (($key -eq 'LeftArrow' -or $key -eq 'A') -and $direction.X -eq 0) { $direction = [pscustomobject]@{X=-1; Y=0} }
            if (($key -eq 'RightArrow' -or $key -eq 'D') -and $direction.X -eq 0) { $direction = [pscustomobject]@{X=1; Y=0} }
            if ($key -eq 'Escape') { break }
        }
        $head = $snake[0]; $newHead = [pscustomobject]@{X = $head.X + $direction.X; Y = $head.Y + $direction.Y}
        if ($newHead.X -le 0 -or $newHead.X -ge ($width + 1) -or $newHead.Y -le 0 -or $newHead.Y -ge ($height + 1)) { break }

        $willEat = ($newHead.X -eq $food.X -and $newHead.Y -eq $food.Y)
        # БАГФИКС: раньше столкновение с собой проверялось по всему телу, включая
        # хвост, который освобождает свою клетку в этот же ход — из-за этого змейка
        # иногда "врезалась" в абсолютно свободную клетку и игра обрывалась зря.
        $bodyToCheck = if ($willEat) { $snake } else { $snake.GetRange(0, $snake.Count - 1) }
        $selfHit = $false
        foreach ($segment in $bodyToCheck) { if ($segment.X -eq $newHead.X -and $segment.Y -eq $newHead.Y) { $selfHit = $true; break } }
        if ($selfHit) { break }

        $snake.Insert(0, $newHead)
        [Console]::SetCursorPosition($newHead.X, $newHead.Y); Write-Host $headChar -ForegroundColor $snakeColor
        if ($snake.Count -gt 1) { $prevHead = $snake[1]; [Console]::SetCursorPosition($prevHead.X, $prevHead.Y); Write-Host $bodyChar -ForegroundColor $snakeColor }

        if ($willEat) {
            $score++; [Console]::SetCursorPosition($width + 5, 1); Write-Host "$(T('games.score')): $score"
            $food = Get-FreeFoodSpot $snake $width $height $random
            [Console]::SetCursorPosition($food.X, $food.Y); Write-Host $foodChar -ForegroundColor Yellow
        } else {
            $tail = $snake[$snake.Count - 1]; $snake.RemoveAt($snake.Count - 1); [Console]::SetCursorPosition($tail.X, $tail.Y); Write-Host " "
        }
        Show-GameBackground ($width + 1) ($height + 1)
        Start-Sleep -Milliseconds 150
    }
    Clear-Host
    $gameOverArt = @(
        '     _______  _______  __   __  _______    _______  __   __  _______  ______   ',
        '    |       ||   _   ||  |_|  ||       |  |       ||  | |  ||       ||    _ |  ',
        '    |    ___||  |_|  ||       ||    ___|  |   _   ||  |_|  ||    ___||   | ||  ',
        '    |   | __ |       ||       ||   |___   |  | |  ||       ||   |___ |   |_||_ ',
        '    |   ||  ||       ||       ||    ___|  |  |_|  ||       ||    ___||    __  |',
        '    |   |_| ||   _   || ||_|| ||   |___   |       | |     | |   |___ |   |  | |',
        '    |_______||__| |__||_|   |_||_______|  |_______|  |___|  |_______||___|  |_|'
    )
    $indent = ' ' * 5
    foreach ($line in $gameOverArt) { Write-Host "$indent$line" -ForegroundColor Red }
    Write-Host "`n$indent   $(T('games.your_score')): $score" -ForegroundColor Yellow
    Write-Log -Action "GAME_OVER" -Details "Game=Snake | Score=$score"
    Write-Host "`n$indent   $(T('games.press_any_key'))" -ForegroundColor Gray
    [Console]::ReadKey($true) | Out-Null
}

function Start-ClaudeCrabGame {
    Write-Log -Action "GAME_START" -Details "Game=ClaudeCrab | Style=$($global:settings.game_styles.claude_crab.current)"
    Clear-Host; [Console]::CursorVisible = $false
    $width = 60; $height = 20; $score = 0; $gameOver = $false

    # БАГФИКС: рамка "-...¬ / L...-" заменена на нормальную псевдографику (+++++).
    [Console]::SetCursorPosition(0, 0); Write-Host ("+" + ("-" * $width) + "+")
    for ($y = 1; $y -le $height; $y++) { [Console]::SetCursorPosition(0, $y); Write-Host "+"; [Console]::SetCursorPosition($width + 1, $y); Write-Host "+" }
    [Console]::SetCursorPosition(0, $height + 1); Write-Host ("+" + ("-" * $width) + "+")
    [Console]::SetCursorPosition($width + 5, 1); Write-Host "$(T('games.score')): $score"
    [Console]::SetCursorPosition($width + 5, 3); Write-Host "$(T('dinosaur.controls'))"
    [Console]::SetCursorPosition($width + 5, 4); Write-Host "$(T('dinosaur.move'))"
    [Console]::SetCursorPosition($width + 5, 5); Write-Host "$(T('dinosaur.fire'))"

    $playerArt = $global:settings.game_styles.claude_crab.styles.($global:settings.game_styles.claude_crab.current)
    # БАГФИКС: ширина считалась только по первой строке скина. Если строки скина
    # были разной длины, при движении корабля за ним оставался "хвост" из старых
    # пикселей — стирание рисовало прямоугольник уже, чем реальный спрайт.
    $playerWidth = ($playerArt | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $playerHeight = $playerArt.Length
    $player = [pscustomobject]@{ X = [int](($width - $playerWidth)/2); Y = $height - $playerHeight; Color = "221;127;97" }
    $oldPlayerX = $player.X

    $projectiles = [System.Collections.Generic.List[object]]::new()
    $asteroids = [System.Collections.Generic.List[object]]::new()
    $asteroidArt = @("@@", "@@")
    $asteroidWidth = $asteroidArt[0].Length
    $asteroidHeight = $asteroidArt.Length
    $random = New-Object Random

    $gameTick = 0

    while (-not $gameOver) {
        $gameTick++

        $oldPlayerX = $player.X

        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true).Key
            if (($key -eq 'LeftArrow' -or $key -eq 'A') -and $player.X -gt 1) { $player.X-- }
            if (($key -eq 'RightArrow' -or $key -eq 'D') -and $player.X -lt ($width - $playerWidth)) { $player.X++ }
            if ($key -eq 'Spacebar') { $projectiles.Add([pscustomobject]@{X=$player.X + [int]($playerWidth/2); Y=$player.Y-1}) }
            if ($key -eq 'Escape') { break }
        }

        # Стирание
        for($i=0; $i -lt $playerHeight; $i++) { [Console]::SetCursorPosition($oldPlayerX, $player.Y + $i); Write-Host (" " * $playerWidth) }
        foreach($p in $projectiles) { [Console]::SetCursorPosition($p.X, $p.Y); Write-Host " " }
        foreach($a in $asteroids) { for($i=0; $i -lt $asteroidHeight; $i++) { [Console]::SetCursorPosition($a.X, $a.Y + $i); Write-Host (" " * $asteroidWidth) } }

        # Обновление
        if ($gameTick % 3 -eq 0) {
            for ($i = $projectiles.Count - 1; $i -ge 0; $i--) {
                $projectiles[$i].Y--
                if ($projectiles[$i].Y -le 0) { $projectiles.RemoveAt($i) }
            }
        }
        if ($gameTick % 8 -eq 0) {
            if ($gameTick % (80 - [Math]::Min(70, [int]($score * 2))) -eq 0) {
                $margin = 5
                $asteroids.Add([pscustomobject]@{X=$random.Next(1 + $margin, $width - $asteroidWidth - $margin); Y=1})
            }
            for ($i = $asteroids.Count - 1; $i -ge 0; $i--) {
                $asteroids[$i].Y++
                if ($asteroids[$i].Y -gt $height) { $asteroids.RemoveAt($i); $gameOver = $true }
            }
        }

        # Коллизии
        for ($i = $projectiles.Count - 1; $i -ge 0; $i--) {
            for ($j = $asteroids.Count - 1; $j -ge 0; $j--) {
                $p = $projectiles[$i]; $a = $asteroids[$j]
                if ($p.Y -ge $a.Y -and $p.Y -lt ($a.Y + $asteroidHeight) -and $p.X -ge $a.X -and $p.X -lt ($a.X + $asteroidWidth)) {
                    $projectiles.RemoveAt($i); $asteroids.RemoveAt($j)
                    $score++; [Console]::SetCursorPosition($width + 10, 1); Write-Host $score
                    break
                }
            }
        }
        foreach($a in $asteroids) {
            if ($player.X -lt ($a.X + $asteroidWidth) -and ($player.X + $playerWidth) -gt $a.X -and $player.Y -lt ($a.Y + $asteroidHeight) -and ($player.Y + $playerHeight) -gt $a.Y) {
                $gameOver = $true
            }
        }

        # Отрисовка
        $playerColorCode = "$ESC[38;2;$($player.Color)m"
        $resetCode = "$ESC[0m"
        for($i=0; $i -lt $playerHeight; $i++) { [Console]::SetCursorPosition($player.X, $player.Y + $i); Write-Host "${playerColorCode}$($playerArt[$i])${resetCode}" }
        foreach($p in $projectiles) { [Console]::SetCursorPosition($p.X, $p.Y); Write-Host "*" -ForegroundColor Yellow }
        foreach($a in $asteroids) { for($i=0; $i -lt $asteroidHeight; $i++) { [Console]::SetCursorPosition($a.X, $a.Y + $i); Write-Host $asteroidArt[$i] -ForegroundColor Magenta } }

        Show-GameBackground ($width + 1) ($height + 1)
        Start-Sleep -Milliseconds 30
    }

    Clear-Host
    $gameOverArt = @(
        '     _______  _______  __   __  _______    _______  __   __  _______  ______   ',
        '    |       ||   _   ||  |_|  ||       |  |       ||  | |  ||       ||    _ |  ',
        '    |    ___||  |_|  ||       ||    ___|  |   _   ||  |_|  ||    ___||   | ||  ',
        '    |   | __ |       ||       ||   |___   |  | |  ||       ||   |___ |   |_||_ ',
        '    |   ||  ||       ||       ||    ___|  |  |_|  ||       ||    ___||    __  |',
        '    |   |_| ||   _   || ||_|| ||   |___   |       | |     | |   |___ |   |  | |',
        '    |_______||__| |__||_|   |_||_______|  |_______|  |___|  |_______||___|  |_|'
    )
    $indent = ' ' * 5
    foreach ($line in $gameOverArt) { Write-Host "$indent$line" -ForegroundColor Red }
    Write-Host "`n$indent   $(T('games.your_score')): $score" -ForegroundColor Yellow
    Write-Log -Action "GAME_OVER" -Details "Game=ClaudeCrab | Score=$score"
    Write-Host "`n$indent   $(T('games.press_any_key'))" -ForegroundColor Gray
    [Console]::ReadKey($true) | Out-Null
}

function Start-DinosaurGame {
    Write-Log -Action "GAME_START" -Details "Game=Dinosaur | Style=$($global:settings.game_styles.dinosaur.current)"
    Clear-Host; [Console]::CursorVisible = $false
    $width = 80; $height = 20; $score = 0; $gameOver = $false
    $groundY = $height - 1

    [Console]::SetCursorPosition(0, $groundY); Write-Host ("-" * $width)
    [Console]::SetCursorPosition(1, 1); Write-Host "$(T('games.score')): 0"

    $dinoArt = $global:settings.game_styles.dinosaur.styles.($global:settings.game_styles.dinosaur.current)
    $dinoHeight = $dinoArt.Length
    $dinoWidth = ($dinoArt | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $dino = [pscustomobject]@{ X = 5; Y = $groundY - $dinoHeight; Y_Velocity = 0; IsJumping = $false }

    $obstacles = [System.Collections.Generic.List[object]]::new()
    # БАГФИКС: раньше препятствием была строка-заглушка "ERROR", оставшаяся от
    # отладки. Теперь это несколько разных фигур одинаковой ширины (случайный выбор
    # при каждом спавне) — заодно и разнообразнее смотрится.
    $obstacleShapes = @("/#\", "n_n", "|^|")
    $obstacleWidth = 3
    $random = New-Object Random
    $obstacleSpawnCounter = 0
    $gameSpeed = 40

    while (-not $gameOver) {
        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true).Key
            if (($key -eq 'Spacebar' -or $key -eq 'W' -or $key -eq 'UpArrow') -and -not $dino.IsJumping) {
                $dino.IsJumping = $true
                $dino.Y_Velocity = -1.6
            }
            if ($key -eq 'Escape') { break }
        }

        # БАГФИКС: Y — дробное число (растёт с ускорением свободного падения), а
        # SetCursorPosition ждёт целые координаты. Раньше это отдавалось на откуп
        # неявному приведению типов; теперь округляем явно.
        $dinoDrawY = [int][Math]::Round($dino.Y)

        # Стирание
        for($i=0; $i -lt $dinoHeight; $i++) { [Console]::SetCursorPosition($dino.X, $dinoDrawY + $i); Write-Host (" " * $dinoWidth) }
        foreach($obs in $obstacles) { [Console]::SetCursorPosition($obs.X, $obs.Y); Write-Host (" " * $obstacleWidth) }

        # Обновление прыжка
        if ($dino.IsJumping) {
            $dino.Y += $dino.Y_Velocity
            $dino.Y_Velocity += 0.2
            if ($dino.Y -ge $groundY - $dinoHeight) {
                $dino.Y = $groundY - $dinoHeight
                $dino.IsJumping = $false
            }
        }
        $dinoDrawY = [int][Math]::Round($dino.Y)

        # Обновление препятствий
        $obstacleSpawnCounter++
        if ($obstacleSpawnCounter -gt ($random.Next(25, 50))) {
            $shape = $obstacleShapes[$random.Next(0, $obstacleShapes.Length)]
            $obstacles.Add([pscustomobject]@{X = $width - $obstacleWidth; Y = $groundY - 1; Art = $shape})
            $obstacleSpawnCounter = 0
        }
        for ($i = $obstacles.Count - 1; $i -ge 0; $i--) {
            $obstacles[$i].X--
            if ($obstacles[$i].X -lt 0) { $obstacles.RemoveAt($i) }
        }

        # Коллизии
        $dinoHitboxWidth = $dinoWidth - 1
        foreach($obs in $obstacles) {
            if (($dino.X + 1) -lt ($obs.X + $obstacleWidth) -and ($dino.X + $dinoHitboxWidth) -gt $obs.X -and $dinoDrawY -lt ($obs.Y + 1) -and ($dinoDrawY + $dinoHeight) -gt $obs.Y) {
                $gameOver = $true
            }
        }

        # Отрисовка
        for($i=0; $i -lt $dinoHeight; $i++) { [Console]::SetCursorPosition($dino.X, $dinoDrawY + $i); Write-Host $dinoArt[$i] -ForegroundColor "Green" }
        foreach($obs in $obstacles) { [Console]::SetCursorPosition($obs.X, $obs.Y); Write-Host $obs.Art -ForegroundColor "Red" }

        $score++; [Console]::SetCursorPosition(7, 1); Write-Host $score
        Show-GameBackground ($width - 1) $groundY
        Start-Sleep -Milliseconds $gameSpeed
    }

    Clear-Host
    $gameOverArt = @(
        '     _______  _______  __   __  _______    _______  __   __  _______  ______   ',
        '    |       ||   _   ||  |_|  ||       |  |       ||  | |  ||       ||    _ |  ',
        '    |    ___||  |_|  ||       ||    ___|  |   _   ||  |_|  ||    ___||   | ||  ',
        '    |   | __ |       ||       ||   |___   |  | |  ||       ||   |___ |   |_||_ ',
        '    |   ||  ||       ||       ||    ___|  |  |_|  ||       ||    ___||    __  |',
        '    |   |_| ||   _   || ||_|| ||   |___   |       | |     | |   |___ |   |  | |',
        '    |_______||__| |__||_|   |_||_______|  |_______|  |___|  |_______||___|  |_|'
    )
    $indent = ' ' * 5
    foreach ($line in $gameOverArt) { Write-Host "$indent$line" -ForegroundColor Red }
    Write-Host "`n$indent   $(T('games.your_score')): $score" -ForegroundColor Yellow
    Write-Log -Action "GAME_OVER" -Details "Game=Dinosaur | Score=$score"
    Write-Host "`n$indent   $(T('games.press_any_key'))" -ForegroundColor Gray
    [Console]::ReadKey($true) | Out-Null
}

function Show-MiniGamesMenu {
    $gameMenuItems = @()
    $gameMenuItems += T("games.snake")
    $gameMenuItems += T("games.dinosaur")
    $gameMenuItems += T("games.claude_crab")
    $selectedIndex = 0
    while ($true) {
        Clear-Host
        Write-Host "`n   $(T('games.main')):`n" -ForegroundColor White
        for ($i = 0; $i -lt $gameMenuItems.Length; $i++) {
            $line = "  " + $(if ($i -eq $selectedIndex) { "> $($gameMenuItems[$i])" } else { "  $($gameMenuItems[$i])" })
            Write-Host $line
        }
        Write-Host "`n   $(T('common.esc_to_return'))" -ForegroundColor Gray
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { $selectedIndex = ($selectedIndex - 1 + $gameMenuItems.Length) % $gameMenuItems.Length }
            "DownArrow" { $selectedIndex = ($selectedIndex + 1) % $gameMenuItems.Length }
            "Enter"     {
                switch ($selectedIndex) {
                    0 { Start-SnakeGame }
                    1 { Start-DinosaurGame }
                    2 { Start-ClaudeCrabGame }
                }
                Clear-Host
            }
            "Escape"    { return }
        }
    }
}

function Show-StyleSelectionMenu {
    param($gameName)

    $styleOptions = $global:settings.game_styles.$gameName.styles.psobject.Properties.Name
    $currentStyle = $global:settings.game_styles.$gameName.current
    $selectedIndex = [array]::IndexOf($styleOptions, $currentStyle)
    if ($selectedIndex -lt 0) { $selectedIndex = 0 }

    while ($true) {
        Clear-Host
        $gameDisplayName = T("styles.$gameName")
        if ($gameDisplayName -eq "styles.$gameName") { $gameDisplayName = $gameName }
        Write-Host "`n   $(T('styles.select_style') -replace 'NAME', $gameDisplayName)`n" -ForegroundColor White
        for ($i = 0; $i -lt $styleOptions.Length; $i++) {
            $line = "  " + $(if ($i -eq $selectedIndex) { "> $($styleOptions[$i])" } else { "  $($styleOptions[$i])" })
            Write-Host $line
        }

        $previewStyle = $global:settings.game_styles.$gameName.styles.($styleOptions[$selectedIndex])
        Write-Host ""
        if ($previewStyle -is [array]) {
            foreach ($artLine in $previewStyle) { Write-Host "     $artLine" -ForegroundColor Cyan }
        } elseif ($null -ne $previewStyle.head) {
            Write-Host "     Head: $($previewStyle.head)   Body: $($previewStyle.body)   Food: $($previewStyle.food)" -ForegroundColor $previewStyle.color
        }

        Write-Host "`n   $(T('common.esc_to_return'))" -ForegroundColor Gray
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { $selectedIndex = ($selectedIndex - 1 + $styleOptions.Length) % $styleOptions.Length }
            "DownArrow" { $selectedIndex = ($selectedIndex + 1) % $styleOptions.Length }
            "Enter"     {
                $global:settings.game_styles.$gameName.current = $styleOptions[$selectedIndex]
                Save-Settings
                Write-Host "`n   $(T('styles.style_saved') -replace 'NAME', $styleOptions[$selectedIndex])" -ForegroundColor Green
                Write-Log -Action "GAME_STYLE_SET" -Details "Game=$gameName | Style=$($styleOptions[$selectedIndex])"
                Start-Sleep -Seconds 1
                return
            }
            "Escape"    { return }
        }
    }
}

function Show-StyleMainMenu {
    $styleMenuItems = @()
    $styleMenuItems += T("styles.claude_crab")
    $styleMenuItems += T("styles.snake")
    $styleMenuItems += T("styles.dinosaur")
    $selectedIndex = 0
    while ($true) {
        Clear-Host
        Write-Host "`n   $(T('styles.main')):`n" -ForegroundColor White
        for ($i = 0; $i -lt $styleMenuItems.Length; $i++) {
            $line = "  " + $(if ($i -eq $selectedIndex) { "> $($styleMenuItems[$i])" } else { "  $($styleMenuItems[$i])" })
            Write-Host $line
        }
        Write-Host "`n   $(T('common.esc_to_return'))" -ForegroundColor Gray
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { $selectedIndex = ($selectedIndex - 1 + $styleMenuItems.Length) % $styleMenuItems.Length }
            "DownArrow" { $selectedIndex = ($selectedIndex + 1) % $styleMenuItems.Length }
            "Enter"     {
                switch ($selectedIndex) {
                    0 { Show-StyleSelectionMenu -gameName "claude_crab" }
                    1 { Show-StyleSelectionMenu -gameName "snake" }
                    2 { Show-StyleSelectionMenu -gameName "dinosaur" }
                }
                Clear-Host
            }
            "Escape"    { return }
        }
    }
}

function Invoke-CleanMgr {
    # Очистка ВСЕХ категорий встроенной утилиты Disk Cleanup (cleanmgr.exe).
    # Включаем каждую категорию из HKLM\...\Explorer\VolumeCaches через флаг
    # StateFlags00XX, запускаем cleanmgr /sagerun:XX и снимаем флаги обратно.
    Write-Host "`n   [.] $(T('cleanup.cleanmgr_start'))" -ForegroundColor Yellow
    Write-Log -Action "CLEANMGR_START" -Details "Starting Disk Cleanup"

    $cleanmgr = Join-Path $env:WINDIR 'System32\cleanmgr.exe'
    if (-not (Test-Path $cleanmgr)) {
        Write-Host "   - $(T('cleanup.cleanmgr_skip'))" -ForegroundColor DarkCyan
        return
    }
    $vcPath = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
    if (-not (Test-Path $vcPath)) {
        Write-Host "   - VolumeCaches not found, skipping." -ForegroundColor DarkCyan
        return
    }

    # БАГФИКС: брали только ближайшие категории из регистра и молились. Теперь
    # считываем ВСЕ подразделы VolumeCaches (включая вложенные, если есть).
    try {
        $categories = @(Get-ChildItem -Path $vcPath -Recurse -ErrorAction Stop | Where-Object { -not $_.GetValueNames().Contains('Extension') })
    } catch {
        Write-Host "   - Cannot read VolumeCaches registry." -ForegroundColor DarkCyan
        return
    }

    $tag  = 13
    $flag = "StateFlags00$tag"  # -> StateFlags0013
    $enabled = 0

    foreach ($cat in $categories) {
        try {
            New-ItemProperty -Path $cat.PSPath -Name $flag -Value 2 -PropertyType DWord -Force -ErrorAction SilentlyContinue | Out-Null
            $enabled++
        } catch {}
    }

    if ($enabled -eq 0) {
        Write-Host "   - No cleanmgr categories found." -ForegroundColor DarkCyan
        Write-Log -Action "CLEANMGR_SKIP" -Details "Reason=No categories"
        return
    }

    Write-Host "   - $(T('cleanup.cleanmgr_categories') -replace 'COUNT', $enabled)" -ForegroundColor Cyan

    try {
        $p = Start-Process -FilePath $cleanmgr -ArgumentList "/sagerun:$tag" -Wait -PassThru -ErrorAction Stop
        Write-Log -Action "CLEANMGR_RUN" -Details "Categories=$enabled | ExitCode=$($p.ExitCode)"
    } catch {
        Write-Log -Action "CLEANMGR_ERROR" -Details "Message=$($_.Exception.Message)"
    }

    # Снимаем временные флаги, чтобы не оставлять "запланированную" очистку.
    foreach ($cat in $categories) {
        try { Remove-ItemProperty -Path $cat.PSPath -Name $flag -ErrorAction SilentlyContinue } catch {}
    }

    Write-Host "   - $(T('cleanup.cleanmgr_done'))" -ForegroundColor Green
}

function Show-CleanupSelection {
    param(
        [object[]]$Items,
        [string]$Title = ""
    )

    # БАГФИКС: раньше очистка шла по всему списку без выбора. Теперь это меню
    # с чекбоксами: [Space] — включить/выключить строку, [A] — все, [N] — снять все,
    # [Enter] — начать, [Esc] — отмена (никакой очистки не происходит).
    $selectedIndex = 0
    $available = @($Items | Where-Object { -not $_.Path -or (Test-Path $_.Path) })
    if ($available.Count -eq 0) { return $Items }

    $headerText = if ($Title) { $Title } else { T("cleanup.select_title") }

    [Console]::CursorVisible = $false
    while ($true) {
        Clear-Host
        Write-Host "`n   $headerText`n" -ForegroundColor White

        for ($i = 0; $i -lt $available.Count; $i++) {
            $item = $available[$i]
            $box = if ($item.Enabled) { "[x]" } else { "[ ]" }
            $line = "   $box $($item.Label)"
            if ($i -eq $selectedIndex) {
                Write-Host " > $line" -ForegroundColor White -BackgroundColor DarkBlue
            } else {
                Write-Host "   $line" -ForegroundColor Gray
            }
        }

        Write-Host "`n   $(T('cleanup.select_all'))" -ForegroundColor Cyan
        Write-Host "   $(T('cleanup.select_none'))" -ForegroundColor Cyan
        Write-Host "   $(T('cleanup.start_hint'))" -ForegroundColor Green
        Write-Host "   $(T('cleanup.cancel_hint'))" -ForegroundColor Gray

        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { $selectedIndex = ($selectedIndex - 1 + $available.Count) % $available.Count }
            "DownArrow" { $selectedIndex = ($selectedIndex + 1) % $available.Count }
            "Spacebar"  { $available[$selectedIndex].Enabled = -not $available[$selectedIndex].Enabled }
            "A"         { foreach ($i in $available) { $i.Enabled = $true } }
            "N"         { foreach ($i in $available) { $i.Enabled = $false } }
            "Enter"     { [Console]::CursorVisible = $true; return $Items }
            "Escape"    { [Console]::CursorVisible = $true; return $null }
        }
    }
}

function Show-DriveSelection {
    # Выбор дисков, которые нужно почистить. Возвращает массив букв дисков
    # (например "C:"), либо $null при отмене.
    $drives = @(Get-Volume -ErrorAction SilentlyContinue |
                Where-Object { $_.DriveLetter -and $_.DriveType -in @('Fixed', 'Removable') } |
                Sort-Object DriveLetter)
    if ($drives.Count -eq 0) {
        # Не нашли диски — хотя бы системный.
        return @($env:SystemDrive)
    }

    $items = @()
    foreach ($d in $drives) {
        $letter = "$($d.DriveLetter):"
        $isSystem = ([string]::Equals($letter, $env:SystemDrive, [System.StringComparison]::OrdinalIgnoreCase))
        $extra = if ($d.FriendlyName) { "  ($($d.FriendlyName))" } else { "" }
        $free  = if ($d.SizeRemaining) {
            $freeNum = [math]::Round(($d.SizeRemaining / 1GB), 1)
            "  " + (T("cleanup.free_gb")).Replace("FREE", $freeNum.ToString())
        } else { "" }
        $sysTag = if ($isSystem) { "  $(T('cleanup.system_marker'))" } else { "" }
        $items += @{
            Letter  = $letter
            Label   = "$letter\$extra$sysTag$free"
            Enabled = $isSystem
        }
    }

    $result = Show-CleanupSelection -Items $items -Title (T("cleanup.drives_title"))
    if ($null -eq $result) { return $null }
    return @($result | Where-Object { $_.Enabled } | ForEach-Object { $_.Letter })
}

function Clean-Junk {
    Write-Log -Action "CLEAN_START" -Details "Starting junk cleanup"
    Clear-Host
    Write-Host "`n   [.] $(T('cleanup.starting'))" -ForegroundColor Yellow

    # Шаг 1 — выбор дисков, которые нужно чистить
    $selectedDrives = Show-DriveSelection
    if ($null -eq $selectedDrives) {
        Write-Host "`n   [..] $(T('cleanup.cancelled'))" -ForegroundColor Gray
        Write-Log -Action "CLEAN_CANCELLED" -Details "User cancelled drive selection"
        Read-Host "`n   $(T('cleanup.press_enter'))"
        return
    }
    if (@($selectedDrives).Count -eq 0) {
        Write-Host "`n   [!] $(T('cleanup.nothing_selected'))" -ForegroundColor Yellow
        Write-Log -Action "CLEAN_NONE" -Details "No drives selected"
        Read-Host "`n   $(T('cleanup.press_enter'))"
        return
    }

    $targets = @(
        @{ Label = T("cleanup.user_temp");     Path = $env:TEMP;          Type = "folder";     Enabled = $true },
        @{ Label = T("cleanup.system_temp");   Path = "$env:WINDIR\Temp"; Type = "folder";     Enabled = $true },
        @{ Label = T("cleanup.prefetch");      Path = "$env:WINDIR\Prefetch"; Type = "folder"; Enabled = $true },
        @{ Label = T("cleanup.dns_cache");     Path = "$env:WINDIR\System32\dns"; Type = "folder"; Enabled = $true },
        @{ Label = T("cleanup.wu_cache");      Path = "$env:WINDIR\SoftwareDistribution\Download"; Type = "folder"; Enabled = $true },
        @{ Label = T("cleanup.windows_logs");  Path = "$env:WINDIR\Logs"; Type = "folder";     Enabled = $true },
        @{ Label = T("cleanup.error_reports"); Path = "$env:LOCALAPPDATA\Microsoft\Windows\WER"; Type = "folder"; Enabled = $true },
        @{ Label = T("cleanup.recent");        Path = "$env:USERPROFILE\Recent"; Type = "folder"; Enabled = $true },
        @{ Label = T("cleanup.thumbnails");    Path = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"; Type = "folder"; Enabled = $true },
        @{ Label = T("cleanup.recycle_bin");   Path = ""; Type = "recyclebin"; Enabled = $true },
        @{ Label = T("cleanup.cleanmgr");      Path = ""; Type = "cleanmgr";   Enabled = $false }
    )

    # Шаг 2 — выбор папок (что именно чистить внутри выбранных дисков)
    $targets = Show-CleanupSelection -Items $targets
    if ($null -eq $targets) {
        Write-Host "`n   [..] $(T('cleanup.cancelled'))" -ForegroundColor Gray
        Write-Log -Action "CLEAN_CANCELLED" -Details "User cancelled folder selection"
        Read-Host "`n   $(T('cleanup.press_enter'))"
        return
    }

    $selected = @($targets | Where-Object { $_.Enabled })
    if ($selected.Count -eq 0) {
        Write-Host "`n   [!] $(T('cleanup.nothing_selected'))" -ForegroundColor Yellow
        Write-Log -Action "CLEAN_NONE" -Details "Nothing selected"
        Read-Host "`n   $(T('cleanup.press_enter'))"
        return
    }

    $totalCleaned = 0
    $totalBytes = [long]0
    Clear-Host

    foreach ($t in $selected) {
        switch ($t.Type) {
            "folder" {
                # Проверяем, что диск, на котором лежит папка, выбран пользователем
                $targetDrive = (Split-Path -Qualifier $t.Path)
                if ($targetDrive -notin $selectedDrives) {
                    Write-Host "   - $($t.Label): $(T('cleanup.drive_skipped') -replace 'DRIVE', $targetDrive) ($(T('cleanup.drive_unselected')))" -ForegroundColor DarkCyan
                    Write-Log -Action "CLEAN_SKIP_DRIVE" -Details "Target=$($t.Label) | Drive=$targetDrive"
                    continue
                }
                if (-not (Test-Path $t.Path)) {
                    Write-Host "   - $($t.Label): $(T('cleanup.skipped'))" -ForegroundColor DarkCyan
                    Write-Log -Action "CLEAN_SKIP" -Details "Target=$($t.Label) | Reason=Path not accessible"
                    continue
                }
                $files = @(Get-ChildItem -Path $t.Path -Recurse -File -Force -ErrorAction SilentlyContinue)
                $count = $files.Count
                $bytes = ($files | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
                if ($null -eq $bytes) { $bytes = 0 }
                Remove-Item -Path "$($t.Path)\*" -Recurse -Force -ErrorAction SilentlyContinue
                $totalCleaned += $count
                $totalBytes += $bytes
                $cleanedLabel = T("cleanup.cleaned_files")
                Write-Host ("   - {0}: {1} {2} ({3:N1} MB)" -f $t.Label, $count, $cleanedLabel, ($bytes / 1MB)) -ForegroundColor Green
                Write-Log -Action "CLEAN_TARGET" -Details "Name=$($t.Label) | Files=$count | Bytes=$($bytes)"
            }
            "recyclebin" {
                # Корзина чистится ПОСЕЛЕКЦИОННО для каждого выбранного диска
                foreach ($drv in $selectedDrives) {
                    try {
                        Clear-RecycleBin -DriveLetter $drv -Force -ErrorAction SilentlyContinue
                        Write-Host "   - $(T('cleanup.recycle_bin')) [$drv]: $(T('cleanup.cleared'))" -ForegroundColor Green
                        Write-Log -Action "CLEAN_RECYCLEBIN" -Details "Drive=$drv"
                    } catch {}
                }
            }
            "cleanmgr" {
                # Встроенная очистка диска Windows (все категории cleanmgr)
                # cleanmgr умеет чистить только системный диск — запускаем, если он выбран.
                if ($env:SystemDrive -in $selectedDrives) {
                    Invoke-CleanMgr
                } else {
                    Write-Host "   - $(T('cleanup.cleanmgr')): $(T('cleanup.cleanmgr_drive_skip'))" -ForegroundColor DarkCyan
                }
            }
        }
    }

    Write-Host "`n   [OK] $(T('cleanup.total_deleted')): $totalCleaned, $(T('cleanup.total_freed')): $([math]::Round($totalBytes / 1MB, 2))" -ForegroundColor Green
    Write-Log -Action "CLEAN_FINISH" -Details "TotalFiles=$totalCleaned | TotalBytes=$totalBytes | FreedMB=$([math]::Round($totalBytes / 1MB, 2)) | Drives=$($selectedDrives -join ',')"

    # Сводка: сколько памяти занято и свободно после очистки
    $labelUsed = T("cleanup.used")
    $labelFree = T("cleanup.free")
    Write-Host "`n   $(T('cleanup.summary_after'))" -ForegroundColor Green
    foreach ($drv in $selectedDrives) {
        $ps = Get-PSDrive -Name $drv.TrimEnd(':') -ErrorAction SilentlyContinue
        if ($ps -and $ps.Provider.Name -eq "FileSystem" -and $ps.Free) {
            $usedGb = [math]::Round(($ps.Used / 1GB), 1)
            $freeGb = [math]::Round(($ps.Free / 1GB), 1)
            Write-Host ("   - {0}:  {1}: {2} GB | {3}: {4} GB" -f $drv, $labelUsed, $usedGb, $labelFree, $freeGb) -ForegroundColor Cyan
            Write-Log -Action "CLEAN_DRIVE_SUMMARY" -Details "Drive=$drv | UsedGB=$usedGb | FreeGB=$freeGb"
        }
    }
    try {
        $os = Get-CimInstance -ClassName Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($os) {
            $totalRamGb = [math]::Round(($os.TotalVisibleMemorySize / 1MB), 1)
            $freeRamGb  = [math]::Round(($os.FreePhysicalMemory / 1MB), 1)
            $usedRamGb  = [math]::Round(($totalRamGb - $freeRamGb), 1)
            Write-Host ("   - {0}:  {1}: {2}/{3} GB | {4}: {5} GB" -f (T("cleanup.ram")), $labelUsed, $usedRamGb, $totalRamGb, $labelFree, $freeRamGb) -ForegroundColor Cyan
            Write-Log -Action "CLEAN_RAM_SUMMARY" -Details "UsedGB=$usedRamGb | FreeGB=$freeRamGb | TotalGB=$totalRamGb"
        }
    } catch {}

    Read-Host "`n   $(T('cleanup.press_enter'))"
}

function Show-ColorEffectMenu {
    $items = @()
    $items += T("color_effects.effect")
    $items += T("color_effects.speed")
    $items += T("color_effects.custom_rgb")
    $items += T("color_effects.reset_rgb")
    $selectedIndex = 0
    while ($true) {
        Clear-Host
        Write-Host "`n   $(T('color_effects.main')):`n" -ForegroundColor White

        $curEffect = if ($global:settings.PSObject.Properties['color_effect']) { $global:settings.color_effect } else { "wave" }
        $curSpeed  = if ($global:settings.PSObject.Properties['effect_speed']) { [double]$global:settings.effect_speed } else { 0.4 }
        $cR = if ($global:settings.PSObject.Properties['custom_r']) { [int]$global:settings.custom_r } else { -1 }
        $cG = if ($global:settings.PSObject.Properties['custom_g']) { [int]$global:settings.custom_g } else { -1 }
        $cB = if ($global:settings.PSObject.Properties['custom_b']) { [int]$global:settings.custom_b } else { -1 }
        $rgbText = if ($cR -ge 0) { "RGB($cR, $cG, $cB)  $(T('color_effects.rgb_desc'))" } else { T("color_effects.rgb_desc") }

        Write-Host "   $(T('color_effects.current_effect')): $curEffect   |   $(T('color_effects.speed')): $curSpeed   |   $rgbText" -ForegroundColor DarkCyan
        Write-Host ""

        for ($i = 0; $i -lt $items.Length; $i++) {
            $line = "  " + $(if ($i -eq $selectedIndex) { "> $($items[$i])" } else { "  $($items[$i])" })
            if ($i -eq $selectedIndex) { Write-Host $line -ForegroundColor Cyan } else { Write-Host $line }
        }
        Write-Host "`n   $(T('common.esc_to_return'))" -ForegroundColor Gray
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { $selectedIndex = ($selectedIndex - 1 + $items.Length) % $items.Length }
            "DownArrow" { $selectedIndex = ($selectedIndex + 1) % $items.Length }
            "Enter" {
                switch ($selectedIndex) {
                    0 { Set-ColorEffectInteractive }
                    1 { Set-EffectSpeedInteractive }
                    2 { Set-CustomRgbInteractive }
                    3 {
                        $global:settings.custom_r = -1
                        $global:settings.custom_g = -1
                        $global:settings.custom_b = -1
                        Save-Settings
                        Write-Host "`n   [OK] $(T('color_effects.rgb_reset'))" -ForegroundColor Green
                        Write-Log -Action "CUSTOM_RGB_RESET" -Details ""
                        Start-Sleep -Seconds 1
                    }
                }
            }
            "Escape"    { return }
        }
    }
}

function Set-ColorEffectInteractive {
    $effects = @(
        @{ Name = "wave";    Description = T("color_effects.effects.wave") }
        @{ Name = "pulse";   Description = T("color_effects.effects.pulse") }
        @{ Name = "flow";    Description = T("color_effects.effects.flow") }
        @{ Name = "rainbow"; Description = T("color_effects.effects.rainbow") }
    )
    $currentName = if ($global:settings.PSObject.Properties['color_effect']) { $global:settings.color_effect } else { "wave" }
    $idx = [array]::IndexOf($effects.Name, $currentName); if ($idx -lt 0) { $idx = 0 }
    while ($true) {
        Clear-Host
        Write-Host "`n   $(T('color_effects.effect')):`n" -ForegroundColor White
        for ($i = 0; $i -lt $effects.Length; $i++) {
            $marker = if ($i -eq $idx) { "> " } else { "  " }
            $color  = if ($i -eq $idx) { "Cyan" } else { "Gray" }
            Write-Host "   $marker$($effects[$i].Name.PadRight(8)) — $($effects[$i].Description)" -ForegroundColor $color
        }
        Write-Host "`n   $(T('common.enter_save_esc_cancel'))" -ForegroundColor Gray
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { $idx = ($idx - 1 + $effects.Length) % $effects.Length }
            "DownArrow" { $idx = ($idx + 1) % $effects.Length }
            "Enter" {
                $global:settings.color_effect = $effects[$idx].Name
                Save-Settings
                Write-Host "`n   [OK] $($effects[$idx].Description) - $(T('colors.theme_saved') -replace 'THEME','')" -ForegroundColor Green
                Write-Log -Action "COLOR_EFFECT_SET" -Details "Effect=$($effects[$idx].Name)"
                Start-Sleep -Seconds 1
                return
            }
            "Escape"    { return }
        }
    }
}

function Set-EffectSpeedInteractive {
    $current = if ($global:settings.PSObject.Properties['effect_speed']) { [double]$global:settings.effect_speed } else { 0.4 }
    $step = 0.1
    $min = 0.1
    $max = 3.0
    while ($true) {
        Clear-Host
        Write-Host "`n   $(T('color_effects.speed')):`n" -ForegroundColor White
        Write-Host "   $($current) ($min..$max)" -ForegroundColor DarkCyan
        $barLen = 30
        $filled = [int][Math]::Round(($current - $min) / ($max - $min) * $barLen)
        if ($filled -lt 0) { $filled = 0 }
        if ($filled -gt $barLen) { $filled = $barLen }
        $bar = "[" + ("#" * $filled) + ("-" * ($barLen - $filled)) + "]"
        Write-Host "`n   $bar" -ForegroundColor Cyan
        Write-Host "`n   $(T('common.enter_save_esc_cancel'))" -ForegroundColor Gray
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "LeftArrow"  { $current = [Math]::Max($min, [Math]::Round($current - $step, 1)) }
            "RightArrow" { $current = [Math]::Min($max, [Math]::Round($current + $step, 1)) }
            "A"          { $current = [Math]::Max($min, [Math]::Round($current - $step, 1)) }
            "D"          { $current = [Math]::Min($max, [Math]::Round($current + $step, 1)) }
            "Enter" {
                $global:settings.effect_speed = $current
                Save-Settings
                Write-Host "`n   [OK] $(T('color_effects.speed_saved'))" -ForegroundColor Green
                Write-Log -Action "EFFECT_SPEED_SET" -Details "Speed=$current"
                Start-Sleep -Seconds 1
                return
            }
            "Escape"    { return }
        }
    }
}

function Set-CustomRgbInteractive {
    $channels = @(
        @{ Name = "R"; Value = if ($global:settings.PSObject.Properties['custom_r']) { [int]$global:settings.custom_r } else { 0 }; Key = "custom_r" }
        @{ Name = "G"; Value = if ($global:settings.PSObject.Properties['custom_g']) { [int]$global:settings.custom_g } else { 0 }; Key = "custom_g" }
        @{ Name = "B"; Value = if ($global:settings.PSObject.Properties['custom_b']) { [int]$global:settings.custom_b } else { 0 }; Key = "custom_b" }
    )
    $chIdx = 0
    while ($true) {
        Clear-Host
        Write-Host "`n   $(T('customization.custom_rgb')) ($($global:settings.color_theme)):`n" -ForegroundColor White
        for ($i = 0; $i -lt $channels.Length; $i++) {
            $marker = if ($i -eq $chIdx) { ">" } else { " " }
            $v = $channels[$i].Value
            $barLen = 30
            $filled = [int][Math]::Round($v / 255.0 * $barLen)
            $bar = "[" + ("#" * $filled) + ("-" * ($barLen - $filled)) + "]"
            $color = if ($i -eq $chIdx) { "Cyan" } else { "Gray" }
            Write-Host "   $marker $($channels[$i].Name) = $v  $bar" -ForegroundColor $color
        }
        $r = $channels[0].Value; $g = $channels[1].Value; $b = $channels[2].Value
        Write-Host ""
        Write-Host "   $(T('color_effects.preview')) " -NoNewline -ForegroundColor White
        $ESC2 = [char]27
        Write-Host "$ESC2[38;2;$r;$g;${b}m███████ SAMPLE TEXT ███████$ESC2[0m"
        Write-Host ""
        Write-Host "   $(T('color_effects.channel_select'))" -ForegroundColor Gray
        $key = [Console]::ReadKey($true)
        $shift = $key.Modifiers -band [System.ConsoleModifiers]::Shift
        $delta = if ($shift) { 20 } else { 5 }
        switch ($key.Key) {
            "LeftArrow"  { $chIdx = ($chIdx - 1 + 3) % 3 }
            "RightArrow" { $chIdx = ($chIdx + 1) % 3 }
            "UpArrow"    { $channels[$chIdx].Value = [Math]::Min(255, $channels[$chIdx].Value + $delta) }
            "DownArrow"  { $channels[$chIdx].Value = [Math]::Max(0,   $channels[$chIdx].Value - $delta) }
            "Enter" {
                $global:settings.custom_r = $channels[0].Value
                $global:settings.custom_g = $channels[1].Value
                $global:settings.custom_b = $channels[2].Value
                Save-Settings
                Write-Host "`n   [OK] RGB($($channels[0].Value), $($channels[1].Value), $($channels[2].Value)) - $(T('color_effects.rgb_saved'))" -ForegroundColor Green
                Write-Log -Action "CUSTOM_RGB_SET" -Details "RGB=$($channels[0].Value),$($channels[1].Value),$($channels[2].Value)"
                Start-Sleep -Seconds 1
                return
            }
            "Escape"    { return }
        }
    }
}

function Show-BootScreenMenu {
    $bootStyles = @(
        @{ Name = "full";      Description = T("boot_screen.styles.full") }
        @{ Name = "classic";   Description = T("boot_screen.styles.classic") }
        @{ Name = "minimal";   Description = T("boot_screen.styles.minimal") }
        @{ Name = "terminals"; Description = T("boot_screen.styles.terminals") }
        @{ Name = "off";       Description = T("boot_screen.styles.off") }
    )
    $currentName = if ($global:settings.PSObject.Properties['boot_style']) { $global:settings.boot_style } else { "full" }
    $idx = [array]::IndexOf($bootStyles.Name, $currentName)
    if ($idx -lt 0) { $idx = 0 }
    while ($true) {
        Clear-Host
        Write-Host "`n   $(T('boot_screen.main')):`n" -ForegroundColor White
        Write-Host "   $(T('boot_screen.current_style')): $($bootStyles[$idx].Name)`n" -ForegroundColor DarkCyan
        for ($i = 0; $i -lt $bootStyles.Length; $i++) {
            $marker = if ($i -eq $idx) { "> " } else { "  " }
            $color  = if ($i -eq $idx) { "Cyan" } else { "Gray" }
            Write-Host "   $marker$($bootStyles[$i].Name.PadRight(8)) — $($bootStyles[$i].Description)" -ForegroundColor $color
        }
        $previewLines = switch ($bootStyles[$idx].Name) {
            "full"    { @(
                "   _____ ____  _____   _    ____  _   _ ____  ",
                "  |_   _|  _ \| ____| / \  |  _ \| | | / ___| ",
                "    | | | |_) |  _|  / _ \ | |_) | | | \___ \ ",
                "    =========================================",
                "    [████████████████████░░░░░░░░░░░░░] 67%  ",
                "    Stage: Preparing interface...            "
            ) }
            "classic" { @(
                "   =========================================",
                "    [████████████████████░░░░░░░░░░░░░] 67%  ",
                "   ========================================="
            ) }
            "minimal" { @(
                "   Loading... 67%",
                "   Stage: Preparing interface..."
            ) }
            "off"     { @("   [disabled - fast start]") }
            "terminals" { @(
                "   ╔════════════════════════════════════════════════════════════╗",
                "   ║  8 windows 600x800 flying on screen 3 sec                 ║",
                "   ║  [MATRIX] [BSOD] [RICK] [ENCRYPT] [SCAN] [HEX] [BYPASS] ║",
                "   ║  After - smooth transition to OPTIX main window           ║",
                "   ╚════════════════════════════════════════════════════════════╝"
            ) }
        }
        Write-Host ""
        foreach ($l in $previewLines) { Write-Host "   $l" -ForegroundColor DarkCyan }
        Write-Host ""
        Write-Host "   $(T('common.enter_save_esc_cancel'))" -ForegroundColor Gray
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { $idx = ($idx - 1 + $bootStyles.Length) % $bootStyles.Length }
            "DownArrow" { $idx = ($idx + 1) % $bootStyles.Length }
            "Enter" {
                $global:settings.boot_style = $bootStyles[$idx].Name
                Save-Settings
                Write-Host "`n   [OK] $(T('boot_screen.saved') -replace 'NAME', $bootStyles[$idx].Name)" -ForegroundColor Green
                Write-Log -Action "BOOT_STYLE_SET" -Details "Style=$($bootStyles[$idx].Name)"
                Start-Sleep -Seconds 1
                return
            }
            "Escape"    { return }
        }
    }
}

function Show-AnimationStyleMenu {
    $animations = @("off", "stars", "wave", "spiral", "matrix", "rain", "pulse")
    $currentIndex = [array]::IndexOf($animations, $global:settings.animation_style)
    if ($currentIndex -lt 0) { $currentIndex = 0 }
    while ($true) {
        Clear-Host
        Write-Host "`n   $(T('animation.select'))`n" -ForegroundColor White
        for ($i = 0; $i -lt $animations.Length; $i++) {
            $name = $animations[$i]
            $dispName = T("animation.effects.$name")
            if ($dispName -eq "animation.effects.$name") { $dispName = $name }
            if ($i -eq $currentIndex) { Write-Host "   > $dispName <" -ForegroundColor Cyan } else { Write-Host "     $dispName" -ForegroundColor Gray }
        }
        $demoLines = switch ($animations[$currentIndex]) {
            "off"    { @("     [off]") }
            "stars"  { @("    * .  *  .  *", "  .  *  .  *  .  *", "    * .  *  .  *") }
            "wave"   { @("    ~  ~  ~  ~  ~", "   ~~~~       ~~~", "       ~~~~  ~~~~") }
            "spiral" { @("       @", "     @ @ @", "       @") }
            "matrix" { @("  1 0 1 0 1 0 1", "  0 1 0 1 0 1 0", "  1 0 1 0 1 0 1") }
            "rain"   { @("  |   |  /", "  /  |    |", "     /  |") }
            "pulse"  { @("    ( o )", "   ( o o )", "  (  o  )") }
        }
        Write-Host ""
        foreach ($l in $demoLines) { Write-Host "     $l" -ForegroundColor DarkCyan }
        Write-Host "`n   $(T('common.enter_save_esc_cancel'))" -ForegroundColor Gray
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { $currentIndex = ($currentIndex - 1 + $animations.Length) % $animations.Length }
            "DownArrow" { $currentIndex = ($currentIndex + 1) % $animations.Length }
            "Enter"     { $global:settings.animation_style = $animations[$currentIndex]; Save-Settings; $an = $animations[$currentIndex]; $and = T("animation.effects.$an"); if ($and -eq "animation.effects.$an") { $and = $an }; Write-Host "`n   $(T('animation.saved') -replace 'NAME', $and)" -ForegroundColor Green; Write-Log -Action "ANIMATION_SET" -Details "Animation=$an"; Start-Sleep -Seconds 1; return }
            "Escape"    { return }
        }
    }
}

function Show-CustomizationMenu {
    $custMenuItems = @()
    $custMenuItems += T("customization.color_theme")
    $custMenuItems += T("customization.color_effects")
    $custMenuItems += T("customization.custom_rgb")
    $custMenuItems += T("customization.game_styles")
    $custMenuItems += T("customization.ascii_animation")
    $custMenuItems += T("customization.boot_screen")
    $selectedIndex = 0
    while ($true) {
        Clear-Host
        Write-Host "`n   $(T('customization.main')):`n" -ForegroundColor White
        for ($i = 0; $i -lt $custMenuItems.Length; $i++) {
            $line = "  " + $(if ($i -eq $selectedIndex) { "> $($custMenuItems[$i])" } else { "  $($custMenuItems[$i])" })
            Write-Host $line
        }
        Write-Host "`n   $(T('common.esc_to_return'))" -ForegroundColor Gray
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { $selectedIndex = ($selectedIndex - 1 + $custMenuItems.Length) % $custMenuItems.Length }
            "DownArrow" { $selectedIndex = ($selectedIndex + 1) % $custMenuItems.Length }
            "Enter"     {
                switch ($selectedIndex) {
                    0 { Show-ColorThemeMenu }
                    1 { Show-ColorEffectMenu }
                    2 { Set-CustomRgbInteractive }
                    3 { Show-StyleMainMenu }
                    4 { Show-AnimationStyleMenu }
                    5 { Show-BootScreenMenu }
                }
                Clear-Host
            }
            "Escape"    { return }
        }
    }
}

function Show-LanguageMenu {
    $langs = Get-AvailableLanguages
    $currentIdx = 0
    for ($i = 0; $i -lt $langs.Length; $i++) {
        if ($langs[$i].code -eq $global:currentLang) { $currentIdx = $i; break }
    }
    while ($true) {
        Clear-Host
        Write-Host "`n   Select language / Выберите язык:`n" -ForegroundColor White
        for ($i = 0; $i -lt $langs.Length; $i++) {
            $marker = if ($i -eq $currentIdx) { "> " } else { "  " }
            $color  = if ($i -eq $currentIdx) { "Cyan" } else { "White" }
            $native = $langs[$i].native_name
            $enName = $langs[$i].name
            $line = if ($native -eq $enName) { "$marker$native" } else { "$marker$native ($enName)" }
            Write-Host "   $line" -ForegroundColor $color
        }
        Write-Host "`n   (Enter - save, Esc - back)" -ForegroundColor Gray
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { $currentIdx = ($currentIdx - 1 + $langs.Length) % $langs.Length }
            "DownArrow" { $currentIdx = ($currentIdx + 1) % $langs.Length }
            "Enter" {
                $selected = $langs[$currentIdx]
                $global:settings.language = $selected.code
                Save-Settings
                Load-Language -LangCode $selected.code
                Write-Host "`n   [OK] Language: $($selected.native_name)" -ForegroundColor Green
                Write-Host "   Restart OPTIX to apply all interface changes." -ForegroundColor Gray
                Start-Sleep -Seconds 1
                return
            }
            "Escape" { return }
        }
    }
}

function Show-SettingsMenu {
    $settingsMenuItems = @()
    $settingsMenuItems += T("settings.customization")
    $settingsMenuItems += T("settings.cleanup")
    $settingsMenuItems += T("settings.cleanup_lists")
    $settingsMenuItems += T("settings.mini_games")
    $settingsMenuItems += T("settings.language")
    $selectedIndex = 0
    while ($true) {
        Clear-Host
        Write-Host "`n   $(T('settings.main')):`n" -ForegroundColor White
        for ($i = 0; $i -lt $settingsMenuItems.Length; $i++) {
            $line = "  " + $(if ($i -eq $selectedIndex) { "> $($settingsMenuItems[$i])" } else { "  $($settingsMenuItems[$i])" })
            Write-Host $line
        }
        Write-Host "`n   $(T('common.esc_to_return'))" -ForegroundColor Gray
        $key = [Console]::ReadKey($true)
        switch ($key.Key) {
            "UpArrow"   { $selectedIndex = ($selectedIndex - 1 + $settingsMenuItems.Length) % $settingsMenuItems.Length }
            "DownArrow" { $selectedIndex = ($selectedIndex + 1) % $settingsMenuItems.Length }
            "Enter"     {
                switch ($selectedIndex) {
                    0 { Show-CustomizationMenu }
                    1 { Clean-Junk }
                    2 { Show-ProcessManager }
                    3 { Show-MiniGamesMenu }
                    4 { Show-LanguageMenu }
                }
                Clear-Host
            }
            "Escape"    { return }
        }
    }
}

# --- ОСНОВНОЙ ЦИКЛ ---
Load-Settings
Write-Log -Action "LOAD_SETTINGS" -Details "Theme=$($global:settings.color_theme) | Animation=$($global:settings.animation_style)"
$menuItems = @( "[1] $(T('menu.game_mode'))", "[2] $(T('menu.normal_mode'))", "[3] $(T('menu.settings'))", "[4] $(T('menu.optix'))", "[5] $(T('menu.exit'))" )
$selectedIndex = 0
while ($true) {
    Show-Menu $selectedIndex $menuItems
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        $action = 0
        switch ($key.Key) {
            "UpArrow"   { $selectedIndex = ($selectedIndex - 1 + $menuItems.Length) % $menuItems.Length }
            "DownArrow" { $selectedIndex = ($selectedIndex + 1) % $menuItems.Length }
            "Enter"     { $action = $selectedIndex + 1 }
            "D1" { $action = 1 }; "D2" { $action = 2 }; "D3" { $action = 3 }; "D4" { $action = 4 }; "D5" { $action = 5 }
        }
        $wasAction = $action -ne 0
        switch ($action) {
            1 { Write-Log -Action "MENU_SELECT" -Details "Item=Игровой режим"; Start-GameMode }
            2 { Write-Log -Action "MENU_SELECT" -Details "Item=Обычный режим"; Stop-GameMode }
            3 { Write-Log -Action "MENU_SELECT" -Details "Item=Настройки"; Show-SettingsMenu }
            4 { Write-Log -Action "MENU_SELECT" -Details "Item=OPTIX"; Show-OptixMenu }
            5 { Write-Log -Action "EXIT" -Details "Code=0 | User requested exit"; Stop-GameMode -Silent; Clear-Host; exit }
        }
        if ($wasAction) { Clear-Host; $selectedIndex = 0 }
    }
    Start-Sleep -Milliseconds 50
}