# scripts/

Small, self-contained safety helpers. None of these flash anything by
themselves; they exist to catch the failure classes documented in `docs/`.

| Script | What it does | When to use it |
|---|---|---|
| `Invoke-AdbKeepAlive.ps1` | Sends a harmless `echo` to every authorized adb device on an interval; logs connect/authorize state changes. | During any long flashing/rooting session where USB debugging might time out. |
| `Assert-AndroidXmlNoBom.ps1` | Fails if an XML file starts with a UTF-8 BOM or does not parse. | On every XML inside a Magisk/GApps module before `adb push` (see docs/05). |
| `Compare-PartitionHash.ps1` | Hashes a partition on-device (requires `su` usable from adb shell) and compares to a local image hash; exits non-zero and tells you NOT to reboot on mismatch. | Immediately after every manual partition write (see docs/02, docs/04). |

All scripts take `-AdbPath` and `-Serial` parameters; nothing is hardcoded to
a specific machine or device.
