import 'package:flutter/services.dart';
import 'package:idata_rfid/exception/uhf_exception.dart';

import 'enums/frequency_mode.dart';
import 'enums/inventory_mode.dart';
import 'enums/module_type.dart';
import 'enums/read_mode.dart';
import 'enums/session_mode.dart';
import 'idata_rfid_platform_interface.dart';
import 'models/tag_data.dart';

class MethodChannelIdataRfid extends IdataRfidPlatform {
  static const methodChannel = MethodChannel('com.idata_rfid/method');
  static const eventChannel = EventChannel('com.idata_rfid/tags');

  @override
  Future<void> initialize(UhfModuleType moduleType) async {
    try {
      await methodChannel.invokeMethod('initialize', {
        'moduleType': moduleType.platformValue,
      });
    } on PlatformException catch (e) {
      throw UhfException(e.code, e.message ?? 'Initialize failed');
    }
  }

  @override
  Future<void> powerOn() async {
    try {
      await methodChannel.invokeMethod('powerOn');
    } on PlatformException catch (e) {
      throw UhfPowerException(e.message ?? 'Power on failed');
    }
  }

  @override
  Future<void> powerOff() async {
    try {
      await methodChannel.invokeMethod('powerOff');
    } on PlatformException catch (e) {
      throw UhfPowerException(e.message ?? 'Power off failed');
    }
  }

  @override
  Future<void> startInventory({int readMode = 0}) async {
    try {
      await methodChannel.invokeMethod('startInventory', {
        'readMode': readMode,
      });
    } on PlatformException catch (e) {
      throw UhfInventoryException(e.message ?? 'Start inventory failed');
    }
  }

  @override
  Future<void> stopInventory() async {
    try {
      await methodChannel.invokeMethod('stopInventory');
    } on PlatformException catch (e) {
      throw UhfInventoryException(e.message ?? 'Stop inventory failed');
    }
  }

  @override
  Future<void> setPower(int power) async {
    try {
      await methodChannel.invokeMethod('setPower', {'power': power});
    } on PlatformException catch (e) {
      throw UhfPowerException(e.message ?? 'Set power failed');
    }
  }

  @override
  Future<int> getPower() async {
    try {
      final power = await methodChannel.invokeMethod<int>('getPower');
      return power ?? -1;
    } on PlatformException catch (e) {
      throw UhfPowerException(e.message ?? 'Get power failed');
    }
  }

  @override
  Future<void> setFrequencyMode(FrequencyMode mode) async {
    try {
      await methodChannel.invokeMethod('setFrequencyMode', {
        'frequencyMode': mode.value,
      });
    } on PlatformException catch (e) {
      throw UhfConfigException(e.message ?? 'Set frequency failed');
    }
  }

  @override
  Future<int> getFrequencyMode() async {
    try {
      final freq = await methodChannel.invokeMethod<int>('getFrequencyMode');
      return freq ?? -1;
    } on PlatformException catch (e) {
      throw UhfConfigException(e.message ?? 'Get frequency failed');
    }
  }

  @override
  Future<void> setSessionMode(SessionMode mode) async {
    try {
      await methodChannel.invokeMethod('setSessionMode', {
        'sessionMode': mode.value,
      });
    } on PlatformException catch (e) {
      throw UhfConfigException(e.message ?? 'Set session mode failed');
    }
  }

  @override
  Future<void> setInventoryMode(InventoryMode mode) async {
    try {
      await methodChannel.invokeMethod('setInventoryMode', {
        'mode': mode.value,
      });
    } on PlatformException catch (e) {
      throw UhfConfigException(e.message ?? 'Set inventory mode failed');
    }
  }

  @override
  Future<String> getHardwareVersion() async {
    try {
      final version = await methodChannel.invokeMethod<String>(
        'getHardwareVersion',
      );
      return version ?? 'Unknown';
    } on PlatformException catch (e) {
      throw UhfException(e.code, e.message ?? 'Get hardware version failed');
    }
  }

  @override
  Future<String> getFirmwareVersion() async {
    try {
      final version = await methodChannel.invokeMethod<String>(
        'getFirmwareVersion',
      );
      return version ?? 'Unknown';
    } on PlatformException catch (e) {
      throw UhfException(e.code, e.message ?? 'Get firmware version failed');
    }
  }

  @override
  Future<String?> getModuleTemp() async {
    try {
      return await methodChannel.invokeMethod<String>('getModuleTemp');
    } on PlatformException catch (e) {
      throw UhfException(e.code, e.message ?? 'Get module temp failed');
    }
  }

  @override
  Future<void> setReadMode(
    ReadMode mode, {
    int startAddr = 0,
    int wordCnt = 0,
  }) async {
    try {
      await methodChannel.invokeMethod('setReadMode', {
        'mode': mode.value,
        'startAddr': startAddr,
        'wordCnt': wordCnt,
      });
    } on PlatformException catch (e) {
      throw UhfConfigException(e.message ?? 'Set read mode failed');
    }
  }

  @override
  Stream<TagData> get tagStream {
    return eventChannel.receiveBroadcastStream().map((data) {
      try {
        if (data is Map) {
          return TagData.fromMap(data);
        }
        throw FormatException('Invalid tag data format');
      } catch (e) {
        throw UhfException('PARSE_ERROR', 'Failed to parse tag data: $e');
      }
    });
  }
}
