import 'package:flutter/material.dart';
import 'package:idata_rfid/exception/uhf_exception.dart';
import 'package:idata_rfid/idata_rfid.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UHF RFID Plugin Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const UhfHomePage(),
    );
  }
}

class UhfHomePage extends StatefulWidget {
  const UhfHomePage({super.key});

  @override
  State<UhfHomePage> createState() => _UhfHomePageState();
}

class _UhfHomePageState extends State<UhfHomePage> {
  final uhf = IdataRfid();

  bool _isPoweredOn = false;
  bool _isScanning = false;
  final List<TagData> _tags = [];
  String _status = 'Not initialized';
  String? _hardwareVersion;
  String? _firmwareVersion;
  int _currentPower = 30;

  @override
  void initState() {
    super.initState();
    // Delay initialization to ensure context is available
    Future.delayed(Duration.zero, _initializeUhf);
  }

  Future<void> _initializeUhf() async {
    try {
      setState(() => _status = 'Initializing...');

      // IMPORTANT: Device-specific module type
      // M118 = UM_MODULE
      // T1U-1, T2X = SLR_MODULE
      // Auto-detect or let user select

      // For now, default to UM_MODULE (for M118)
      // Change to SLR_MODULE if using T1U-1 or T2X
      await uhf.initialize(
        UhfModuleType.SLR_MODULE,
      ); // <-- Change this based on device

      // Get device info (will work after powerOn)
      setState(() => _status = 'Initialized. Please power on.');
      _showSnackBar('Device initialized. Tap Power On to start.');
    } on UhfException catch (e) {
      setState(() => _status = 'Init error: ${e.message}');
      _showSnackBar('Error: ${e.message}');
    } catch (e) {
      setState(() => _status = 'Unexpected error: $e');
      _showSnackBar('Unexpected error: $e');
    }
  }

  Future<void> _powerOn() async {
    try {
      setState(() => _status = 'Powering on (wait 3 seconds)...');
      await uhf.powerOn();

      // Get device info after power on
      try {
        _hardwareVersion = await uhf.getHardwareVersion();
        _firmwareVersion = await uhf.getFirmwareVersion();
      } catch (e) {
        _hardwareVersion = 'N/A';
        _firmwareVersion = 'N/A';
      }

      setState(() {
        _isPoweredOn = true;
        _status = 'Powered on';
      });
      _showSnackBar('UHF powered on successfully');
    } on UhfException catch (e) {
      setState(() => _status = 'Power on error: ${e.message}');
      _showSnackBar('Power on error: ${e.message}');
    }
  }

  Future<void> _powerOff() async {
    try {
      if (_isScanning) {
        await _stopScanning();
      }

      setState(() => _status = 'Powering off...');
      await uhf.powerOff();

      setState(() {
        _isPoweredOn = false;
        _status = 'Powered off';
        _tags.clear();
      });
      _showSnackBar('UHF powered off successfully');
    } on UhfException catch (e) {
      setState(() => _status = 'Power off error: ${e.message}');
      _showSnackBar('Power off error: ${e.message}');
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
        _tags.clear();
      });

      // Set frequency to USA (recommended for most use cases)
      await uhf.setFrequencyMode(FrequencyMode.USA_902_928);

      // Set to read EPC + TID mode
      await uhf.setReadMode(ReadMode.EPC_AND_TID);

      // For SLR modules (T2X, T1U-1), set inventory mode to RAW (mode 4)
      // This provides optimal performance for these devices
      await uhf.setInventoryMode(InventoryMode.RAW);

      // Set session mode to S0 (recommended for general use)
      await uhf.setSessionMode(SessionMode.S0);

      // Start inventory with read mode 1 (EPC + TID)
      await uhf.startInventory(readMode: 1);

      setState(() {
        _isScanning = true;
        _status = 'Scanning...';
      });

      // Listen to tag stream for real-time tag updates
      uhf.tagStream.listen(
        (tag) {
          setState(() {
            // Check if tag already exists (by EPC)
            final index = _tags.indexWhere((t) => t.epc == tag.epc);
            if (index >= 0) {
              // Update existing tag's RSSI and timestamp
              _tags[index] = tag;
              // Move to top of list (most recent)
              _tags.removeAt(index);
              _tags.insert(0, tag);
            } else {
              // Add new tag at top
              _tags.insert(0, tag);
              // Keep only latest 1000 tags to avoid memory issues
              if (_tags.length > 1000) {
                _tags.removeLast();
              }
            }
          });
        },
        onError: (error) {
          _showSnackBar('Stream error: $error');
          setState(() => _status = 'Stream error: $error');
        },
      );

