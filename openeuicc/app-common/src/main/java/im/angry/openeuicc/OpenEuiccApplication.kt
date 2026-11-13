package im.angry.openeuicc

import android.app.Application
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.os.Build
import android.util.Log
import com.google.android.material.color.DynamicColors
import im.angry.openeuicc.core.EuiccDiagnostics
import im.angry.openeuicc.di.AppContainer
import im.angry.openeuicc.di.DefaultAppContainer

open class OpenEuiccApplication : Application() {
    open val appContainer: AppContainer by lazy {
        DefaultAppContainer(this)
    }

    override fun onCreate() {
        super.onCreate()

        // Observe dynamic colors changes
        DynamicColors.applyToActivitiesIfAvailable(this)

        recordEnvironmentDiagnostics()
    }

    /**
     * Records the environment once per process start. This is what the "no eUICC"
     * screen shows when the app cannot find any eSIM, so that users can report the
     * state of their device without having to set up adb.
     */
    private fun recordEnvironmentDiagnostics() {
        EuiccDiagnostics.clear()
        try {
            val info = packageManager.getPackageInfo(packageName, 0)
            EuiccDiagnostics.record("OpenEUICC ${info.versionName} (${info.longVersionCode})")
        } catch (e: Exception) {
            Log.w("OpenEuiccApplication", "Cannot read own package info", e)
        }
        EuiccDiagnostics.record(
            "Android ${Build.VERSION.RELEASE} (API ${Build.VERSION.SDK_INT}), " +
                "${Build.MANUFACTURER} ${Build.MODEL}"
        )
        EuiccDiagnostics.record(
            "Installed as system app: " +
                ((applicationInfo.flags and ApplicationInfo.FLAG_SYSTEM) != 0)
        )
        for (permission in arrayOf(
            "android.permission.READ_PRIVILEGED_PHONE_STATE",
            "android.permission.MODIFY_PHONE_STATE",
            "android.permission.WRITE_EMBEDDED_SUBSCRIPTIONS",
            "android.permission.READ_PHONE_STATE",
        )) {
            EuiccDiagnostics.record(
                "$permission: " +
                    if (checkSelfPermission(permission) == PackageManager.PERMISSION_GRANTED) {
                        "granted"
                    } else {
                        "denied"
                    }
            )
        }
    }
}
