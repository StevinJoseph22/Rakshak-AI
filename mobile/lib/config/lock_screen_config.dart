// ==============================================================================
// RAKSHAK-AI PHASE 4: LOCK-SCREEN BYSTANDER OVERRIDE CONFIGURATION
// ------------------------------------------------------------------------------
// MODE SELECTION:
// - Set to `false` (DEFAULT): Activates (B) DEMO-SAFE FALLBACK.
//   Provides a realistic in-app simulated Android lock screen with an immediate
//   impact override transition. Guaranteed 100% reliable for live judge demos
//   across all physical devices, OS versions, and battery-saver policies.
// - Set to `true`: Activates (A) REAL IMPLEMENTATION.
//   Uses Android's native `USE_FULL_SCREEN_INTENT`, `showWhenLocked`, and high-
//   priority notification channel to awaken the hardware screen and launch
//   LockedScreenAlertScreen over the real system keyguard.
//
// ANDROID 14+ / 17 (API 34 - 37) RESTRICTION NOTICE:
// Starting in Android 14 (API 34) and continued in Android 15/16/17 (API 37),
// Google restricts `USE_FULL_SCREEN_INTENT` to calling and alarm apps by default.
// For sideloaded/debug builds, users must explicitly grant "Turn on full screen intent"
// under: Settings -> Apps -> Special app access -> Full screen intents.
// Rakshak-AI detects this via `NotificationManager.canUseFullScreenIntent()` and
// routes users directly to this system settings screen if denied.
//
// OEM / MANUFACTURER BATTERY-OPTIMIZATION CAVEATS:
// Aggressive OEM battery killers (Xiaomi MIUI/HyperOS, Samsung OneUI, Vivo, Oppo)
// frequently kill background sensor listeners after the screen is dark for >60s.
// On physical test devices, disable battery optimization for Rakshak-AI:
// App Info -> Battery -> "Unrestricted", and enable "Auto-start" on Xiaomi/Oppo.
// ==============================================================================

/// Master debug switch controlling whether the app invokes the native Android
/// full-screen keyguard intent or the demo-safe in-app lock screen simulator.
/// Set to `true` (DEFAULT): Activates (A) REAL IMPLEMENTATION.
/// Set to `false`: Activates (B) DEMO-SAFE FALLBACK.
const bool kUseRealFullScreenIntent = true;

/// Name of the method channel bridging Flutter to MainActivity.kt
const String kLockScreenMethodChannel = 'com.rakshak.mobile/lock_screen';

/// Emergency notification channel ID registered in Android NotificationManager
const String kEmergencyNotificationChannelId = 'rakshak_emergency_sos';
