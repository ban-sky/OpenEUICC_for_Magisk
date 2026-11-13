package im.angry.openeuicc.util

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager

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
    checkSelfPermission(Manifest.permission.READ_PRIVILEGED_PHONE_STATE) ==
            PackageManager.PERMISSION_GRANTED
