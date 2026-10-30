package com.rakshak.mobile

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioTrack
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import android.provider.Settings
import android.telephony.SmsManager
import android.view.WindowManager
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import kotlin.math.sin

class MainActivity : FlutterActivity() {
    companion object {
        var pendingCrashDetected: Boolean = false
        var pendingCrashG: Double = 4.8
    }

    private val CHANNEL = "com.rakshak.mobile/lock_screen"
    private val SMS_CHANNEL = "com.rakshak.mobile/emergency_sms"
    private val SIREN_CHANNEL = "com.rakshak.mobile/emergency_siren"
    private val EMERGENCY_CHANNEL_ID = "rakshak_emergency_sos"

    private var sirenAudioTrack: AudioTrack? = null
    private var sirenVibrator: Vibrator? = null
    private var sirenStopRunnable: Runnable? = null
    private val sirenHandler = Handler(Looper.getMainLooper())
    private var sirenWakeLock: PowerManager.WakeLock? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        checkCrashIntent(intent)
        enableLockScreenFlags()
        createEmergencyNotificationChannel()
        // Safely start the 24/7 background sentinel service
        try {
            RakshakCrashGuardService.startService(this)
        } catch (e: Exception) {
            android.util.Log.w("MainActivity", "Failed to start crash guard service: ${e.message}")
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        checkCrashIntent(intent)
    }

    private fun checkCrashIntent(intent: Intent?) {
        if (intent?.getBooleanExtra("crash_detected", false) == true) {
            pendingCrashDetected = true
            pendingCrashG = intent.getDoubleExtra("deceleration_g", 4.8)
        }
    }

