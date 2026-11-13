package im.angry.openeuicc

import android.util.Log
import im.angry.openeuicc.core.PrivilegedEuiccChannelManager
import im.angry.openeuicc.di.AppContainer
import im.angry.openeuicc.di.PrivilegedAppContainer
import im.angry.openeuicc.util.isRunningAsPrivilegedSystemApp

class PrivilegedOpenEuiccApplication : OpenEuiccApplication() {
    override val appContainer: AppContainer by lazy {
        PrivilegedAppContainer(this)
    }

    override fun onCreate() {
        super.onCreate()

        // If the module did not get mounted (a common problem on Android 16 with
        // some KernelSU / mountify setups), this process is just a normal data
        // app and must not run privileged startup tasks. The UI shows an
        // explanation instead of crashing on launch.
        if (!isRunningAsPrivilegedSystemApp()) {
            Log.w(TAG, "Not running as a privileged system app, skipping privileged startup tasks")
            return
        }

        try {
            (appContainer.euiccChannelManager as PrivilegedEuiccChannelManager).closeAllStaleChannels()
        } catch (e: Exception) {
            Log.w(TAG, "Failed to close stale logical channels", e)
        }
    }

    companion object {
        private const val TAG = "PrivilegedOpenEuiccApp"
    }
}
