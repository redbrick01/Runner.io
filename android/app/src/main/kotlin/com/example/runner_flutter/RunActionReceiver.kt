package com.example.runner_flutter

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class RunActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != RunLockScreenService.ACTION_HANDLE_NOTIFICATION) return

        val runId = intent.getStringExtra(RunLockScreenService.EXTRA_RUN_ID) ?: return
        val action = intent.getStringExtra(RunLockScreenService.EXTRA_ACTION_TYPE) ?: return

        RunLockScreenService.storePendingAction(context, runId, action)

        when (action) {
            "pause" -> {
                RunLockScreenService.updatePausedState(context, true)
                context.startService(RunLockScreenService.stopBackgroundTrackingIntent(context))
                RunLockScreenService.refreshIntent(context)?.let { context.startService(it) }
            }

            "resume" -> {
                RunLockScreenService.updatePausedState(context, false)
                context.startService(RunLockScreenService.startBackgroundTrackingIntent(context, emptyMap<String, Any?>()))
                RunLockScreenService.refreshIntent(context)?.let { context.startService(it) }
            }

            "stop", "cancel" -> {
                context.startService(
                    RunLockScreenService.stopIntent(context, emptyMap<String, Any?>())
                )
            }
        }

        context.sendBroadcast(
            Intent(RunLockScreenService.ACTION_NOTIFICATION_EVENT).apply {
                putExtra(RunLockScreenService.EXTRA_RUN_ID, runId)
                putExtra(RunLockScreenService.EXTRA_ACTION_TYPE, action)
            }
        )
    }
}
