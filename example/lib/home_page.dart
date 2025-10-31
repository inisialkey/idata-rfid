import 'dart:async';

import 'package:flutter/material.dart';
import 'package:idata_rfid/exception/uhf_exception.dart';
import 'package:idata_rfid/idata_rfid.dart';
import 'package:idata_rfid_example/models/tag_with_count.dart';

import 'settings_page.dart';

// 🔘 Tambah enum untuk mode scanning
enum ScanMode { single, continuous }

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final uhf = IdataRfid();

  bool _isPoweredOn = false;
  bool _isScanning = false;
  final List<TagWithCount> _tags = [];
  String _status = 'Not initialized';
  String? _hardwareVersion;
  String? _firmwareVersion;
  int _currentPower = 30;

  // ⭐ Inventory time tracking
  DateTime? _scanStartTime;
  Timer? _inventoryTimer;
  Timer? _autoStopTimer; // ⏱️ Tambahan untuk auto stop
  Duration _inventoryDuration = Duration.zero;
  StreamSubscription<TagData>? _tagSubscription;

  // ⌨️ Controller untuk input inventory time (ms)
  final _inventoryTimeController = TextEditingController();

  // 🔘 Tambah variabel mode
  ScanMode _scanMode = ScanMode.continuous;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration.zero, _initializeUhf);
  }

  Future<void> _initializeUhf() async {
    try {
      setState(() => _status = 'Initializing...');
      await uhf.initialize(UhfModuleType.slrModule);

      setState(() => _status = 'Initialized. Powering on...');
      await uhf.powerOn();

      try {
        _hardwareVersion = await uhf.getHardwareVersion();
        _firmwareVersion = await uhf.getFirmwareVersion();
        _currentPower = await uhf.getPower();
      } catch (_) {
        _hardwareVersion = 'N/A';
        _firmwareVersion = 'N/A';
      }

      setState(() {
        _isPoweredOn = true;
        _status = 'Ready to scan';
      });
      _showSnackBar('Device ready. Initialize Success');
    } on UhfException catch (e) {
      setState(() => _status = 'Init error: ${e.message}');
      _showSnackBar('Error: ${e.message}');
    }
  }

  Future<void> _startScanning() async {
    if (!_isPoweredOn) {
      _showSnackBar('Please power on UHF first');
      return;
    }

    try {
      setState(() {
        _status = 'Configuring...';
        _inventoryDuration = Duration.zero;
      });

      await uhf.setFrequencyMode(FrequencyMode.usa_902_928);
      await uhf.setReadMode(ReadMode.epcAndTid);
      await uhf.setInventoryMode(InventoryMode.raw);
      await uhf.setSessionMode(SessionMode.s0);
      await uhf.startInventory(readMode: 1);

      _scanStartTime = DateTime.now();
      _startInventoryTimer();

      setState(() {
        _isScanning = true;
        _status = 'Scanning...';
      });

      _tagSubscription?.cancel();
      _tagSubscription = uhf.tagStream.listen((tag) {
        setState(() {
          final index = _tags.indexWhere((t) => t.tag.epc == tag.epc);

          // 🔘 Logika tergantung mode scanning
          if (_scanMode == ScanMode.single) {
            // Mode SINGLE: hanya tambahkan jika tag belum pernah dibaca
            if (index == -1) {
              _tags.add(
                TagWithCount(tag: tag, count: 1, lastSeen: DateTime.now()),
              );
            }
          } else {
            // Mode CONTINUOUS: hitung terus setiap kali tag terbaca
            if (index >= 0) {
              _tags[index] = TagWithCount(
                tag: tag,
                count: _tags[index].count + 1,
                lastSeen: DateTime.now(),
              );
            } else {
              _tags.add(
                TagWithCount(tag: tag, count: 1, lastSeen: DateTime.now()),
              );
              if (_tags.length > 1000) _tags.removeAt(0);
            }
          }
        });
      });

      // 🔥 Auto stop berdasarkan input user
      final inputMs = int.tryParse(_inventoryTimeController.text.trim());
      if (inputMs != null && inputMs > 0) {
        _autoStopTimer?.cancel();
        _autoStopTimer = Timer(Duration(milliseconds: inputMs), () async {
          await _stopScanning();
        });
      }
    } on UhfException catch (e) {
      setState(() => _status = 'Start error: ${e.message}');
      _showSnackBar('Start error: ${e.message}');
    }
  }

  Future<void> _stopScanning() async {
    try {
      setState(() => _status = 'Stopping inventory...');
      _stopInventoryTimer();
      _autoStopTimer?.cancel();
      await _tagSubscription?.cancel();
      await uhf.stopInventory();

      setState(() {
        _isScanning = false;
        _status = 'Stopped';
      });
    } on UhfException catch (e) {
      setState(() => _status = 'Stop error: ${e.message}');
      _showSnackBar('Stop error: ${e.message}');
    }
  }

  void _startInventoryTimer() {
    _inventoryTimer?.cancel();
    _inventoryTimer = Timer.periodic(const Duration(milliseconds: 100), (
      timer,
    ) {
      if (_scanStartTime != null) {
        setState(() {
          _inventoryDuration = DateTime.now().difference(_scanStartTime!);
        });
      }
    });
  }

  void _stopInventoryTimer() {
    _inventoryTimer?.cancel();
    _inventoryTimer = null;
  }

  Future<void> _clearTags() async {
    setState(() {
      _tags.clear();
      _inventoryDuration = Duration.zero;
    });
  }

  Future<void> _confirmClearTags() async {
    if (_isScanning) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm', style: TextStyle(fontSize: 14)),
        content: const Text(
          'Are you sure you want to clear all detected tags?',
          style: TextStyle(fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black38),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
            child: const Text('Clear', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _clearTags();
      _showSnackBar('All tags cleared');
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          isPoweredOn: _isPoweredOn,
          status: _status,
          hardwareVersion: _hardwareVersion,
          firmwareVersion: _firmwareVersion,
          currentPower: _currentPower,
          isScanning: _isScanning,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _stopInventoryTimer();
    _autoStopTimer?.cancel();
    _tagSubscription?.cancel();
    if (_isPoweredOn) {
      if (_isScanning) {
        uhf.stopInventory();
      }
      uhf.powerOff();
    }
    _inventoryTimeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('iData RFID'),
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _navigateToSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Inventory Mode', style: TextStyle(fontSize: 12)),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<ScanMode>(
                segments: const [
                  ButtonSegment<ScanMode>(
                    value: ScanMode.single,
                    label: Text('Single', style: TextStyle(fontSize: 12)),
                  ),
                  ButtonSegment<ScanMode>(
                    value: ScanMode.continuous,
                    label: Text('Continuous', style: TextStyle(fontSize: 12)),
                  ),
                ],
                selected: {_scanMode},
                onSelectionChanged: _isScanning
                    ? null
                    : (Set<ScanMode> selected) {
                        setState(() => _scanMode = selected.first);
                      },
                showSelectedIcon: false,
                style: ButtonStyle(visualDensity: VisualDensity.compact),
              ),
            ),

            const SizedBox(height: 12),

            // ⌨️ Input field untuk durasi inventory
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: TextField(
                      controller: _inventoryTimeController,
                      decoration: const InputDecoration(
                        labelText: 'Inventory Time (ms)',
                        labelStyle: TextStyle(fontSize: 12),
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isPoweredOn
                          ? (_isScanning ? _stopScanning : _startScanning)
                          : null,
                      icon: Icon(_isScanning ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        _isScanning ? 'Inventory Stop' : 'Inventory Start',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 📊 Info Tags
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tags Found: ${_tags.length}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Inventory Time: ${_inventoryDuration.inMilliseconds} ms',
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
                if (_tags.isNotEmpty)
                  Opacity(
                    opacity: _isScanning ? 0.4 : 1,
                    child: IgnorePointer(
                      ignoring: _isScanning,
                      child: GestureDetector(
                        onTap: _confirmClearTags,
                        child: Row(
                          children: const [
                            Icon(Icons.delete_outline, size: 16),
                            SizedBox(width: 8),
                            Text('Clear', style: TextStyle(fontSize: 11)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 10),

            if (_tags.isEmpty)
              Container(
                padding: const EdgeInsets.all(32),
                child: Center(
                  child: Text(
                    _isScanning
                        ? 'Waiting for tags...'
                        : 'No tags found. Start to detect tags.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              )
            else
              Card(
                elevation: 2,
                child: Column(
                  children: [
                    Container(
                      color: Colors.grey[200],
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 40,
                              child: Text(
                                'SN',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                            Expanded(
                              child: Text(
                                'EPC',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 50,
                              child: Text(
                                'Num',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                            SizedBox(
                              width: 60,
                              child: Text(
                                'RSSI',
                                textAlign: TextAlign.right,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 8,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _tags.length,
                      separatorBuilder: (_, __) =>
                          Divider(height: 1, color: Colors.grey[300]),
                      itemBuilder: (context, index) {
                        final tag = _tags[index].tag;
                        return Padding(
                          padding: const EdgeInsets.all(8),
                          child: Row(
                            children: [
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '${index + 1}',
                                  style: const TextStyle(fontSize: 8),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  tag.epc,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 8,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 50,
                                child: Text(
                                  '${_tags[index].count}',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 60,
                                child: Text(
                                  '${tag.rssi}',
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                    color: _getRssiColor(tag.rssi),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -60) return Colors.green;
    if (rssi >= -80) return Colors.orange;
    return Colors.red;
  }
}
