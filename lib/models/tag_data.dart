class TagData {
  final String epc;
  final String? tid;
  final int rssi;
  final DateTime timestamp;

  TagData({
    required this.epc,
    this.tid,
    required this.rssi,
    required this.timestamp,
  });

  /// Parse TagData from platform response
  factory TagData.fromMap(Map<dynamic, dynamic> map) {
    return TagData(
      epc: map['epc'] as String? ?? '',
      tid: map['tid'] as String?,
      rssi: map['rssi'] as int? ?? 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        map['timestamp'] as int? ?? DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Convert to JSON map
  Map<String, dynamic> toMap() => {
    'epc': epc,
    'tid': tid,
    'rssi': rssi,
    'timestamp': timestamp.millisecondsSinceEpoch,
  };

  @override
  String toString() => 'TagData(epc: $epc, tid: $tid, rssi: $rssi)';
}
