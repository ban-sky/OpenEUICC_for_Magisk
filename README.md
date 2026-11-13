# OpenEUICC for Magisk (Android 16 crash fix)

[![Build Magisk module](https://github.com/ban-sky/OpenEUICC_for_Magisk/actions/workflows/build.yml/badge.svg)](https://github.com/ban-sky/OpenEUICC_for_Magisk/actions/workflows/build.yml)

This repository packages [OpenEUICC](https://gitea.angry.im/PeterCxy/OpenEUICC) — PeterCxy's
open-source eSIM LPA implementation for Android — as a Magisk / KernelSU / APatch module, and
fixes the crash on launch that Android 16 users hit when the module is not mounted correctly.

It is derived from [hzy132/OpenEUICC_for_Magisk](https://github.com/hzy132/OpenEUICC_for_Magisk)
and builds the vendored upstream source at commit `9a537a25163c5159899260fb6191a5da35a692bd`
(the same commit that release `3(802)` was built from) with a small, focused patch.

* **OpenEUICC** (`im.angry.openeuicc`) — the privileged build, installed as a system app in
  **both** `/system/priv-app/OpenEUICC/` and `/system_ext/priv-app/OpenEUICC/`. KernelSU mount
  implementations differ in which partitions they overlay, and shipping both raises the success
  rate; when both are visible the package manager keeps the `/system` copy and ignores the other.
* **EasyEUICC** (`im.angry.easyeuicc`) — the unprivileged build, a normal user app, attached to
  each release as a separate APK.

## The Android 16 crash

### Symptom

The app closes immediately after being opened. The stack trace looks like this:

```
FATAL EXCEPTION: main
Process: im.angry.openeuicc, PID: ...
java.lang.RuntimeException: Unable to create application im.angry.openeuicc.PrivilegedOpenEuiccApplication
    at android.app.ActivityThread.handleBindApplication(ActivityThread.java:...)
Caused by: java.lang.SecurityException: Caller does not have permission.
    at android.os.Parcel.createExceptionOrNull(Parcel.java:...)
    at android.os.Parcel.readException(Parcel.java:...)
```

### Root cause

OpenEUICC is a *privileged* app: it calls `TelephonyManager.uiccCardsInfo`, which requires the
`READ_PRIVILEGED_PHONE_STATE` signature permission. That permission is only granted to an APK
installed as a system app **and** listed in a `privapp-permissions` whitelist.

On Android 16 (and with newer KernelSU / Magisk mount modes) the module often is not mounted at
the time the package manager scans `/system` (older releases shipped the APK under `/system_ext`,
which many KernelSU mount implementations never overlay), so the privileged APK is not visible. In
addition, the module used to run `pm install` during installation, which created a second,
unprivileged copy of the same package in `/data/app`. That copy takes precedence over the system
app, so the app ran as an ordinary user app, and `PrivilegedOpenEuiccApplication.onCreate()` —
which queried `uiccCardsInfo` without any guard — threw `SecurityException` and killed the
process before the first activity appeared.

### Fixes in this repository

| Where | Change |
| --- | --- |
| `openeuicc/app/src/main/java/im/angry/openeuicc/util/PrivilegedTelephonyCompat.kt` | `uiccCardsInfoCompat` catches `SecurityException` and returns an empty list instead of throwing. |
| `openeuicc/app/src/main/java/im/angry/openeuicc/PrivilegedOpenEuiccApplication.kt` | Skips the privileged clean-up work when the app is not privileged, and never lets it escape `onCreate()`. |
| `openeuicc/app/src/main/java/im/angry/openeuicc/ui/PrivilegedMainActivity.kt` | When started without `READ_PRIVILEGED_PHONE_STATE`, shows a dialog that explains why the app cannot work and what to do (reboot, fix the module mount) instead of crashing. |
| `magisk-module/customize.sh` | No longer runs `pm install` (the source of the unprivileged shadow copy); removes a leftover `/data/app` copy from older versions. |
| `magisk-module/service.sh` | Grants `READ_PHONE_STATE` / `POST_NOTIFICATIONS` after boot instead of during installation. |
| `magisk-module/system/system_ext/etc/default-permissions/openeuicc.xml` | Grants the runtime permissions on first boot as a second safety net. |
| `openeuicc/app-common/src/main/java/im/angry/openeuicc/core/EuiccDiagnostics.kt` and friends | Records cards, ports, permission state and channel-open exceptions, and shows them from the overflow menu and the "no eUICC" screen. |
| `openeuicc/buildSrc/.../Versioning.kt` + `build.sh` | Pins an explicit, increasing `versionCode` (the vendored tree has no upstream git history, so the derived code would have been far below the previously published `802`). |

The app itself is unchanged otherwise; this is not a rewrite.

**Note:** the app still cannot do anything useful if the module is not mounted — a
non-privileged app has no access to the eUICC. The patch only makes the failure visible instead
of crashing, and removes the module-side cause.

## Install

1. Download `OpenEUICC-Magisk_module.zip` from the
   [latest release](https://github.com/ban-sky/OpenEUICC_for_Magisk/releases/latest).
2. Flash it in Magisk, KernelSU (Next) or APatch.
3. Reboot.
4. Open OpenEUICC.

If the app reports that it is not privileged, the module was not mounted. Check with a root
shell:

```sh
ls -l /system/priv-app/OpenEUICC/OpenEUICC.apk
cat /data/local/tmp/openeuicc-boot.log
```

If the file is missing, change the way your root manager mounts modules (for KernelSU Next,
different mount modes or the `mountify` module are known to help) and reboot. Re-flashing the
module and rebooting twice also helps on some devices.

### What happens when the module is not mounted

The module never leaves the phone without an app:

* at boot, `post-fs-data.sh` records the mount state in `/data/local/tmp/openeuicc-mount.log`;
* after boot, `service.sh` decides:
  * system APK visible → remove a leftover `/data/app` copy so the privileged system app wins
    (`pm install-existing` if needed);
  * system APK missing (module not mounted) → install the same APK as a normal app, so the app still
    opens and explains the problem instead of disappearing;
  * once the mount is fixed, the next boot removes the ordinary copy and switches back to the system
    app.

### KernelSU notes

* The APK now lives in `/system/priv-app`, the one partition every KernelSU mount implementation
  (overlayfs, magic mount, mountify, meta-overlayfs) overlays. `/system_ext` is not covered by all
  of them.
* Do not add OpenEUICC to KernelSU's per-app "umount modules" list — that hides this module's
  mount from the app and it falls back to an unprivileged identity.
* When upgrading from the old module (hzy132's, or this module's 3.806/3.809), the previous
  `pm install` may have left a copy in `/data/app`. `customize.sh` removes it when it can, and
  `service.sh` retries on boot — reboot once after upgrading, then open the app.
* `/data/local/tmp/openeuicc-boot.log` records the module directory, whether the system APK is
  present, what `pm path` points at, and whether the self-heal ran. The diagnostics dialog shows
  the matching `APK path`, `System flags` and `File /system/priv-app/...` lines.

## "No eUICC detected" / cannot see eSIM information

If the app opens but the main screen says no eUICC was found, use the built-in **diagnostics**
first:

* overflow menu on the main screen → **Diagnostics**; or
* the **Show diagnostics** button on the "no eUICC" screen.

The dialog lists every UICC card and port reported by the system (is it an eUICC, is it
removable, does it support MEP), the state of each relevant permission, the APK the app actually
runs from together with its system flags, whether the APK exists under `/system/priv-app` and
`/system_ext`, and the exact exception that prevented a logical channel from being opened. **Copy** puts the whole dump on the
clipboard so it can be pasted into an issue.

The usual causes fall into three groups:

1. **The module is not mounted** — the dump shows `Installed as system app: false` or
   `READ_PRIVILEGED_PHONE_STATE: denied`. See the mounting notes above.
2. **eSIM disabled in system settings** — Android removes a disabled eUICC from
   `UiccCardsInfo`, so third-party apps cannot see the chip at all. Re-enable it under
   Settings → Network & internet → SIMs, then reboot (upstream issue #346).
3. **Slot mapping / baseband limits** — some devices (especially MEP-capable ones) only let the
   baseband talk to a given physical port and return `NO_SUCH_ELEMENT` when a logical channel is
   opened. Try enabling **Use TelephonyManager everywhere** in the app's developer options (or in
   Android's developer options) and reopen the app; the diagnostics dump records these failures.

If the dump contains `SecurityException: The calling package is not allowed to access ISD-R`,
the platform considers another LPA (for example the vendor's own eUICC service) to be the best
eUICC service and therefore refuses this app access to ISD-R. Please attach the dump to an issue
together with the device model and OS build.

## Build

Everything happens in GitHub Actions: [`.github/workflows/build.yml`](.github/workflows/build.yml)
installs JDK 17, the Android SDK (`platforms;android-37.0`, `build-tools;37.0.0`,
`ndk;26.1.10909125`), builds both APKs and packages the module.

Trigger it from *Actions → Build Magisk module → Run workflow*. The inputs are the version name
and version code (empty = `802 + commit count`); a release `v<version>` is created unless
`create_release` is disabled. Pushing to `main` also builds and publishes.

Locally, with the same JDK/SDK/NDK installed:

```sh
# openeuicc/keystore.properties must point at a keystore:
#   storeFile=/absolute/path/to/keystore.p12
#   storePassword=...
#   keyAlias=...
#   keyPassword=...
#   unprivKeyAlias=...        (EasyEUICC)
#   unprivKeyPassword=...
OPENEUICC_VERSION_NAME=3 OPENEUICC_VERSION_CODE=803 ./build.sh
```

The output is written to `out/`:

* `OpenEUICC-Magisk_module-<version>.zip` — versioned module (`<version>` is e.g. `3.806`, while
  `module.prop` shows the same build as `3(806)`)
* `OpenEUICC-Magisk_module.zip` — same file under a stable name, used by `update.json`
* `EasyEUICC-<version>.apk` — unprivileged build
* `update.json` — Magisk update metadata

### Signing

APKs are signed with a keystore generated by the workflow on first use and then restored from
the Actions cache (`openeuicc-signing-v1`), so consecutive builds share one signature and can be
installed over each other. If that cache is evicted, the signature changes and the previously
installed app has to be uninstalled once (or its data wiped).

To make the key permanent, add a repository secret `KEYSTORE_BASE64` containing the base64 of a
PKCS#12 keystore whose key password is `openeuicc-module-2026` and whose alias is `openeuicc`
(see `KEYSTORE_PASSWORD` / `KEYSTORE_ALIAS` in the workflow). No private key is committed to this
repository.

## Credits

* [PeterCxy/OpenEUICC](https://gitea.angry.im/PeterCxy/OpenEUICC) — the app (GPL-3.0).
* [hzy132/OpenEUICC_for_Magisk](https://github.com/hzy132/OpenEUICC_for_Magisk) — the original
  module packaging this repository started from.
* [liuran001/OpenEUICC_Magisk_Module](https://github.com/liuran001/OpenEUICC_Magisk_Module) and
  [EmilienCourt/kernelsu-module-openeuicc](https://github.com/EmilienCourt/kernelsu-module-openeuicc)
  — other module packagings that helped identify the mount/privilege cause.

Licensed under GPL-3.0, see [LICENSE](LICENSE).
