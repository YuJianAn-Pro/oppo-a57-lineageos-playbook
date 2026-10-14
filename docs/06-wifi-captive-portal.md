# 06 - Wi-Fi "connected, no internet" on a hotspot

## Symptom

The phone joins a hotspot, the hotspot side shows the client connected, but
Android reports "no internet" and marks the network unusable.

## What was actually true

Measured from the phone, at that moment:

- Wi-Fi association: COMPLETED; DHCP succeeded; valid IP and gateway
- ping to gateway: OK; ping to a public resolver IP: OK; DNS resolution: OK
- Android `NetworkAgent`: stuck failing validation

The network was fine. The **captive-portal probe** was not: Android's
NetworkStack was probing the default Google connectivity endpoints, which
were timing out / being reset in that network environment (a common
situation behind certain carriers, regions, or VPN-less setups). A failed
probe makes Android declare a perfectly working network dead.

## The fix (keep validation, change the probes)

Do **not** disable captive-portal detection (that hides real captive
portals and weakens the signal apps rely on). Instead, point both probes at
reachable endpoints that return HTTP 204:

```
settings put global captive_portal_http_url  "http://connect.rom.miui.com/generate_204"
settings put global captive_portal_https_url "https://connectivitycheck.platform.hicloud.com/generate_204"
```

Only these two keys were changed. `captive_portal_mode` was left untouched,
detection stays enabled. Save the previous values (all three were unset
/default here) before changing anything, so you can revert.

Any pair of reliable 204-returning endpoints that are reachable in your
environment works; the above are examples that worked in this one.

## Verify

After the next reconnect: `NetworkAgent` reports `VALIDATED` /
`IS_VALIDATED` and capabilities include `INTERNET` + `VALIDATED`.

Also verify general connectivity independently of Android's validator - a
small on-device `HttpURLConnection`-based probe (normal TLS, no pinning
tricks) against both the HTTP and HTTPS endpoints returning 204 is a good
ground truth when the UI and reality disagree.
