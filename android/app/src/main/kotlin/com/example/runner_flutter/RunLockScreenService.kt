package com.example.runner_flutter

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.IBinder
import android.os.Looper
import android.speech.tts.TextToSpeech
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.ToneGenerator
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import org.json.JSONArray
import org.json.JSONObject
import kotlin.math.max
import java.util.Locale

class RunLockScreenService : Service() {
    private var locationManager: LocationManager? = null
    private var locationListener: LocationListener? = null
    private var splitTts: TextToSpeech? = null
    private var isSplitTtsReady: Boolean = false
    private var pendingSplitSpeech: String? = null
    private var splitToneGenerator: ToneGenerator? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_START, ACTION_UPDATE -> {
                if (shouldIgnoreIncomingUpdate(intent)) {
                    return START_NOT_STICKY
                }
                persistNotificationState(intent)
                val notification = buildNotification(intent)
                if (intent.action == ACTION_START) {
                    startForeground(NOTIFICATION_ID, notification)
                } else {
                    val manager = getSystemService(NotificationManager::class.java)
                    manager.notify(NOTIFICATION_ID, notification)
                }
            }

            ACTION_BACKGROUND_TRACKING_START -> {
                persistBackgroundTrackingState(intent)
                startBackgroundLocationTracking()
            }

            ACTION_BACKGROUND_TRACKING_STOP -> {
                setBackgroundTrackingEnabled(false)
                stopBackgroundLocationTracking()
            }

            ACTION_STOP -> {
                setBackgroundTrackingEnabled(false)
                stopBackgroundLocationTracking()
                clearNotificationState(this)
                stopForeground(STOP_FOREGROUND_REMOVE)
                stopSelf()
            }

