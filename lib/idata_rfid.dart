import 'dart:async';

import 'package:flutter/services.dart';

class IdataRfid {
  static const MethodChannel _methodChannel = MethodChannel('idata_rfid');
  static const EventChannel _eventChannel = EventChannel('idata_rfid/event');

  /// Stream untuk tag RFID yang terbaca
  static Stream<String> get tagStream =>
      _eventChannel.receiveBroadcastStream().cast<String>();

  /// Mulai scanning
  static Future<void> startScan() async {
    await _methodChannel.invokeMethod('startScan');
  }

  /// Hentikan scanning
  static Future<void> stopScan() async {
    await _methodChannel.invokeMethod('stopScan');
  }

  /// Dapatkan versi platform (optional)
  static Future<String?> getPlatformVersion() async {
    return await _methodChannel.invokeMethod<String>('getPlatformVersion');
  }
}
