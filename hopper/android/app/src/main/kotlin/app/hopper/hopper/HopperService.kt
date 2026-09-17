package app.hopper.hopper

import android.Manifest
import android.app.Notification
import android.app.PendingIntent
import android.app.Service
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.io.BufferedReader
import java.io.InputStreamReader
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Foreground service that keeps the process (and therefore the Dart sync engine, its
 * TCP listener and mDNS) alive, and captures the clipboard automatically.
 *
 * Automatic capture on Android 10+ (the KDE Connect method): the OS refuses clipboard
 * reads from background apps and logs "ClipboardService: Denying clipboard access to
 * <package>…" every time the clipboard changes. With READ_LOGS granted once over adb we
 * tail that log; on a hit we flash [ClipboardCaptureActivity], a transparent activity that
 * has focus for one frame, reads the clip and hands it to Dart.
 */
class HopperService : Service() {
    private var listener: ClipboardManager.OnPrimaryClipChangedListener? = null
    private var logcat: Process? = null
    private var logThread: Thread? = null
    private val main = Handler(Looper.getMainLooper())
    @Volatile private var lastTrigger = 0L

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        Notifications.ensureChannels(this)
        startForegroundCompat()
        running = true

        val cm = ContextCompat.getSystemService(this, ClipboardManager::class.java)
        listener = ClipboardManager.OnPrimaryClipChangedListener { onClipboardChanged() }
        cm?.addPrimaryClipChangedListener(listener)
        // The log reader is started from MainActivity.onResume only: Android declines log
        // access requested from the background and caches that decision for 60 s.
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SEND_NOW -> startActivity(ClipboardCaptureActivity.intent(this, showToast = true))
            ACTION_RESTART_WATCHER -> startLogWatcher(fromForeground = true, force = intent.getBooleanExtra("force", false))
            ACTION_PROBE_WATCHER -> main.postDelayed({ probeWatcher() }, 1500)
        }
        return START_STICKY
    }

    override fun onDestroy() {
        running = false
        listener?.let { ContextCompat.getSystemService(this, ClipboardManager::class.java)?.removePrimaryClipChangedListener(it) }
        logcat?.destroy()
        super.onDestroy()
    }

    private fun startForegroundCompat() {
        val n = buildNotification()
        if (Build.VERSION.SDK_INT >= 29) {
            startForeground(Notifications.ID_SERVICE, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE)
        } else {
            startForeground(Notifications.ID_SERVICE, n)
        }
    }

    private fun buildNotification(): Notification {
        val open = PendingIntent.getActivity(this, 0, Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val sendNow = PendingIntent.getService(this, 1,
            Intent(this, HopperService::class.java).setAction(ACTION_SEND_NOW),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val granted = checkSelfPermission(Manifest.permission.READ_LOGS) == PackageManager.PERMISSION_GRANTED
        val text = when {
            !granted -> "Automatic capture not set up yet. Tap to finish setup."
            !watcherActive && logThread?.isAlive == true -> "Automatic capture: verifying…"
            !watcherActive -> "Automatic capture paused — open Hopper once to re-enable it."
            else -> "Copy anything — it goes to your paired devices."
        }
        return NotificationCompat.Builder(this, Notifications.CH_SERVICE)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Hopper is syncing your clipboard")
            .setContentText(text)
            .setContentIntent(open)
            .addAction(0, "Send clipboard now", sendNow)
            .setOngoing(true)
            .setSilent(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build()
    }

    /** Fires when the clipboard changes. In the foreground we can read directly; in the
     *  background the read returns null and the log watcher takes over. */
    private fun onClipboardChanged() {
        if (System.currentTimeMillis() < HopperBridge.suppressUntil) return
        val clip = try { HopperBridge.readClipboard(this) } catch (_: Exception) { null } ?: return
        if (clip["type"] == "text" && clip["text"] == HopperBridge.lastWrittenText) return
        HopperBridge.clipCaptured(clip + mapOf("manual" to false))
    }

    /**
     * Start (or restart) the logcat reader. Android 13+ shows a one-time "Allow Hopper to
     * access all device logs?" dialog the first time our process reads logs — but only while
     * the app is in front; in the background the read is refused silently. So MainActivity
     * asks for a restart every time it comes to the front until the reader is confirmed alive.
     */
    fun startLogWatcher(fromForeground: Boolean, force: Boolean = false) {
        if (!fromForeground) return
        if (checkSelfPermission(Manifest.permission.READ_LOGS) != PackageManager.PERMISSION_GRANTED) return
        // A reader that is already running is either confirmed, or waiting for the user to answer
        // Android's consent dialog / the background probe. Never kill it here — the probe
        // destroys a declined reader itself, after which a new request is allowed.
        if (logThread?.isAlive == true) {
            if (watcherActive || !force) return
            // Explicit "Enable" tap: throw away an unverified reader and ask Android again.
            logcat?.destroyForcibly()
            try { logThread?.join(1500) } catch (_: Exception) {}
        }
        // Android caches a declined log-access decision for 60 s; asking again sooner is pointless.
        if (!force && System.currentTimeMillis() - lastWatcherAttempt < 61_000 && lastWatcherAttempt != 0L) {
            Log.i(TAG, "log watcher: last attempt was <60 s ago, waiting")
            return
        }
        lastWatcherAttempt = System.currentTimeMillis()
        watcherStartedInForeground = fromForeground
        logThread = Thread {
            var err = ""
            try {
                val since = SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS", Locale.US).format(Date())
                // Android 16 changed logcat's filter syntax.
                val filter = if (Build.VERSION.SDK_INT > 35) "E ClipboardService" else "ClipboardService:E"
                val p = Runtime.getRuntime().exec(arrayOf("logcat", "-T", since, filter, "*:S"))
                logcat = p
                Log.i(TAG, "log watcher started (foreground=$fromForeground, filter='$filter')")
                BufferedReader(InputStreamReader(p.inputStream)).forEachLine { line ->
                    if (!line.contains(packageName)) return@forEachLine
                    if (probePending && System.currentTimeMillis() - probeAt < 3000) {
                        // Our own probe came back through the system log: access is really approved.
                        probePending = false
                        if (!watcherActive) { watcherActive = true; Log.i(TAG, "log watcher confirmed live"); updateNotification() }
                        return@forEachLine
                    }
                    onDenialLogged()
                }
                err = try { p.errorStream.bufferedReader().readText() } catch (_: Exception) { "" }
            } catch (e: Exception) {
                err = e.message ?: "exception"
            }
            watcherActive = false
            Log.w(TAG, "logcat watcher ended: $err")
            updateNotification()
        }.apply { isDaemon = true; name = "hopper-logcat"; start() }
    }

    /**
     * Real health check, run shortly after the app leaves the foreground: touching the
     * clipboard from the background makes the system log a denial line for our package.
     * Only a reader that Android actually approved can see that line — reading our own
     * log lines is always allowed, so they prove nothing.
     */
    private fun probeWatcher() {
        if (logThread?.isAlive != true || watcherActive) return
        if (MainActivity.current?.isResumedNow == true) return   // still in front: no denial would be logged
        probePending = true
        probeAt = System.currentTimeMillis()
        try { ContextCompat.getSystemService(this, ClipboardManager::class.java)?.primaryClipDescription } catch (_: Exception) {}
        main.postDelayed({
            if (probePending) {
                probePending = false
                Log.w(TAG, "log watcher probe got nothing — Android declined log access; will retry next time Hopper is opened")
                logcat?.destroyForcibly()
                watcherActive = false
                updateNotification()
            }
        }, 2500)
    }

    private fun updateNotification() {
        try {
            ContextCompat.getSystemService(this, android.app.NotificationManager::class.java)
                ?.notify(Notifications.ID_SERVICE, buildNotification())
        } catch (_: Exception) {}
    }

    /** The system just refused us the clipboard → something was copied while we were in the background. */
    private fun onDenialLogged() {
        val now = System.currentTimeMillis()
        if (now < HopperBridge.suppressUntil) return          // it was our own write
        if (now - lastTrigger < 400) return                    // debounce duplicate log lines
        lastTrigger = now
        main.post {
            try {
                Log.i(TAG, "clipboard changed in background → capturing")
                startActivity(ClipboardCaptureActivity.intent(this, showToast = false))
            } catch (e: Exception) {
                Log.w(TAG, "cannot start capture activity (grant 'Appear on top'): ${e.message}")
            }
        }
    }

    companion object {
        private const val TAG = "HopperService"
        const val ACTION_SEND_NOW = "app.hopper.SEND_NOW"
        const val ACTION_RESTART_WATCHER = "app.hopper.RESTART_WATCHER"
        @Volatile var running = false
        @Volatile var watcherActive = false
        @Volatile private var watcherStartedInForeground = false
        @Volatile private var lastWatcherAttempt = 0L
        @Volatile private var probePending = false
        @Volatile private var probeAt = 0L
        const val ACTION_PROBE_WATCHER = "app.hopper.PROBE_WATCHER"

        /** Call when the app goes to the background: verifies the reader really works. */
        fun requestProbe(ctx: Context) {
            try {
                ContextCompat.startForegroundService(ctx, Intent(ctx, HopperService::class.java).setAction(ACTION_PROBE_WATCHER))
            } catch (e: Exception) { Log.w(TAG, "could not request probe: ${e.message}") }
        }

        /** Call from a visible activity: (re)starts the log reader so Android can show its consent dialog. */
        fun requestWatcher(ctx: Context, force: Boolean = false) {
            try {
                ContextCompat.startForegroundService(ctx, Intent(ctx, HopperService::class.java).setAction(ACTION_RESTART_WATCHER).putExtra("force", force))
            } catch (e: Exception) {
                Log.w(TAG, "could not request watcher: ${e.message}")
            }
        }

        fun ensureRunning(ctx: Context) {
            try {
                ContextCompat.startForegroundService(ctx, Intent(ctx, HopperService::class.java))
            } catch (e: Exception) {
                Log.w(TAG, "could not start foreground service: ${e.message}")
            }
        }
    }
}
