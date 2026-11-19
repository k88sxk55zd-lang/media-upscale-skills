# Upscayl batch upscaler - portable version
# Usage: .\upscayl-batch.ps1 -InputDir "in" [-OutputDir "out"] [-Workers 2]
# Fixed rules: 2x / PNG lossless(0) / ultrasharp-4x / TTA off / GPU 0
# Path resolution: env var -> auto detect -> hardcoded fallback. Source kept ASCII-only
# on purpose (PowerShell 5.1 reads -File as GBK; see HANDOFF.md pitfall #13).
param(
    [Parameter(Mandatory=$true)][string]$InputDir,
    [string]$OutputDir = '',
    [int]$Workers = 2,
    [string]$Exe = '',
    [string]$Models = ''
)

$ErrorActionPreference = 'Stop'

# ---------- config resolution ----------
# 1) explicit parameter
# 2) environment variable UPSCAYL_EXE / UPSCAYL_MODELS
# 3) auto detect: "阿普升图" (char codes) on all fixed drives, + common install paths
if (-not $Exe)    { $Exe    = $env:UPSCAYL_EXE }
if (-not $Models) { $Models = $env:UPSCAYL_MODELS }

$appDir = "F:\" + [char]0x963F + [char]0x666E + [char]0x5347 + [char]0x56FE   # 阿普升图 fallback
$exeCandidates = @(
    $Exe,
    (Join-Path $appDir 'resources\bin\upscayl-bin.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\Upscayl\resources\bin\upscayl-bin.exe'),
    (Join-Path $env:ProgramFiles 'Upscayl\resources\bin\upscayl-bin.exe')
) | Where-Object { $_ }

$resolvedExe = $exeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $resolvedExe -and -not $Exe) {
    # last resort: scan drive roots for a folder that contains the CLI
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Root -match '^[A-Z]:\\$' })) {
        $hit = Get-ChildItem -Path $d.Root -Directory -ErrorAction SilentlyContinue |
               ForEach-Object { Join-Path $_.FullName 'resources\bin\upscayl-bin.exe' } |
               Where-Object { Test-Path $_ } | Select-Object -First 1
        if ($hit) { $resolvedExe = $hit; break }
    }
}
if (-not $resolvedExe) {
    Write-Host "[ERROR] upscayl-bin.exe not found. Set env UPSCAYL_EXE or edit -Exe." -ForegroundColor Red
    exit 1
}
$UPSCAYL_EXE = $resolvedExe
$root = Split-Path (Split-Path (Split-Path $UPSCAYL_EXE -Parent) -Parent) -Parent  # .../resources/bin/exe -> app root
if (-not $Models) {
    $modelCandidates = @(
        (Join-Path $root 'resources\models'),
        (Join-Path $appDir 'resources\models')
    )
    $Models = $modelCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
}
if (-not $Models -or -not (Test-Path $Models)) {
    Write-Host "[ERROR] model dir not found. Set env UPSCAYL_MODELS or edit -Models." -ForegroundColor Red
    exit 1
}
$MODEL_PATH = $Models

$MODEL_NAME  = 'ultrasharp-4x'
$SCALE       = 2
$FORMAT      = 'png'
$COMPRESS    = 0
$TILE_SIZE   = 0
$THREADS     = '2:4:4'   # load:proc:save, ~10-20% faster than default 1:2:2
$GPU_ID      = 0
if ($env:UPSCAYL_MODEL) { $MODEL_NAME = $env:UPSCAYL_MODEL }
if ($env:UPSCAYL_SCALE) { $SCALE = [int]$env:UPSCAYL_SCALE }

# ---------- validate ----------
if (-not (Test-Path $InputDir)) {
    Write-Host "[ERROR] Input folder not found: $InputDir" -ForegroundColor Red
    exit 1
}
if (-not $OutputDir) { $OutputDir = Join-Path $InputDir 'upscaled_2x' }
if (-not (Test-Path $OutputDir)) { New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null }

Write-Host "EXE    : $UPSCAYL_EXE"
Write-Host "MODELS : $MODEL_PATH"
Write-Host "MODEL  : $MODEL_NAME  SCALE: $SCALE  GPU: $GPU_ID"

# ---------- resume: skip inputs already having an output ----------
$imgs = @(Get-ChildItem -Path (Join-Path $InputDir '*') -File |
          Where-Object { $_.Extension -match '^\.(png|jpg|jpeg|webp)$' })
$pending = @($imgs | Where-Object {
    -not (Test-Path (Join-Path $OutputDir ($_.BaseName + '.' + $FORMAT)))
})
Write-Host "Total $($imgs.Count), skip $($imgs.Count - $pending.Count), todo $($pending.Count)"
if ($pending.Count -eq 0) { Write-Host "All done." -ForegroundColor Green; exit 0 }

# ---------- run (pass STRING paths into jobs, never objects) ----------
$startTime = Get-Date
$jobs = @()
$pendingPaths = @($pending | ForEach-Object { $_.FullName })
for ($w = 0; $w -lt $Workers; $w++) {
    $paths = @()
    for ($i = $w; $i -lt $pendingPaths.Count; $i += $Workers) { $paths += $pendingPaths[$i] }
    if ($paths.Count -eq 0) { continue }
    $jobs += Start-Job -ScriptBlock {
        foreach ($p in $using:paths) {
            $name = [IO.Path]::GetFileNameWithoutExtension($p) + '.' + $using:FORMAT
            & $using:UPSCAYL_EXE -i $p -o (Join-Path $using:OutputDir $name) `
                -m $using:MODEL_PATH -n $using:MODEL_NAME -s $using:SCALE -f $using:FORMAT `
                -c $using:COMPRESS -t $using:TILE_SIZE -j $using:THREADS -g $using:GPU_ID 2>$null
        }
    }
}
Wait-Job $jobs | Out-Null
$failed = 0
foreach ($j in $jobs) {
    Receive-Job $j | ForEach-Object { Write-Host $_ -ForegroundColor DarkGray }
    if ($j.State -eq 'Failed') { $failed++ }
    Remove-Job $j
}

# ---------- verification: count outputs actually produced this round ----------
$done = @(Get-ChildItem -Path (Join-Path $OutputDir "*.$FORMAT") -File).Count
$elapsed = [math]::Round(((Get-Date) - $startTime).TotalSeconds, 1)
Write-Host "Done in ${elapsed}s. Output now has $done files. (Workers=$Workers, $MODEL_NAME, ${SCALE}x)" -ForegroundColor Green
if ($failed -gt 0) { Write-Host "[WARN] $failed worker(s) exited with error." -ForegroundColor Red }
