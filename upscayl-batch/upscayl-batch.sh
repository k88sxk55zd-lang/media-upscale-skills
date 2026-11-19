#!/bin/bash
# Upscayl batch upscaler (Git Bash) - portable version
# Usage: bash upscayl-batch.sh "input_dir" ["output_dir"]
# Fixed rules: 2x / PNG lossless(0) / ultrasharp-4x / TTA off / GPU 0 / single-image loop
# Path resolution: env var UPSCAYL_EXE / UPSCAYL_MODELS -> "阿普升图" on common drives -> common install paths
set -u

SRC="${1:-}"
if [ -z "$SRC" ]; then echo "[ERROR] no input folder given"; exit 1; fi
OUT="${2:-$SRC/upscaled_2x}"

# ---------- config resolution ----------
EXE="${UPSCAYL_EXE:-}"
MODELS="${UPSCAYL_MODELS:-}"
MODEL="${UPSCAYL_MODEL:-ultrasharp-4x}"
SCALE="${UPSCAYL_SCALE:-2}"

if [ -z "$EXE" ]; then
  # "阿普升图" built from UTF-8 bytes so this file stays ASCII-safe conceptually
  appname=$'\xe9\x98\xbf\xe6\99\xae\xe5\x8d\x87\xe5\x9b\xbe'
  for drv in /c /d /e /f /g /h /i /j /k /s; do
    if [ -f "$drv/$appname/resources/bin/upscayl-bin.exe" ]; then
      EXE="$drv/$appname/resources/bin/upscayl-bin.exe"; break
    fi
  done
fi
if [ -z "$EXE" ]; then
  for base in "$LOCALAPPDATA/Programs/Upscayl" "$PROGRAMFILES/Upscayl"; do
    if [ -f "$base/resources/bin/upscayl-bin.exe" ]; then EXE="$base/resources/bin/upscayl-bin.exe"; break; fi
  done
fi
if [ -z "$EXE" ] || [ ! -f "$EXE" ]; then
  echo "[ERROR] upscayl-bin.exe not found. Set UPSCAYL_EXE env var."; exit 1
fi
if [ -z "$MODELS" ]; then
  root="$(dirname "$(dirname "$(dirname "$EXE")")")"
  MODELS="$root/resources/models"
  [ -d "$MODELS" ] || MODELS="${EXE%/resources/bin/upscayl-bin.exe}/resources/models"
fi
if [ ! -d "$MODELS" ]; then echo "[ERROR] model dir not found: $MODELS (set UPSCAYL_MODELS)"; exit 1; fi

[ -d "$SRC" ] || { echo "[ERROR] input folder not found: $SRC"; exit 1; }
mkdir -p "$OUT"
ERRLOG="$OUT/_errors.log"; : > "$ERRLOG"
MIN_BYTES=10000

echo "===== Upscayl batch ====="
echo "EXE   : $EXE"
echo "MODEL : $MODEL  SCALE: $SCALE"
echo "IN    : $SRC"
echo "OUT   : $OUT"
echo "-------------------------"

total=0; done_n=0; skip=0; fail=0
for f in "$SRC"/*.png "$SRC"/*.jpg "$SRC"/*.jpeg "$SRC"/*.webp; do
  [ -e "$f" ] || continue
  name="$(basename "${f%.*}").png"
  total=$((total+1))
  dst="$OUT/$name"
  if [ -f "$dst" ] && [ "$(wc -c < "$dst" 2>/dev/null || echo 0)" -ge "$MIN_BYTES" ]; then
    skip=$((skip+1)); echo "[$total] SKIP $name"; continue
  fi
  "$EXE" -i "$f" -o "$dst" -m "$MODELS" -n "$MODEL" -s "$SCALE" -f png -c 0 -g 0 >>"$ERRLOG" 2>&1
  rc=$?
  size=$(wc -c < "$dst" 2>/dev/null || echo 0)
  if [ $rc -eq 0 ] && [ -f "$dst" ] && [ "$size" -ge "$MIN_BYTES" ]; then
    done_n=$((done_n+1)); echo "[$total] OK   $name"
  else
    fail=$((fail+1)); echo "[$total] FAIL $name (rc=$rc size=${size}B) see _errors.log"
  fi
done

echo "-------------------------"
echo "===== total=$total new=$done_n skip=$skip fail=$fail ====="
[ "$fail" -eq 0 ] && rm -f "$ERRLOG"

# Optional dimension verification (needs PIL). Convert /c/ -> C:/ for native python.
OUT_WIN="$(cygpath -w "$OUT" 2>/dev/null || echo "$OUT")"
OUT_WIN="$OUT_WIN" python -c "
import glob,os
try:
    from PIL import Image
except ImportError:
    print('(PIL not available, skip dimension check)'); raise SystemExit
out=os.environ['OUT_WIN']
files=[x for x in glob.glob(os.path.join(out,'*.png')) if not os.path.basename(x).startswith('_')]
sizes={}; bad=[]
for x in files:
    try:
        w,h=Image.open(x).size; sizes['%dx%d'%(w,h)]=sizes.get('%dx%d'%(w,h),0)+1
    except Exception: bad.append(os.path.basename(x))
print('verify: %d files, sizes=%s'%(len(files),sizes))
print('corrupt:', bad if bad else 'none')
" 2>/dev/null || echo "(python/PIL check skipped)"
