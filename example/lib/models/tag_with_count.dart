import 'package:idata_rfid/idata_rfid.dart';

class TagWithCount {
  final TagData tag;
  int count;
  DateTime lastSeen;

  TagWithCount({required this.tag, this.count = 1, required this.lastSeen});
}
