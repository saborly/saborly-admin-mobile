package com.saborly.saborly_admin

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class CustomFirebaseMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        val data = remoteMessage.data
        val isNewOrder = data["type"] == "new_order" ||
                remoteMessage.notification?.title?.contains("Order", ignoreCase = true) == true ||
                data["orderId"] != null

        if (!isNewOrder) return

        val appInForeground = isAppInForeground()

        if (!appInForeground) {
            // Start looping alarm service (background case).
            // For the killed-app case the service is started in MainActivity.onCreate.
            OrderRingtoneService.start(this)

            // Only show our notification for data-only messages.
            // Notification messages are auto-displayed by FCM — avoid duplicates.
            if (remoteMessage.notification == null) {
                showNotification(remoteMessage)
            }
        }
    }

    private fun isAppInForeground(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val appProcesses = activityManager.runningAppProcesses ?: return false
        for (process in appProcesses) {
            if (process.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
                process.processName == packageName
            ) return true
        }
        return false
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
    }

    private fun showNotification(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data
        val title = "🔔 New Order ${data["orderNumber"] ?: ""}"
        val body = "Order from ${data["customerName"] ?: "Customer"} - €${data["total"] ?: "0.00"}"
        val channelId = "order_channel"

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Order Notifications", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(true)
                enableLights(true)
                setSound(null, null) // Sound handled by OrderRingtoneService
            }
            notificationManager.createNotificationChannel(channel)
        }

        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("notification_type", "new_order")
            putExtra("order_id", data["orderId"])
        }
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .build()

        notificationManager.notify(1001, notification)
    }
}
