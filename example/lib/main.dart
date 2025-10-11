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

class _MyAppState extends State<MyApp> {
  String? platformVersion;
  List<String> tags = [];
  StreamSubscription<String>? _subscription;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    platformVersion = await IdataRfid.getPlatformVersion();
    setState(() {});
  }

  void _startScan() async {
    await IdataRfid.startScan();

    _subscription = IdataRfid.tagStream.listen((tag) {
      setState(() {
        tags.insert(0, tag); // tambahkan tag terbaru di atas
      });
    });
  }

  void _stopScan() async {
    await IdataRfid.stopScan();
    _subscription?.cancel();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('iData RFID Test')),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text('Platform: ${platformVersion ?? '-'}'),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: _startScan,
                    child: const Text('Start Scan'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _stopScan,
                    child: const Text('Stop Scan'),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: tags.length,
                  itemBuilder: (_, i) => ListTile(title: Text(tags[i])),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
