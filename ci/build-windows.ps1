param(
    [Parameter(Mandatory = $true)][string]$RaylibDir,
    [string]$OutDir = "dist\release",
    [string]$ZaylibSrc = ""
)

$ErrorActionPreference = "Stop"
$Root = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path

if (-not [System.IO.Path]::IsPathRooted($OutDir)) {
    $OutDir = Join-Path $Root $OutDir
}

if (-not $ZaylibSrc) {
    $map = & zora --no-color --manifest-path (Join-Path $Root "Zora.toml") deps-map
    if ($LASTEXITCODE -ne 0) {
        throw "zora deps-map failed"
    }
    $line = $map | Where-Object { $_ -match '^zaylib=' } | Select-Object -First 1
    if (-not $line) {
        throw "zaylib source path not found, run: zora deps-map"
    }
    $ZaylibSrc = $line.Substring("zaylib=".Length)
}

if (-not (Test-Path $RaylibDir)) {
    throw "raylib directory not found: $RaylibDir"
}

$Out = $OutDir
if (Test-Path $Out) {
    Remove-Item -Recurse -Force $Out
}
New-Item -ItemType Directory -Path $Out -Force | Out-Null

$Source = Join-Path $Root "src"
$Exe = Join-Path $Out "ZeenSnake.exe"
$RaylibLib = Join-Path $RaylibDir "lib"

Push-Location $Source
try {
    & zeen main.zn (Join-Path $Out "ZeenSnake") `
        --mode Release `
        --pkg "snake=$Source" `
        --pkg "zaylib=$ZaylibSrc" `
        --link raylib `
        --link winmm `
        --link gdi32 `
        --link opengl32 `
        --link shell32 `
        --link ole32 `
        --link-dir $RaylibLib

    if ($LASTEXITCODE -ne 0) {
        throw "zeen failed with exit code $LASTEXITCODE"
    }
}
finally {
    Pop-Location
}

if (-not (Test-Path $Exe)) {
    throw "windows binary was not created"
}

$VsWhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $VsWhere) {
    $EditBin = & $VsWhere -latest -find "VC\Tools\MSVC\**\bin\Hostx64\x64\editbin.exe" |
        Select-Object -First 1
    if ($EditBin) {
        & $EditBin /SUBSYSTEM:WINDOWS $Exe | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Warning "editbin could not switch the executable to the windows subsystem"
        }
    }
}

$Pkg = Join-Path $Out "pkg\ZeenSnake"
New-Item -ItemType Directory -Path $Pkg -Force | Out-Null
Copy-Item $Exe $Pkg
Copy-Item (Join-Path $Root "assets") (Join-Path $Pkg "assets") -Recurse
Copy-Item (Join-Path $Root "LICENSE") $Pkg
Copy-Item (Join-Path $Root "README.md") $Pkg

Compress-Archive -Path (Join-Path $Pkg "*") `
    -DestinationPath (Join-Path $Out "ZeenSnake-windows-x86_64.zip") -Force

Write-Host "ZeenSnake.exe"
Write-Host "ZeenSnake-windows-x86_64.zip"
