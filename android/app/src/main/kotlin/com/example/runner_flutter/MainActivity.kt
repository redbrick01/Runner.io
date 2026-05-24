package com.runnerio.app

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.content.pm.PackageManager
import android.media.AudioManager
import android.media.ToneGenerator
import android.os.Bundle
import android.os.Build
import androidx.core.app.NotificationManagerCompat
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private lateinit var liveActivityChannel: MethodChannel
    private var pendingPermissionResult: MethodChannel.Result? = null
    private var splitToneGenerator: ToneGenerator? = null

    private val actionReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != RunLockScreenService.ACTION_NOTIFICATION_EVENT) return

            val runId = intent.getStringExtra(RunLockScreenService.EXTRA_RUN_ID) ?: return
            val action = intent.getStringExtra(RunLockScreenService.EXTRA_ACTION_TYPE) ?: return
            val payload = mapOf("runId" to runId, "action" to action)
            liveActivityChannel.invokeMethod("onLiveActivityAction", payload)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        liveActivityChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            RUN_LIVE_ACTIVITY_CHANNEL,
        )

        liveActivityChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "startLiveActivity" -> {
                    val arguments = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                    ContextCompat.startForegroundService(
                        this,
                        RunLockScreenService.startIntent(this, arguments),
                    )
                    result.success(arguments["runId"] as? String)
                }

                "updateLiveActivity" -> {
                    val arguments = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                    startService(RunLockScreenService.updateIntent(this, arguments))
                    result.success(null)
                }

                "endLiveActivity" -> {
                    val arguments = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                    startService(RunLockScreenService.stopIntent(this, arguments))
                    result.success(null)
                }

                "consumePendingAction" -> {
                    result.success(RunLockScreenService.consumePendingAction(this))
                }

                "startAndroidBackgroundTracking" -> {
                    val arguments = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
                    startService(RunLockScreenService.startBackgroundTrackingIntent(this, arguments))
                    result.success(null)
                }

                "stopAndroidBackgroundTracking" -> {
                    startService(RunLockScreenService.stopBackgroundTrackingIntent(this))
                    result.success(null)
                }

                "getAndroidRunSnapshot" -> {
                    result.success(RunLockScreenService.buildSnapshot(this))
                }

                "clearPendingAction" -> {
                    RunLockScreenService.clearPendingAction(this)
                    result.success(null)
                }

                "requestNotificationPermission" -> {
                    requestNotificationPermission(result)
                }

                "playSplitChime" -> {
                    playSplitChime()
                    result.success(null)
                }

                "announceSplitInBackground" -> {
                    val speech = (call.arguments as? String)?.trim().orEmpty()
                    if (speech.isNotEmpty()) {
                        startService(RunLockScreenService.announceSplitIntent(this, speech))
                    }
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        handleNotificationIntent(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleNotificationIntent(intent)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)

        if (requestCode != NOTIFICATION_PERMISSION_REQUEST_CODE) return

        val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
    }

    override fun onStart() {
        super.onStart()
        val filter = IntentFilter(RunLockScreenService.ACTION_NOTIFICATION_EVENT)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(actionReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            @Suppress("DEPRECATION")
            registerReceiver(actionReceiver, filter)
        }
    }

    override fun onStop() {
        unregisterReceiver(actionReceiver)
        super.onStop()
    }

    override fun onDestroy() {
        splitToneGenerator?.release()
        splitToneGenerator = null
        super.onDestroy()
    }

    companion object {
        private const val RUN_LIVE_ACTIVITY_CHANNEL = "run_live_activity"
        private const val NOTIFICATION_PERMISSION_REQUEST_CODE = 3001
    }

    private fun handleNotificationIntent(intent: Intent?) {
        val launchAction = intent?.getStringExtra(RunLockScreenService.EXTRA_ACTION_TYPE) ?: return
        val runId = intent.getStringExtra(RunLockScreenService.EXTRA_RUN_ID) ?: return

        RunLockScreenService.storePendingAction(this, runId, launchAction)
        startService(RunLockScreenService.stopIntent(this, emptyMap<String, Any?>()))

        if (::liveActivityChannel.isInitialized) {
            liveActivityChannel.invokeMethod(
                "onLiveActivityAction",
                mapOf("runId" to runId, "action" to launchAction),
            )
        }

        intent.replaceExtras(Bundle())
    }

    private fun requestNotificationPermission(result: MethodChannel.Result) {
        if (!NotificationManagerCompat.from(this).areNotificationsEnabled()) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
                result.success(false)
                return
            }
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) {
            result.success(true)
            return
        }

        if (ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.POST_NOTIFICATIONS,
            ) == PackageManager.PERMISSION_GRANTED
        ) {
            result.success(true)
            return
        }

        pendingPermissionResult = result
        ActivityCompat.requestPermissions(
            this,
            arrayOf(Manifest.permission.POST_NOTIFICATIONS),
            NOTIFICATION_PERMISSION_REQUEST_CODE,
        )
    }

    private fun playSplitChime() {
        if (splitToneGenerator == null) {
            splitToneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
        }
        runCatching {
            splitToneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP2, 180)
        }
    }
}
