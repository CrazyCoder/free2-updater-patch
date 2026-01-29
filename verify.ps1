# UpdateFirmware Patch Verification Script
# Compares original and patched files to verify the patch was applied correctly.

$originalFile = "UpdateFirmware.exe"
$patchedFile = "UpdateFirmware_patched.exe"
$patchOffset = 0x2BE2

Write-Host "UpdateFirmware Patch Verification" -ForegroundColor Cyan
Write-Host "==================================" -ForegroundColor Cyan
Write-Host ""

$hasOriginal = Test-Path $originalFile
$hasPatched = Test-Path $patchedFile

if (-not $hasOriginal -and -not $hasPatched) {
    Write-Host "ERROR: No files found to verify." -ForegroundColor Red
    Write-Host "Expected: $originalFile and/or $patchedFile" -ForegroundColor Yellow
    exit 1
}

Write-Host ("Patch offset: 0x{0:X4} ({0} decimal)" -f $patchOffset)
Write-Host ""

if ($hasOriginal) {
    $origBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $originalFile))
    $origByte = $origBytes[$patchOffset]
    $origStatus = if ($origByte -eq 0x7B) { "ORIGINAL (unpatched)" }
                  elseif ($origByte -eq 0xEB) { "PATCHED" }
                  else { "UNKNOWN" }

    Write-Host ("{0}:" -f $originalFile) -ForegroundColor White
    Write-Host ("  Size: {0:N0} bytes" -f $origBytes.Length)
    Write-Host ("  Byte at 0x{0:X4}: 0x{1:X2} - {2}" -f $patchOffset, $origByte, $origStatus)
    Write-Host ""
}

if ($hasPatched) {
    $patchedBytes = [System.IO.File]::ReadAllBytes((Resolve-Path $patchedFile))
    $patchedByte = $patchedBytes[$patchOffset]
    $patchedStatus = if ($patchedByte -eq 0x7B) { "ORIGINAL (unpatched)" }
                     elseif ($patchedByte -eq 0xEB) { "PATCHED" }
                     else { "UNKNOWN" }

    Write-Host ("{0}:" -f $patchedFile) -ForegroundColor White
    Write-Host ("  Size: {0:N0} bytes" -f $patchedBytes.Length)
    Write-Host ("  Byte at 0x{0:X4}: 0x{1:X2} - {2}" -f $patchOffset, $patchedByte, $patchedStatus)
    Write-Host ""
}

# Summary
Write-Host "Expected values:" -ForegroundColor Yellow
Write-Host "  Original: 0x7B (jnp - conditional jump)"
Write-Host "  Patched:  0xEB (jmp - unconditional jump)"
Write-Host ""

if ($hasPatched -and $patchedByte -eq 0xEB) {
    Write-Host "Verification: PASSED" -ForegroundColor Green
} elseif ($hasPatched) {
    Write-Host "Verification: FAILED - Patched file has unexpected byte" -ForegroundColor Red
}
