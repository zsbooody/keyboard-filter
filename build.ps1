# Build Windows KeyboardFilter (requires MSYS2 ucrt64 gcc)
param(
    [switch]$Install
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$gxx = "C:\msys64\ucrt64\bin\g++.exe"
$windres = "C:\msys64\ucrt64\bin\windres.exe"
$build = Join-Path $root "build"
$out = Join-Path $root "dist\KeyboardFilter"
$version = "2.5.4"

if (-not (Test-Path $gxx)) { throw "g++ not found: $gxx" }
if (-not (Test-Path $windres)) { throw "windres not found: $windres" }

New-Item -ItemType Directory -Force -Path $build, $out, (Join-Path $root "dist") | Out-Null

Write-Host "[1/4] resources"
& $windres -I (Join-Path $root "src") (Join-Path $root "src\resources.rc") -O coff -o (Join-Path $build "resources.o")
if ($LASTEXITCODE -ne 0) { throw "windres failed" }

Write-Host "[2/4] compile+link"
& $gxx -std=c++17 -Os -s -ffunction-sections -fdata-sections -mwindows -static -DUNICODE -D_UNICODE `
  -I (Join-Path $root "src") `
  (Join-Path $root "src\keyboard_filter.cpp") `
  (Join-Path $build "resources.o") `
  "-Wl,--gc-sections" `
  -lcomctl32 -lshell32 -ladvapi32 -lgdi32 -luser32 `
  -o (Join-Path $out "keyboard_filter.exe")
if ($LASTEXITCODE -ne 0) { throw "g++ failed" }

Write-Host "[3/4] docs + zip"
Copy-Item (Join-Path $root "README.md") (Join-Path $out "README.md") -Force
Get-ChildItem -LiteralPath (Join-Path $root "docs") -File | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $out $_.Name) -Force
}

$zip = Join-Path (Join-Path $root "dist") "KeyboardFilter_v${version}_Windows.zip"
if (Test-Path -LiteralPath $zip) { Remove-Item -LiteralPath $zip -Force }
# Remove older zip packages in dist root
Get-ChildItem -LiteralPath (Join-Path $root "dist") -Filter "KeyboardFilter_v*_Windows.zip" -File |
    Where-Object { $_.FullName -ne $zip } |
    Remove-Item -Force -ErrorAction SilentlyContinue

Add-Type -AssemblyName System.IO.Compression.FileSystem
[System.IO.Compression.ZipFile]::CreateFromDirectory($out, $zip)

$exe = Get-Item (Join-Path $out "keyboard_filter.exe")
Write-Host "Build OK: $($exe.FullName) ($($exe.Length) bytes)"
Write-Host "Zip OK:   $zip ($((Get-Item -LiteralPath $zip).Length) bytes)"

if ($Install) {
    Write-Host "[4/4] install + restart"
    Get-Process keyboard_filter -ErrorAction SilentlyContinue | Stop-Process -Force
    Start-Sleep -Milliseconds 800

    $installDir = Join-Path $env:LOCALAPPDATA "KeyboardFilter"
    New-Item -ItemType Directory -Force -Path $installDir | Out-Null
    Get-ChildItem -LiteralPath $out -File | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination (Join-Path $installDir $_.Name) -Force
    }

    $shell = New-Object -ComObject WScript.Shell
    $lnkPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs\KeyboardFilter.lnk"
    $shortcut = $shell.CreateShortcut($lnkPath)
    $shortcut.TargetPath = Join-Path $installDir "keyboard_filter.exe"
    $shortcut.WorkingDirectory = $installDir
    $shortcut.Description = "Keyboard Filter v$version"
    $shortcut.Save()

    Start-Process -FilePath (Join-Path $installDir "keyboard_filter.exe") -WorkingDirectory $installDir
    Start-Sleep -Seconds 1
    $p = Get-Process keyboard_filter -ErrorAction SilentlyContinue
    if ($p) {
        Write-Host "Installed + running: $($p.Path) (pid $($p.Id))"
    } else {
        Write-Host "Installed, but process not detected. Check tray or antivirus."
    }
} else {
    Write-Host "[4/4] skip install (pass -Install to deploy locally)"
}

