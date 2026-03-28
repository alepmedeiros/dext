@echo off
echo.
echo ============================================================
echo   Dext - Build and Test Suite
echo ============================================================
echo.

call "C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat"

REM ProductVersion must match IDE version (37.0) so DCU paths resolve correctly
set MSBUILD_OPTS=/p:Config=Debug /p:Platform=Win32 /p:ProductVersion=37.0 /v:minimal /nologo

echo.
echo [1/4] Building Dext.Core...
msbuild "C:\dev\Dext\DextRepository\Sources\Dext.Core.dproj" /t:Rebuild %MSBUILD_OPTS%
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Build failed for Dext.Core
    exit /b %errorlevel%
)

echo.
echo [2/4] Building Dext.EF.Core...
msbuild "C:\dev\Dext\DextRepository\Sources\Dext.EF.Core.dproj" /t:Rebuild %MSBUILD_OPTS%
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Build failed for Dext.EF.Core
    exit /b %errorlevel%
)

@REM Dext.EntityDataSet.UnitTests
@REM C:\dev\Dext\DextRepository\Tests\Entity\UnitTests\Dext.Entity.UnitTests.dproj

set PROJECT_NAME=Dext.EntityDataSet.Tests
set PROJECT_TO_BUILD=C:\dev\Dext\DextRepository\Tests\Entity\DataSet\%PROJECT_NAME%.dproj
set PROJECT_TO_RUN=C:\dev\Dext\DextRepository\Tests\Output\%PROJECT_NAME%.exe

echo.
echo [3/4] Building %PROJECT_NAME%...
msbuild %PROJECT_TO_BUILD% /t:Rebuild %MSBUILD_OPTS%
if %errorlevel% neq 0 (
    echo.
    echo ERROR: Build failed for %PROJECT_NAME%
    exit /b %errorlevel%
)

echo.
echo [4/4] Running %PROJECT_NAME%...
%PROJECT_TO_RUN%

set EXIT_CODE=%errorlevel%
if %EXIT_CODE% neq 0 (
    echo.
    echo WARNING: Some tests failed (Exit Code: %EXIT_CODE%)
) else (
    echo.
    echo SUCCESS: All tests passed!
)

exit /b %EXIT_CODE%
