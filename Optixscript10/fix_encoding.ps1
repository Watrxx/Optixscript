# Fix-Encoding: нормализует кодировку файлов OPTIX в UTF-8 с BOM.
# Windows PowerShell 5.1 читает UTF-8 БЕЗ BOM как ANSI, из-за чего
# кириллица во встроенных строках скрипта превращается в кракозябры.
# BOM заставляет 5.1 читать файл как UTF-8.

$root = $PSScriptRoot
if (-not (Test-Path $root)) { exit 0 }

$files = Get-ChildItem -Path $root -Recurse -File -Include *.ps1, *.json, *.txt -ErrorAction SilentlyContinue
foreach ($f in $files) {
    $rel = $f.FullName.Substring($root.Length).TrimStart('\')
    # Логи не трогаем, служебный чёрный список кодировок и свою же папку logs тоже.
    if ($rel -match '^(logs[\\/])') { continue }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        if ($hasBom) { continue }

        # Если есть не-ASCII байты — файл в UTF-8 без BOM либо иная кодировка.
        $nonAscii = $false
        foreach ($b in $bytes) { if ($b -ge 0x80) { $nonAscii = $true; break } }
        if (-not $nonAscii) { continue }

        # Пробуем прочитать как UTF-8; если некорректно — пропускаем (не наш файл).
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        if ($text.Contains([char]0xFFFD)) { continue }

        [System.IO.File]::WriteAllText($f.FullName, $text, (New-Object System.Text.UTF8Encoding $true))
        Write-Host ("[OK] " + $f.FullName)
    } catch {}
}
exit 0