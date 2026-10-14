# 02 - Backup and safe flashing

Goal of this phase: prove you can restore the phone before you change it.

## Full backup first

Once the Firehose programmer is loaded and the link verified:

1. Read and validate **both** primary and backup GPT: CRC32 of the header,
   CRC32 of the partition entries, and that both tables agree.
2. Read every partition **except `userdata` and `cache`** (large, and for a
   planned wipe you do not need them). On the reference device this was
   ~50 partitions, including `boot`, `recovery`, `aboot`, `abootbak`, modem,
   and calibration data.
3. Compute SHA-256 for each file during capture, and **independently
   re-hash every file afterwards**. Treat the backup as non-existent until
   this second pass is clean.
4. Also snapshot the exact byte ranges of any image you intend to flash
   (TWRP, compatible aboot) and record expected full-partition SHA-256s.

Why this matters: the only reason a bad `aboot` write later in the session
was recoverable is that a verified backup existed.

## Write protocol that did not corrupt anything

- Refuse to continue if chip serial / HWID / eMMC geometry do not match the
  values captured at session start.
- Negotiate a 16 KiB payload. Send each chunk with one `write()` call.
  A short write is fatal - stop immediately, leave the session clean, and
  inspect.
- Never run the device-side "reset" until the user is at the phone holding
  whatever key combo the next stage needs.
- After each partition write, read the partition back and compare full
  SHA-256. Not a prefix hash. Not a size match. The whole thing.

With zero-padding (flash writers usually program a full partition), hashing
the entire partition catches offset errors that a prefix-only hash would
miss.

## What was flashed, and what was deliberately not flashed

Flashed, with readback verification:

- a **compatible `aboot`** for this device family (needed so later custom
  images boot - A57 needs the OPPO-style signature story, see
  [04-magisk-root.md](04-magisk-root.md))
- **TWRP** into `recovery`

Deliberately not applied:

- any `patch0.xml`-style partition-table patching
- GPT rewrites
- `abootbak` or any modem/calibration partition
- any third-party flasher's bundled "cleanup" scripts

## After recovery is installed

1. Keep the Firehose session alive (no reset) until the user is physically
   holding the key combo for recovery.
2. Then send the reset and confirm the device enumerates as ADB recovery.
3. Only now proceed to partitioning/format and ROM install
   ([03-lineage-install.md](03-lineage-install.md)).

If anything in the write-verify chain fails: restore the affected partition
from the verified backup in the same session, re-verify, and stop. Do not
"try the write again" on a partition whose state you have not re-proven.
