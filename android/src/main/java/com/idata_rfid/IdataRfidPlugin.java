package com.idata_rfid;

import androidx.annotation.NonNull;
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
import com.uhf.base.UHFFunction;
import com.uhf.base.UHFModuleType;

public class IdataRfidPlugin implements FlutterPlugin, MethodCallHandler {
    private static final String METHOD_CHANNEL = "idata_rfid";
    private static final String EVENT_CHANNEL = "idata_rfid/event";
    private static final String TAG = "PDA_RFID";

    private MethodChannel methodChannel;
    private EventChannel eventChannel;
    private EventChannel.EventSink eventSink;

    private UHFManager uhfManager;
    private Context context;
    private Handler handler;
    private boolean isScanning = false;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        methodChannel = new MethodChannel(binding.getBinaryMessenger(), METHOD_CHANNEL);
        methodChannel.setMethodCallHandler(this);

        eventChannel = new EventChannel(binding.getBinaryMessenger(), EVENT_CHANNEL);
        eventChannel.setStreamHandler(new EventChannel.StreamHandler() {
            @Override
            public void onListen(Object arguments, EventChannel.EventSink sink) {
                eventSink = sink;
            }

            @Override
            public void onCancel(Object arguments) {
                eventSink = null;
            }
        });

        handler = new Handler(Looper.getMainLooper());
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        switch (call.method) {
            case "getPlatformVersion":
                result.success("Android " + android.os.Build.VERSION.RELEASE);
                break;
            case "startScan":
                startScan();
                result.success("Scanning started");
                break;
            case "stopScan":
                stopScan();
                result.success("Scanning stopped");
                break;
            default:
                result.notImplemented();
                break;
        }
    }

    private void startScan() {
        if (isScanning) return;
        isScanning = true;

        try {
            uhfManager = UHFManager.getUHFImplSigleInstance(UHFModuleType.UM_MODULE, context);
            uhfManager.powerOn();

            Log.d(TAG, "UHF powered on, starting inventory...");
            uhfManager.startInventoryTag();

            handler.post(scanRunnable);
        } catch (Exception e) {
            Log.e(TAG, "startScan error: " + e.getMessage());
        }
    }

    private final Runnable scanRunnable = new Runnable() {
        @Override
        public void run() {
            if (!isScanning || uhfManager == null) return;

            try {
                String[] tagData = uhfManager.readTagFromBuffer();
                if (tagData != null && tagData.length >= 3 && eventSink != null) {
                    try {
                        // Ambil EPC & RSSI
                        String epc = tagData[1];
                        String rssiHex = tagData[2];

                        int rssi = 0;
                        if (rssiHex != null && rssiHex.length() >= 4) {
                            int Hb = Integer.parseInt(rssiHex.substring(0, 2), 16);
                            int Lb = Integer.parseInt(rssiHex.substring(2, 4), 16);
                            rssi = ((Hb - 256 + 1) * 256 + (Lb - 256)) / 10;
                        }

                        // Kirim hanya tag EPC yang valid
                        if (epc != null && epc.length() >= 16 && epc.startsWith("E2")) {
                            eventSink.success(epc + "|" + rssi);
                        }

                    } catch (Exception e) {
                        Log.e(TAG, "Error parsing RSSI: " + e.getMessage());
                    }
                }
            } catch (Exception e) {
                Log.e(TAG, "readTagFromBuffer error: " + e.getMessage());
            }

            // ulangi baca setiap 100ms
            handler.postDelayed(this, 100);
        }
    };

    private void stopScan() {
        if (!isScanning) return;
        isScanning = false;

        try {
            uhfManager.stopInventory();
            uhfManager.powerOff();
            Log.d(TAG, "UHF stopped and powered off");
        } catch (Exception e) {
            Log.e(TAG, "stopScan error: " + e.getMessage());
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        stopScan();
        methodChannel.setMethodCallHandler(null);
    }
}