      _showSnackBar('Inventory started');
    } on UhfException catch (e) {
      setState(() => _status = 'Start error: ${e.message}');
      _showSnackBar('Start error: ${e.message}');
    } catch (e) {
      setState(() => _status = 'Unexpected error: $e');
      _showSnackBar('Unexpected error: $e');
    }
  }

  Future<void> _stopScanning() async {
    try {
      setState(() => _status = 'Stopping inventory...');
      await uhf.stopInventory();

      setState(() {
        _isScanning = false;
        _status = 'Stopped';
      });
      _showSnackBar('Inventory stopped');
    } on UhfException catch (e) {
      setState(() => _status = 'Stop error: ${e.message}');
      _showSnackBar('Stop error: ${e.message}');
    }
  }

  Future<void> _setPower(int power) async {
    try {
      await uhf.setPower(power);
      int current = await uhf.getPower();
      setState(() => _currentPower = current);
      _showSnackBar('Power set to $current');
    } on UhfException catch (e) {
      _showSnackBar('Power error: ${e.message}');
    }
  }

  Future<void> _clearTags() async {
    setState(() => _tags.clear());
    _showSnackBar('Tags cleared');
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UHF RFID Reader'), elevation: 2),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Status',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const Divider(),
                      Text('Status: $_status'),
                      const SizedBox(height: 8),
                      Text(
                        'Power: ${_isPoweredOn ? 'ON' : 'OFF'}',
                        style: TextStyle(
                          color: _isPoweredOn ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Scanning: ${_isScanning ? 'YES' : 'NO'}',
                        style: TextStyle(
                          color: _isScanning ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_hardwareVersion != null)
                        Text('Hardware: $_hardwareVersion'),
                      if (_firmwareVersion != null)
                        Text('Firmware: $_firmwareVersion'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Control Buttons
              Text('Controls', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isPoweredOn ? null : _powerOn,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Power On'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isPoweredOn ? _powerOff : null,
                    icon: const Icon(Icons.power_settings_new),
                    label: const Text('Power Off'),
                  ),
                  ElevatedButton.icon(
                    onPressed: (_isPoweredOn && !_isScanning)
                        ? _startScanning
                        : null,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Start Scan'),
                  ),
                  ElevatedButton.icon(
                    onPressed: _isScanning ? _stopScanning : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Stop Scan'),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Power Level Control
              if (_isPoweredOn)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RF Power Level: $_currentPower',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        Slider(
                          min: 0,
                          max: 33,
                          divisions: 33,
                          value: _currentPower.toDouble(),
                          label: '$_currentPower',
                          onChanged: (value) => _setPower(value.toInt()),
                        ),
                        Text(
                          'Adjust RF power (0-33). Higher values = longer read distance but higher power consumption.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),

              // Tags List Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Tags Found: ${_tags.length}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (_tags.isNotEmpty)
                    TextButton.icon(
                      onPressed: _clearTags,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Clear'),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              // Tags List
              if (_tags.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      _isScanning
                          ? 'Waiting for tags...'
                          : 'No tags found. Start scanning to detect tags.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _tags.length,
                  itemBuilder: (context, index) {
                    final tag = _tags[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${index + 1}')),
                        title: Text(
                          'EPC: ${tag.epc}',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 12,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (tag.tid != null)
                              Text(
                                'TID: ${tag.tid}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            Text(
                              'RSSI: ${tag.rssi} dBm',
                              style: TextStyle(
                                fontSize: 11,
                                color: _getRssiColor(tag.rssi),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        trailing: Text(
                          '${tag.timestamp.hour}:${tag.timestamp.minute}:${tag.timestamp.second}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRssiColor(int rssi) {
    if (rssi >= -60) return Colors.green;
    if (rssi >= -80) return Colors.orange;
    return Colors.red;
  }

  @override
  void dispose() {
    // Clean up when app closes
    if (_isPoweredOn) {
      _powerOff();
    }
    super.dispose();
  }
}
