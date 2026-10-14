# 05 - Google apps on LineageOS 21 without a factory reset

## Why the official route doesn't apply here

LineageOS's official guidance (wiki.lineageos.org/gapps) for Android 14
points at MindTheGapps and says: install from recovery **before first boot**,
or factory-reset afterwards. If the phone is already set up and a wipe is
off the table, you need another way.

The approach that worked: a **file-only Magisk module** that overlays a
minimal, original-Google-signed GApps core, with every privilege it needs
explicitly allowlisted and audited.

## Module contents (and what was deliberately excluded)

Included, all with original Google signatures re-verified:

- GMS core, Google Services Framework, Play Store (Phonesky), ConfigUpdater
- Calendar and Contacts sync adapters
- A generated `privapp-permissions` XML: every platform-privileged permission
  each APK requests is either explicitly allowed (only if the reference
  GApps package's own allowlist grants it) or explicitly denied
- A minimal sysconfig XML, trimmed to only the entries scoped to these
  packages
- One single-resource overlay: sets `config_persistentDataPackageName` to
  `com.google.android.gms` (see "The FRP crash" below)

Excluded: every install/uninstall/cleanup script from the donor GApps
package, `system.prop`, sepolicy changes, `SetupWizard`, ExtServices/
ExtShared replacement, `.replace` files, and anything that deletes
`runtime-permissions.xml`, clears app data, resets provisioning flags, or
disables SELinux. The donor package's own scripts did all of those; none of
them ran. To roll back, disable the module and reboot - nothing
un-revertable ever happened.

## Failure 1: the invisible BOM that crashed system_server

The first module boot-looped into `system_server` crash: "privileged
permissions not in allowlist". Root cause: the generated
`privapp-permissions-*.xml` was written with a **UTF-8 BOM**. Android's
`SystemConfig` uses a `FileReader` that does not consume a BOM, so the whole
file failed to parse and the allowlist was empty.

Diagnosis trick: reproduce the failure off-boot with a tiny `app_process`
probe that parses the exact file through `android.util.Xml` (see
`scripts/Assert-AndroidXmlNoBom.ps1` for the host-side preflight).

Fix: write XML as UTF-8 **without BOM**, LF line endings, and assert byte 0
is `<`. Re-validate on-device before rebooting.

## Failure 2: Gmail missing READ_GSERVICES

Gmail installed before GSF defined the (normal) `READ_GSERVICES` permission,
so it was silently not granted. Fix: re-`adb install -r` the same Gmail APK
after core services exist - the permission then grants normally, no data
loss.

## Failure 3: the FRP provider crash

GMS core crashed with `UnsupportedOperationException` from
`PersistentDataBlockService`: the ROM set `ro.frp.pst` to use the `config`
partition, but the `config_persistentDataPackageName` resource was empty,
so the service had no allowed UID (-1).

The donor GApps' own overlay sets this resource to `com.google.android.gms` -
but that overlay also rewrites dozens of unrelated defaults. So instead:
build a tiny code-less overlay APK containing **only** that one string
resource, and place it where the ROM actually mounts overlays
(`/product/overlay`, **not** `/overlay` - the latter didn't exist and the
module silently no-ops). Verify with `cmd overlay list` and a runtime
readback of the resource, and confirm the crash stops and the service's
allowed UID resolves to the Google UID.

This configures a standard Android service; it does not touch, erase, or
bypass FRP data.

## Verification checklist

- All six core packages present as system apps; Play is privileged
- `SELinux: Enforcing`, privapp-whitelist enforcement still on
- provisioning/setup flags untouched; `crash` log buffer empty after boot
- Play opens to the sign-in page and the web sign-in flow loads
- No modified APKs: every shipped APK still carries its original Google
  signature

## Notes

- The pinned packages are not "the latest GApps"; they are a known-good,
  signature-verified set. Update afterwards through normal channels.
- This proves Play/Gmail boot, not Play Integrity, banking apps, or camera
  features. Test what you care about explicitly.
