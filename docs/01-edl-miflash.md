# 01 - EDL and MiFlash troubleshooting

Symptoms this phase solves:

- MiFlash shows `cannot receive hello packet, MiFlash is trying to reset status!`
- Shortly after, the status flips to a `.NET` "object reference not set to an
  instance of an object" error
- The device sits in Qualcomm HS-USB QDLoader 9008 but nothing flashes

## What is actually happening

EDL flashing has two stages:

1. **Sahara** handshake over the 9008 serial port: hello, chip info, then
   upload of a device-matched Firehose programmer (`.mbn`/`.elf`) into RAM.
2. **Firehose** commands over the same port to actually read/write eMMC.

Most "MiFlash cannot receive hello packet" loops are not phone problems. They
are host-side transport problems:

- **Windows/pyserial drops the hello.** pyserial's Windows `open()` calls
  `PurgeComm` with `PURGE_RXCLEAR | PURGE_RXABORT`, which can discard the
  Sahara hello that arrived before the host was listening. Workaround: wrap
  port-open so the RX-clear flags are masked out during open only. Do not
  patch your installed pyserial globally; scope the override to the one
  `connect()` call.
- **Wrong or duplicated port selection.** If more than one
  `VID_05C6&PID_9008` device ever appears, any tool that "just picks one"
  will eventually pick wrong. Refuse to proceed unless exactly one 9008
  device exists.
- **Misleading error strings.** Some EDL forks have a misaligned status
  table; e.g. Sahara status `0x01` prints as "protocol version mismatch" in
  one table but is actually `SAHARA_NAK_INVALID_CMD`. Trust the numeric code,
  not the string.
- **MiFlash itself.** MiFlash's reset loop and the follow-up null-reference
  error are MiUI-flasher quirks, not a bricked phone. If MiFlash keeps
  looping, drop to `edl` (bkerler) with a strict port-open wrapper instead of
  fighting the GUI.

## Checklist before any EDL session

1. Phone fully powered off, then boot to 9008 (device-specific key combo,
   typically both volume keys while plugging USB on this class of device).
2. Device manager shows exactly one `Qualcomm HS-USB QDLoader 9008 (COMx)`.
3. You have a programmer matched to the SoC (for MSM8940-class devices, the
   generic msm8937-family programmers in bkerler/Loaders or vendor-specific
   collections work - confirm chip info via Sahara readback before trusting
   it).
4. Your first commands are read-only: hello, chip serial/HWID readback,
   `getstorageinfo`, GPT read. A tool that insists on writing before it has
   proven the link is a tool you stop using.

## The write-path trap found on this device

During the real session behind this playbook, an initial `aboot` write
"succeeded" but readback showed a block-shifted image: the writer split
payload into multiple 4 KiB serial writes and the link silently mis-chunked.
The fix that made writes reliable:

- negotiate a **16 KiB Firehose payload**
- send **each block as a single OS-level write** (no manual chunking)
- treat any short write as a fatal error
- after programming, **hash the entire partition on-device** and compare to
  the expected SHA-256 before rebooting

A corrupted `aboot` recovered cleanly only because a full partition backup
existed. See [02-backup-and-flash.md](02-backup-and-flash.md).

## Manual-vs-automatic entry into 9008

`adb reboot edl` may simply reboot normally on some ROMs. If you rely on it,
run a watcher that waits up to ~15 minutes for a 9008 port to appear and
fails cleanly otherwise - never assume the mode changed.
