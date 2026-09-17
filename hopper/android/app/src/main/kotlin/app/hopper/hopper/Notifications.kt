package app.hopper.hopper

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat

/** Small helper around the three notification channels Hopper uses. */
object Notifications {
    const val CH_SERVICE = "hopper.service"
    const val CH_CLIPS = "hopper.clips"
    const val CH_HELD = "hopper.held"
    const val ID_SERVICE = 1
    private const val ID_CLIP = 2

    fun ensureChannels(ctx: Context) {
        val nm = ContextCompat.getSystemService(ctx, NotificationManager::class.java) ?: return
        nm.createNotificationChannel(NotificationChannel(CH_SERVICE, "Sync status", NotificationManager.IMPORTANCE_MIN).apply {
            description = "Keeps Hopper running in the background"; setShowBadge(false)
        })
        nm.createNotificationChannel(NotificationChannel(CH_CLIPS, "Received clips", NotificationManager.IMPORTANCE_LOW).apply {
            description = "A short notice when something arrives from another device"; setShowBadge(false)
        })
        nm.createNotificationChannel(NotificationChannel(CH_HELD, "Held back (sensitive)", NotificationManager.IMPORTANCE_DEFAULT).apply {
            description = "Something that looks like a password or code was held back"
        })
    }

    /** args: title, body, heldClipId?, openPath? */
    fun show(ctx: Context, args: Map<*, *>) {
        ensureChannels(ctx)
        val title = args["title"] as String? ?: "Hopper"
        val body = args["body"] as String? ?: ""
        val heldId = args["heldClipId"] as String?
        val open = PendingIntent.getActivity(ctx, 0, Intent(ctx, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
        val b = NotificationCompat.Builder(ctx, if (heldId != null) CH_HELD else CH_CLIPS)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setContentIntent(open)
            .setAutoCancel(true)
        if (heldId != null) {
            val send = PendingIntent.getBroadcast(ctx, heldId.hashCode(),
                Intent(ctx, ActionReceiver::class.java).setAction(ActionReceiver.ACTION_SEND_HELD).putExtra("id", heldId),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT)
            b.addAction(0, "Send once", send)
        } else {
            b.setTimeoutAfter(5000).setSilent(true)
        }
        try { NotificationManagerCompat.from(ctx).notify(heldId?.hashCode() ?: ID_CLIP, b.build()) } catch (_: SecurityException) {}
    }

    fun cancel(ctx: Context, id: Int) = NotificationManagerCompat.from(ctx).cancel(id)
}

/** Handles notification button taps. */
class ActionReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        when (intent.action) {
            ACTION_SEND_HELD -> intent.getStringExtra("id")?.let {
                HopperBridge.sendHeldClip(it)
                Notifications.cancel(ctx, it.hashCode())
            }
        }
    }
    companion object { const val ACTION_SEND_HELD = "app.hopper.SEND_HELD" }
}

/** Restart the sync service after a reboot. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(ctx: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED || intent.action == Intent.ACTION_MY_PACKAGE_REPLACED) {
            HopperService.ensureRunning(ctx)
        }
    }
}
