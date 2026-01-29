@echo off
setlocal enabledelayedexpansion

echo UpdateFirmware VID Check Bypass Patch
echo =====================================
echo.

set "INPUT=UpdateFirmware.exe"
set "OUTPUT=UpdateFirmware_patched.exe"
set "OFFSET=11234"
rem 0x2BE2 = 11234 decimal

if not exist "%INPUT%" (
    echo ERROR: %INPUT% not found in current directory.
    echo Place this script in the same directory as UpdateFirmware.exe
    exit /b 1
)

echo Reading %INPUT%...

rem Use PowerShell for binary manipulation (most reliable on modern Windows)
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$bytes = [System.IO.File]::ReadAllBytes('%INPUT%'); " ^
    "$offset = %OFFSET%; " ^
    "$current = $bytes[$offset]; " ^
    "Write-Host ('Byte at offset 0x{0:X4}: 0x{1:X2}' -f $offset, $current); " ^
    "if ($current -eq 0xEB) { Write-Host ''; Write-Host 'File is already patched!'; exit 0 }; " ^
    "if ($current -ne 0x7B) { Write-Host ''; Write-Host 'ERROR: Unexpected byte value'; exit 1 }; " ^
    "Write-Host ''; " ^
    "Write-Host 'Applying patch...'; " ^
    "Write-Host '  0x7B (jnp) -> 0xEB (jmp)'; " ^
    "$bytes[$offset] = 0xEB; " ^
    "[System.IO.File]::WriteAllBytes('%OUTPUT%', $bytes); " ^
    "Write-Host ''; " ^
    "Write-Host 'Patch applied successfully!'; " ^
    "Write-Host 'Output: %OUTPUT%'"

if errorlevel 1 (
    echo.
    echo Patch failed!
    exit /b 1
)

echo.
pause
