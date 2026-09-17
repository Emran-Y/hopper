package app.hopper.hopper

import android.Manifest
import android.app.NotificationManager
import android.content.ClipData
import android.content.ClipDescription
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.provider.MediaStore
import android.provider.OpenableColumns
import android.provider.Settings
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

/**
 * The single MethodChannel between the Dart sync engine and the Android side.
 *
 * Dart → Android: startService, readClipboard, writeClipboard, saveFile, setupStatus,
 *                 requestNotifications, requestBattery, openOverlaySettings, notify, cancelNotify
 * Android → Dart: clipCaptured(map), sendHeldClip(id)
 */
object HopperBridge {
    private const val CHANNEL = "hopper/native"
    const val MAX_BYTES = 100L * 1024 * 1024

    private lateinit var appContext: Context
    private var channel: MethodChannel? = null
    private val main = Handler(Looper.getMainLooper())

    /** After we write the clipboard ourselves, ignore change events for a moment. */
    @Volatile var suppressUntil: Long = 0
    @Volatile var lastWrittenText: String? = null

    fun attach(context: Context, engine: FlutterEngine) {
        appContext = context.applicationContext
        channel = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).also { ch ->
            ch.setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "startService" -> { HopperService.ensureRunning(appContext); result.success(true) }
                        "startWatcher" -> { HopperService.requestWatcher(appContext, force = true); result.success(true) }
                        "readClipboard" -> result.success(readClipboard(appContext))
                        "writeClipboard" -> { writeClipboard(appContext, call.arguments as Map<*, *>); result.success(true) }
                        "saveFile" -> result.success(saveToDownloads(appContext, call.arguments as Map<*, *>))
                        "setupStatus" -> result.success(setupStatus(appContext))
                        "requestNotifications" -> { MainActivity.current?.requestNotificationPermission(); result.success(true) }
                        "requestBattery" -> { requestBatteryExemption(appContext); result.success(true) }
                        "openOverlaySettings" -> { openOverlaySettings(appContext); result.success(true) }
                        "notify" -> { Notifications.show(appContext, call.arguments as Map<*, *>); result.success(true) }
                        "cancelNotify" -> { Notifications.cancel(appContext, (call.arguments as Number).toInt()); result.success(true) }
                        else -> result.notImplemented()
                    }
                } catch (e: Exception) {
                    result.error("native", e.message, null)
                }
            }
        }
    }

    // ---------------------------------------------------------------- Android → Dart
    fun clipCaptured(payload: Map<String, Any?>) {
        main.post { channel?.invokeMethod("clipCaptured", payload) }
    }

    fun sendHeldClip(id: String) {
        main.post { channel?.invokeMethod("sendHeldClip", id) }
    }

    // ---------------------------------------------------------------- clipboard
    /** Read the primary clip. Returns null when empty or when Android denies access (app not focused). */
    fun readClipboard(ctx: Context): Map<String, Any?>? {
        val cm = ContextCompat.getSystemService(ctx, ClipboardManager::class.java) ?: return null
        val clip = cm.primaryClip ?: return null
        if (clip.itemCount == 0) return null
        val item = clip.getItemAt(0)
        val desc = clip.description
        val sensitive = Build.VERSION.SDK_INT >= 33 &&
            desc.extras?.getBoolean(ClipDescription.EXTRA_IS_SENSITIVE, false) == true
        android.util.Log.i("HopperBridge", "clip: mimes=${(0 until desc.mimeTypeCount).map { desc.getMimeType(it) }} uri=${item.uri} text=${item.text?.length ?: 0}ch html=${item.htmlText?.length ?: 0}ch intent=${item.intent != null}")

        item.uri?.let { uri ->
            val scheme = uri.scheme ?: ""
            if (scheme == "http" || scheme == "https") {
                return mapOf("type" to "text", "text" to uri.toString(), "sensitive" to sensitive)
            }
            if (scheme == "content" || scheme == "file") {
                val bytes = readUri(ctx, uri)
                android.util.Log.i("HopperBridge", "uri read: ${bytes?.size ?: -1} bytes")
                if (bytes != null && bytes.isNotEmpty()) {
                    val declared = try { ctx.contentResolver.getType(uri) } catch (_: Exception) { null }
                        ?: (if (desc.mimeTypeCount > 0 && desc.getMimeType(0) != "text/uri-list") desc.getMimeType(0) else null)
                    val mime = sniffMime(bytes) ?: declared ?: "application/octet-stream"
                    if (mime.startsWith("text/") && declared?.startsWith("text/") == true) {
                        return mapOf("type" to "text", "text" to String(bytes), "sensitive" to sensitive)
                    }
                    val name = displayName(ctx, uri)?.takeIf { it.contains('.') }
                        ?: "clip-${System.currentTimeMillis()}.${extFor(mime)}"
                    return mapOf(
                        "type" to if (mime.startsWith("image/")) "image" else "file",
                        "bytes" to bytes, "mime" to mime, "name" to name, "sensitive" to sensitive,
                    )
                }
                // Unreadable content URI (e.g. a vendor clipboard we have no access to): fall through
                // to the text, but never send the raw URI string as if it were text.
                if (item.text.isNullOrEmpty()) return null
            }
        }
        val text = item.text?.toString() ?: item.coerceToText(ctx)?.toString()
        if (text.isNullOrEmpty()) return null
        return mapOf("type" to "text", "text" to text, "sensitive" to sensitive)
    }

    fun writeClipboard(ctx: Context, args: Map<*, *>) {
        val cm = ContextCompat.getSystemService(ctx, ClipboardManager::class.java) ?: return
        suppressUntil = System.currentTimeMillis() + 2000
        val text = args["text"] as String?
        val bytes = args["bytes"] as ByteArray?
        val mime = (args["mime"] as String?) ?: "image/png"
        if (bytes != null) {
            val dir = File(ctx.cacheDir, "clips").apply { mkdirs() }
            // Keep the cache small: only the last few clips.
            dir.listFiles()?.sortedByDescending { it.lastModified() }?.drop(5)?.forEach { it.delete() }
            val ext = when (mime) { "image/jpeg" -> "jpg"; "image/gif" -> "gif"; "image/webp" -> "webp"; else -> "png" }
            val f = File(dir, "${UUID.randomUUID()}.$ext")
            FileOutputStream(f).use { it.write(bytes) }
            val uri = FileProvider.getUriForFile(ctx, "${ctx.packageName}.fileprovider", f)
            val clip = ClipData.newUri(ctx.contentResolver, "Hopper image", uri)
            cm.setPrimaryClip(clip)
            lastWrittenText = null
            saveToGallery(ctx, bytes, (args["name"] as String?) ?: "hopper-${System.currentTimeMillis()}.$ext", mime)
            return
        }
        if (text != null) {
            lastWrittenText = text
            cm.setPrimaryClip(ClipData.newPlainText("Hopper", text))
        }
    }

    /** Received images also go to Pictures/Hopper so they show up in Gallery. */
    private fun saveToGallery(ctx: Context, bytes: ByteArray, name: String, mime: String) {
        if (Build.VERSION.SDK_INT < 29) return
        try {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, mime)
                put(MediaStore.Images.Media.RELATIVE_PATH, Environment.DIRECTORY_PICTURES + "/Hopper")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = ctx.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return
            ctx.contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
            values.clear(); values.put(MediaStore.Images.Media.IS_PENDING, 0)
            ctx.contentResolver.update(uri, values, null, null)
        } catch (e: Exception) {
            android.util.Log.w("HopperBridge", "gallery save failed: $e")
        }
    }

    /** Save bytes into Downloads/Hopper and return the display path. */
    fun saveToDownloads(ctx: Context, args: Map<*, *>): String {
        val bytes = args["bytes"] as ByteArray
        val name = (args["name"] as String?) ?: "hopper-${System.currentTimeMillis()}"
        val mime = (args["mime"] as String?) ?: "application/octet-stream"
        if (Build.VERSION.SDK_INT >= 29) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, name)
                put(MediaStore.Downloads.MIME_TYPE, mime)
                put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/Hopper")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val uri = ctx.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("could not create download entry")
            ctx.contentResolver.openOutputStream(uri)!!.use { it.write(bytes) }
            values.clear(); values.put(MediaStore.Downloads.IS_PENDING, 0)
            ctx.contentResolver.update(uri, values, null, null)
            return "Download/Hopper/$name"
        }
        @Suppress("DEPRECATION")
        val dir = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS), "Hopper").apply { mkdirs() }
        val f = File(dir, name)
        FileOutputStream(f).use { it.write(bytes) }
        return f.absolutePath
    }

    /** Detect images by their magic bytes — vendor clipboards often report no mime type. */
    private fun sniffMime(b: ByteArray): String? {
        if (b.size < 12) return null
        fun at(i: Int) = b[i].toInt() and 0xFF
        return when {
            at(0) == 0x89 && at(1) == 0x50 && at(2) == 0x4E && at(3) == 0x47 -> "image/png"
            at(0) == 0xFF && at(1) == 0xD8 && at(2) == 0xFF -> "image/jpeg"
            at(0) == 0x47 && at(1) == 0x49 && at(2) == 0x46 -> "image/gif"
            at(0) == 0x52 && at(1) == 0x49 && at(2) == 0x46 && at(8) == 0x57 && at(9) == 0x45 -> "image/webp"
            at(4) == 0x66 && at(5) == 0x74 && at(6) == 0x79 && at(7) == 0x70 && at(8) == 0x68 && at(9) == 0x65 -> "image/heic"
            at(0) == 0x25 && at(1) == 0x50 && at(2) == 0x44 && at(3) == 0x46 -> "application/pdf"
            else -> null
        }
    }

    private fun extFor(mime: String) = when (mime) {
        "image/png" -> "png"; "image/jpeg" -> "jpg"; "image/gif" -> "gif"; "image/webp" -> "webp"; "image/heic" -> "heic"
        "application/pdf" -> "pdf"; "text/plain" -> "txt"; else -> "bin"
    }

    private fun readUri(ctx: Context, uri: Uri): ByteArray? = try {
        android.util.Log.i("HopperBridge", "opening $uri")
        ctx.contentResolver.openInputStream(uri)?.use { input ->
            val out = java.io.ByteArrayOutputStream()
            val buf = ByteArray(64 * 1024)
            var total = 0L
            while (true) {
                val n = input.read(buf); if (n < 0) break
                total += n; if (total > MAX_BYTES) return null
                out.write(buf, 0, n)
            }
            out.toByteArray()
        }
    } catch (e: Exception) { android.util.Log.w("HopperBridge", "cannot read $uri: $e"); null }

    private fun displayName(ctx: Context, uri: Uri): String? = try {
        ctx.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        } ?: uri.lastPathSegment
    } catch (_: Exception) { uri.lastPathSegment }

    // ---------------------------------------------------------------- permissions & setup
    fun setupStatus(ctx: Context): Map<String, Any?> {
        val pm = ContextCompat.getSystemService(ctx, PowerManager::class.java)
        val nm = ContextCompat.getSystemService(ctx, NotificationManager::class.java)
        return mapOf(
            "readLogs" to (ctx.checkSelfPermission(Manifest.permission.READ_LOGS) == PackageManager.PERMISSION_GRANTED),
            "overlay" to Settings.canDrawOverlays(ctx),
            "battery" to (pm?.isIgnoringBatteryOptimizations(ctx.packageName) ?: false),
            "notifications" to (nm?.areNotificationsEnabled() ?: false),
            "serviceRunning" to HopperService.running,
            "watcher" to HopperService.watcherActive,
            "sdk" to Build.VERSION.SDK_INT,
            "package" to ctx.packageName,
        )
    }

    private fun requestBatteryExemption(ctx: Context) {
        val i = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
            data = Uri.parse("package:${ctx.packageName}")
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        try { ctx.startActivity(i) } catch (_: Exception) {
            ctx.startActivity(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }
    }

    private fun openOverlaySettings(ctx: Context) {
        val i = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${ctx.packageName}"))
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        ctx.startActivity(i)
    }
}
