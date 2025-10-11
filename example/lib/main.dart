import 'dart:async';

import 'package:flutter/material.dart';
import 'package:idata_rfid/idata_rfid.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class TagInfo {
  final String epc;
  int rssi;
  int count;

  TagInfo(this.epc, this.rssi, this.count);
}

class _MyAppState extends State<MyApp> {
  String platformVersion = 'Unknown';
  final Map<String, TagInfo> _tags = {};
  StreamSubscription<String>? _subscription;
  bool isScanning = false;

  @override
  void initState() {
    super.initState();
    _initPlatform();
  }

  Future<void> _initPlatform() async {
    final version = await IdataRfid.getPlatformVersion() ?? 'Unknown';
    setState(() => platformVersion = version);
  }

  Future<void> _startScan() async {
    if (isScanning) return;
    await IdataRfid.startScan();
    setState(() => isScanning = true);

    _subscription = IdataRfid.tagStream.listen((rawTag) {
      // Format contoh: "EPC|RSSI" → E280689400005028A03601FB|-44
      final parts = rawTag.split('|');
      final epc = parts.isNotEmpty ? parts[0] : '';
      final rssi = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;

      if (epc.isEmpty) return;

      setState(() {
        if (_tags.containsKey(epc)) {
          _tags[epc]!.rssi = rssi;
          _tags[epc]!.count++;
        } else {
          _tags[epc] = TagInfo(epc, rssi, 1);
        }
      });
    });
  }

  Future<void> _stopScan() async {
    await IdataRfid.stopScan();
    await _subscription?.cancel();
    setState(() => isScanning = false);
  }

  void _clearTags() {
    setState(() => _tags.clear());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tagsList = _tags.values.toList().reversed.toList();

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueAccent,
          brightness: Brightness.light,
        ),
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('iData RFID'),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              onPressed: _clearTags,
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text('Platform: $platformVersion'),
                  Text(
                    'Status: ${isScanning ? "Scanning..." : "Idle"} (${_tags.length} tags)',
                    style: TextStyle(
                      color: isScanning ? Colors.greenAccent : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Start'),
                        onPressed: isScanning ? null : _startScan,
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.stop),
                        label: const Text('Stop'),
                        onPressed: isScanning ? _stopScan : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              // color: Colors.grey[900],
              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
              child: const Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: Text(
                      'SN',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    flex: 5,
                    child: Text(
                      'EPC',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'RSSI',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Times',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 0),
            Expanded(
              child: ListView.builder(
                itemCount: tagsList.length,
                itemBuilder: (context, i) {
                  final tag = tagsList[i];
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[800]!),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            '${i + 1}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 5,
                          child: Text(
                            tag.epc,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${tag.rssi}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            '${tag.count}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.lightBlueAccent,
                              fontSize: 11,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
