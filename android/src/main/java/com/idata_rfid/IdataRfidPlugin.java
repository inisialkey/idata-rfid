package com.idata_rfid;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

import android.content.Context;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;

import com.uhf.base.UHFManager;
import com.uhf.base.UHFModuleType;

import java.util.concurrent.atomic.AtomicBoolean;
import java.util.HashMap;
import java.util.Map;

/**
 * UHF RFID Plugin for Flutter
 * Supports UM, SLR, GX modules with proper error handling and thread safety
 */
public class IdataRfidPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String METHOD_CHANNEL = "com.idata_rfid/method";
    private static final String EVENT_CHANNEL = "com.idata_rfid/tags";
    private static final String TAG = "IdataRfidPlugin";

    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    
    private UHFManager uhfManager;
    private Context context;
    private Handler mainHandler;
    private Handler tagHandler;
    
    private final AtomicBoolean isScanning = new AtomicBoolean(false);
    private final AtomicBoolean isPoweredOn = new AtomicBoolean(false);
    private final Object uhfLock = new Object();
    
    private volatile EventChannel.EventSink eventSink;
    private UHFModuleType moduleType = UHFModuleType.SLR_MODULE;
    private TagPollingThread tagPollingThread;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        mainHandler = new Handler(Looper.getMainLooper());
        
        // Setup method channel
        methodChannel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
        methodChannel.setMethodCallHandler(this);

        // Setup event channel for tag streaming
        eventChannel = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL);
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink sink) {
                eventSink = sink;
                Log.d(TAG, "EventChannel listener attached");
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
                Log.d(TAG, "EventChannel listener detached");
            }
        });

        Log.d(TAG, "Plugin attached to engine");
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        try {
            switch (call.method) {
                case "getPlatformVersion":
                    result.success("Android " + android.os.Build.VERSION.RELEASE);
                    break;
                    
                case "initialize":
                    handleInitialize(call, result);
                    break;
                    
                case "powerOn":
                    handlePowerOn(result);
                    break;
                    
                case "powerOff":
                    handlePowerOff(result);
                    break;
                    
                case "startInventory":
                    handleStartInventory(call, result);
                    break;
                    
                case "stopInventory":
                    handleStopInventory(result);
                    break;
                    
                case "setPower":
                    handleSetPower(call, result);
                    break;
                    
                case "getPower":
                    handleGetPower(result);
                    break;
                    
                case "setFrequencyMode":
                    handleSetFrequencyMode(call, result);
                    break;
                    
                case "getFrequencyMode":
                    handleGetFrequencyMode(result);
                    break;
                    
                case "setSessionMode":
                    handleSetSessionMode(call, result);
                    break;
                    
                case "setInventoryMode":
                    handleSetInventoryMode(call, result);
                    break;
                    
                case "getHardwareVersion":
                    handleGetHardwareVersion(result);
                    break;
                    
                case "getFirmwareVersion":
                    handleGetFirmwareVersion(result);
                    break;
                    
                case "getModuleTemp":
                    handleGetModuleTemp(result);
                    break;
                    
                case "setReadMode":
                    handleSetReadMode(call, result);
                    break;
                    
                default:
                    result.notImplemented();
                    break;
            }
        } catch (Exception e) {
            Log.e(TAG, "Method call error: " + call.method, e);
            result.error("PLATFORM_ERROR", e.getMessage(), null);
        }
    }

    private void handleInitialize(MethodCall call, Result result) {
        try {
            String moduleTypeString = call.argument("moduleType");
            if (moduleTypeString != null) {
                moduleType = UHFModuleType.valueOf(moduleTypeString);
            }
            
            // Check if high baud rate requested (for some M118 devices)
            Boolean highBaud = call.argument("highBaud");
            if (highBaud != null && highBaud) {
                Log.d(TAG, "High baud rate enabled (921600)");
                // This will be used when powerOn is called
            }
            
            Log.d(TAG, "Initialized with module type: " + moduleType);
            result.success(true);
        } catch (Exception e) {
            Log.e(TAG, "Initialize error", e);
            result.error("INIT_ERROR", e.getMessage(), null);
        }
    }

    private void handlePowerOn(Result result) {
        // IMPORTANT: UHFManager must be initialized on main thread because
        // SLRLib constructor creates a Handler which requires Looper
        try {
            synchronized (uhfLock) {
                if (isPoweredOn.get()) {
                    result.success(true);
                    return;
                }

                // Initialize UHFManager on main thread
                uhfManager = UHFManager.getUHFImplSigleInstance(moduleType, context);
                
                // Now do power on in background thread
                new Thread(() -> {
                    try {
                        boolean success = uhfManager.powerOn();
                        
                        if (success) {
                            // CRITICAL: Give time for serial port and module to initialize
                            // According to vendor demo: 2.5 seconds is sufficient
                            Log.d(TAG, "Waiting 2.5s for module initialization...");
                            try {
                                Thread.sleep(2500);
                            } catch (InterruptedException e) {
                                Thread.currentThread().interrupt();
                            }
                            
                            isPoweredOn.set(true);
                            Log.d(TAG, "UHF powered on successfully");
                            final Result finalResult = result;
                            mainHandler.post(() -> finalResult.success(true));
                        } else {
                            Log.e(TAG, "Failed to power on UHF");
                            final Result finalResult = result;
                            mainHandler.post(() -> finalResult.error("POWER_ERROR", "Failed to power on. Check module type and device compatibility.", null));
                        }
                    } catch (Exception e) {
                        Log.e(TAG, "Power on error", e);
                        final Result finalResult = result;
                        final String errorMsg = e.getMessage();
                        mainHandler.post(() -> finalResult.error("POWER_ERROR", errorMsg, null));
                    }
                }).start();
            }
        } catch (Exception e) {
            Log.e(TAG, "Power on initialization error", e);
            result.error("POWER_ERROR", e.getMessage(), null);
        }
    }

    private void handlePowerOff(Result result) {
        new Thread(() -> {
            try {
                synchronized (uhfLock) {
                    if (isScanning.get()) {
                        stopInventoryInternal();
                    }

                    if (uhfManager != null && isPoweredOn.get()) {
                        boolean success = uhfManager.powerOff();
                        isPoweredOn.set(false);
                        UHFManager.clearConfigInfo();
                        uhfManager = null;
                        
                        Log.d(TAG, "UHF powered off successfully");
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.success(true));
                    } else {
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.success(false));
                    }
                }
            } catch (Exception e) {
                Log.e(TAG, "Power off error", e);
                final Result finalResult = result;
                final String errorMsg = e.getMessage();
                mainHandler.post(() -> finalResult.error("POWER_ERROR", errorMsg, null));
            }
        }).start();
    }

    private void handleStartInventory(MethodCall call, Result result) {
        new Thread(() -> {
            try {
                synchronized (uhfLock) {
                    if (!isPoweredOn.get()) {
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.error("STATE_ERROR", "UHF not powered on", null));
                        return;
                    }

                    if (isScanning.get()) {
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.success(true));
                        return;
                    }

                    Integer readModeArg = call.argument("readMode");
                    int readMode = readModeArg != null ? readModeArg : 0;
                    uhfManager.readTagModeSet(readMode, 0, 0, 0);
                    
                    boolean success = uhfManager.startInventoryTag();
                    
                    if (success) {
                        isScanning.set(true);
                        tagPollingThread = new TagPollingThread();
                        tagPollingThread.start();
                        
                        Log.d(TAG, "Inventory started successfully");
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.success(true));
                    } else {
                        Log.e(TAG, "Failed to start inventory");
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.error("INVENTORY_ERROR", "Failed to start inventory", null));
                    }
                }
            } catch (Exception e) {
                Log.e(TAG, "Start inventory error", e);
                final Result finalResult = result;
                final String errorMsg = e.getMessage();
                mainHandler.post(() -> finalResult.error("INVENTORY_ERROR", errorMsg, null));
            }
        }).start();
    }

    private void handleStopInventory(Result result) {
        new Thread(() -> {
            try {
                synchronized (uhfLock) {
                    stopInventoryInternal();
                    final Result finalResult = result;
                    mainHandler.post(() -> finalResult.success(true));
                }
            } catch (Exception e) {
                Log.e(TAG, "Stop inventory error", e);
                final Result finalResult = result;
                final String errorMsg = e.getMessage();
                mainHandler.post(() -> finalResult.error("INVENTORY_ERROR", errorMsg, null));
            }
        }).start();
    }

    private void stopInventoryInternal() {
        if (isScanning.getAndSet(false)) {
            if (tagPollingThread != null) {
                tagPollingThread.interrupt();
                tagPollingThread = null;
            }

            if (uhfManager != null) {
                uhfManager.stopInventory();
                Log.d(TAG, "Inventory stopped");
            }
        }
    }

    private void handleSetPower(MethodCall call, Result result) {
        new Thread(() -> {
            try {
                synchronized (uhfLock) {
                    if (uhfManager == null) {
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.error("STATE_ERROR", "UHF not initialized", null));
                        return;
                    }

                    Integer powerArg = call.argument("power");
                    int power = powerArg != null ? powerArg : 0;
                    boolean success = uhfManager.powerSet(power);
                    final Result finalResult = result;
                    final boolean finalSuccess = success;
                    mainHandler.post(() -> finalResult.success(finalSuccess));
                }
            } catch (Exception e) {
                Log.e(TAG, "Set power error", e);
                final Result finalResult = result;
                final String errorMsg = e.getMessage();
                mainHandler.post(() -> finalResult.error("POWER_ERROR", errorMsg, null));
            }
        }).start();
    }

    private void handleGetPower(Result result) {
        new Thread(() -> {
            try {
                synchronized (uhfLock) {
                    if (uhfManager == null) {
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.error("STATE_ERROR", "UHF not initialized", null));
                        return;
                    }

                    int power = uhfManager.powerGet();
                    final Result finalResult = result;
                    final int finalPower = power;
                    mainHandler.post(() -> finalResult.success(finalPower));
                }
            } catch (Exception e) {
                Log.e(TAG, "Get power error", e);
                final Result finalResult = result;
                final String errorMsg = e.getMessage();
                mainHandler.post(() -> finalResult.error("POWER_ERROR", errorMsg, null));
            }
        }).start();
    }

    private void handleSetFrequencyMode(MethodCall call, Result result) {
        new Thread(() -> {
            try {
                synchronized (uhfLock) {
                    if (uhfManager == null) {
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.error("STATE_ERROR", "UHF not initialized", null));
                        return;
                    }

                    Integer freqModeArg = call.argument("frequencyMode");
                    int freqMode = freqModeArg != null ? freqModeArg : 0;
                    boolean success = uhfManager.frequencyModeSet(freqMode);
                    final Result finalResult = result;
                    final boolean finalSuccess = success;
                    mainHandler.post(() -> finalResult.success(finalSuccess));
                }
            } catch (Exception e) {
                Log.e(TAG, "Set frequency error", e);
                final Result finalResult = result;
                final String errorMsg = e.getMessage();
                mainHandler.post(() -> finalResult.error("FREQ_ERROR", errorMsg, null));
            }
        }).start();
    }

    private void handleGetFrequencyMode(Result result) {
        new Thread(() -> {
            try {
                synchronized (uhfLock) {
                    if (uhfManager == null) {
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.error("STATE_ERROR", "UHF not initialized", null));
                        return;
                    }

                    int freq = uhfManager.frequencyModeGet();
                    final Result finalResult = result;
                    final int finalFreq = freq;
                    mainHandler.post(() -> finalResult.success(finalFreq));
                }
            } catch (Exception e) {
                Log.e(TAG, "Get frequency error", e);
                final Result finalResult = result;
                final String errorMsg = e.getMessage();
                mainHandler.post(() -> finalResult.error("FREQ_ERROR", errorMsg, null));
            }
        }).start();
    }

    private void handleSetSessionMode(MethodCall call, Result result) {
        new Thread(() -> {
            try {
                synchronized (uhfLock) {
                    if (uhfManager == null) {
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.error("STATE_ERROR", "UHF not initialized", null));
                        return;
                    }

                    Integer sessionModeArg = call.argument("sessionMode");
                    int sessionMode = sessionModeArg != null ? sessionModeArg : 0;
                    boolean success = uhfManager.sessionModeSet(sessionMode);
                    final Result finalResult = result;
                    final boolean finalSuccess = success;
                    mainHandler.post(() -> finalResult.success(finalSuccess));
                }
            } catch (Exception e) {
                Log.e(TAG, "Set session mode error", e);
                final Result finalResult = result;
                final String errorMsg = e.getMessage();
                mainHandler.post(() -> finalResult.error("SESSION_ERROR", errorMsg, null));
            }
        }).start();
    }

    private void handleSetInventoryMode(MethodCall call, Result result) {
        new Thread(() -> {
            try {
                synchronized (uhfLock) {
                    if (uhfManager == null) {
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.error("STATE_ERROR", "UHF not initialized", null));
                        return;
                    }

                    Integer modeArg = call.argument("mode");
                    int mode = modeArg != null ? modeArg : 0;
                    boolean success = false;
                    
                    // For SLR modules, use slrInventoryModeSet
                    if (moduleType == UHFModuleType.SLR_MODULE) {
                        success = uhfManager.slrInventoryModeSet(mode);
                    } else {
                        success = uhfManager.inventoryModelSet(mode, false);
                    }
                    
                    final Result finalResult = result;
                    final boolean finalSuccess = success;
                    mainHandler.post(() -> finalResult.success(finalSuccess));
                }
            } catch (Exception e) {
                Log.e(TAG, "Set inventory mode error", e);
                final Result finalResult = result;
                final String errorMsg = e.getMessage();
                mainHandler.post(() -> finalResult.error("INVENTORY_ERROR", errorMsg, null));
            }
        }).start();
    }

    private void handleGetHardwareVersion(Result result) {
        new Thread(() -> {
            try {
                synchronized (uhfLock) {
                    if (uhfManager == null) {
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.error("STATE_ERROR", "UHF not initialized", null));
                        return;
                    }

                    String version = uhfManager.hardwareVerGet();
                    final Result finalResult = result;
                    final String finalVersion = version;
                    mainHandler.post(() -> finalResult.success(finalVersion));
                }
            } catch (Exception e) {
                Log.e(TAG, "Get hardware version error", e);
                final Result finalResult = result;
                final String errorMsg = e.getMessage();
                mainHandler.post(() -> finalResult.error("VERSION_ERROR", errorMsg, null));
            }
        }).start();
    }

    private void handleGetFirmwareVersion(Result result) {
        new Thread(() -> {
            try {
                synchronized (uhfLock) {
                    if (uhfManager == null) {
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.error("STATE_ERROR", "UHF not initialized", null));
                        return;
                    }

                    String version = uhfManager.firmwareVerGet();
                    final Result finalResult = result;
                    final String finalVersion = version;
                    mainHandler.post(() -> finalResult.success(finalVersion));
                }
            } catch (Exception e) {
                Log.e(TAG, "Get firmware version error", e);
                final Result finalResult = result;
                final String errorMsg = e.getMessage();
                mainHandler.post(() -> finalResult.error("VERSION_ERROR", errorMsg, null));
            }
        }).start();
    }

    private void handleGetModuleTemp(Result result) {
        new Thread(() -> {
            try {
                synchronized (uhfLock) {
                    if (uhfManager == null) {
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.error("STATE_ERROR", "UHF not initialized", null));
                        return;
                    }

                    String temp = uhfManager.getModuleTemp();
                    final Result finalResult = result;
                    final String finalTemp = temp;
                    mainHandler.post(() -> finalResult.success(finalTemp));
                }
            } catch (Exception e) {
                Log.e(TAG, "Get module temp error", e);
                final Result finalResult = result;
                final String errorMsg = e.getMessage();
                mainHandler.post(() -> finalResult.error("TEMP_ERROR", errorMsg, null));
            }
        }).start();
    }

    private void handleSetReadMode(MethodCall call, Result result) {
        new Thread(() -> {
            try {
                synchronized (uhfLock) {
                    if (uhfManager == null) {
                        final Result finalResult = result;
                        mainHandler.post(() -> finalResult.error("STATE_ERROR", "UHF not initialized", null));
                        return;
                    }

                    Integer modeArg = call.argument("mode");
                    int mode = modeArg != null ? modeArg : 0;
                    Integer startAddrArg = call.argument("startAddr");
                    int startAddr = startAddrArg != null ? startAddrArg : 0;
                    Integer wordCntArg = call.argument("wordCnt");
                    int wordCnt = wordCntArg != null ? wordCntArg : 0;
                    
                    boolean success = uhfManager.readTagModeSet(mode, startAddr, wordCnt, 0);
                    final Result finalResult = result;
                    final boolean finalSuccess = success;
                    mainHandler.post(() -> finalResult.success(finalSuccess));
                }
            } catch (Exception e) {
                Log.e(TAG, "Set read mode error", e);
                final Result finalResult = result;
                final String errorMsg = e.getMessage();
                mainHandler.post(() -> finalResult.error("READ_MODE_ERROR", errorMsg, null));
            }
        }).start();
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        Log.d(TAG, "Plugin detaching from engine");
        
        try {
            // Stop scanning first
            if (isScanning.get()) {
                synchronized (uhfLock) {
                    stopInventoryInternal();
                }
            }

            // Power off and cleanup
            if (isPoweredOn.get()) {
                synchronized (uhfLock) {
                    if (uhfManager != null) {
                        uhfManager.powerOff();
                        UHFManager.clearConfigInfo();
                        uhfManager = null;
                    }
                    isPoweredOn.set(false);
                }
            }

            // Cleanup channels
            methodChannel.setMethodCallHandler(null);
            eventChannel.setStreamHandler(null);
            eventSink = null;
            
        } catch (Exception e) {
            Log.e(TAG, "Error during detach", e);
        }
    }

    /**
     * Background thread for polling tags
     */
    private class TagPollingThread extends Thread {
        private static final int POLL_INTERVAL_MS = 50;
        private static final int RSSI_TIMEOUT_MS = 5000;

        @Override
        public void run() {
            long lastRssiTime = System.currentTimeMillis();
            
            while (isScanning.get() && !Thread.currentThread().isInterrupted()) {
                try {
                    synchronized (uhfLock) {
                        if (uhfManager == null || eventSink == null) {
                            continue;
                        }

                        String[] tagData = uhfManager.readTagFromBuffer();
                        
                        if (tagData != null && tagData.length >= 2) {
                            Map<String, Object> tag = parseTagData(tagData);
                            if (tag != null && eventSink != null) {
                                mainHandler.post(() -> {
                                    if (eventSink != null) {
                                        eventSink.success(tag);
                                    }
                                });
                                lastRssiTime = System.currentTimeMillis();
                            }
                        }
                    }

                    Thread.sleep(POLL_INTERVAL_MS);
                    
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                    break;
                } catch (Exception e) {
                    Log.e(TAG, "Tag polling error", e);
                }
            }
            
            Log.d(TAG, "Tag polling thread stopped");
        }

        @Nullable
        private Map<String, Object> parseTagData(String[] tagData) {
            try {
                Map<String, Object> tag = new HashMap<>();
                
                // Format depends on module type and read mode
                // tagData[0] = TID or null
                // tagData[1] = EPC
                // tagData[2] = RSSI (hex string)
                
                String tid = tagData.length > 0 ? tagData[0] : null;
                String epc = tagData.length > 1 ? tagData[1] : null;
                String rssiHex = tagData.length > 2 ? tagData[2] : null;

                if (epc == null || epc.isEmpty()) {
                    return null;
                }

                tag.put("epc", epc);
                
                if (tid != null && !tid.isEmpty()) {
                    tag.put("tid", tid);
                }

                int rssi = parseRssi(rssiHex);
                tag.put("rssi", rssi);
                
                tag.put("timestamp", System.currentTimeMillis());

                return tag;
                
            } catch (Exception e) {
                Log.e(TAG, "Error parsing tag data", e);
                return null;
            }
        }

        private int parseRssi(String rssiHex) {
            try {
                if (rssiHex == null || rssiHex.length() < 4) {
                    return 0;
                }

                int hb = Integer.parseInt(rssiHex.substring(0, 2), 16);
                int lb = Integer.parseInt(rssiHex.substring(2, 4), 16);
                
                // Formula for SLRLib RSSI calculation
                return ((hb - 256 + 1) * 256 + (lb - 256)) / 10;
                
            } catch (Exception e) {
                Log.e(TAG, "Error parsing RSSI", e);
                return 0;
            }
        }
    }
}