package im.angry.openeuicc.core

/**
 * A tiny in-memory log of what the app observed while looking for eUICC channels.
 *
 * The purpose is to make "no eSIM detected" situations debuggable without adb: the
 * entries are shown inside the "no eUICC" placeholder screen, and the same entries
 * are written to logcat by the code that records them.
 */
object EuiccDiagnostics {
    private const val MAX_LINES = 200

    private val lines = ArrayDeque<String>()

    @Synchronized
    fun record(message: String) {
        if (lines.size >= MAX_LINES) {
            lines.removeFirst()
        }
        lines.addLast(message)
    }

    @Synchronized
    fun dump(): List<String> = lines.toList()

    @Synchronized
    fun clear() {
        lines.clear()
    }
}
