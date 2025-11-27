package com.saborly.saborly_admin

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.flutter.plugins.firebase.messaging.FlutterFirebaseMessagingService

class CustomFirebaseMessagingService : FlutterFirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        super.onMessageReceived(remoteMessage)

        // Check if this is a new order notification
        val data = remoteMessage.data
        val isNewOrder = data["type"] == "new_order" ||
                        remoteMessage.notification?.title?.contains("Order") == true

        if (isNewOrder && !isAppInForeground()) {
            showNotification(remoteMessage)
        }
    }

    private fun isAppInForeground(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        val appProcesses = activityManager.runningAppProcesses ?: return false

        val packageName = packageName
        for (appProcess in appProcesses) {
            if (appProcess.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND &&
                appProcess.processName == packageName) {
                return true
            }
        }
        return false
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Handle token refresh if needed
    }

    private fun showNotification(remoteMessage: RemoteMessage) {
        val data = remoteMessage.data

        // Get title and body
        val title = remoteMessage.notification?.title ?: "🔔 New Order ${data["orderNumber"] ?: ""}"
        val body = remoteMessage.notification?.body ?:
                  "Order from ${data["customerName"] ?: "Customer"} - €${data["total"] ?: "0.00"}"

        val channelId = "order_channel"
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        // Create notification channel for Android 8.0+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Order Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for new orders"
                enableVibration(true)
                enableLights(true)
                setSound(Uri.parse("android.resource://" + packageName + "/" + R.raw.order_notification), null)
            }
            notificationManager.createNotificationChannel(channel)
        }

        // Create intent for notification tap
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("notification_type", "new_order")
            putExtra("order_id", data["orderId"])
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // Build notification
        val notificationBuilder = NotificationCompat.Builder(this, channelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setAutoCancel(true)
            .setSound(Uri.parse("android.resource://" + packageName + "/" + R.raw.order_notification))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setContentIntent(pendingIntent)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))

        // Show notification
        notificationManager.notify(System.currentTimeMillis().toInt(), notificationBuilder.build())
    }
}