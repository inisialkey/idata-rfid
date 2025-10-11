import 'package:plugin_platform_interface/plugin_platform_interface.dart';

import 'idata_rfid_method_channel.dart';

abstract class IdataRfidPlatform extends PlatformInterface {
  /// Constructs a IdataRfidPlatform.
  IdataRfidPlatform() : super(token: _token);

  static final Object _token = Object();

  static IdataRfidPlatform _instance = MethodChannelIdataRfid();

  /// The default instance of [IdataRfidPlatform] to use.
  ///
  /// Defaults to [MethodChannelIdataRfid].
  static IdataRfidPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [IdataRfidPlatform] when
  /// they register themselves.
  static set instance(IdataRfidPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }
}
