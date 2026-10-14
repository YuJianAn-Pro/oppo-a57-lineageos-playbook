# 07 - Installing third-party APKs (and fixing the broken ones)

Notes from installing a mixed pile of user-supplied APKs on a fresh rooted
ROM. Useful when "just install it" doesn't just work.

## Triage each file before installing

1. **Check what the file actually is, not its extension.** One file named
   `*.apk.1` was actually a ZIP containing the real APK. `file`,
   `unzip -l`, or a signature-magic check beats trusting the name.
2. **`aapt dump badging`** for package name, versionCode, minSdk/targetSdk,
   and ABI splits. On a modern ROM, very low `targetSdkVersion` APKs may be
   flat-out refused by the installer; know before you try.
3. **`apksigner verify --print-certs`** for signature state.

## Failure: "package appears to be invalid" / missing signature

One APK had no valid signature at all. Android 7+ won't install it, period.
The repair that worked without touching app content:

- `zipalign` the APK
- sign it locally with apksigner and a local test keystore
- verify every non-`META-INF` entry is byte-identical to the original

Consequence to remember: the re-signed app is now signed by **you**, not the
original publisher. An original-signed update will never install over it
(signature mismatch), and any app that pins the publisher certificate will
break. Keep the original file.

## Failure: installer rejects low targetSdk

Modern Android (14+) refuses `adb install` for apps targeting ancient SDKs
unless you pass `--bypass-low-target-sdk-block`. Prefer not to. If you just
want the app for inspection rather than daily driving, extract and read it
instead of weakening install-time policy system-wide.

## Failure: wrong ABI / wrong variant from a bundle

A "zip of APKs" release needs you to pick the device's ABI
(`arm64-v8a` here). Installing a base APK without its config splits also
fails or crashes; when an app ships splits, install them together
(`adb install-multiple`).

## After install

- `pm path <pkg>` and `dumpsys package <pkg>` to confirm the installed
  version is the one you intended, not an older one the store shadowed.
- Grant nothing extra by default. Root, accessibility, device admin, VPN,
  and notification access stay off unless you deliberately turn them on.
- Keep a manifest of what was installed, from where, its SHA-256, and any
  repackaging you did - future-you will need it when something misbehaves.
