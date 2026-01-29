# UpdateFirmware VID Check Bypass Patch

A patch for the JieLi firmware updater used by **Free2 Bluetooth page turner** devices. Bypasses the VID (Version ID) check that incorrectly rejects compatible firmware due to floating-point comparison issues.

## Confirmed Working

| Device | Firmware | Category |
|--------|----------|----------|
| **Xteink X4** | E730LJ | Android e-readers, Yuexingtong |

## Downloads

| Resource | Link |
|----------|------|
| **Firmware (E730LJ)** | https://cdn.hanlinyue.com.cn/E730LJ.ufw |
| **Firmware Browser** | https://hanlinyue.com.cn/1755595121764 |
| **Updater App** | https://cdn.hanlinyue.com.cn/hanlinyue-win-1.2.3-ia32.exe |

> **Note:** If the sites don't open, try using a VPN (servers are located in China).

### Locating UpdateFirmware.exe

After installing the updater app, `UpdateFirmware.exe` is located at:
```
C:\Users\<username>\AppData\Local\Programs\hanlinyue\resources\extraResources\exe\
```

Copy the patch scripts to that directory and run them there.

## The Problem

The JieLi firmware updater (`UpdateFirmware.exe`) refuses to flash firmware even when the device and firmware VID (Version ID) appear identical in the UI.

![Error Screenshot](screen.png)

**Error Message:**
```
您的选择的固件与设备不匹配，请检查并更换为正确固件
(The firmware you selected does not match the device, please check and replace with the correct firmware)
```

## Root Cause Analysis

### Why It Fails Even With Matching VIDs

The application reads VID values from UI labels as text strings, converts them to **floating-point numbers** using `QString::toFloat()`, and then compares them:

```c
device_vid = QString::toFloat(label_device_vid->text());
firmware_vid = QString::toFloat(label_vid->text());

if (device_vid == firmware_vid) {
    // Allow upgrade
} else {
    return -30;  // Error: firmware doesn't match
}
```

**The problem:** Floating-point comparison (`==`) is inherently unreliable due to precision limitations. Two VID values that *display* identically (e.g., "1.00") may have slightly different internal representations:
- `1.0000000000` vs `0.9999999999`
- `1.00` vs `1.000000001`

This causes the equality check to fail even when the values appear the same to the user.

### Where The "Garbage" Comes From

The VID values go through multiple conversions:
1. **Firmware file** → Binary data → String → Float
2. **Device query** → DLL response → String → Float

Each conversion can introduce tiny floating-point rounding errors. When comparing these independently-derived floats, the accumulated errors cause `==` to return `false`.

### The Flawed Logic Location

The check occurs in function `sub_403750` at address `0x4037E2`:

```asm
4037e2  jnp     short loc_4037EB     ; Jump to upgrade if VIDs "equal"
4037e4  mov     esi, 0FFFFFFE2h      ; Otherwise: error code -30
```

The `jnp` (jump if not parity) instruction is used after a floating-point comparison, which relies on the CPU's parity flag to determine equality—an approach that fails with imprecise floats.

## The Patch

The patch changes the conditional jump to an **unconditional jump**, bypassing the VID comparison entirely:

| Item | Original | Patched |
|------|----------|---------|
| Address | `0x4037E2` (VA) / `0x2BE2` (file) | Same |
| Bytes | `7B 07` (`jnp +7`) | `EB 07` (`jmp +7`) |
| Effect | Jump if VIDs equal | Always jump (bypass check) |

This allows flashing any firmware regardless of VID mismatch, which is safe for compatible devices where only the version numbering differs.

## Usage

### Pre-patched Download

Both the original and patched `UpdateFirmware.exe` files are available in the [Releases](../../releases) section of this repository.

### Apply the Patch Yourself

**PowerShell:**
```powershell
.\patch.ps1
```

**Command Prompt:**
```cmd
patch.cmd
```

Both scripts will:
1. Read `UpdateFirmware.exe` from the current directory
2. Patch byte at offset `0x2BE2`: `7B` → `EB`
3. Write `UpdateFirmware_patched.exe`

### Verify the Patch

```powershell
.\verify.ps1
```

## Technical Details

### Compatibility

This patch was developed for a specific version of the updater:

| Item | Value |
|------|-------|
| Updater App | hanlinyue-win-1.2.3-ia32 |
| Target File | `UpdateFirmware.exe` |
| SHA256 | `76924667c6a75fec3a34f8a432c643e5a8cced3e0bca07866f0d69d1d2431e90` |

> **Warning:** If your `UpdateFirmware.exe` has a different hash, the patch offset may be incorrect. Verify the hash before patching, or use the verify script after patching to confirm the correct bytes were modified.

### Patch Location

- **Virtual Address:** `0x4037E2`
- **File Offset:** `0x2BE2`
- **Section:** `.text`
- **Function:** `sub_403750` (manual flash handler)

### Why This Patch Is Safe

The patch only bypasses the **VID comparison** in the EXE. The actual firmware flashing is performed by the DLL (`jl_firmware_upgrade_x86.dll`), which has its own internal validation. If the firmware is truly incompatible with the hardware, the DLL will reject it.

## Disclaimer

Use at your own risk. Flashing incompatible firmware can brick your device. This patch is intended for cases where the firmware is known to be compatible but the updater incorrectly rejects it due to version number formatting differences.
