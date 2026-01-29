# UpdateFirmware VID Check Bypass Patch

![Free2 Bluetooth Page Turner](free2.png)

A patch for the JieLi firmware updater used by **Free2 Bluetooth page turner** devices. Bypasses the VID (Version ID) check that fails due to a buffer handling bug in the DLL.

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

### The DLL Buffer Bug

The VID comparison fails due to a **buffer handling bug** in `jl_firmware_upgrade_x86.dll`. When the DLL returns the device VID string, it doesn't properly null-terminate the buffer.

**What happens:**

1. The EXE calls `JL_queryDevicePidVid()` in the DLL to get the device VID
2. The DLL writes the VID string (e.g., `"0.12"`) to a buffer but **fails to null-terminate** it
3. The EXE uses `QString::fromLocal8Bit(buffer, -1)` which reads until it finds a null byte
4. This picks up **garbage bytes** (uninitialized memory: `0xFF` = `'я'` in Cyrillic)
5. The UI displays: `"0.12яяяяяяяяяяя"` (VID followed by garbage)
6. `QString::toFloat("0.12яяяяяяяяяяя")` **fails to parse** and returns `0`
7. The comparison `0 == 0.12` fails → **Error -30**

### Debug Evidence

Running with debug output enabled shows the actual parsed values:

```
Device VID (parsed):   0      ← Parse failed due to garbage
Firmware VID (parsed): 0.12  ← Parsed correctly
```

Meanwhile, the UI displays:
- Device VID field: `0.12яяяяяяяяяяя` (garbage visible)
- Firmware VID field: `0.12`

### The Flawed Comparison

The check occurs in function `sub_403750` at address `0x4037E2`:

```c
device_vid = QString::toFloat(label_device_vid->text());   // Returns 0 (parse failure)
firmware_vid = QString::toFloat(label_vid->text());        // Returns 0.12

if (device_vid < 0.01 || device_vid == firmware_vid) {
    // Allow upgrade
} else {
    return -30;  // Error: firmware doesn't match
}
```

Since `device_vid` is `0` (not the actual VID), and `0 != 0.12`, the check fails.

### Why It Works in Chinese Locale

Testing with [Locale Emulator](https://github.com/xupefei/Locale-Emulator) confirmed the bug is **locale-dependent**:

| Locale | Code Page | 0xFF Interpretation | Result |
|--------|-----------|---------------------|--------|
| Chinese (Simplified) | 936 (GBK) | Part of multi-byte sequence | **Works** |
| Cyrillic (Russian) | 1251 | 'я' (valid character) | **Fails** |
| Western European | 1252 | 'ÿ' (valid character) | Likely fails |

In **GBK (Chinese)**, `0xFF` is a lead byte for multi-byte characters. When `QString::fromLocal8Bit()` encounters `0xFF` followed by invalid continuation bytes, it likely stops or handles the error gracefully, resulting in a clean string that parses correctly.

In **single-byte encodings** (CP1251, CP1252), `0xFF` is a valid standalone character, so garbage gets appended to the string.

## The Patch

The patch changes the conditional jump to an **unconditional jump**, bypassing the VID comparison entirely:

| Item | Original | Patched |
|------|----------|---------|
| Address | `0x4037E2` (VA) / `0x2BE2` (file) | Same |
| Bytes | `7B 07` (`jnp +7`) | `EB 07` (`jmp +7`) |
| Effect | Jump if VIDs equal | Always jump (bypass check) |

This allows flashing any firmware regardless of VID mismatch, which is safe for compatible devices where only the version numbering differs.

## Workarounds

### Option 1: Use the Patched EXE (Recommended)

Download the pre-patched `UpdateFirmware.exe` from the [Releases](../../releases) section.

### Option 2: Use Locale Emulator

If you prefer not to patch the executable, you can run it with Chinese locale using [Locale Emulator](https://github.com/xupefei/Locale-Emulator):

1. Download and install [Locale Emulator](https://github.com/xupefei/Locale-Emulator/releases)
2. Run `LEInstaller.exe` and click "Install for current user"
3. Navigate to the UpdateFirmware.exe location:
   ```
   C:\Users\<username>\AppData\Local\Programs\hanlinyue\resources\extraResources\exe\
   ```
4. Right-click `UpdateFirmware.exe` → **Locale Emulator** → **Run in Chinese (Simplified)**
5. Proceed with firmware update as normal

### Option 3: Apply the Patch Yourself

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
