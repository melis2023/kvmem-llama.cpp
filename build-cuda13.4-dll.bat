@echo off
setlocal
REM ============================================================
REM  kvmem  CUDA 13.4  dll+exe  one-click build (self-contained)
REM  Supported GPUs: RTX30(75) / RTX40(89) / RTX50(120a) / some(86)
REM  NOTE: RTX 5060 Ti (sm_120) - use THIS script.
REM        V100/RTX20 users use the 12.4 script (build-cuda12.4-dll.bat)
REM ============================================================

REM ---------- EDITABLE PARAMS (independent of the 12.4 script) ----------
set "SRC_DIR=%~dp0"
set "BUILD_DIR=%SRC_DIR%build-cuda13.4-dll"
set "NVCC=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4\bin\nvcc.exe"
set "CUDA_BIN=C:\Program Files\NVIDIA GPU Computing Toolkit\CUDA\v13.4\bin"
set "CUDA_ARCH=75-real;86-real;89-real;120a-real"
set "TARGETS=llama-kvmem-server llama-kvmem-cli"
set "JOBS=8"
REM ---------------------------------------------------------------------

echo.
echo  ============================================
echo   kvmem CUDA 13.4 dll+exe build
echo   arch: %CUDA_ARCH%
echo   dir : %BUILD_DIR%
echo  ============================================
echo.

REM ---- check ninja ----
where ninja >nul 2>nul
if errorlevel 1 (
    echo [ERROR] ninja not found. Install ninja-build and add it to PATH.
    pause & exit /b 1
)

REM ---- check nvcc ----
if not exist "%NVCC%" (
    echo [ERROR] CUDA 13.4 nvcc not found: %NVCC%
    echo         Edit NVCC / CUDA_BIN at the top of this file.
    pause & exit /b 1
)

REM ---- init MSVC env (VsDevShell) ----
set "VSWHERE=%ProgramFiles(x86)%\Microsoft Visual Studio\Installer\vswhere.exe"
for /f "usebackq tokens=*" %%i in (`"%VSWHERE%" -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath`) do set "VS_DIR=%%i"
if not defined VS_DIR (
    echo [ERROR] Visual Studio not found.
    pause & exit /b 1
)
call "%VS_DIR%\VC\Auxiliary\Build\vcvars64.bat" >nul

REM ---- prepend CUDA 13.4 to PATH ----
set "PATH=%CUDA_BIN%;%CUDA_BIN%\x64;%PATH%"

REM ---- configure (only when cache missing) ----
if not exist "%BUILD_DIR%\CMakeCache.txt" (
    echo [1/2] Configuring CMake ...
    cmake -S "%SRC_DIR%" -B "%BUILD_DIR%" -G Ninja -DCMAKE_BUILD_TYPE=Release ^
        -DBUILD_SHARED_LIBS=ON ^
        "-DCMAKE_CUDA_COMPILER=%NVCC%" ^
        "-DCMAKE_CUDA_ARCHITECTURES=%CUDA_ARCH%" ^
        -DGGML_CUDA_FA_ALL_QUANTS=ON
    if errorlevel 1 ( echo [ERROR] CMake configure failed & pause & exit /b 1 )
) else (
    echo [1/2] Already configured, skipping cmake configure.
    echo         To reconfigure, delete %BUILD_DIR% and rerun.
)

REM ---- build ----
echo [2/2] Building %TARGETS% ...
cmake --build "%BUILD_DIR%" --target %TARGETS% --parallel %JOBS%
if errorlevel 1 ( echo [ERROR] Build failed & pause & exit /b 1 )

echo.
echo  ============================================
echo   BUILD OK!
for %%f in ("%BUILD_DIR%\bin\llama-kvmem-server.exe" "%BUILD_DIR%\bin\llama-kvmem-cli.exe") do (
    if exist %%f echo     %%~nxf
)
echo   output dir: %BUILD_DIR%\bin
echo  ============================================
pause
exit /b 0