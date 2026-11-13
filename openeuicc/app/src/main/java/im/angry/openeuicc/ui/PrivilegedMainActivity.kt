package im.angry.openeuicc.ui

import android.os.Build
import android.os.Bundle
import android.view.Menu
import android.view.MenuItem
import android.widget.Toast
import androidx.appcompat.app.AlertDialog
import im.angry.openeuicc.R
import im.angry.openeuicc.util.*

class PrivilegedMainActivity : MainActivity() {
    private val isPrivileged by lazy { isRunningAsPrivilegedSystemApp() }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Android 16: if the Magisk / KernelSU module did not get mounted, this
        // app is a plain data app. Explain that instead of crashing or silently
        // showing an empty list.
        if (!isPrivileged) {
            AlertDialog.Builder(this)
                .setTitle(R.string.not_privileged_title)
                .setMessage(R.string.not_privileged_message)
                .setCancelable(false)
                .setPositiveButton(android.R.string.ok) { _, _ -> finish() }
                .show()
        }
    }

    override fun onInit() {
        // Without privileged permissions every channel lookup just comes back
        // empty; the dialog shown in onCreate() explains why.
        if (!isPrivileged) return
        super.onInit()
    }

    override fun onCreateOptionsMenu(menu: Menu): Boolean {
        super.onCreateOptionsMenu(menu)
        menuInflater.inflate(R.menu.activity_main_privileged, menu)

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            menu.findItem(R.id.slot_mapping).isVisible = false
        }

        menu.findItem(R.id.dsds).apply {
            isVisible = tm.supportsDSDS
            isChecked = tm.dsdsEnabled
        }

        return true
    }

    internal fun showSlotMappingFragment() =
        SlotMappingFragment().show(supportFragmentManager, SlotMappingFragment.TAG)

    override fun onOptionsItemSelected(item: MenuItem): Boolean = when (item.itemId) {
        R.id.dsds -> {
            tm.setDsdsEnabled(euiccChannelManager, !item.isChecked)
            Toast.makeText(this, R.string.toast_dsds_switched, Toast.LENGTH_LONG).show()
            finish()
            true
        }

        R.id.slot_mapping -> {
            showSlotMappingFragment()
            true
        }

        else -> super.onOptionsItemSelected(item)
    }
}
