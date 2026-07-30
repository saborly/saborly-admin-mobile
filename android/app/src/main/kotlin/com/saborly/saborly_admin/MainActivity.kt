package com.saborly.saborly_admin

import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CHANNEL = "com.saborly.saborly_admin/ringtone"
    private var methodChannel: MethodChannel? = null
    private var pendingOrderId: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "stopRingtone" -> {
                    OrderRingtoneService.stop(this)
                    result.success(null)
                }
                "startRingtone" -> {
                    OrderRingtoneService.start(this)
                    result.success(null)
                }
                "getInitialOrderId" -> {
                    result.success(pendingOrderId)
                    pendingOrderId = null
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleNotificationIntent(intent)
    }

    private fun handleNotificationIntent(intent: Intent?) {
        val extras = intent?.extras
        val type = intent?.getStringExtra("notification_type") ?: extras?.getString("notification_type")
        val orderId = intent?.getStringExtra("order_id") ?: extras?.getString("order_id")

        if (type == "new_order") {
            OrderRingtoneService.start(this)
        }

        if (!orderId.isNullOrEmpty()) {
            val channel = methodChannel
            if (channel != null) {
                channel.invokeMethod("openOrder", orderId)
            } else {
                // Engine not ready yet (cold start) — deliver once configureFlutterEngine runs.
                pendingOrderId = orderId
            }
        }
    }
}
