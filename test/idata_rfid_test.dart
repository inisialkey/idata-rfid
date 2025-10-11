import 'package:flutter_test/flutter_test.dart';
import 'package:idata_rfid/idata_rfid_method_channel.dart';
import 'package:idata_rfid/idata_rfid_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class MockIdataRfidPlatform
    with MockPlatformInterfaceMixin
    implements IdataRfidPlatform {
  @override
  Future<String?> getPlatformVersion() => Future.value('42');
}

void main() {
  final IdataRfidPlatform initialPlatform = IdataRfidPlatform.instance;

  test('$MethodChannelIdataRfid is the default instance', () {
    expect(initialPlatform, isInstanceOf<MethodChannelIdataRfid>());
  });

  // test('getPlatformVersion', () async {
  //   IdataRfid idataRfidPlugin = IdataRfid();
  //   MockIdataRfidPlatform fakePlatform = MockIdataRfidPlatform();
  //   IdataRfidPlatform.instance = fakePlatform;

  //   expect(await idataRfidPlugin.getPlatformVersion(), '42');
  // });
}
