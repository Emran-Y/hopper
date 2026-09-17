package app.hopper.hopper

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The app window. Attaches to the process-wide cached engine (see HopperApplication) so
 * closing the window does not stop syncing. Also receives Share → Hopper (text, images, files).
 */
class MainActivity : FlutterActivity() {
    private var shareChannel: MethodChannel? = null
    private var pendingText: String? = null

    override fun getCachedEngineId(): String = HopperApplication.ENGINE_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        current = this
        HopperService.ensureRunning(this)
    }

    private val handler = android.os.Handler(android.os.Looper.getMainLooper())
    private val watcherRetry = object : Runnable {
        override fun run() {
            if (!isResumedNow) return
            if (!HopperService.watcherActive) HopperService.requestWatcher(this@MainActivity)
            handler.postDelayed(this, 62_000)   // a declined request is cached for 60 s
        }
    }
    @Volatile var isResumedNow = false

    override fun onResume() {
        super.onResume()
        isResumedNow = true
        // We are visible: let the service (re)start its log reader. Wait a beat so the process
        // is definitely in the "top" state when Android decides whether to allow log access.
        handler.removeCallbacks(watcherRetry)
        handler.postDelayed(watcherRetry, 2000)
    }

    override fun onPause() {
        isResumedNow = false
        handler.removeCallbacks(watcherRetry)
        // Now that we are leaving the foreground the service can verify the reader for real.
        if (!HopperService.watcherActive) HopperService.requestProbe(this)
        super.onPause()
    }

    override fun onDestroy() {
        if (current === this) current = null
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        shareChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "hopper/share").also { ch ->
            ch.setMethodCallHandler { call, result ->
                if (call.method == "getInitialText") { result.success(pendingText); pendingText = null } else result.notImplemented()
            }
        }
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    fun requestNotificationPermission() {
        if (Build.VERSION.SDK_INT >= 33) requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 41)
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action != Intent.ACTION_SEND) return
        val type = intent.type ?: return
        if (type.startsWith("text/")) {
            val text = intent.getStringExtra(Intent.EXTRA_TEXT) ?: return
            if (shareChannel != null) shareChannel?.invokeMethod("sharedText", text) else pendingText = text
        } else {
            @Suppress("DEPRECATION")
            val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM) ?: return
            Thread {
                val bytes = contentResolver.openInputStream(uri)?.use { it.readBytes() } ?: return@Thread
                if (bytes.size > HopperBridge.MAX_BYTES) return@Thread
                val name = contentResolver.query(uri, arrayOf(android.provider.OpenableColumns.DISPLAY_NAME), null, null, null)
                    ?.use { c -> if (c.moveToFirst()) c.getString(0) else null } ?: "shared"
                HopperBridge.clipCaptured(mapOf(
                    "type" to if (type.startsWith("image/")) "image" else "file",
                    "bytes" to bytes, "mime" to type, "name" to name, "manual" to true, "sensitive" to false,
                ))
            }.start()
        }
        intent.action = null
    }

    companion object {
        @Volatile var current: MainActivity? = null
    }
}