    private fun enableLockScreenFlags() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON or
            WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
            WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
        )
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableLockScreenDisplay" -> {
                    enableLockScreenFlags()
                    result.success(true)
                }
                "canUseFullScreenIntent" -> {
                    if (Build.VERSION.SDK_INT >= 34) { // Android 14+
                        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        result.success(nm.canUseFullScreenIntent())
                    } else {
                        result.success(true)
                    }
                }
                "openFullScreenIntentSettings" -> {
                    try {
                        val intent = if (Build.VERSION.SDK_INT >= 34) {
                            Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                                data = Uri.parse("package:$packageName")
                            }
                        }
                        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        startActivity(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        // Fallback to app details
                        val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(fallback)
                        result.success(true)
                    }
                }
                "triggerFullScreenAlert" -> {
                    val title = call.argument<String>("title") ?: "CRASH DETECTED — EMERGENCY SOS"
                    val body = call.argument<String>("body") ?: "Broadcasting coordinates to nearest trauma centers"
                    sendFullScreenNotification(title, body)
                    result.success(true)
                }
                "startBackgroundCrashGuard" -> {
                    RakshakCrashGuardService.startService(this)
                    result.success(true)
                }
                "stopBackgroundCrashGuard" -> {
                    RakshakCrashGuardService.stopService(this)
                    result.success(true)
                }
                "isBackgroundCrashGuardRunning" -> {
                    result.success(RakshakCrashGuardService.isRunning)
                }
                "isIgnoringBatteryOptimizations" -> {
                    val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
                    val ignoring = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        pm.isIgnoringBatteryOptimizations(packageName)
                    } else {
                        true
                    }
                    result.success(ignoring)
                }
                "requestBatteryOptimizationExemption" -> {
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                                data = Uri.parse("package:$packageName")
                                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                            }
                            startActivity(intent)
                        }
                        result.success(true)
                    } catch (e: Exception) {
                        val fallback = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                            data = Uri.parse("package:$packageName")
                            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                        }
                        startActivity(fallback)
                        result.success(true)
                    }
                }
                "getPendingCrashEvent" -> {
                    if (pendingCrashDetected) {
                        result.success(mapOf(
                            "crash_detected" to true,
                            "deceleration_g" to pendingCrashG
                        ))
                        pendingCrashDetected = false
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SMS_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkSmsPermission" -> {
                    val granted = ContextCompat.checkSelfPermission(
                        this,
                        android.Manifest.permission.SEND_SMS
                    ) == PackageManager.PERMISSION_GRANTED
                    result.success(granted)
                }
                "requestSmsPermission" -> {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(android.Manifest.permission.SEND_SMS),
                        1011
                    )
                    result.success(true)
                }
                "sendSmsNative" -> {
                    val phone = call.argument<String>("phone")
                    val message = call.argument<String>("message")
                    if (phone.isNullOrBlank() || message.isNullOrBlank()) {
                        result.error("INVALID_ARGS", "Phone and message must not be blank", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val hasPerm = ContextCompat.checkSelfPermission(
                            this,
                            android.Manifest.permission.SEND_SMS
                        ) == PackageManager.PERMISSION_GRANTED

                        if (!hasPerm) {
                            result.error("PERMISSION_DENIED", "SEND_SMS permission not granted", null)
                            return@setMethodCallHandler
                        }

                        android.util.Log.i("RakshakSms", "Attempting SMS to $phone (length ${message.length}): $message")
                        val smsManager: SmsManager = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                            getSystemService(SmsManager::class.java) ?: SmsManager.getDefault()
                        } else {
                            SmsManager.getDefault()
                        }

                        val parts = smsManager.divideMessage(message)
                        if (parts.size > 1) {
                            android.util.Log.i("RakshakSms", "Sending multipart SMS (${parts.size} parts) to $phone")
                            try {
                                smsManager.sendMultipartTextMessage(phone, null, parts, null, null)
                            } catch (e: Exception) {
                                android.util.Log.w("RakshakSms", "sendMultipartTextMessage failed, falling back to sequential sendTextMessage: ${e.message}")
                                for (part in parts) {
                                    smsManager.sendTextMessage(phone, null, part, null, null)
                                }
                            }
                        } else {
                            android.util.Log.i("RakshakSms", "Sending single SMS to $phone")
                            smsManager.sendTextMessage(phone, null, message, null, null)
                        }
                        android.util.Log.i("RakshakSms", "SMS dispatch call completed successfully for $phone")
                        result.success(true)
                    } catch (e: Exception) {
                        android.util.Log.e("RakshakSms", "SMS dispatch error: ${e.message}", e)
                        result.error("SMS_SEND_FAILED", e.message ?: "Failed to send SMS via SIM", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, SIREN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startEmergencySiren" -> {
                    val durationSeconds = call.argument<Int>("durationSeconds") ?: 10
                    val isAmbulance = call.argument<Boolean>("isAmbulance") ?: false
                    startEmergencySiren(durationSeconds, isAmbulance)
                    result.success(true)
                }
                "stopEmergencySiren" -> {
                    stopEmergencySiren()
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startEmergencySiren(durationSeconds: Int, isAmbulance: Boolean) {
        stopEmergencySiren()

        try {
            // 1. Acquire WakeLock to keep screen & CPU active during alarm
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            sirenWakeLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "rakshak:emergency_siren_alarm"
            )
            sirenWakeLock?.acquire((durationSeconds * 1000).toLong() + 2000L)
        } catch (_: Exception) {}

        try {
            // 2. Audio: Set STREAM_ALARM to maximum volume
            val audioManager = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            val maxAlarmVol = audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            audioManager.setStreamVolume(AudioManager.STREAM_ALARM, maxAlarmVol, 0)

            // 3. AudioTrack high-intensity emergency siren synthesis (bypasses silent/vibrate/DND via USAGE_ALARM)
            val sampleRate = 44100
            val cycleDuration = if (isAmbulance) 1.2 else 0.8 // Cycle period in seconds
            val numSamples = (sampleRate * cycleDuration).toInt()
            val buffer = ShortArray(numSamples)
            var phase = 0.0

            val minFreq = if (isAmbulance) 650.0 else 750.0
            val maxFreq = if (isAmbulance) 1200.0 else 1350.0

            for (i in 0 until numSamples) {
                val progress = i.toDouble() / numSamples
                val freq = if (progress < 0.5) {
                    minFreq + (maxFreq - minFreq) * (progress * 2.0)
                } else {
                    maxFreq - (maxFreq - minFreq) * ((progress - 0.5) * 2.0)
                }
                phase += 2.0 * Math.PI * freq / sampleRate
                val sample = (sin(phase) * 32767.0 * 0.98).toInt().toShort()
                buffer[i] = sample
            }

            val audioAttributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                .setFlags(AudioAttributes.FLAG_AUDIBILITY_ENFORCED)
                .build()

            val audioFormat = AudioFormat.Builder()
                .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                .setSampleRate(sampleRate)
                .setChannelMask(AudioFormat.CHANNEL_OUT_MONO)
                .build()

            sirenAudioTrack = AudioTrack.Builder()
                .setAudioAttributes(audioAttributes)
                .setAudioFormat(audioFormat)
                .setBufferSizeInBytes(buffer.size * 2)
                .setTransferMode(AudioTrack.MODE_STATIC)
                .build()

            sirenAudioTrack?.write(buffer, 0, buffer.size)
            sirenAudioTrack?.setLoopPoints(0, numSamples, -1) // -1 loops continuously
            sirenAudioTrack?.play()
        } catch (e: Exception) {
            android.util.Log.e("RakshakSiren", "AudioTrack siren failed: ${e.message}", e)
        }

        try {
            // 4. Heavy continuous haptic vibration that bypasses DND via USAGE_ALARM
            val vibrator = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val vm = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
                vm.defaultVibrator
            } else {
                @Suppress("DEPRECATION")
                getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            }
            sirenVibrator = vibrator

            val pattern = longArrayOf(0, 450, 100, 450, 100, 800)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val effect = VibrationEffect.createWaveform(pattern, 0)
                val alarmVibeAttrs = AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .build()
                vibrator.vibrate(effect, alarmVibeAttrs)
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, 0)
            }
        } catch (e: Exception) {
            android.util.Log.e("RakshakSiren", "Heavy vibration failed: ${e.message}", e)
        }

        // 5. Automatically stop when timer expires
        val stopRunnable = Runnable {
            stopEmergencySiren()
        }
        sirenStopRunnable = stopRunnable
        sirenHandler.postDelayed(stopRunnable, (durationSeconds * 1000).toLong())
    }

    private fun stopEmergencySiren() {
        sirenStopRunnable?.let {
            sirenHandler.removeCallbacks(it)
            sirenStopRunnable = null
        }
        try {
            sirenAudioTrack?.let {
                if (it.playState == AudioTrack.PLAYSTATE_PLAYING) {
                    it.stop()
                }
                it.release()
            }
            sirenAudioTrack = null
        } catch (_: Exception) {}

        try {
            sirenVibrator?.cancel()
            sirenVibrator = null
        } catch (_: Exception) {}

        try {
            if (sirenWakeLock?.isHeld == true) {
                sirenWakeLock?.release()
            }
            sirenWakeLock = null
        } catch (_: Exception) {}
    }

    override fun onDestroy() {
        stopEmergencySiren()
        super.onDestroy()
    }

    private fun createEmergencyNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                EMERGENCY_CHANNEL_ID,
                "Emergency SOS Crash Alerts",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "High priority full-screen alerts for confirmed vehicle crash impacts"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500)
                setBypassDnd(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun sendFullScreenNotification(title: String, body: String) {
        // Wake up device screen
        try {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            val wakeLock = pm.newWakeLock(
                PowerManager.SCREEN_BRIGHT_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
                "rakshak:emergency_full_screen_sos"
            )
            wakeLock.acquire(10000) // 10 seconds
        } catch (_: Exception) {}

        val notifyIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }

        val fullScreenPendingIntent = PendingIntent.getActivity(
            this,
            1001,
            notifyIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or (if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) PendingIntent.FLAG_IMMUTABLE else 0)
        )

        val notification = NotificationCompat.Builder(this, EMERGENCY_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_notify_error)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setAutoCancel(true)
            .setOngoing(true)
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(999, notification)
    }
}
