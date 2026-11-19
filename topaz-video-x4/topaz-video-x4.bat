@echo off
chcp 65001 >nul
rem Drag a video onto this icon -> three presets (1080P/2K/4K).
rem Script path is relative to this .bat, no hardcoded username.
if "%~1"=="" (
  echo Drag a video onto this icon to upscale with local Topaz:
  echo   1080P  1890x1080
  echo   2K     2520x1440
  echo   4K     3780x2160
  echo Output goes next to the source, suffixed _1080p / _2k / _4k.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0topaz-video-x4.ps1" -WaitAtEnd -Preset all %*
