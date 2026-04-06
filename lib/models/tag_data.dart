class TagData {
  final String epc;
  final String? tid;
  final int rssi;

  TagData({required this.epc, this.tid, required this.rssi});

  /// Parse TagData from platform response
  factory TagData.fromMap(Map<dynamic, dynamic> map) {
    return TagData(
      epc: map['epc'] as String? ?? '',
      tid: map['tid'] as String?,
      rssi: map['rssi'] as int? ?? 0,
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toMap() => {'epc': epc, 'tid': tid, 'rssi': rssi};

  @override
  String toString() => 'TagData(epc: $epc, tid: $tid, rssi: $rssi)';
}
