# Topaz Video AI (Proteus / prob-4) upscaler - portable version
# Default -Preset all: 1080P 1890x1080, 2K 2520x1440, 4K 3780x2160
# Single: -Preset 1080p/2k/4k ; 4x: -Preset x4
# AI callers: do NOT pass -WaitAtEnd. Drag-drop bat does.
# Path resolution: env TOPAZ_HOME / TOPAZ_MODEL_DIR -> common install paths. Source ASCII-only.
param(
    [switch]$WaitAtEnd,
    [string]$Preset = 'all',
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Videos
)

$ErrorActionPreference = 'Stop'

function Pause-IfNeeded([string]$message) {
    if ($WaitAtEnd) {
        if ($message) { Write-Host $message }
        Read-Host 'Press Enter to exit' | Out-Null
    }
}

# ---------- config resolution ----------
$Topaz = $env:TOPAZ_HOME
if (-not $Topaz) {
    $cand = @(
        (Join-Path $env:ProgramFiles 'Topaz Labs LLC\Topaz Video AI'),
        (Join-Path ${env:ProgramFiles(x86)} 'Topaz Labs LLC\Topaz Video AI'),
        'C:\Program Files\Topaz Labs LLC\Topaz Video AI'
    )
    $Topaz = $cand | Where-Object { Test-Path (Join-Path $_ 'ffmpeg.exe') } | Select-Object -First 1
}
$Models = $env:TOPAZ_MODEL_DIR
if (-not $Models) { $Models = 'C:\ProgramData\Topaz Labs LLC\Topaz Video AI\models' }
$Model = $env:TOPAZ_MODEL
if (-not $Model) { $Model = 'prob-4' }
if (-not $Topaz) { throw 'Topaz home not found. Set env TOPAZ_HOME.' }

$env:TVAI_MODEL_DIR = $Models
$env:TVAI_MODEL_DATA_DIR = $Models
$env:Path = "$Topaz;" + $env:Path

$ffmpeg = Join-Path $Topaz 'ffmpeg.exe'
$ffprobe = Join-Path $Topaz 'ffprobe.exe'

if (-not (Test-Path $ffmpeg)) { throw "Topaz ffmpeg not found: $ffmpeg" }
if (-not (Test-Path (Join-Path $Models "$Model.json"))) { throw "Model $Model not found in: $Models" }

if (-not $Videos -or $Videos.Count -eq 0) {
    Write-Host 'Usage: powershell -File topaz-video-x4.ps1 -Preset all "video.mp4"'
    Write-Host 'Presets: all(default=1080P+2K+4K) / 1080p / 2k / 4k / x4'
    Write-Host '1080P=1890x1080  2K=2520x1440  4K=3780x2160  x4=w*4,h*4'
    Pause-IfNeeded ''
    exit 1
}

function Get-VideoSize([string]$path) {
    $csv = & $ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 -- $path
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($csv)) { throw "Cannot read size: $path" }
    $parts = $csv.Trim().Split(',')
    return [int]$parts[0], [int]$parts[1]
}

function Get-Jobs([string]$key, [int]$srcW, [int]$srcH) {
    $k = $key.Trim().ToLower()
    switch ($k) {
        { $_ -in @('all', 'v2', 'v2.0') } {
            return @(
                @{ Label = '1080P'; Suffix = '_1080p'; W = 1890; H = 1080; Scale = 0 }
                @{ Label = '2K';    Suffix = '_2k';    W = 2520; H = 1440; Scale = 0 }
                @{ Label = '4K';    Suffix = '_4k';    W = 3780; H = 2160; Scale = 0 }
            )
        }
        { $_ -in @('1080p', '1080', 'fhd') } { return @(@{ Label = '1080P'; Suffix = '_1080p'; W = 1890; H = 1080; Scale = 0 }) }
        { $_ -in @('2k', '1440p', 'qhd') }   { return @(@{ Label = '2K';    Suffix = '_2k';    W = 2520; H = 1440; Scale = 0 }) }
        { $_ -in @('4k', '2160p', 'uhd') }   { return @(@{ Label = '4K';    Suffix = '_4k';    W = 3780; H = 2160; Scale = 0 }) }
        { $_ -in @('x4', '4x', '4倍') }      { return @(@{ Label = '4x';    Suffix = '_x4';    W = $srcW * 4; H = $srcH * 4; Scale = 4 }) }
        default { throw "Unknown preset: $key. Use all/1080p/2k/4k/x4" }
    }
}