            ACTION_ANNOUNCE_SPLIT -> {
                val speech = intent.getStringExtra(EXTRA_SPLIT_SPEECH).orEmpty().trim()
                if (speech.isNotEmpty()) {
                    speakSplit(speech)
                }
            }
        }

        return START_NOT_STICKY
    }

    override fun onDestroy() {
        stopBackgroundLocationTracking()
        splitTts?.stop()
        splitTts?.shutdown()
        splitTts = null
        isSplitTtsReady = false
        pendingSplitSpeech = null
        splitToneGenerator?.release()
        splitToneGenerator = null
        super.onDestroy()
    }

    private fun buildNotification(intent: Intent): Notification {
        createNotificationChannel()

        val runId = intent.getStringExtra(EXTRA_RUN_ID).orEmpty()
        val title = intent.getStringExtra(EXTRA_TITLE).orEmpty().ifBlank { "러닝 중" }
        val elapsedSeconds = resolvedElapsedSeconds(intent.getIntExtra(EXTRA_ELAPSED_SECONDS, 0))
        val distanceMeters = resolvedDistanceMeters(intent.getDoubleExtra(EXTRA_DISTANCE_METERS, 0.0))
        val paceText = resolvedPaceText(intent.getStringExtra(EXTRA_PACE_TEXT)).orEmpty().ifBlank { "--'--\"" }
        val isPaused = resolvedPausedState(intent.getBooleanExtra(EXTRA_IS_PAUSED, false))

        val pauseLabel = if (isPaused) "재개" else "일시정지"
        val pauseIcon = if (isPaused) android.R.drawable.ic_media_play else android.R.drawable.ic_media_pause
        val statusText = if (isPaused) "일시정지" else "러닝 중"
        val contentIntent = contentPendingIntent(runId)
        val startedAt = System.currentTimeMillis() - (elapsedSeconds * 1000L)

        val builder = NotificationCompat.Builder(this, NOTIFICATION_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_media_play)
            .setContentTitle(title)
            .setContentText("$statusText · ${formatDistance(distanceMeters)} · $paceText")
            .setStyle(
                NotificationCompat.BigTextStyle().bigText(
                    "시간 ${formatElapsedTime(elapsedSeconds)}   거리 ${formatDistance(distanceMeters)}   페이스 $paceText"
                )
            )
            .setContentIntent(contentIntent)
            .setWhen(startedAt)
            .setShowWhen(true)
            .setUsesChronometer(!isPaused)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setCategory(NotificationCompat.CATEGORY_PROGRESS)
            .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
            .addAction(
                pauseIcon,
                pauseLabel,
                actionPendingIntent(runId, if (isPaused) "resume" else "pause")
            )
            .addAction(
                android.R.drawable.ic_media_next,
                "종료",
                stopActivityPendingIntent(runId)
            )
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "취소",
                actionPendingIntent(runId, "cancel")
            )

        if (NotificationManagerCompat.from(this).canPostPromotedNotifications()) {
            builder.setRequestPromotedOngoing(true)
        }

        return builder.build()
    }

    private fun actionPendingIntent(runId: String, action: String): PendingIntent {
        val intent = Intent(this, RunActionReceiver::class.java).apply {
            this.action = ACTION_HANDLE_NOTIFICATION
            putExtra(EXTRA_RUN_ID, runId)
            putExtra(EXTRA_ACTION_TYPE, action)
        }

        return PendingIntent.getBroadcast(
            this,
            (runId.hashCode() * 31) + action.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun stopActivityPendingIntent(runId: String): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_RUN_ID, runId)
            putExtra(EXTRA_ACTION_TYPE, "stop")
        }

        return PendingIntent.getActivity(
            this,
            (runId.hashCode() * 31) + "stop_activity".hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun contentPendingIntent(runId: String): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra(EXTRA_RUN_ID, runId)
        }

        return PendingIntent.getActivity(
            this,
            runId.hashCode(),
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return

        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(NOTIFICATION_CHANNEL_ID) != null) return

        val channel = NotificationChannel(
            NOTIFICATION_CHANNEL_ID,
            "Running Controls",
            NotificationManager.IMPORTANCE_DEFAULT,
        ).apply {
            description = "러닝 잠금화면 컨트롤"
            setShowBadge(false)
            lockscreenVisibility = Notification.VISIBILITY_PUBLIC
        }

        manager.createNotificationChannel(channel)
    }

    private fun resolvedPausedState(defaultValue: Boolean): Boolean {
        val preferences = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        return when (preferences.getString(PENDING_ACTION_KEY, null)) {
            "pause" -> true
            "resume" -> false
            else -> defaultValue
        }
    }

    private fun resolvedElapsedSeconds(defaultValue: Int): Int {
        val preferences = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        return when (preferences.getString(PENDING_ACTION_KEY, null)) {
            "pause" -> preferences.getInt(STATE_ELAPSED_SECONDS_KEY, defaultValue)
            else -> defaultValue
        }
    }

    private fun resolvedDistanceMeters(defaultValue: Double): Double {
        val preferences = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        return when (preferences.getString(PENDING_ACTION_KEY, null)) {
            "pause" -> preferences.getFloat(STATE_DISTANCE_METERS_KEY, defaultValue.toFloat()).toDouble()
            else -> defaultValue
        }
    }

    private fun resolvedPaceText(defaultValue: String?): String? {
        val preferences = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        return when (preferences.getString(PENDING_ACTION_KEY, null)) {
            "pause" -> preferences.getString(STATE_PACE_TEXT_KEY, defaultValue)
            else -> defaultValue
        }
    }

    private fun shouldIgnoreIncomingUpdate(intent: Intent): Boolean {
        val runId = intent.getStringExtra(EXTRA_RUN_ID) ?: return false
        val preferences = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val pendingRunId = preferences.getString(PENDING_RUN_ID_KEY, null)
        val pendingAction = preferences.getString(PENDING_ACTION_KEY, null)
        if (pendingRunId != runId || pendingAction == null) return false

        return pendingAction == "stop" || pendingAction == "cancel"
    }

    private fun startBackgroundLocationTracking() {
        if (!isBackgroundTrackingEnabled(this) || isPaused(this)) {
            return
        }
        if (
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_FINE_LOCATION) != PackageManager.PERMISSION_GRANTED &&
            ContextCompat.checkSelfPermission(this, android.Manifest.permission.ACCESS_COARSE_LOCATION) != PackageManager.PERMISSION_GRANTED
        ) {
            return
        }

        val manager = getSystemService(LocationManager::class.java) ?: return
        val listener = object : LocationListener {
            override fun onLocationChanged(location: Location) {
                handleBackgroundLocation(location)
            }
        }

        locationManager = manager
        locationListener = listener

        runCatching {
            manager.requestLocationUpdates(
                LocationManager.GPS_PROVIDER,
                2000L,
                5f,
                listener,
                Looper.getMainLooper(),
            )
        }
        runCatching {
            manager.requestLocationUpdates(
                LocationManager.NETWORK_PROVIDER,
                5000L,
                5f,
                listener,
                Looper.getMainLooper(),
            )
        }
    }

    private fun stopBackgroundLocationTracking() {
        val manager = locationManager ?: return
        val listener = locationListener ?: return
        runCatching {
            manager.removeUpdates(listener)
        }
        locationManager = null
        locationListener = null
    }

    private fun handleBackgroundLocation(location: Location) {
        if (!isBackgroundTrackingEnabled(this) || isPaused(this)) {
            return
        }
        if (location.accuracy > 25f) {
            return
        }

        val preferences = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val previousLat = preferences.getString(STATE_LAST_LAT_KEY, null)?.toDoubleOrNull()
        val previousLng = preferences.getString(STATE_LAST_LNG_KEY, null)?.toDoubleOrNull()
        val previousAltitude = preferences.getString(STATE_LAST_ALTITUDE_KEY, null)?.toDoubleOrNull()
        val previousTime = preferences.getLong(STATE_LAST_TIME_MS_KEY, 0L)
        val editor = preferences.edit()
        val currentAltitude = if (location.hasAltitude()) location.altitude else Double.NaN

        if (previousLat == null || previousLng == null || previousTime == 0L) {
            appendRoutePoint(editor, location.latitude, location.longitude, currentAltitude)
            editor
                .putString(STATE_LAST_LAT_KEY, location.latitude.toString())
                .putString(STATE_LAST_LNG_KEY, location.longitude.toString())
                .putString(STATE_LAST_ALTITUDE_KEY, currentAltitude.takeIf { it.isFinite() }?.toString())
                .putLong(STATE_LAST_TIME_MS_KEY, location.time)
                .apply()
            return
        }

        val results = FloatArray(1)
        Location.distanceBetween(previousLat, previousLng, location.latitude, location.longitude, results)
        val distance = results[0].toDouble()
        if (distance < 3.0) {
            return
        }

        val elapsedSeconds = max((location.time - previousTime) / 1000.0, 0.001)
        val derivedSpeed = distance / elapsedSeconds
        if (derivedSpeed > 30.0) {
            return
        }

        val totalDistance = preferences.getFloat(STATE_DISTANCE_METERS_KEY, 0f).toDouble() + distance
        val ascentGain =
            if (previousAltitude != null && currentAltitude.isFinite()) max(currentAltitude - previousAltitude, 0.0) else 0.0
        val totalAscent = preferences.getFloat(STATE_TOTAL_ASCENT_METERS_KEY, 0f).toDouble() + ascentGain
        val totalElapsed = currentElapsedSeconds(preferences)
        val paceText = formatPace(totalElapsed, totalDistance)
        val completedKm = (totalDistance / 1000.0).toInt()
        val lastAnnouncedKm = preferences.getInt(STATE_LAST_ANNOUNCED_SPLIT_KM_KEY, 0)
        val lastSplitElapsed = preferences.getInt(STATE_LAST_ANNOUNCED_SPLIT_ELAPSED_SECONDS_KEY, 0)

        appendRoutePoint(editor, location.latitude, location.longitude, currentAltitude)
        editor
            .putFloat(STATE_DISTANCE_METERS_KEY, totalDistance.toFloat())
            .putFloat(STATE_TOTAL_ASCENT_METERS_KEY, totalAscent.toFloat())
            .putString(STATE_PACE_TEXT_KEY, paceText)
            .putInt(STATE_ELAPSED_SECONDS_KEY, totalElapsed)
            .putString(STATE_LAST_LAT_KEY, location.latitude.toString())
            .putString(STATE_LAST_LNG_KEY, location.longitude.toString())
            .putString(STATE_LAST_ALTITUDE_KEY, currentAltitude.takeIf { it.isFinite() }?.toString())
            .putLong(STATE_LAST_TIME_MS_KEY, location.time)
        if (completedKm > lastAnnouncedKm) {
            val splitDuration = max(totalElapsed - lastSplitElapsed, 0)
            val speech = "${completedKm}킬로미터, 구간 페이스 ${formatSplitPaceKorean(splitDuration)}"
            speakSplit(speech)
            editor
                .putInt(STATE_LAST_ANNOUNCED_SPLIT_KM_KEY, completedKm)
                .putInt(STATE_LAST_ANNOUNCED_SPLIT_ELAPSED_SECONDS_KEY, totalElapsed)
        }
        editor.apply()

        refreshNotification()
    }

    private fun ensureSplitTts() {
        if (splitTts != null) {
            return
        }
        splitTts = TextToSpeech(applicationContext) { status ->
            if (status == TextToSpeech.SUCCESS) {
                isSplitTtsReady = true
                splitTts?.language = Locale.KOREAN
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                    splitTts?.setAudioAttributes(
                        AudioAttributes.Builder()
                            .setUsage(AudioAttributes.USAGE_ASSISTANCE_NAVIGATION_GUIDANCE)
                            .setContentType(AudioAttributes.CONTENT_TYPE_SPEECH)
                            .build()
                    )
                }
                pendingSplitSpeech?.let {
                    pendingSplitSpeech = null
                    speakSplit(it)
                }
            }
        }
    }

    private fun speakSplit(message: String) {
        ensureSplitTts()
        val tts = splitTts
        if (tts == null || !isSplitTtsReady) {
            pendingSplitSpeech = message
            return
        }
        playSplitChime()
        android.os.Handler(Looper.getMainLooper()).postDelayed({
            val activeTts = splitTts ?: return@postDelayed
            if (!isSplitTtsReady) return@postDelayed
            activeTts.speak(
                message,
                TextToSpeech.QUEUE_FLUSH,
                null,
                "split_${System.currentTimeMillis()}"
            )
        }, 180L)
    }

    private fun playSplitChime() {
        if (splitToneGenerator == null) {
            splitToneGenerator = ToneGenerator(AudioManager.STREAM_MUSIC, 80)
        }
        runCatching {
            splitToneGenerator?.startTone(ToneGenerator.TONE_PROP_BEEP2, 120)
        }
    }

    private fun refreshNotification() {
        val intent = refreshIntent(this) ?: return
        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(NOTIFICATION_ID, buildNotification(intent))
    }

    companion object {
        const val ACTION_START = "com.example.runner_flutter.run.START"
        const val ACTION_UPDATE = "com.example.runner_flutter.run.UPDATE"
        const val ACTION_STOP = "com.example.runner_flutter.run.STOP"
        const val ACTION_BACKGROUND_TRACKING_START = "com.example.runner_flutter.run.BACKGROUND_START"
        const val ACTION_BACKGROUND_TRACKING_STOP = "com.example.runner_flutter.run.BACKGROUND_STOP"
        const val ACTION_ANNOUNCE_SPLIT = "com.example.runner_flutter.run.ANNOUNCE_SPLIT"
        const val ACTION_HANDLE_NOTIFICATION = "com.example.runner_flutter.run.HANDLE_NOTIFICATION"
        const val ACTION_NOTIFICATION_EVENT = "com.example.runner_flutter.run.NOTIFICATION_EVENT"

        const val EXTRA_RUN_ID = "runId"
        const val EXTRA_TITLE = "title"
        const val EXTRA_ELAPSED_SECONDS = "elapsedSeconds"
        const val EXTRA_DISTANCE_METERS = "distanceMeters"
        const val EXTRA_TOTAL_ASCENT_METERS = "totalAscentMeters"
        const val EXTRA_PACE_TEXT = "paceText"
        const val EXTRA_IS_PAUSED = "isPaused"
        const val EXTRA_ACTION_TYPE = "action"
        const val EXTRA_ROUTE_POINTS_JSON = "routePointsJson"
        const val EXTRA_SPLIT_SPEECH = "splitSpeech"

        private const val NOTIFICATION_CHANNEL_ID = "running_live_updates"
        private const val NOTIFICATION_ID = 12001
        private const val PREFERENCES_NAME = "run_live_activity"
        private const val PENDING_ACTION_KEY = "pending_action"
        private const val PENDING_RUN_ID_KEY = "pending_run_id"
        private const val STATE_TITLE_KEY = "state_title"
        private const val STATE_RUN_ID_KEY = "state_run_id"
        private const val STATE_ELAPSED_SECONDS_KEY = "state_elapsed_seconds"
        private const val STATE_DISTANCE_METERS_KEY = "state_distance_meters"
        private const val STATE_PACE_TEXT_KEY = "state_pace_text"
        private const val STATE_IS_PAUSED_KEY = "state_is_paused"
        private const val STATE_STARTED_AT_MS_KEY = "state_started_at_ms"
        private const val STATE_PAUSED_AT_MS_KEY = "state_paused_at_ms"
        private const val STATE_PAUSED_DURATION_MS_KEY = "state_paused_duration_ms"
        private const val STATE_LAST_LAT_KEY = "state_last_lat"
        private const val STATE_LAST_LNG_KEY = "state_last_lng"
        private const val STATE_LAST_ALTITUDE_KEY = "state_last_altitude"
        private const val STATE_LAST_TIME_MS_KEY = "state_last_time_ms"
        private const val STATE_ROUTE_POINTS_KEY = "state_route_points_json"
        private const val STATE_BACKGROUND_TRACKING_ENABLED_KEY = "state_background_tracking_enabled"
        private const val STATE_TOTAL_ASCENT_METERS_KEY = "state_total_ascent_meters"
        private const val STATE_LAST_ANNOUNCED_SPLIT_KM_KEY = "state_last_announced_split_km"
        private const val STATE_LAST_ANNOUNCED_SPLIT_ELAPSED_SECONDS_KEY = "state_last_announced_split_elapsed_seconds"

        fun startIntent(context: Context, arguments: Map<*, *>): Intent {
            return baseIntent(context, ACTION_START, arguments)
        }

        fun updateIntent(context: Context, arguments: Map<*, *>): Intent {
            return baseIntent(context, ACTION_UPDATE, arguments)
        }

        fun stopIntent(context: Context, arguments: Map<*, *>): Intent {
            return baseIntent(context, ACTION_STOP, arguments)
        }

        fun startBackgroundTrackingIntent(context: Context, arguments: Map<*, *>): Intent {
            return baseIntent(context, ACTION_BACKGROUND_TRACKING_START, arguments)
        }

        fun stopBackgroundTrackingIntent(context: Context): Intent {
            return Intent(context, RunLockScreenService::class.java).apply {
                action = ACTION_BACKGROUND_TRACKING_STOP
            }
        }

        fun announceSplitIntent(context: Context, speech: String): Intent {
            return Intent(context, RunLockScreenService::class.java).apply {
                action = ACTION_ANNOUNCE_SPLIT
                putExtra(EXTRA_SPLIT_SPEECH, speech)
            }
        }

        fun refreshIntent(context: Context): Intent? {
            val state = loadNotificationState(context) ?: return null
            return Intent(context, RunLockScreenService::class.java).apply {
                action = ACTION_UPDATE
                putExtra(EXTRA_RUN_ID, state.runId)
                putExtra(EXTRA_TITLE, state.title)
                putExtra(EXTRA_ELAPSED_SECONDS, state.elapsedSeconds)
                putExtra(EXTRA_DISTANCE_METERS, state.distanceMeters)
                putExtra(EXTRA_PACE_TEXT, state.paceText)
                putExtra(EXTRA_IS_PAUSED, state.isPaused)
            }
        }

        fun storePendingAction(context: Context, runId: String, action: String) {
            context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .edit()
                .putString(PENDING_RUN_ID_KEY, runId)
                .putString(PENDING_ACTION_KEY, action)
                .apply()
        }

        fun consumePendingAction(context: Context): Map<String, String>? {
            val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            val runId = preferences.getString(PENDING_RUN_ID_KEY, null)
            val action = preferences.getString(PENDING_ACTION_KEY, null)
            if (runId.isNullOrBlank() || action.isNullOrBlank()) return null
            return mapOf("runId" to runId, "action" to action)
        }

        fun clearPendingAction(context: Context) {
            context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .edit()
                .remove(PENDING_RUN_ID_KEY)
                .remove(PENDING_ACTION_KEY)
                .apply()
        }

        fun updatePausedState(context: Context, isPaused: Boolean) {
            val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            val now = System.currentTimeMillis()
            val editor = preferences.edit().putBoolean(STATE_IS_PAUSED_KEY, isPaused)
            if (isPaused) {
                editor.putLong(STATE_PAUSED_AT_MS_KEY, now)
            } else {
                val pausedAt = preferences.getLong(STATE_PAUSED_AT_MS_KEY, 0L)
                val pausedDuration = preferences.getLong(STATE_PAUSED_DURATION_MS_KEY, 0L)
                if (pausedAt > 0L) {
                    editor.putLong(STATE_PAUSED_DURATION_MS_KEY, pausedDuration + (now - pausedAt))
                }
                editor.putLong(STATE_PAUSED_AT_MS_KEY, 0L)
            }
            editor.apply()
        }

        fun clearNotificationState(context: Context) {
            context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .edit()
                .remove(STATE_RUN_ID_KEY)
                .remove(STATE_TITLE_KEY)
                .remove(STATE_ELAPSED_SECONDS_KEY)
                .remove(STATE_DISTANCE_METERS_KEY)
                .remove(STATE_PACE_TEXT_KEY)
                .remove(STATE_IS_PAUSED_KEY)
                .remove(STATE_STARTED_AT_MS_KEY)
                .remove(STATE_PAUSED_AT_MS_KEY)
                .remove(STATE_PAUSED_DURATION_MS_KEY)
                .remove(STATE_LAST_LAT_KEY)
                .remove(STATE_LAST_LNG_KEY)
                .remove(STATE_LAST_ALTITUDE_KEY)
                .remove(STATE_LAST_TIME_MS_KEY)
                .remove(STATE_ROUTE_POINTS_KEY)
                .remove(STATE_BACKGROUND_TRACKING_ENABLED_KEY)
                .remove(STATE_TOTAL_ASCENT_METERS_KEY)
                .remove(STATE_LAST_ANNOUNCED_SPLIT_KM_KEY)
                .remove(STATE_LAST_ANNOUNCED_SPLIT_ELAPSED_SECONDS_KEY)
                .apply()
        }

        fun buildSnapshot(context: Context): Map<String, Any>? {
            val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            val runId = preferences.getString(STATE_RUN_ID_KEY, null) ?: return null
            val routePointsJson = preferences.getString(STATE_ROUTE_POINTS_KEY, "[]").orEmpty()
            val routePoints = JSONArray(routePointsJson)
            val serializedRoute = mutableListOf<Map<String, Double>>()
            for (index in 0 until routePoints.length()) {
                val point = routePoints.optJSONObject(index) ?: continue
                val serializedPoint = mutableMapOf(
                    "lat" to point.optDouble("lat"),
                    "lng" to point.optDouble("lng"),
                )
                if (point.has("altitude")) {
                    serializedPoint["altitude"] = point.optDouble("altitude")
                }
                serializedRoute.add(serializedPoint)
            }

            return mapOf(
                "runId" to runId,
                "startedAt" to preferences.getLong(STATE_STARTED_AT_MS_KEY, 0L),
                "isPaused" to preferences.getBoolean(STATE_IS_PAUSED_KEY, false),
                "pausedDurationMillis" to currentPausedDurationMillis(preferences),
                "elapsedSeconds" to currentElapsedSeconds(preferences),
                "distanceMeters" to preferences.getFloat(STATE_DISTANCE_METERS_KEY, 0f).toDouble(),
                "totalAscentMeters" to preferences.getFloat(STATE_TOTAL_ASCENT_METERS_KEY, 0f).toDouble(),
                "paceText" to preferences.getString(STATE_PACE_TEXT_KEY, null).orEmpty(),
                "routePoints" to serializedRoute,
            )
        }

        private fun baseIntent(context: Context, action: String, arguments: Map<*, *>): Intent {
            return Intent(context, RunLockScreenService::class.java).apply {
                this.action = action
                putExtra(EXTRA_RUN_ID, arguments[EXTRA_RUN_ID] as? String)
                putExtra(EXTRA_TITLE, arguments[EXTRA_TITLE] as? String)
                putExtra(EXTRA_ELAPSED_SECONDS, (arguments[EXTRA_ELAPSED_SECONDS] as? Number)?.toInt() ?: 0)
                putExtra(EXTRA_DISTANCE_METERS, (arguments[EXTRA_DISTANCE_METERS] as? Number)?.toDouble() ?: 0.0)
                putExtra(EXTRA_TOTAL_ASCENT_METERS, (arguments[EXTRA_TOTAL_ASCENT_METERS] as? Number)?.toDouble() ?: 0.0)
                putExtra(EXTRA_PACE_TEXT, arguments[EXTRA_PACE_TEXT] as? String)
                putExtra(EXTRA_IS_PAUSED, arguments[EXTRA_IS_PAUSED] as? Boolean ?: false)
                putExtra(EXTRA_ROUTE_POINTS_JSON, arguments[EXTRA_ROUTE_POINTS_JSON] as? String)
            }
        }

        private fun formatElapsedTime(totalSeconds: Int): String {
            val safeSeconds = max(totalSeconds, 0)
            val hours = safeSeconds / 3600
            val minutes = (safeSeconds % 3600) / 60
            val seconds = safeSeconds % 60
            return if (hours > 0) {
                "%02d:%02d:%02d".format(hours, minutes, seconds)
            } else {
                "%02d:%02d".format(minutes, seconds)
            }
        }

        private fun formatDistance(distanceMeters: Double): String {
            return String.format("%.2fkm", distanceMeters / 1000.0)
        }

        private fun loadNotificationState(context: Context): NotificationState? {
            val preferences = context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            val runId = preferences.getString(STATE_RUN_ID_KEY, null) ?: return null
            return NotificationState(
                runId = runId,
                title = preferences.getString(STATE_TITLE_KEY, null),
                elapsedSeconds = preferences.getInt(STATE_ELAPSED_SECONDS_KEY, 0),
                distanceMeters = preferences.getFloat(STATE_DISTANCE_METERS_KEY, 0f).toDouble(),
                paceText = preferences.getString(STATE_PACE_TEXT_KEY, null),
                isPaused = preferences.getBoolean(STATE_IS_PAUSED_KEY, false),
            )
        }

        private fun isPaused(context: Context): Boolean {
            return context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .getBoolean(STATE_IS_PAUSED_KEY, false)
        }

        private fun isBackgroundTrackingEnabled(context: Context): Boolean {
            return context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .getBoolean(STATE_BACKGROUND_TRACKING_ENABLED_KEY, false)
        }

        private fun updateBackgroundTrackingEnabled(context: Context, enabled: Boolean) {
            context.getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
                .edit()
                .putBoolean(STATE_BACKGROUND_TRACKING_ENABLED_KEY, enabled)
                .apply()
        }

        private fun currentPausedDurationMillis(preferences: android.content.SharedPreferences): Long {
            val base = preferences.getLong(STATE_PAUSED_DURATION_MS_KEY, 0L)
            if (!preferences.getBoolean(STATE_IS_PAUSED_KEY, false)) {
                return base
            }
            val pausedAt = preferences.getLong(STATE_PAUSED_AT_MS_KEY, 0L)
            return if (pausedAt > 0L) base + (System.currentTimeMillis() - pausedAt) else base
        }

        private fun currentElapsedSeconds(preferences: android.content.SharedPreferences): Int {
            val startedAt = preferences.getLong(STATE_STARTED_AT_MS_KEY, 0L)
            if (startedAt == 0L) {
                return preferences.getInt(STATE_ELAPSED_SECONDS_KEY, 0)
            }
            val elapsedMillis = System.currentTimeMillis() - startedAt - currentPausedDurationMillis(preferences)
            return max((elapsedMillis / 1000L).toInt(), 0)
        }

        private fun formatPace(elapsedSeconds: Int, distanceMeters: Double): String {
            if (distanceMeters < 10.0) return "-'--\""
            val paceDecimal = (elapsedSeconds / 60.0) / (distanceMeters / 1000.0)
            val minutes = paceDecimal.toInt()
            val seconds = ((paceDecimal - minutes) * 60.0).toInt()
            return "$minutes'${seconds.toString().padStart(2, '0')}\""
        }

        private fun formatSplitPaceKorean(secondsPerKm: Int): String {
            if (secondsPerKm <= 0) {
                return "측정 불가"
            }
            val minutes = secondsPerKm / 60
            val seconds = secondsPerKm % 60
            return "${minutes}분 ${seconds.toString().padStart(2, '0')}초"
        }
    }

    private fun persistNotificationState(intent: Intent) {
        val runId = intent.getStringExtra(EXTRA_RUN_ID) ?: return
        val resolvedPaused = resolvedPausedState(intent.getBooleanExtra(EXTRA_IS_PAUSED, false))
        val resolvedElapsed = resolvedElapsedSeconds(intent.getIntExtra(EXTRA_ELAPSED_SECONDS, 0))
        val resolvedDistance = resolvedDistanceMeters(intent.getDoubleExtra(EXTRA_DISTANCE_METERS, 0.0))
        val resolvedPace = resolvedPaceText(intent.getStringExtra(EXTRA_PACE_TEXT))
        getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
            .edit()
            .putString(STATE_RUN_ID_KEY, runId)
            .putString(STATE_TITLE_KEY, intent.getStringExtra(EXTRA_TITLE))
            .putInt(STATE_ELAPSED_SECONDS_KEY, resolvedElapsed)
            .putFloat(STATE_DISTANCE_METERS_KEY, resolvedDistance.toFloat())
            .putString(STATE_PACE_TEXT_KEY, resolvedPace)
            .putBoolean(STATE_IS_PAUSED_KEY, resolvedPaused)
            .apply()
    }

    private fun persistBackgroundTrackingState(intent: Intent) {
        val preferences = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        if (intent.getStringExtra(EXTRA_RUN_ID).isNullOrBlank()) {
            preferences.edit()
                .putBoolean(STATE_BACKGROUND_TRACKING_ENABLED_KEY, true)
                .apply()
            return
        }
        val now = System.currentTimeMillis()
        val elapsedSeconds = intent.getIntExtra(EXTRA_ELAPSED_SECONDS, 0)
        val isPaused = intent.getBooleanExtra(EXTRA_IS_PAUSED, false)
        val routePointsJson = intent.getStringExtra(EXTRA_ROUTE_POINTS_JSON) ?: "[]"
        val editor = preferences.edit()
            .putBoolean(STATE_BACKGROUND_TRACKING_ENABLED_KEY, true)
            .putLong(STATE_STARTED_AT_MS_KEY, now - (elapsedSeconds * 1000L))
            .putLong(STATE_PAUSED_DURATION_MS_KEY, 0L)
            .putLong(STATE_PAUSED_AT_MS_KEY, if (isPaused) now else 0L)
            .putString(STATE_ROUTE_POINTS_KEY, routePointsJson)
            .putInt(STATE_ELAPSED_SECONDS_KEY, elapsedSeconds)
            .putFloat(STATE_DISTANCE_METERS_KEY, intent.getDoubleExtra(EXTRA_DISTANCE_METERS, 0.0).toFloat())
            .putFloat(STATE_TOTAL_ASCENT_METERS_KEY, intent.getDoubleExtra(EXTRA_TOTAL_ASCENT_METERS, 0.0).toFloat())
            .putString(STATE_PACE_TEXT_KEY, intent.getStringExtra(EXTRA_PACE_TEXT))
            .putBoolean(STATE_IS_PAUSED_KEY, isPaused)
            .putInt(
                STATE_LAST_ANNOUNCED_SPLIT_KM_KEY,
                (intent.getDoubleExtra(EXTRA_DISTANCE_METERS, 0.0) / 1000.0).toInt()
            )
            .putInt(
                STATE_LAST_ANNOUNCED_SPLIT_ELAPSED_SECONDS_KEY,
                elapsedSeconds
            )

        val routePoints = JSONArray(routePointsJson)
        if (routePoints.length() > 0) {
            val lastPoint = routePoints.optJSONObject(routePoints.length() - 1)
            if (lastPoint != null) {
                editor
                    .putString(STATE_LAST_LAT_KEY, lastPoint.optDouble("lat").toString())
                    .putString(STATE_LAST_LNG_KEY, lastPoint.optDouble("lng").toString())
                    .putString(
                        STATE_LAST_ALTITUDE_KEY,
                        lastPoint.takeIf { it.has("altitude") }?.optDouble("altitude")?.toString()
                    )
            }
        }

        editor.putLong(STATE_LAST_TIME_MS_KEY, now).apply()
    }

    private fun setBackgroundTrackingEnabled(enabled: Boolean) {
        updateBackgroundTrackingEnabled(this, enabled)
    }

    private fun appendRoutePoint(
        editor: android.content.SharedPreferences.Editor,
        lat: Double,
        lng: Double,
        altitude: Double,
    ) {
        val preferences = getSharedPreferences(PREFERENCES_NAME, Context.MODE_PRIVATE)
        val routePoints = JSONArray(preferences.getString(STATE_ROUTE_POINTS_KEY, "[]"))
        val point = JSONObject()
            .put("lat", lat)
            .put("lng", lng)
        if (altitude.isFinite()) {
            point.put("altitude", altitude)
        }
        routePoints.put(point)
        editor.putString(STATE_ROUTE_POINTS_KEY, routePoints.toString())
    }

    private data class NotificationState(
        val runId: String,
        val title: String?,
        val elapsedSeconds: Int,
        val distanceMeters: Double,
        val paceText: String?,
        val isPaused: Boolean,
    )
}
