import 'package:flutter/material.dart';
import 'package:idata_rfid/exception/uhf_exception.dart';
import 'package:idata_rfid/idata_rfid.dart';

class SettingsPage extends StatefulWidget {
  final bool isPoweredOn;
  final String status;
  final String? hardwareVersion;
  final String? firmwareVersion;
  final int currentPower;
  final bool isScanning;

  const SettingsPage({
    super.key,
    required this.isPoweredOn,
    required this.status,
    this.hardwareVersion,
    this.firmwareVersion,
    required this.currentPower,
    required this.isScanning,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final uhf = IdataRfid();
  late int _currentPower;

  @override
  void initState() {
    super.initState();
    _currentPower = widget.currentPower;
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

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings'), elevation: 2),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Device Status Card
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Device Status',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Divider(),
                      Text('Status: ${widget.status}'),
                      const SizedBox(height: 8),
                      Text(
                        'Power: ${widget.isPoweredOn ? 'ON' : 'OFF'}',
                        style: TextStyle(
                          color: widget.isPoweredOn ? Colors.green : Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Scanning: ${widget.isScanning ? 'YES' : 'NO'}',
                        style: TextStyle(
                          color: widget.isScanning ? Colors.green : Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (widget.hardwareVersion != null)
                        Text('Hardware: ${widget.hardwareVersion}'),
                      if (widget.firmwareVersion != null)
                        Text('Firmware: ${widget.firmwareVersion}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // RF Power Level Control
              if (widget.isPoweredOn)
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RF Power Level: $_currentPower',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Slider(
                          min: 0,
                          max: 33,
                          divisions: 33,
                          value: _currentPower.toDouble(),
                          label: '$_currentPower',
                          onChanged: widget.isScanning
                              ? null
                              : (value) => _setPower(value.toInt()),
                        ),
                        Text(
                          'Adjust RF power (0-33). Higher values = longer read distance but higher power consumption.',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        if (widget.isScanning)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '⚠️ Stop scanning to adjust power',
                              style: TextStyle(
                                color: Colors.orange,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
