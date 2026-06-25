package com.example.expense_tracker

import android.Manifest
import android.app.KeyguardManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val smsPermissionRequestCode = 901
    private val notificationPermissionRequestCode = 902
    private val appLockRequestCode = 903
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var pendingNotificationPermissionResult: MethodChannel.Result? = null
    private var pendingAppLockResult: MethodChannel.Result? = null
    private var secureWindowRequested = false
    private var secureWindowAlwaysOn = false

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
                "hasNotificationPermission" -> result.success(hasNotificationPermission())
                "requestNotificationPermission" -> requestNotificationPermission(result)
                else -> result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "expense_tracker/app_lock",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "isDeviceLockSupported" -> result.success(isDeviceLockSupported())
                "authenticateDeviceLock" -> authenticateDeviceLock(result)
                "setSecureWindow" -> {
                    secureWindowRequested = call.argument<Boolean>("enabled") ?: false
                    applySecureWindowFlag()
                    result.success(null)
                }
                "setSecureWindowAlwaysOn" -> {
                    secureWindowAlwaysOn = call.argument<Boolean>("enabled") ?: false
                    applySecureWindowFlag()
                    result.success(null)
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

    private fun hasNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            return true
        }
        return checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) ==
            PackageManager.PERMISSION_GRANTED
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (hasNotificationPermission()) {
            result.success(true)
            return
        }
        pendingNotificationPermissionResult?.success(false)
        pendingNotificationPermissionResult = result
        requestPermissions(
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            notificationPermissionRequestCode,
        )
    }

    private fun isDeviceLockSupported(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.M) {
            return false
        }
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        return keyguardManager.isDeviceSecure
    }

    private fun authenticateDeviceLock(result: MethodChannel.Result) {
        if (!isDeviceLockSupported()) {
            result.success(false)
            return
        }
        val keyguardManager = getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager
        val intent = keyguardManager.createConfirmDeviceCredentialIntent(
            "Unlock Expense Tracker",
            "Confirm your device PIN, pattern, or password",
        )
        if (intent == null) {
            result.success(false)
            return
        }
        pendingAppLockResult?.success(false)
        pendingAppLockResult = result
        startActivityForResult(intent, appLockRequestCode)
    }

    private fun applySecureWindowFlag() {
        if (secureWindowRequested || secureWindowAlwaysOn) {
            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
        }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        when (requestCode) {
            smsPermissionRequestCode -> {
                pendingPermissionResult?.success(
                    grantResults.isNotEmpty() &&
                        grantResults.first() == PackageManager.PERMISSION_GRANTED,
                )
                pendingPermissionResult = null
            }
            notificationPermissionRequestCode -> {
                pendingNotificationPermissionResult?.success(
                    grantResults.isNotEmpty() &&
                        grantResults.first() == PackageManager.PERMISSION_GRANTED,
                )
                pendingNotificationPermissionResult = null
            }
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == appLockRequestCode) {
            pendingAppLockResult?.success(resultCode == RESULT_OK)
            pendingAppLockResult = null
        }
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
            .setSmallIcon(R.drawable.ic_notification)
            .setContentTitle("Provisional transactions pending")
            .setContentText("You have $count transaction SMS to review")
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setAutoCancel(false)
            .build()
            .apply {
                flags = flags or Notification.FLAG_NO_CLEAR or Notification.FLAG_ONGOING_EVENT
            }
        manager.notify(notificationId, notification)
    }

    private fun clearPendingNotification() {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        manager.cancel(notificationId)
    }
}
