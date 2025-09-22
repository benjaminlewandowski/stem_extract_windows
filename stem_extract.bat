@echo off
setlocal enableextensions enabledelayedexpansion

if "%~1" == "" (
    echo Please specify one or more .mp4/.m4a files, or use /d [directory].
    goto :eof
)

REM Directory mode: handle /d outside of parenthesis
if /i "%~1" == "/d" goto :dir_mode

REM Loop over each file argument and call :processfile
for %%F in (%*) do (
    call :processfile "%%~fF"
)
goto :eof

:dir_mode
set "TARGETDIR=%~2"
echo TARGETDIR is [%TARGETDIR%]
if "%TARGETDIR%"=="" (
    echo Please specify a directory after /d.
    goto :eof
)
if not exist "%TARGETDIR%" (
    echo Directory "%TARGETDIR%" does not exist.
    goto :eof
)
pushd "%TARGETDIR%"
set "FILES_FOUND=0"
for %%F in (*.mp4 *.m4a) do (
    set "FILES_FOUND=1"
    call "%~f0" "%%~fF"
)
if "!FILES_FOUND!"=="0" (
    echo No .mp4 or .m4a files found in "%TARGETDIR%".
)
popd
goto :eof

:processfile
setlocal enableextensions enabledelayedexpansion
set "FILENAME=%~1"
set "BASENAME_NO_EXT=%~n1"
set "FILE_EXTENSION=%~x1"

if /i not "!FILE_EXTENSION!" == ".mp4" if /i not "!FILE_EXTENSION!" == ".m4a" (
    echo   Error: This script only works on .mp4 or .m4a Stems files.
    goto :eof
)

set "TRACKCOUNT_PLACEHOLDER=0"
for /f "tokens=*" %%a in ('ffmpeg -i "!FILENAME!" 2^>^&1 ^| findstr /R /C:"Stream #[0-9]:[0-9].*Audio"') do (
    set /a TRACKCOUNT_PLACEHOLDER+=1
)

if not "!TRACKCOUNT_PLACEHOLDER!" == "5" (
    echo   Error: There must be exactly 5 audio tracks in the file.
    goto :eof
)

set "DIRNAME=!BASENAME_NO_EXT!.stems"

if exist "!DIRNAME!" (
    echo Removing existing directory: "!DIRNAME!"
    rd /s /q "!DIRNAME!"
)

if not exist "!DIRNAME!" (
    echo Creating directory: "!DIRNAME!"
    mkdir "!DIRNAME!"
)

for /L %%T in (1,1,5) do (
    set /a "NUM=%%T - 1"
    set "TRACKFILE=!DIRNAME!\!BASENAME_NO_EXT! (Stem !NUM!).mp4"
    if not exist "!TRACKFILE!" (
        echo Extracting track !NUM! to "!TRACKFILE!"
        ffmpeg -i "!FILENAME!" -map 0:a:!NUM! -c:a copy -vn -sn "!TRACKFILE!" -y >nul 2>&1
        if errorlevel 1 (
            echo   Error extracting track !NUM! from "!FILENAME!"
        )
    ) else (
        echo   Skipping: "!TRACKFILE!" already exists.
    )
)
endlocal
goto :eof