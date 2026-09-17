package app.hopper.hopper

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.WindowManager
import android.widget.Toast

/**
 * Invisible, focus-grabbing activity. Android only lets the focused app read the
 * clipboard, so this is raised for a single frame, reads the clip in
 * onWindowFocusChanged and finishes. Started by HopperService (log watcher or the
 * "Send clipboard now" notification action).
 */
class ClipboardCaptureActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        window.attributes = window.attributes.apply {
            dimAmount = 0f
            flags = WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL
        }
        overridePendingTransition(0, 0)
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (!hasFocus) return
        val manual = intent.getBooleanExtra(EXTRA_TOAST, false)
        val clip = try { HopperBridge.readClipboard(this) } catch (e: Exception) { android.util.Log.w("HopperCapture", "read failed: $e"); null }
        android.util.Log.i("HopperCapture", "focus=$hasFocus manual=$manual clip=${clip?.get("type")}")
        if (clip != null) {
            val isOurOwnText = clip["type"] == "text" && clip["text"] == HopperBridge.lastWrittenText
            if (manual || !isOurOwnText) HopperBridge.clipCaptured(clip + mapOf("manual" to manual))
            if (manual) Toast.makeText(this, "Sent to your devices", Toast.LENGTH_SHORT).show()
        } else if (manual) {
            Toast.makeText(this, "Clipboard is empty", Toast.LENGTH_SHORT).show()
        }
        finish()
        overridePendingTransition(0, 0)
    }

    companion object {
        private const val EXTRA_TOAST = "toast"
        fun intent(ctx: Context, showToast: Boolean): Intent =
            Intent(ctx.applicationContext, ClipboardCaptureActivity::class.java)
                .putExtra(EXTRA_TOAST, showToast)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION)
    }
}
