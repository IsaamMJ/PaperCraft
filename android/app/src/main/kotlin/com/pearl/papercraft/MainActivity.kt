package com.pearl.papercraft

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val NOTIFICATION_CHANNEL = "com.pearl.papercraft/notifications"
    private val REQUEST_CODE_NOTIFICATION = 2713

    private var notificationMethodChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Notification permission channel
        notificationMethodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, NOTIFICATION_CHANNEL)
        notificationMethodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "isNotificationPermissionGranted" -> {
                    result.success(isNotificationPermissionGranted())
                }
                "requestNotificationPermission" -> {
                    requestNotificationPermission(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    // ============= NOTIFICATION PERMISSION METHODS =============

    private fun isNotificationPermissionGranted(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            return ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        }
        // For Android < 13, notifications are allowed by default
        return true
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) {
                // Permission is not granted, request it
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(Manifest.permission.POST_NOTIFICATIONS),
                    REQUEST_CODE_NOTIFICATION
                )
                // Store the result callback for onRequestPermissionsResult
                pendingNotificationPermissionResult = result
            } else {
                // Permission already granted
                result.success(true)
            }
        } else {
            // For Android < 13, notifications are allowed by default
            result.success(true)
        }
    }

    private var pendingNotificationPermissionResult: MethodChannel.Result? = null

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode == REQUEST_CODE_NOTIFICATION) {
            val isGranted = grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            pendingNotificationPermissionResult?.success(isGranted)
            pendingNotificationPermissionResult = null
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        notificationMethodChannel = null
        pendingNotificationPermissionResult = null
    }
}
