import 'package:flutter/services.dart';
import 'package:idata_rfid/enums/frequency_mode.dart';
import 'package:idata_rfid/enums/inventory_mode.dart';
import 'package:idata_rfid/enums/module_type.dart';
import 'package:idata_rfid/enums/read_mode.dart';
import 'package:idata_rfid/enums/session_mode.dart';
import 'package:idata_rfid/exception/uhf_exception.dart';
import 'package:idata_rfid/idata_rfid_platform_interface.dart';
import 'package:idata_rfid/models/tag_data.dart';

export 'enums/frequency_mode.dart';
export 'enums/inventory_mode.dart';
export 'enums/module_type.dart';
export 'enums/read_mode.dart';
export 'enums/session_mode.dart';
export 'idata_rfid_method_channel.dart';
export 'idata_rfid_platform_interface.dart';
export 'models/tag_data.dart';
export 'models/uhf_response.dart';

/// Main UHF RFID plugin class
///
/// This class provides a high-level interface to control UHF RFID devices.
/// Supports UM, SLR, GX, RM, and YRM modules.
///
/// Example usage:
/// ```dart
/// final uhf = IdataRfid();
/// await uhf.initialize(UhfModuleType.SLR_MODULE);
/// await uhf.powerOn();
/// await uhf.startInventory();
///
/// uhf.tagStream.listen((tag) {
///   print('Tag: ${tag.epc}, RSSI: ${tag.rssi}');
/// });
///
/// // Later...
/// await uhf.stopInventory();
/// await uhf.powerOff();
/// ```
class IdataRfid {
  static final IdataRfid _instance = IdataRfid._internal();

  /// Get singleton instance
  factory IdataRfid() {
    return _instance;
  }

  IdataRfid._internal();

  /// Current platform implementation
  late IdataRfidPlatform _platform;
  bool _initialized = false;

  /// Initialize the UHF plugin with specified module type
  ///
  /// [moduleType] The type of UHF module to use
  ///
  /// Throws [UhfException] if initialization fails
  Future<void> initialize(UhfModuleType moduleType) async {
    try {
      _platform = IdataRfidPlatform.instance;
      await _platform.initialize(moduleType);
      _initialized = true;
    } on UhfException {
      rethrow;
    } catch (e) {
      throw UhfException('INIT_ERROR', 'Failed to initialize: $e');
    }
  }

  /// Power on the UHF device
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfPowerException] if operation fails
  Future<void> powerOn() async {
    _checkInitialized();
    await _platform.powerOn();
  }

  /// Power off the UHF device
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfPowerException] if operation fails
  Future<void> powerOff() async {
    _checkInitialized();
    await _platform.powerOff();
  }

  /// Start tag inventory scanning
  ///
  /// [readMode] The read mode (0: EPC only, 1: EPC+TID, 2: EPC+User, etc.)
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfInventoryException] if operation fails
  Future<void> startInventory({int readMode = 0}) async {
    _checkInitialized();
    await _platform.startInventory(readMode: readMode);
  }

  /// Stop tag inventory scanning
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfInventoryException] if operation fails
  Future<void> stopInventory() async {
    _checkInitialized();
    await _platform.stopInventory();
  }

  /// Set RF power level (0-33 typically)
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfPowerException] if operation fails
  Future<void> setPower(int power) async {
    _checkInitialized();
    await _platform.setPower(power);
  }

  /// Get current RF power level
  ///
  /// Returns power level, or -1 if error
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfPowerException] if operation fails
  Future<int> getPower() async {
    _checkInitialized();
    return _platform.getPower();
  }

  /// Set frequency mode (region)
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfConfigException] if operation fails
  Future<void> setFrequencyMode(FrequencyMode mode) async {
    _checkInitialized();
    await _platform.setFrequencyMode(mode);
  }

  /// Get current frequency mode
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfConfigException] if operation fails
  Future<int> getFrequencyMode() async {
    _checkInitialized();
    return _platform.getFrequencyMode();
  }

  /// Set session mode (S0-S3)
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfConfigException] if operation fails
  Future<void> setSessionMode(SessionMode mode) async {
    _checkInitialized();
    await _platform.setSessionMode(mode);
  }

  /// Set inventory mode (for SLR modules: modes 0-8)
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfConfigException] if operation fails
  Future<void> setInventoryMode(InventoryMode mode) async {
    _checkInitialized();
    await _platform.setInventoryMode(mode);
  }

  /// Get hardware version string
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfException] if operation fails
  Future<String> getHardwareVersion() async {
    _checkInitialized();
    return _platform.getHardwareVersion();
  }

  /// Get firmware version string
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfException] if operation fails
  Future<String> getFirmwareVersion() async {
    _checkInitialized();
    return _platform.getFirmwareVersion();
  }

  /// Get module temperature (if supported)
  ///
  /// Returns null if not supported or error
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfException] if operation fails
  Future<String?> getModuleTemp() async {
    _checkInitialized();
    return _platform.getModuleTemp();
  }

  /// Set read mode (what data to return with tags)
  ///
  /// [mode] The read mode
  /// [startAddr] Starting address (for user data)
  /// [wordCnt] Word count (for user data)
  ///
  /// Throws [UhfNotInitializedException] if not initialized
  /// Throws [UhfConfigException] if operation fails
  Future<void> setReadMode(
    ReadMode mode, {
    int startAddr = 0,
    int wordCnt = 0,
  }) async {
    _checkInitialized();
    await _platform.setReadMode(mode, startAddr: startAddr, wordCnt: wordCnt);
  }

  /// Stream of tag data during inventory
  ///
  /// The stream emits [TagData] objects containing EPC, TID (if available),
  /// RSSI, and timestamp.
  ///
  /// Example:
  /// ```dart
  /// uhf.tagStream.listen((tag) {
  ///   print('EPC: ${tag.epc}');
  ///   print('RSSI: ${tag.rssi} dBm');
  /// });
  /// ```
  Stream<TagData> get tagStream {
    _checkInitialized();
    return _platform.tagStream;
  }

  /// Check if plugin is initialized
  void _checkInitialized() {
    if (!_initialized) {
      throw UhfNotInitializedException();
    }
  }

  /// Get platform version (for testing)
  static Future<String?> getPlatformVersion() async {
    const platform = MethodChannel('com.idata_rfid/method');
    try {
      final version = await platform.invokeMethod<String>('getPlatformVersion');
      return version;
    } catch (e) {
      return null;
    }
  }
}
