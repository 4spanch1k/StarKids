package com.example.star_kids_mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val PAYMENT_RETURN_CHANNEL = "kz.boombala/payment_return"
    }

    private var paymentReturnChannel: MethodChannel? = null
    private var initialPaymentLink: String? = null

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        initialPaymentLink = intent?.dataString
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                getString(R.string.boom_bala_notification_channel_id),
                getString(R.string.boom_bala_notification_channel_name),
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            getSystemService(NotificationManager::class.java)
                ?.createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        paymentReturnChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PAYMENT_RETURN_CHANNEL,
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                if (call.method == "getInitialLink") {
                    result.success(initialPaymentLink)
                    initialPaymentLink = null
                } else {
                    result.notImplemented()
                }
            }
        }
        dispatchPaymentLink(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        dispatchPaymentLink(intent)
    }

    private fun dispatchPaymentLink(intent: Intent?) {
        val link = intent?.dataString ?: return
        initialPaymentLink = link
        val channel = paymentReturnChannel
        if (channel != null) {
            channel.invokeMethod("paymentLink", link)
        }
    }
}
