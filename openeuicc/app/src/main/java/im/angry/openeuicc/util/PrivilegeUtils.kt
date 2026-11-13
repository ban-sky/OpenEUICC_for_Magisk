package im.angry.openeuicc.util

import android.content.Context
import android.content.pm.PackageManager

/**
 * READ_PRIVILEGED_PHONE_STATE is a platform-only permission constant, so it is
 * not part of the public android.Manifest.permission API that we compile
 * against. Its value is stable and part of the platform permission namespace.
 */
private const val PERMISSION_READ_PRIVILEGED_PHONE_STATE =
    "android.permission.READ_PRIVILEGED_PHONE_STATE"

/**
 * Whether this process is running as the privileged system app that the
 * Magisk / KernelSU module installs into /system_ext/priv-app.
 *
 * This is the one thing that used to crash the app on Android 16: if the module
 * is not mounted (common with some KernelSU / mountify configurations), the APK
 * installed by customize.sh keeps running as a normal data app, and the first
 * privileged telephony call throws SecurityException from Application.onCreate().
 */
fun Context.isRunningAsPrivilegedSystemApp(): Boolean =
    checkSelfPermission(PERMISSION_READ_PRIVILEGED_PHONE_STATE) ==
            PackageManager.PERMISSION_GRANTED
