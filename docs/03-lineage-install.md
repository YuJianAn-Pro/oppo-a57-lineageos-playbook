# 03 - Installing LineageOS 21 via TWRP

## Preflight inside TWRP

- Confirm `adb devices` shows the device as `recovery` and TWRP version is
  what you flashed (3.7.1_12-4 for A57 here).
- Verify the ROM zip **on the host**: SHA-256 plus `zipfile.testzip()` for
  every member. Re-verify the same hash **on the device after pushing**.
- Read the ROM's `META-INF/com/android/` update script: confirm it targets
  your device codename and expected partitions (here: `system`, `oem` as
  vendor, `boot`, matching block counts).

## Data format (this is the destructive step - say it out loud)

`twrp format data` erases all personal files and converts userdata to the
filesystem the ROM expects (f2fs here). There is no undo. The backup from
phase 02 does **not** contain personal files.

Do not run "wipe" more than once, and do not let any automated script touch
`reserve`/`metadata`-style partitions that the ROM's fstab marks for
first-stage mount - let the ROM's own first boot handle them.

## Install and what the logs must show

`twrp install /data/<rom>.zip` should end with updater `RC=0` and
`script succeeded`. Afterwards, verify, don't believe:

- read back `boot` (prefix length = image size) and hash-compare to the
  image inside the zip
- `vendor` on this ROM is **squashfs**: TWRP mounting it as ext4 fails with
  `Invalid argument` and that is expected, not corruption. Mount read-only
  as squashfs instead and sanity-check contents (camera HAL present, fstab
  sane).
- check `system/build.prop`: release, SDK, `ro.lineage.version`, security
  patch level.

## First boot - what "normal" looks like

- Three pulsing dots for several minutes is normal on first boot of this
  build. Anything under ~8-10 minutes with the device still enumerating
  (MTP appears even though ADB is not yet authorized) is not a bootloop.
- Windows will show the phone as a portable device (MTP) before USB
  debugging is re-authorized. ADB disappearing at this stage is expected.
- After the setup wizard, re-enable USB debugging, re-authorize the host,
  then verify: `sys.boot_completed=1`, `init.svc.bootanim=stopped`,
  `device_provisioned=1`, both cameras enumerated, camera app opens.

## USB debugging that turns itself off

Some ColorOS-era habits break on a fresh ROM: if USB debugging
authorization keeps expiring during long operations, keep a harmless ADB
heartbeat running on the host (see `scripts/Invoke-AdbKeepAlive.ps1`).
A short `adb shell echo` every ~20 s was enough to keep the link authorized
through hours of flashing work.
