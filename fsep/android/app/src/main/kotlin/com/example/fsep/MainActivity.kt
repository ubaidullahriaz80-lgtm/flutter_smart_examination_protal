package com.example.fsep

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity (not FlutterActivity) is required by local_auth:
// androidx.biometric.BiometricPrompt needs a FragmentActivity context.
class MainActivity : FlutterFragmentActivity() {
    // Same channel name as the Windows kiosk implementation (windows/runner);
    // shared Dart-facing contract in lib/core/kiosk/kiosk_service.dart.
    private val kioskChannelName = "com.fsep.app/kiosk"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, kioskChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enterKioskMode" -> result.success(enterKioskMode())
                    "exitKioskMode" -> result.success(exitKioskMode())
                    "isKioskModeActive" -> result.success(isKioskModeActive())
                    else -> result.notImplemented()
                }
            }
    }

    // FR-KS-02: engages Android Screen Pinning (Activity.startLockTask()).
    private fun enterKioskMode(): Boolean {
        return try {
            startLockTask()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun exitKioskMode(): Boolean {
        return try {
            stopLockTask()
            true
        } catch (e: Exception) {
            false
        }
    }

    private fun isKioskModeActive(): Boolean {
        val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            activityManager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else {
            @Suppress("DEPRECATION")
            activityManager.isInLockTaskMode
        }
    }
}
