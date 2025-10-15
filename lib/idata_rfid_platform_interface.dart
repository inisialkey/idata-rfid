import 'package:idata_rfid/idata_rfid_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'enums/frequency_mode.dart';
import 'enums/inventory_mode.dart';
import 'enums/module_type.dart';
import 'enums/read_mode.dart';
import 'enums/session_mode.dart';
import 'models/tag_data.dart';

abstract class IdataRfidPlatform extends PlatformInterface {
  IdataRfidPlatform() : super(token: _token);

  static final Object _token = Object();
  static IdataRfidPlatform _instance = MethodChannelIdataRfid();

  static IdataRfidPlatform get instance => _instance;

  static set instance(IdataRfidPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<void> initialize(UhfModuleType moduleType);
  Future<void> powerOn();
  Future<void> powerOff();
  Future<void> startInventory({int readMode = 0});
  Future<void> stopInventory();
  Future<void> setPower(int power);
  Future<int> getPower();
  Future<void> setFrequencyMode(FrequencyMode mode);
  Future<int> getFrequencyMode();
  Future<void> setSessionMode(SessionMode mode);
  Future<void> setInventoryMode(InventoryMode mode);
  Future<String> getHardwareVersion();
  Future<String> getFirmwareVersion();
  Future<String?> getModuleTemp();
  Future<void> setReadMode(ReadMode mode, {int startAddr = 0, int wordCnt = 0});
  Stream<TagData> get tagStream;
}
