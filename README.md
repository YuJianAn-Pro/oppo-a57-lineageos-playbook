# OPPO A57 (CPH1701) LineageOS 21 Playbook

Field notes and helper scripts from a real, end-to-end flash of an OPPO A57
(CPH1701, MSM8940) to unofficial LineageOS 21 (Android 14), with Magisk root,
a no-wipe Google apps module, and a Wi-Fi captive-portal fix.

> **Warning**
> This playbook involves EDL (Qualcomm 9008) writes, bootloader-adjacent
> partitions, and userdata erasure. It can permanently brick a phone or
> destroy all data on it. It is written for the OPPO A57 only. Using any file,
> offset, or partition map from here on another model will likely brick it.
> Read a full phase before running anything. You are responsible for your
> device and for complying with local law and the terms of the software you
> install.

## What this repository is

A documentation-first playbook: what was done, in what order, what failed
along the way, how each failure was diagnosed, and which invariants were
checked before every write. Companion scripts are generic safety helpers
(keepalive, hash verification, XML sanity checks), not one-click flashers.

## What this repository is not

- Not a ROM, not a firmware package, not a Magisk/GApps distribution.
- No partition images, backups, passwords, subscription data, device serials,
  or personal identifiers are included, and none should ever be committed.
- Not an endorsement of piracy, warranty circumvention, or account abuse.

## Device scope

Tested against exactly one device profile:

- OPPO A57 (CPH1701), Snapdragon 435 / MSM8940, eMMC, A/B-less layout
- Target: unofficial LineageOS 21 (Android 14) build for A57
- Recovery: TWRP 3.7.1_12-4 for A57
- Root: Magisk (tested with v30.x) plus a device-specific boot tail signature
- Host: Windows 10/11 + PowerShell + platform-tools (adb), Python 3 + pyserial

## The workflow at a glance

| Phase | Doc | Key risk it manages |
|---|---|---|
| 1. EDL / MiFlash troubleshooting | [docs/01-edl-miflash.md](docs/01-edl-miflash.md) | Losing the Sahara hello; writing with a flaky transport |
| 2. Backup and safe flashing | [docs/02-backup-and-flash.md](docs/02-backup-and-flash.md) | Corrupt chunk writes; writing before verifying backups |
| 3. LineageOS install via TWRP | [docs/03-lineage-install.md](docs/03-lineage-install.md) | First-boot confusion; fstab/format pitfalls |
| 4. Magisk root on this device | [docs/04-magisk-root.md](docs/04-magisk-root.md) | Boot loop from missing OPPO fake signature |
| 5. Google apps without wiping | [docs/05-gapps-no-wipe.md](docs/05-gapps-no-wipe.md) | BOM-broken XML, missing privapp allowlist, FRP provider crash |
| 6. Wi-Fi "no internet" on hotspot | [docs/06-wifi-captive-portal.md](docs/06-wifi-captive-portal.md) | Misdiagnosing a captive-portal probe failure as a dead radio |
| 7. Installing third-party APKs | [docs/07-sideloading-apks.md](docs/07-sideloading-apks.md) | Unsigned APKs, mislabeled zips, low targetSdk |

## Companion scripts

See [scripts/README.md](scripts/README.md). TL;DR:

- `scripts/Invoke-AdbKeepAlive.ps1` - keep USB debugging alive while you work
- `scripts/Assert-AndroidXmlNoBom.ps1` - catch the UTF-8 BOM that breaks
  Android's privapp permission XML parser
- `scripts/Compare-PartitionHash.ps1` - readback-verify a flashed partition
  over adb before trusting a write

## High-level lessons (the "why" behind every doc)

1. **Verify before write.** Hash the whole partition after every write, on
   the device, and compare against the expected image. A "Success" from a
   flasher UI means nothing on its own.
2. **Watch the transport, not just the payload.** A Sahara/Firehose session
   that loses the hello packet, or a writer that splits blocks across serial
   writes, will corrupt real partitions.
3. **Rollback files first.** You cannot recover from a bad `aboot` write if
   you never backed `aboot` up.
4. **Prefer additive changes.** A file-only Magisk module you can disable
   beats permanently editing `/system` ten times out of ten.
5. **Suspect encoding before content.** One invisible UTF-8 BOM broke an
   entire privileged-permission allowlist and crashed `system_server`.

## Credits and upstream sources

All real credit goes to upstream projects; this repo only documents a path
through them:

- [LineageOS](https://lineageos.org/) and the unofficial A57 lineage thread
  (forums.xda-developers.com, "LineageOS 21 for OPPO A57")
- TWRP A57 builds (`tipzbuilds` on SourceForge)
- [Magisk](https://github.com/topjohnwu/Magisk)
- [bkerler/edl](https://github.com/bkerler/edl) and the
  [bkerler/Loaders](https://github.com/bkerler/Loaders) programmer collection
- [oppo_fake_signature](https://github.com/affggh/oppo_fake_signature)
- [BiTGApps](https://bitgapps.io/) and [MindTheGapps](https://github.com/MindTheGapps)
  (reference material for GApps layout; nothing redistributed here)

## License

MIT - see [LICENSE](LICENSE). No warranty of any kind; see the warning above.
