package im.angry.openeuicc.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.widget.ScrollView
import android.widget.TextView
import androidx.appcompat.app.AlertDialog
import im.angry.openeuicc.common.R
import im.angry.openeuicc.core.EuiccDiagnostics

/**
 * Shows whatever the app recorded while looking for eUICC channels, so that a user
 * who cannot see their eSIM can report the exact state of their device without adb.
 */
fun Context.showEuiccDiagnosticsDialog() {
    val textView = TextView(this).apply {
        text = EuiccDiagnostics.dump().joinToString("\n").ifEmpty {
            getString(R.string.no_euicc_diagnostics_empty)
        }
        setTextIsSelectable(true)
        setPadding(48, 32, 48, 32)
        textSize = 12f
    }
    val scrollView = ScrollView(this).apply {
        addView(textView)
    }
    AlertDialog.Builder(this)
        .setTitle(R.string.no_euicc_diagnostics_title)
        .setView(scrollView)
        .setPositiveButton(android.R.string.ok, null)
        .setNeutralButton(R.string.diagnostics_copy) { _, _ ->
            val clipboard = getSystemService(ClipboardManager::class.java)
            clipboard?.setPrimaryClip(
                ClipData.newPlainText(
                    getString(R.string.no_euicc_diagnostics_title),
                    textView.text
                )
            )
        }
        .show()
}
