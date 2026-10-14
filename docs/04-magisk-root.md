# 04 - Magisk root on the A57 (the fake-signature trap)

This is the phase where generic Magisk tutorials will bootloop this device.

## The device-specific problem

The A57's boot chain expects an OPPO-style trailing signature on the boot
image (see `affggh/oppo_fake_signature`). Magisk's official `boot_patch.sh`
produces a perfectly valid **generic** Android boot image - which this
device's bootloader will reject or fail to boot, because the expected tail
structure is missing.

Consequences:

- **Do not** use Magisk app's "Direct Install" blindly.
- **Do not** flash a Magisk-patched boot image with a generic flasher.
- The compatible `aboot` from phase 02 relaxes some checks, but the boot
  image still needs the expected tail re-applied after Magisk re-packs it.

## The safe procedure (what worked)

1. **Back up the working partitions first.** Full-partition dumps of `boot`
   and `recovery` with SHA-256, pulled to the host and re-verified. These
   are your one-command rollback.
2. **Patch on-device, file-only.** Push the stock ROM's `boot.img` and the
   official Magisk `boot_patch.sh` to an isolated directory on the device
   and run it there. Insist the script runs in patch-only mode: no direct
   flashing, no wipes. Record its environment detection (SAR, ramdisk,
   KEEPVERITY, KEEPFORCEENCRYPT) - on this device: SAR=true, ramdisk=yes,
   keep verity/forceencrypt, preinit on `cache`.
3. **Audit the patched image instead of trusting it.** Unpack both the
   original and patched images and verify:
   - kernel bytes identical
   - original ramdisk entries unchanged except `init` (which becomes an xz
     backup) plus the expected Magisk additions
   - new binaries match the exact bytes shipped in the official Magisk APK
     (same version, hashed)
   - header fields only differ where expected
4. **Re-apply the device signature tail**, at the offset the project's
   algorithm computes for the new image layout. Do not use the upstream
   heuristic that guesses offsets from strings - compute it from the actual
   v0 header fields (`page`, kernel/ramdisk sizes).
5. **Hash full-partition payloads** (zero-padded to partition size) before
   writing.
6. **Write only `boot`.** Not `recovery`, not `aboot`, not GPT. Read back
   the full partition and compare SHA-256 before rebooting.
7. **Reboot, then let Magisk's own "fix environment" flow run** (it extracts
   files and reboots again; per its own source, it does not re-patch boot).

## Post-root verification checklist

- `sys.boot_completed=1`, bootanim stopped
- `magisk -v` / daemon alive, manager shows matching version codes
- plain `adb shell id` still uid=2000 (shell), while `su -c id` returns
  uid=0 with the Magisk SELinux context - that pairing proves root comes
  from Magisk, not from a permissive adbd
- `getenforce` still `Enforcing`
- after the second (environment-fix) reboot, boot/recovery hashes are
  byte-identical to the verified images

## Do not

- Do not enable "grant root to everything" or auto-response.
- Do not stack random modules immediately. One variable at a time.
- Do not re-lock the bootloader, flash stock `aboot` over the compatible
  one, or flash another model's boot image "to fix" a bootloop - restore
  your verified `boot` backup instead.
