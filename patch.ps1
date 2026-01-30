# UpdateFirmware VID Check Bypass Patch
# Patches UpdateFirmware.exe to bypass the VID comparison that fails due to
# a DLL buffer bug (VID string not null-terminated, causing parse issues).

$ErrorActionPreference = "Stop"

$inputFile = "UpdateFirmware.exe"
$outputFile = "UpdateFirmware_patched.exe"
$patchOffset = 0x2BE2
$originalByte = 0x7B  # jnp (jump if not parity)
$patchedByte = 0xEB   # jmp (unconditional jump)

Write-Host "UpdateFirmware VID Check Bypass Patch" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# Check input file exists
if (-not (Test-Path $inputFile)) {
    Write-Host "ERROR: $inputFile not found in current directory." -ForegroundColor Red
    Write-Host "Place this script in the same directory as UpdateFirmware.exe" -ForegroundColor Yellow
    exit 1
}

# Read the file
Write-Host "Reading $inputFile..."
$bytes = [System.IO.File]::ReadAllBytes((Resolve-Path $inputFile))

# Verify original byte
$currentByte = $bytes[$patchOffset]
Write-Host ("Byte at offset 0x{0:X4}: 0x{1:X2}" -f $patchOffset, $currentByte)

if ($currentByte -eq $patchedByte) {
    Write-Host ""
    Write-Host "File is already patched!" -ForegroundColor Yellow
    exit 0
}

if ($currentByte -ne $originalByte) {
    Write-Host ""
    Write-Host ("ERROR: Unexpected byte at offset 0x{0:X4}" -f $patchOffset) -ForegroundColor Red
    Write-Host ("Expected: 0x{0:X2}, Found: 0x{1:X2}" -f $originalByte, $currentByte) -ForegroundColor Red
    Write-Host "This may be a different version of UpdateFirmware.exe" -ForegroundColor Yellow
    exit 1
}

# Apply patch
Write-Host ""
Write-Host "Applying patch..." -ForegroundColor Green
Write-Host ("  0x{0:X2} (jnp) -> 0x{1:X2} (jmp)" -f $originalByte, $patchedByte)
$bytes[$patchOffset] = $patchedByte

# Write output file
[System.IO.File]::WriteAllBytes($outputFile, $bytes)
Write-Host ""
Write-Host "Patch applied successfully!" -ForegroundColor Green
Write-Host "Output: $outputFile" -ForegroundColor Cyan
