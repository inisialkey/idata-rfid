package com.example.idata_rfid_example

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.idata_rfid/hardware_key"
    private var methodChannel: MethodChannel? = null
    private var scannerReceiver: ScannerBroadcastReceiver? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        methodChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        )
        
        android.util.Log.d("MainActivity", "✅ MethodChannel configured")
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        android.util.Log.d("MainActivity", "🔑 onKeyDown: keyCode=$keyCode")
        
        when (keyCode) {
            KeyEvent.KEYCODE_F8,
            KeyEvent.KEYCODE_F4,
            KeyEvent.KEYCODE_F1,
            KeyEvent.KEYCODE_F2,
            KeyEvent.KEYCODE_F3,
            KeyEvent.KEYCODE_F5,
            KeyEvent.KEYCODE_F6,
            KeyEvent.KEYCODE_F7,
            KeyEvent.KEYCODE_F9,
            KeyEvent.KEYCODE_F10,
            KeyEvent.KEYCODE_F11,
            KeyEvent.KEYCODE_F12,
            KeyEvent.KEYCODE_BUTTON_3,
            KeyEvent.KEYCODE_BUTTON_4,
            KeyEvent.KEYCODE_PROG_RED,
            KeyEvent.KEYCODE_BUTTON_1,
            KeyEvent.KEYCODE_BUTTON_2
            -> {
                android.util.Log.d("MainActivity", "✅ Hardware trigger PRESSED!")
                
                methodChannel?.invokeMethod("onHardwareTriggerPressed", mapOf(
                    "keyCode" to keyCode,
                    "keyName" to getKeyName(keyCode)
                ))
                
                return true
            }
        }
        
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        android.util.Log.d("MainActivity", "🔓 onKeyUp: keyCode=$keyCode")
        
        when (keyCode) {
            KeyEvent.KEYCODE_F8, KeyEvent.KEYCODE_F4, 
            KeyEvent.KEYCODE_F1, KeyEvent.KEYCODE_F2, KeyEvent.KEYCODE_F3, 
            KeyEvent.KEYCODE_F5, KeyEvent.KEYCODE_F6, KeyEvent.KEYCODE_F7,
            KeyEvent.KEYCODE_F9, KeyEvent.KEYCODE_F10, KeyEvent.KEYCODE_F11, KeyEvent.KEYCODE_F12,
            KeyEvent.KEYCODE_BUTTON_3, KeyEvent.KEYCODE_BUTTON_4, KeyEvent.KEYCODE_PROG_RED,
            KeyEvent.KEYCODE_BUTTON_1, KeyEvent.KEYCODE_BUTTON_2
            -> {
                android.util.Log.d("MainActivity", "✅ Hardware trigger RELEASED!")
                
                methodChannel?.invokeMethod("onHardwareTriggerReleased", mapOf(
                    "keyCode" to keyCode,
                    "keyName" to getKeyName(keyCode)
                ))
                
                return true
            }
        }
        
        return super.onKeyUp(keyCode, event)
    }

    private fun getKeyName(keyCode: Int): String {
        return when (keyCode) {
            KeyEvent.KEYCODE_F1 -> "F1"
            KeyEvent.KEYCODE_F2 -> "F2"
            KeyEvent.KEYCODE_F3 -> "F3"
            KeyEvent.KEYCODE_F4 -> "F4"
            KeyEvent.KEYCODE_F5 -> "F5"
            KeyEvent.KEYCODE_F6 -> "F6"
            KeyEvent.KEYCODE_F7 -> "F7"
            KeyEvent.KEYCODE_F8 -> "F8"
            KeyEvent.KEYCODE_F9 -> "F9"
            KeyEvent.KEYCODE_F10 -> "F10"
            KeyEvent.KEYCODE_F11 -> "F11"
            KeyEvent.KEYCODE_F12 -> "F12"
            KeyEvent.KEYCODE_BUTTON_1 -> "BUTTON_1"
            KeyEvent.KEYCODE_BUTTON_2 -> "BUTTON_2"
            KeyEvent.KEYCODE_BUTTON_3 -> "BUTTON_3"
            KeyEvent.KEYCODE_BUTTON_4 -> "BUTTON_4"
            KeyEvent.KEYCODE_PROG_RED -> "PROG_RED"
            else -> "UNKNOWN($keyCode)"
        }
    }

    // ⭐ MULTIPLE BROADCAST ATTEMPTS
    private fun lockBarcodeScanner() {
        android.util.Log.d("MainActivity", "🚫 Attempting to LOCK barcode scanner...")
        
        // Method 1: LOCK key broadcast
        sendBroadcast(Intent("android.intent.action.BARCODELOCKSCANKEY"))
        android.util.Log.d("MainActivity", "   ✓ Sent: BARCODELOCKSCANKEY")
        
        // Method 2: Disable scan broadcast
        sendBroadcast(Intent("android.intent.action.UHF_CHECK_TRIGGER").apply {
            putExtra("isEnableScan", false)
        })
        android.util.Log.d("MainActivity", "   ✓ Sent: UHF_CHECK_TRIGGER (false)")
        
        // Method 3: Scanner disable broadcast
        sendBroadcast(Intent("com.idata.scanner.ACTION_DISABLE"))
        android.util.Log.d("MainActivity", "   ✓ Sent: com.idata.scanner.ACTION_DISABLE")
        
        // Method 4: Set RFID mode
        sendBroadcast(Intent("android.intent.action.SCANNER_MODE").apply {
            putExtra("mode", "RFID")
        })
        android.util.Log.d("MainActivity", "   ✓ Sent: SCANNER_MODE (RFID)")
    }

    private fun unlockBarcodeScanner() {
        android.util.Log.d("MainActivity", "🔓 Attempting to UNLOCK barcode scanner...")
        
        // Method 1: UNLOCK key broadcast
        sendBroadcast(Intent("android.intent.action.BARCODEUNLOCKSCANKEY"))
        android.util.Log.d("MainActivity", "   ✓ Sent: BARCODEUNLOCKSCANKEY")
        
        // Method 2: Enable scan broadcast
        sendBroadcast(Intent("android.intent.action.UHF_CHECK_TRIGGER").apply {
            putExtra("isEnableScan", true)
        })
        android.util.Log.d("MainActivity", "   ✓ Sent: UHF_CHECK_TRIGGER (true)")
        
        // Method 3: Scanner enable broadcast
        sendBroadcast(Intent("com.idata.scanner.ACTION_ENABLE"))
        android.util.Log.d("MainActivity", "   ✓ Sent: com.idata.scanner.ACTION_ENABLE")
    }

    // ⭐ FIXED: Register with RECEIVER_EXPORTED flag for Android 13+
    private fun registerScannerMonitor() {
        scannerReceiver = ScannerBroadcastReceiver()
        val filter = IntentFilter().apply {
            addAction("android.intent.action.SCAN_BUTTON_DOWN")
            addAction("android.intent.action.SCAN_BUTTON_UP")
            addAction("android.intent.action.SCANNER_BUTTON_DOWN")
            addAction("android.intent.action.SCANNER_BUTTON_UP")
            addAction("com.idata.scanner.ACTION_SCAN")
            addAction("com.scanner.action.START_SCAN")
            addAction("com.scanner.action.STOP_SCAN")
        }
        
        // Android 13+ requires RECEIVER_EXPORTED flag
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(scannerReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
            android.util.Log.d("MainActivity", "📡 Scanner monitor registered (NOT_EXPORTED)")
        } else {
            registerReceiver(scannerReceiver, filter)
            android.util.Log.d("MainActivity", "📡 Scanner monitor registered")
        }
    }

    private fun unregisterScannerMonitor() {
        scannerReceiver?.let {
            try {
                unregisterReceiver(it)
                scannerReceiver = null
                android.util.Log.d("MainActivity", "📡 Scanner monitor unregistered")
            } catch (e: Exception) {
                android.util.Log.w("MainActivity", "Monitor already unregistered: ${e.message}")
            }
        }
    }

    override fun onResume() {
        super.onResume()
        android.util.Log.d("MainActivity", "📱 App RESUMED")
        
        // Register scanner monitor
        registerScannerMonitor()
        
        // Lock barcode scanner (disable for RFID mode)
        lockBarcodeScanner()
    }

    override fun onPause() {
        super.onPause()
        android.util.Log.d("MainActivity", "📱 App PAUSED")
        
        // Unregister scanner monitor
        unregisterScannerMonitor()
        
        // Unlock barcode scanner (enable for other apps)
        unlockBarcodeScanner()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        android.util.Log.d("MainActivity", "📱 App DESTROYED")
        
        // Ensure monitor is unregistered
        unregisterScannerMonitor()
        
        // Ensure scanner is unlocked
        unlockBarcodeScanner()
    }

    // Broadcast receiver to monitor scanner events
    inner class ScannerBroadcastReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            val action = intent?.action ?: return
            android.util.Log.e("MainActivity", "🚨 SCANNER BROADCAST DETECTED: $action")
            
            // Abort scanner broadcasts to prevent flash
            try {
                abortBroadcast()
                android.util.Log.d("MainActivity", "   ✓ Scanner broadcast ABORTED")
            } catch (e: Exception) {
                android.util.Log.w("MainActivity", "   ✗ Could not abort: ${e.message}")
            }
        }
    }
}