$ok = @()
foreach ($raw in $Videos) {
    $in = [System.IO.Path]::GetFullPath($raw)
    if (-not (Test-Path $in)) { Write-Host "SKIP (not found): $in"; continue }

    $dir = [System.IO.Path]::GetDirectoryName($in)
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($in)
    $sw, $sh = Get-VideoSize $in
    $jobs = Get-Jobs $Preset $sw $sh

    foreach ($job in $jobs) {
        $ow = [int]$job.W; $oh = [int]$job.H
        $out = Join-Path $dir ($stem + $job.Suffix + '.mp4')
        $scale = [int]$job.Scale
        Write-Host ""
        Write-Host "Preset $($job.Label) ${ow}x${oh}"
        Write-Host "IN  $in  (${sw}x${sh})"
        Write-Host "OUT $out"
        if ($ow -gt 8192 -or $oh -gt 8192) { Write-Host "SKIP: exceeds HEVC limit 8192."; continue }

        $filter = "tvai_up=model=${Model}:scale=${scale}:w=${ow}:h=${oh}:preblur=0:noise=0:details=0:halo=0:blur=0:compression=0:estimate=8:blend=0.2:device=0:vram=1:instances=1:download=0,scale=w=${ow}:h=${oh}:flags=lanczos:threads=0"
        $ffArgs = @('-hide_banner', '-nostdin', '-y', '-i', $in,
                    '-sws_flags', 'spline+accurate_rnd+full_chroma_int',
                    '-filter_complex', $filter)
        if ($ow -gt 4096 -or $oh -gt 4096) {
            $ffArgs += @('-c:v','hevc_nvenc','-profile:v','main','-pix_fmt','yuv420p',
                        '-b_ref_mode','disabled','-tag:v','hvc1','-g','30',
                        '-preset','p7','-tune','hq','-rc','constqp','-qp','17',
                        '-rc-lookahead','20','-spatial_aq','1','-aq-strength','15','-b:v','0')
            Write-Host 'Codec HEVC'
        } else {
            $ffArgs += @('-c:v','h264_nvenc','-profile:v','high','-pix_fmt','yuv420p','-g','30',
                        '-preset','p7','-tune','hq','-rc','constqp','-qp','18',
                        '-rc-lookahead','20','-spatial_aq','1','-aq-strength','15','-b:v','0')
            Write-Host 'Codec H.264'
        }
        $ffArgs += @('-map','0:a?','-c:a','copy','-fps_mode','passthrough',$out)
        & $ffmpeg @ffArgs
        if ($LASTEXITCODE -ne 0) { throw "$($job.Label) upscale failed, exit $LASTEXITCODE" }

        $ow2, $oh2 = Get-VideoSize $out
        $sizeMb = [math]::Round((Get-Item $out).Length / 1MB, 1)
        if ($ow2 -ne $ow -or $oh2 -ne $oh) { throw "Verify failed: $($job.Label) expected ${ow}x${oh}, got ${ow2}x${oh2}" }
        Write-Host "OK $($job.Label) ${ow2}x${oh2} ${sizeMb} MB"
        Write-Host "RESULT_PATH=$out"
        $ok += $out
    }
}
if ($ok.Count -eq 0) { throw 'No video was upscaled.' }
Write-Host ""
Write-Host 'All done.'
Pause-IfNeeded ''
