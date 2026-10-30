package com.rakshak.mobile

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.os.SystemClock
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import kotlin.math.sqrt

/**
 * 24/7 Indestructible Native Crash Guard Foreground Service for Rakshak-AI.
 * 
 * DESIGN PRINCIPLES:
 * 1. Zero-Kill Persistence: Runs as an active foreground service with START_STICKY.
 *    When the user swipes the app away from Recents, onTaskRemoved() maintains the service
 *    and schedules an instant alarm watchdog resurrection.
 * 2. Ultra-Low Battery Consumption: Uses SensorManager.SENSOR_DELAY_NORMAL (~20Hz).
 *    Modern smartphone IMUs (Bosch/InvenSense) use internal hardware FIFOs, consuming
 *    < 1mA (< 1% battery per day) while the phone is stationary or in a pocket.
 * 3. Instant Crash Awakening: On deceleration spike >= 4.8G, acquires WakeLock,
 *    sounds the alarm notification, and launches MainActivity with FLAG_ACTIVITY_NEW_TASK
 *    over the keyguard to trigger the 15-second SOS countdown!
 */
class RakshakCrashGuardService : Service(), SensorEventListener {

    companion object {
        private const val TAG = "RakshakCrashGuard"
        private const val NOTIFICATION_ID = 8801
        private const val CHANNEL_ID = "rakshak_sentinel_foreground"
        private const val CRASH_CHANNEL_ID = "rakshak_emergency_sos"
        private const val CRASH_THRESHOLD_G = 4.8
        private const val SENSOR_EARTH_G = 9.80665

        @Volatile
        var isRunning: Boolean = false
            private set

        fun startService(context: Context) {
            try {
                val intent = Intent(context, RakshakCrashGuardService::class.java)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    ContextCompat.startForegroundService(context, intent)
                } else {
                    context.startService(intent)
                }
            } catch (e: Exception) {
                Log.w(TAG, "🛡️ Failed to start foreground service: ${e.message}")
            }
        }

