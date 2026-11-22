@echo off
REM Builds language_builder for Windows (MSVC) into ..\build\language_builder\language_builder.exe
REM
REM Usage: build.bat [-d|-r]       -d debug (default), -r release
REM
REM Needs cOMS next to this repository (..\cOMS, the engine defines the file formats)
REM
REM The target architecture (x64 or arm64) is the one of the developer environment:
REM     * already inside of a developer prompt (DevEnvDir set, e.g. the CI): that environment is used
REM     * otherwise the latest Visual Studio is located with vswhere and set up for the cpu of this machine
setlocal enabledelayedexpansion

set "EXE_NAME=language_builder"
set "SCRIPT_DIR=%~dp0"
set "DESTINATION_DIR=%SCRIPT_DIR%..\build\language_builder"

if not exist "%SCRIPT_DIR%..\cOMS\stdlib\Types.h" (
    echo ERROR: cOMS not found next to this repository ^(%SCRIPT_DIR%..\cOMS^)
    exit /b 1
)

if defined DevEnvDir goto :env_ready

set "HOST_ARCH=x64"
if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" set "HOST_ARCH=arm64"

set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
if not exist "%VSWHERE%" (
    echo ERROR: vswhere.exe not found, install Visual Studio with the C++ workload
    exit /b 1
)

set "VS_PATH="
for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -property installationPath`) do set "VS_PATH=%%i"
if not defined VS_PATH (
    echo ERROR: no Visual Studio installation found
    exit /b 1
)

REM vcvarsall itself calls vswhere through the PATH
set "PATH=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer;%PATH%"
call "%VS_PATH%\VC\Auxiliary\Build\vcvarsall.bat" %HOST_ARCH% > NUL
if errorlevel 1 (
    echo ERROR: vcvarsall.bat %HOST_ARCH% failed
    exit /b 1
)

:env_ready
set "TARGET_ARCH=%VSCMD_ARG_TGT_ARCH%"
if not defined TARGET_ARCH set "TARGET_ARCH=%Platform%"
if /i not "%TARGET_ARCH%"=="x64" if /i not "%TARGET_ARCH%"=="arm64" (
    echo ERROR: unsupported target architecture "%TARGET_ARCH%" ^(x64 or arm64^)
    exit /b 1
)

if not exist "%DESTINATION_DIR%" mkdir "%DESTINATION_DIR%"
del "%DESTINATION_DIR%\*.pdb" /F /Q > NUL 2> NUL
del "%DESTINATION_DIR%\*.idb" /F /Q > NUL 2> NUL

set "BUILD_TYPE=DEBUG"
set "BUILD_FLAGS=/Od /Z7 /WX /FC /RTC1 /DDEBUG"
set "DEBUG_DATA=/Fd"%DESTINATION_DIR%\%EXE_NAME%.pdb" /Fm"%DESTINATION_DIR%\%EXE_NAME%.map""

if "%~1"=="-r" (
    set "BUILD_TYPE=RELEASE"
    set "BUILD_FLAGS=/O2 /D NDEBUG"
    set "DEBUG_DATA="
)

REM No cpu feature flags (__SSE4_2__, __AVX2__, ...): cOMS uses its portable code paths -> the exe runs on every cpu
REM of the architecture. /fp:precise: the output files are the same on every platform (the tests compare them)
set "DEFAULT_COMPILER_ARGS=/Oi /MT /nologo /Gm- /GR- /EHsc /W4 /wd4201 /wd4706 /wd4324 /Zc:wchar_t /Zc:forScope /Zc:inline /permissive- /std:c++20 /fp:precise /D CPP_VERSION=20 /D _WIN32 /D _WINDOWS /D _UNICODE /D UNICODE /D _CRT_SECURE_NO_WARNINGS"

echo Building %EXE_NAME% (%BUILD_TYPE%, %TARGET_ARCH%)

cl ^
    %BUILD_FLAGS% %DEFAULT_COMPILER_ARGS% ^
    /Fo"%DESTINATION_DIR%/" /Fe"%DESTINATION_DIR%/%EXE_NAME%.exe" %DEBUG_DATA% ^
    "%SCRIPT_DIR%%EXE_NAME%.cpp" ^
    /link /INCREMENTAL:no /SUBSYSTEM:CONSOLE ^
    kernel32.lib user32.lib gdi32.lib winmm.lib

if errorlevel 1 (
    echo ERROR: %EXE_NAME% compile/link failed
    endlocal
    exit /b 1
)

endlocal
exit /b 0
