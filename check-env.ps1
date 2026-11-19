# Environment self-check before using the skills. Read-only, changes nothing.
# PowerShell 5.1 compatible (no ternary operator).
$ErrorActionPreference = 'SilentlyContinue'
function Mark($ok) { if ($ok) { return 'OK  ' } else { return 'MISS' } }

Write-Host "=== Upscayl (image) ==="
$exe = $env:UPSCAYL_EXE
if (-not $exe) {
    $appDir = "F:\" + [char]0x963F + [char]0x666E + [char]0x5347 + [char]0x56FE
    $exe = @((Join-Path $appDir 'resources\bin\upscayl-bin.exe'),
             (Join-Path $env:LOCALAPPDATA 'Programs\Upscayl\resources\bin\upscayl-bin.exe'),
             (Join-Path $env:ProgramFiles 'Upscayl\resources\bin\upscayl-bin.exe')) |
           Where-Object { Test-Path $_ } | Select-Object -First 1
}
if ($exe -and (Test-Path $exe)) {
    Write-Host "OK   upscayl-bin.exe : $exe"
    $root = Split-Path (Split-Path (Split-Path $exe -Parent) -Parent) -Parent
    $models = $env:UPSCAYL_MODELS
    if (-not $models) { $models = Join-Path $root 'resources\models' }
    Write-Host "$(Mark (Test-Path $models)) models dir      : $models"
    $ultraOk = (Test-Path (Join-Path $models 'ultrasharp-4x.bin')) -or (Test-Path (Join-Path $models 'ultrasharp-4x'))
    Write-Host "$(Mark $ultraOk) ultrasharp-4x model"
} else {
    Write-Host "MISS Upscayl CLI not found -> install Upscayl desktop, or set UPSCAYL_EXE"
}

Write-Host ""
Write-Host "=== Topaz Video AI (video) ==="
$topaz = $env:TOPAZ_HOME
if (-not $topaz) {
    $topaz = @((Join-Path $env:ProgramFiles 'Topaz Labs LLC\Topaz Video AI'),
               'C:\Program Files\Topaz Labs LLC\Topaz Video AI') |
             Where-Object { Test-Path (Join-Path $_ 'ffmpeg.exe') } | Select-Object -First 1
}
if ($topaz -and (Test-Path (Join-Path $topaz 'ffmpeg.exe'))) {
    Write-Host "OK   Topaz ffmpeg    : $(Join-Path $topaz 'ffmpeg.exe')"
} else {
    Write-Host "MISS Topaz ffmpeg not found -> install Topaz Video AI, or set TOPAZ_HOME"
}
$models = $env:TOPAZ_MODEL_DIR
if (-not $models) { $models = 'C:\ProgramData\Topaz Labs LLC\Topaz Video AI\models' }
$model = $env:TOPAZ_MODEL
if (-not $model) { $model = 'prob-4' }
$json = Join-Path $models "$model.json"
Write-Host "$(Mark (Test-Path $json)) model $model     : $json"

Write-Host ""
Write-Host "=== GPU ==="
$gpu = nvidia-smi --query-gpu=name --format=csv,noheader 2>$null
if ($gpu) { Write-Host "OK   $gpu" } else { Write-Host "MISS nvidia-smi not found (NVIDIA driver?)" }