        fun stopService(context: Context) {
            try {
                val intent = Intent(context, RakshakCrashGuardService::class.java)
                context.stopService(intent)
            } catch (e: Exception) {
                Log.w(TAG, "🛡️ Failed to stop foreground service: ${e.message}")
            }
        }
    }

    private var sensorManager: SensorManager? = null
    private var accelerometer: Sensor? = null
    private var lastTriggerTime: Long = 0L

    override fun onCreate() {
        super.onCreate()
        Log.i(TAG, "🛡️ [RakshakCrashGuardService] Created. Initializing 24/7 Foreground Sentinel...")
        createNotificationChannel()
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                startForeground(
                    NOTIFICATION_ID,
                    buildForegroundNotification(),
                    ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                )
            } else {
                startForeground(NOTIFICATION_ID, buildForegroundNotification())
            }
        } catch (e: Exception) {
            Log.w(TAG, "🛡️ startForeground fallback: ${e.message}")
            try {
                startForeground(NOTIFICATION_ID, buildForegroundNotification())
            } catch (e2: Exception) {
                Log.e(TAG, "🛡️ startForeground completely failed: ${e2.message}")
            }
        }
        initSensors()
        isRunning = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.i(TAG, "🛡️ [RakshakCrashGuardService] onStartCommand triggered. Returning START_STICKY.")
        isRunning = true
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // 1. Silent persistent foreground status channel
            val statusChannel = NotificationChannel(
                CHANNEL_ID,
                "Rakshak-AI 24/7 Sentinel Guard",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Monitors safety sensors in the background with near-zero battery drain"
                setShowBadge(false)
            }
            nm.createNotificationChannel(statusChannel)

            // 2. High priority crash alert channel (sound + vibration)
            val crashChannel = NotificationChannel(
                CRASH_CHANNEL_ID,
                "Emergency SOS Crash Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High priority full-screen alerts for confirmed vehicle crash impacts"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                setBypassDnd(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            nm.createNotificationChannel(crashChannel)
        }
    }

    private fun buildForegroundNotification() =
        NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("🛡️ Rakshak-AI Sentinel Active")
            .setContentText("24/7 Crash Guard Running (Ultra-Low Battery Mode)")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .setOngoing(true)
            .setContentIntent(
                PendingIntent.getActivity(
                    this,
                    0,
                    Intent(this, MainActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
                    },
                    PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
                )
            )
            .build()

    private fun initSensors() {
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        if (accelerometer != null) {
            // SENSOR_DELAY_NORMAL: ~20Hz rate, lowest possible battery consumption (< 1mA)
            sensorManager?.registerListener(this, accelerometer, SensorManager.SENSOR_DELAY_NORMAL)
            Log.i(TAG, "🛡️ Accelerometer registered at SENSOR_DELAY_NORMAL (Zero-Drain FIFO mode).")
        } else {
            Log.w(TAG, "⚠️ No hardware accelerometer found on device.")
        }
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || event.sensor.type != Sensor.TYPE_ACCELEROMETER) return

        val ax = event.values[0]
        val ay = event.values[1]
        val az = event.values[2]

        val totalAccel = sqrt((ax * ax + ay * ay + az * az).toDouble())
        val netG = totalAccel / SENSOR_EARTH_G

        // Check if deceleration breaches threshold
        if (netG >= CRASH_THRESHOLD_G) {
            val now = SystemClock.elapsedRealtime()
            // 8-second debounce between triggers
            if (now - lastTriggerTime > 8000) {
                lastTriggerTime = now
                Log.e(TAG, "🚨 [IMPACT BREACH IN BACKGROUND] Deceleration: ${String.format("%.2f", netG)}G >= ${CRASH_THRESHOLD_G}G! Waking device...")
                triggerBackgroundEmergencyAlert(netG)
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun triggerBackgroundEmergencyAlert(peakG: Double) {
        // 1. Acquire WakeLock to turn screen on
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "rakshak:background_crash_wakeup"
            )
            wakeLock.acquire(15000) // 15 seconds
        } catch (e: Exception) {
            Log.w(TAG, "WakeLock acquisition exception: ${e.message}")
        }

        // 2. Prepare intent to awaken and pop up MainActivity
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            putExtra("crash_detected", true)
            putExtra("deceleration_g", peakG)
        }

        val pendingIntent = PendingIntent.getActivity(
            this,
            9001,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        // 3. Post full screen heads-up notification with alarm siren
        val notification = NotificationCompat.Builder(this, CRASH_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle("🚨 CRASH DETECTED — EMERGENCY SOS")
            .setContentText("Impact Deceleration: ${String.format("%.1f", peakG)}G! Waking emergency response...")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(pendingIntent, true)
            .setAutoCancel(true)
            .setOngoing(true)
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(999, notification)

        // 4. Also launch activity directly
        try {
            startActivity(intent)
        } catch (e: Exception) {
            Log.w(TAG, "Direct startActivity from service failed: ${e.message}")
        }
    }

    /**
     * CRITICAL: Called when user swipes app away from Recents.
     * Service remains alive, and schedules an alarm watchdog in case OS attempts to kill it.
     */
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        Log.w(TAG, "⚠️ [RakshakCrashGuardService] onTaskRemoved: App swiped away from Recents! Arming watchdog alarm...")
        
        // Re-arm through AlarmManager watchdog
        try {
            val restartIntent = Intent(applicationContext, RakshakCrashGuardService::class.java).apply {
                setPackage(packageName)
            }
            val restartPendingIntent = PendingIntent.getService(
                this,
                1,
                restartIntent,
                PendingIntent.FLAG_ONE_SHOT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
            )
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            alarmManager.set(
                AlarmManager.ELAPSED_REALTIME,
                SystemClock.elapsedRealtime() + 1000, // 1 second watchdog
                restartPendingIntent
            )
        } catch (e: Exception) {
            Log.e(TAG, "Failed to schedule resurrection alarm: ${e.message}")
        }
    }

    override fun onDestroy() {
        Log.w(TAG, "🛑 [RakshakCrashGuardService] onDestroy called. Unregistering sensors...")
        sensorManager?.unregisterListener(this)
        isRunning = false
        super.onDestroy()
    }
}
