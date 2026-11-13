# OpenEUICC for Magisk (Android 16 crash fix)

[![Build Magisk module](https://github.com/ban-sky/OpenEUICC_for_Magisk/actions/workflows/build.yml/badge.svg)](https://github.com/ban-sky/OpenEUICC_for_Magisk/actions/workflows/build.yml)

This repository packages [OpenEUICC](https://gitea.angry.im/PeterCxy/OpenEUICC) — PeterCxy's
open-source eSIM LPA implementation for Android — as a Magisk / KernelSU / APatch module, and
fixes the crash on launch that Android 16 users hit when the module is not mounted correctly.

It is derived from [hzy132/OpenEUICC_for_Magisk](https://github.com/hzy132/OpenEUICC_for_Magisk)
and builds the vendored upstream source at commit `9a537a25163c5159899260fb6191a5da35a692bd`
(the same commit that release `3(802)` was built from) with a small, focused patch.

* **OpenEUICC** (`im.angry.openeuicc`) — the privileged build, installed as a system app in
  `/system_ext/priv-app/OpenEUICC/`.
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
the time the package manager scans `/system_ext`, so the privileged APK is not visible. In
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
ls -l /system_ext/priv-app/OpenEUICC/OpenEUICC.apk
```

If the file is missing, change the way your root manager mounts modules (for KernelSU Next,
different mount modes or the `mountify` module are known to help) and reboot. Re-flashing the
module and rebooting twice also helps on some devices.

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

* `OpenEUICC-Magisk_module-<version>.zip` — versioned module
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
