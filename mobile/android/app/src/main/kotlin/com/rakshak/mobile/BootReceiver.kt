package com.rakshak.mobile

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

/**
 * Automatically launches Rakshak-AI 24/7 Crash Sentinel on phone boot or package update.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context?, intent: Intent?) {
        if (context == null || intent == null) return
        
        val action = intent.action
        Log.i("RakshakBootReceiver", "Received broadcast action: $action. Auto-starting Crash Guard Service...")
        
        if (Intent.ACTION_BOOT_COMPLETED == action ||
            Intent.ACTION_MY_PACKAGE_REPLACED == action ||
            "android.intent.action.QUICKBOOT_POWERON" == action ||
            "com.htc.intent.action.QUICKBOOT_POWERON" == action
        ) {
            RakshakCrashGuardService.startService(context)
        }
    }
}
