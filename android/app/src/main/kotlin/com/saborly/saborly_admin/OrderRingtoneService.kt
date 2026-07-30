package com.saborly.saborly_admin

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.os.Build
import android.os.IBinder
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import androidx.core.app.NotificationCompat

class OrderRingtoneService : Service() {

    private var mediaPlayer: MediaPlayer? = null
    private var wakeLock: PowerManager.WakeLock? = null
    private val stopHandler = Handler(Looper.getMainLooper())
    private val stopRunnable = Runnable { stopRingtoneAndSelf() }

    companion object {
        const val CHANNEL_ID = "order_alarm_channel"
        const val NOTIFICATION_ID = 9001
        const val ACTION_STOP = "com.saborly.saborly_admin.STOP_RINGTONE"
        const val RING_DURATION_MS = 20_000L

        fun start(context: Context) {
            val intent = Intent(context, OrderRingtoneService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            // Use regular startService (NOT startForegroundService) so Android
            // does NOT require startForeground() to be called — we're stopping, not starting.
            val intent = Intent(context, OrderRingtoneService::class.java)
            intent.action = ACTION_STOP
            try {
                context.startService(intent)
            } catch (_: Exception) {
                // If service isn't running, just force-stop it
                context.stopService(Intent(context, OrderRingtoneService::class.java))
            }
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // Always call startForeground() immediately — Android requires this within
        // 5 s of startForegroundService(), regardless of what we do next.
        createNotificationChannel()
        startForeground(NOTIFICATION_ID, buildNotification())

        if (intent?.action == ACTION_STOP) {
            stopRingtoneAndSelf()
            return START_NOT_STICKY
        }

        acquireWakeLock()
        playRingtone()

        // Auto-stop after RING_DURATION_MS, mirroring the foreground ring duration.
        stopHandler.removeCallbacks(stopRunnable)
        stopHandler.postDelayed(stopRunnable, RING_DURATION_MS)

        return START_STICKY
    }

    private fun playRingtone() {
        stopRingtone() // stop any existing player first
        try {
            // Use the raw resource — most reliable path
            val afd = resources.openRawResourceFd(R.raw.order_notification)

            mediaPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .setLegacyStreamType(AudioManager.STREAM_ALARM)
                        .build()
                )

                setDataSource(afd.fileDescriptor, afd.startOffset, afd.length)
                afd.close()

                // Max alarm volume
                val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
                val maxVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxVol, 0)

                isLooping = true
                setOnCompletionListener { mp ->
                    // Fallback: restart manually if loop flag didn't fire
                    try { mp.seekTo(0); mp.start() } catch (_: Exception) {}
                }
                prepare()
                start()
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun stopRingtone() {
        try {
            mediaPlayer?.apply {
                if (isPlaying) stop()
                release()
            }
            mediaPlayer = null
        } catch (_: Exception) {}
    }

    private fun stopRingtoneAndSelf() {
        stopHandler.removeCallbacks(stopRunnable)
        stopRingtone()
        wakeLock?.apply { if (isHeld) release() }
        wakeLock = null
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    private fun acquireWakeLock() {
        val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = pm.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "saborly::OrderRingtone"
        ).apply { acquire(15 * 60 * 1000L) } // 15 min max
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Order Alarm",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                setSound(null, null) // Sound handled by MediaPlayer
                description = "Incoming order alarm"
            }
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                .createNotificationChannel(channel)
        }
    }

    private fun buildNotification(): android.app.Notification {
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_type", "new_order")
        }
        val openPending = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val stopIntent = Intent(this, OrderRingtoneService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPending = PendingIntent.getService(
            this, 1, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("🔔 New Order!")
            .setContentText("Tap to open and accept or decline")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setOngoing(true)
            .setAutoCancel(false)
            .setContentIntent(openPending)
            .addAction(android.R.drawable.ic_delete, "Dismiss", stopPending)
            .build()
    }

    override fun onDestroy() {
        stopHandler.removeCallbacks(stopRunnable)
        stopRingtone()
        wakeLock?.apply { if (isHeld) release() }
        super.onDestroy()
    }
}
