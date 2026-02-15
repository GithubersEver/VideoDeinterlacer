@echo off
setlocal EnableDelayedExpansion

REM --- SILICON PREDATOR WINDOWS EDITION ---

set OUTPUT_DIR=PREDATOR_OUTPUT
set LOG_FILE=PREDATOR_LOG.txt
set PREVIEW_TIME=10
set ANALYZE_TIME=8
set PRESET=slow

if not exist "%OUTPUT_DIR%" mkdir "%OUTPUT_DIR%"
if not exist "%LOG_FILE%" type nul > "%LOG_FILE%"

REM =========================================
REM GET NEXT TAPE NUMBER
REM =========================================

set TAPE_COUNTER=1

for %%f in ("%OUTPUT_DIR%\Tape_*.mp4") do (
    set NAME=%%~nf
    for /f "tokens=2 delims=_" %%a in ("!NAME!") do (
        set NUM=%%a
        set /a NUM+=1
        set TAPE_COUNTER=!NUM!
    )
)

REM =========================================
REM INPUT MODE
REM =========================================

echo.
echo Select input mode:
echo 1^) One video
echo 2^) Folder (sequential)
echo 3^) Current directory
set /p INPUT_MODE=Choice:

if "%INPUT_MODE%"=="1" (
    set /p FILE_INPUT=Enter full video path:
    set FILE_LIST="%FILE_INPUT%"
)

if "%INPUT_MODE%"=="2" (
    set /p FOLDER_INPUT=Enter folder path:
    set FILE_LIST=
    for /r "%FOLDER_INPUT%" %%f in (*.mov *.mp4 *.avi *.mkv) do (
        call :PROCESS_FILE "%%f"
    )
    goto END
)

if "%INPUT_MODE%"=="3" (
    for %%f in (*.mov *.mp4 *.avi *.mkv) do (
        call :PROCESS_FILE "%%f"
    )
    goto END
)

call :PROCESS_FILE "%FILE_LIST%"
goto END

REM =========================================
REM PROCESS FILE FUNCTION
REM =========================================

:PROCESS_FILE
set FILE=%~1

findstr /C:"DONE|%FILE%" "%LOG_FILE%" >nul
if %errorlevel%==0 (
    echo Skipping completed: %FILE%
    goto :eof
)

echo.
echo Processing %FILE%

REM ---------- ANALYSIS ----------
echo Analyzing video...
ffmpeg -hide_banner -i "%FILE%" -t %ANALYZE_TIME% -vf signalstats -f null NUL

echo Choose encoder:
echo 1^) CPU x265
echo 2^) VideoToolbox / NVENC / QSV (hardware)
set /p MODE=Choice:

if "%MODE%"=="1" (
    set ENCODER=cpu
    set /p CRF=Enter CRF (18-24):
) else (
    set ENCODER=vt
    set /p BITRATE=Enter bitrate (example 12M):
)

REM ---------- PREVIEWS ----------

ffmpeg -hide_banner -i "%FILE%" -t %PREVIEW_TIME% ^
-vf bwdif=mode=1:parity=1 ^
-c:v hevc_qsv -b:v 10M "%OUTPUT_DIR%\preview_bff.mp4"

ffmpeg -hide_banner -i "%FILE%" -t %PREVIEW_TIME% ^
-vf bwdif=mode=1:parity=0 ^
-c:v hevc_qsv -b:v 10M "%OUTPUT_DIR%\preview_tff.mp4"

start "" "%OUTPUT_DIR%\preview_bff.mp4"
timeout /t 1 >nul
start "" "%OUTPUT_DIR%\preview_tff.mp4"

set /p CHOICE=Correct field order (bff/tff/skip):

echo STARTED|%FILE%>>"%LOG_FILE%"

set TAPE_NAME=Tape_00%TAPE_COUNTER%
if %TAPE_COUNTER% GEQ 10 set TAPE_NAME=Tape_0%TAPE_COUNTER%
if %TAPE_COUNTER% GEQ 100 set TAPE_NAME=Tape_%TAPE_COUNTER%

REM ---------- ENCODE ----------

if "%ENCODER%"=="cpu" (

    ffmpeg -hide_banner -i "%FILE%" ^
    -vf bwdif=mode=1 ^
    -c:v libx265 -preset %PRESET% -crf %CRF% ^
    -c:a aac -b:a 192k ^
    "%OUTPUT_DIR%\%TAPE_NAME%_CPU_HEVC.mp4"

) else (

    ffmpeg -hide_banner -i "%FILE%" ^
    -vf bwdif=mode=1 ^
    -c:v hevc_qsv -b:v %BITRATE% ^
    -c:a aac -b:a 192k ^
    "%OUTPUT_DIR%\%TAPE_NAME%_VT_HEVC.mp4"
)

if %errorlevel%==0 (
    echo DONE|%FILE%>>"%LOG_FILE%"
    set /a TAPE_COUNTER+=1
)

del "%OUTPUT_DIR%\preview_*.mp4" >nul 2>&1

goto :eof

:END
echo.
echo ALL TASKS COMPLETE
pause
