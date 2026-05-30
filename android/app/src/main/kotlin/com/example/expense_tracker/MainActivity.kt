package com.example.expense_tracker

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val smsPermissionRequestCode = 901
    private var pendingPermissionResult: MethodChannel.Result? = null

    companion object {
        private const val notificationChannelId = "provisional_transactions"
        private const val notificationId = 44
        private const val openProvisionalAction =
            "com.example.expense_tracker.OPEN_PROVISIONAL"
        private var launchProvisionalRequested = false
    }

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        handleIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleIntent(intent)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        SmsEventStreamHandler.initialize(applicationContext)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "expense_tracker/sms_permissions",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasSmsPermission" -> result.success(hasSmsPermission())
                "requestSmsPermission" -> requestSmsPermission(result)
                else -> result.notImplemented()
            }
        }

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "expense_tracker/sms_events",
        ).setStreamHandler(SmsEventStreamHandler)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "expense_tracker/provisional_notify",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "showPendingNotification" -> {
                    val count = call.argument<Int>("count") ?: 0
                    showPendingNotification(count)
                    result.success(null)
                }
                "clearPendingNotification" -> {
                    clearPendingNotification()
                    result.success(null)
                }
                "consumeLaunchRequest" -> {
                    val requested = launchProvisionalRequested
                    launchProvisionalRequested = false
                    result.success(requested)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun hasSmsPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return true
        }
        return checkSelfPermission(Manifest.permission.RECEIVE_SMS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (hasSmsPermission()) {
            result.success(true)
            return
        }
        pendingPermissionResult?.success(false)
        pendingPermissionResult = result
        val permissions = mutableListOf(Manifest.permission.RECEIVE_SMS)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissions.add(Manifest.permission.POST_NOTIFICATIONS)
        }
        requestPermissions(
            permissions.toTypedArray(),
            smsPermissionRequestCode,
        )
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != smsPermissionRequestCode) {
            return
        }
        pendingPermissionResult?.success(
            grantResults.isNotEmpty() &&
                grantResults.first() == PackageManager.PERMISSION_GRANTED,
        )
        pendingPermissionResult = null
    }

    private fun handleIntent(intent: Intent?) {
        if (intent?.action == openProvisionalAction) {
            launchProvisionalRequested = true
        }
    }

    private fun showPendingNotification(count: Int) {
        if (count <= 0) {
            clearPendingNotification()
            return
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) {
            return
        }
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                notificationChannelId,
                "Provisional transactions",
                NotificationManager.IMPORTANCE_DEFAULT,
            )
            manager.createNotificationChannel(channel)
        }
        val intent = Intent(this, MainActivity::class.java).apply {
            action = openProvisionalAction
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            Notification.Builder(this, notificationChannelId)
        } else {
            Notification.Builder(this)
        }
        val notification = builder
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("Provisional transactions pending")
            .setContentText("You have $count transaction SMS to review")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
        manager.notify(notificationId, notification)
    }

    private fun clearPendingNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(notificationId)
    }
}
