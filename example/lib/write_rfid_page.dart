import 'dart:async';

import 'package:flutter/material.dart';
import 'package:idata_rfid/exception/uhf_exception.dart';
import 'package:idata_rfid/idata_rfid.dart';

/// Write Operations Page
/// Allows writing data to RFID tags
class WriteRfidPage extends StatefulWidget {
  const WriteRfidPage({super.key});

  @override
  State<WriteRfidPage> createState() => _WriteRfidPageState();
}

class _WriteRfidPageState extends State<WriteRfidPage> {
  final uhf = IdataRfid();

  // Controllers
  final _accessPasswordController = TextEditingController(text: '00000000');
  final _filterDataController = TextEditingController();
  final _writeDataController = TextEditingController();

  // Write operation type
  WriteOperationType _operationType = WriteOperationType.writeEpc;

  // Filter settings
  int _filterBank = 1; // EPC
  int _filterStartAddr = 32; // Skip PC and CRC (in bits)
  int _filterLength = 96; // 6 words = 96 bits

  // Target settings
  final int _targetBank = 1; // EPC
  int _targetStartAddr = 2; // Start after PC (in words)
  int _targetLength = 6; // 6 words

  // Lock settings
  int _lockBank = 2; // EPC
  int _lockType = 0; // Unlock

  // Status
  String _status = 'Ready';
  bool _isProcessing = false;

  // Scan for tag
  bool _isScanning = false;
  StreamSubscription<TagData>? _tagSubscription;
  String? _scannedEpc;

  @override
  void dispose() {
    _accessPasswordController.dispose();
    _filterDataController.dispose();
    _writeDataController.dispose();
    _tagSubscription?.cancel();
    super.dispose();
  }

  Future<void> _startScanForTag() async {
    try {
      setState(() {
        _isScanning = true;
        _status = 'Scanning for tag...';
        _scannedEpc = null;
      });

      await uhf.setReadMode(ReadMode.epcOnly);
      await uhf.startInventory();

      _tagSubscription?.cancel();
      _tagSubscription = uhf.tagStream.listen((tag) {
        if (_scannedEpc == null) {
          setState(() {
            _scannedEpc = tag.epc;
            _filterDataController.text = tag.epc;
            _status = 'Tag found: ${tag.epc}';
          });
          _stopScan();
        }
      });
    } catch (e) {
      setState(() {
        _status = 'Scan error: $e';
        _isScanning = false;
      });
    }
  }

  Future<void> _stopScan() async {
    try {
      await _tagSubscription?.cancel();
      await uhf.stopInventory();
      setState(() => _isScanning = false);
    } catch (e) {
      _showSnackBar('Stop error: $e');
    }
  }

  Future<void> _performWriteOperation() async {
    if (_isProcessing) return;

    // Validation
    if (_filterDataController.text.isEmpty &&
        _operationType != WriteOperationType.writeEpcNoFilter) {
      _showSnackBar('Please scan a tag or enter filter data');
      return;
    }

    if (_writeDataController.text.isEmpty &&
        _operationType != WriteOperationType.lockTag &&
        _operationType != WriteOperationType.killTag) {
      _showSnackBar('Please enter data to write');
      return;
    }

    // Validate hex format
    if (_operationType != WriteOperationType.lockTag &&
        _operationType != WriteOperationType.killTag) {
      if (!_isValidHex(_writeDataController.text)) {
        _showSnackBar('Write data must be valid hexadecimal');
        return;
      }
    }

    if (_filterDataController.text.isNotEmpty &&
        !_isValidHex(_filterDataController.text)) {
      _showSnackBar('Filter data must be valid hexadecimal');
      return;
    }

    setState(() {
      _isProcessing = true;
      _status = 'Processing...';
    });

    try {
      bool success = false;

      switch (_operationType) {
        case WriteOperationType.writeEpcNoFilter:
          success = await _writeEpcNoFilter();
          break;
        case WriteOperationType.writeEpc:
          success = await _writeEpcWithFilter();
          break;
        case WriteOperationType.writeUser:
          success = await _writeUserData();
          break;
        case WriteOperationType.writeTid:
          success = await _writeTidData();
          break;
        case WriteOperationType.lockTag:
          success = await _lockTagMemory();
          break;
        case WriteOperationType.killTag:
          success = await _killTagPermanently();
          break;
      }

      setState(() {
        _status = success ? 'Success! ✓' : 'Failed ✗';
        _isProcessing = false;
      });

      _showSnackBar(success ? 'Operation successful!' : 'Operation failed!');

      if (success) {
        // Clear write data after success
        _writeDataController.clear();
      }
    } on UhfException catch (e) {
      setState(() {
        _status = 'Error: ${e.message}';
        _isProcessing = false;
      });
      _showSnackBar('Error: ${e.message}');
    }
  }

  Future<bool> _writeEpcNoFilter() async {
    // Write to any tag in range (no filter)
    return await uhf.writeDataToEpc(
      _accessPasswordController.text,
      _targetStartAddr,
      _targetLength,
      _writeDataController.text,
    );
  }

  Future<bool> _writeEpcWithFilter() async {
    // Write to specific tag (with filter)
    return await uhf.writeTag(
      _accessPasswordController.text,
      _filterBank, // Filter by EPC
      _filterStartAddr, // Start at bit 32 (skip PC, CRC)
      _filterLength, // 96 bits (6 words)
      _filterDataController.text,
      1, // Target EPC bank
      _targetStartAddr,
      _targetLength,
      _writeDataController.text,
    );
  }

  Future<bool> _writeUserData() async {
    return await uhf.writeTag(
      _accessPasswordController.text,
      _filterBank,
      _filterStartAddr,
      _filterLength,
      _filterDataController.text,
      3, // USER bank
      _targetStartAddr,
      _targetLength,
      _writeDataController.text,
    );
  }

  Future<bool> _writeTidData() async {
    // Note: TID is usually read-only on most tags
    _showSnackBar('Warning: TID is usually read-only!');
    return await uhf.writeTag(
      _accessPasswordController.text,
      _filterBank,
      _filterStartAddr,
      _filterLength,
      _filterDataController.text,
      2, // TID bank
      _targetStartAddr,
      _targetLength,
      _writeDataController.text,
    );
  }

  Future<bool> _lockTagMemory() async {
    return await uhf.lockTag(
      _accessPasswordController.text,
      _filterBank,
      _filterStartAddr,
      _filterLength,
      _filterDataController.text,
      _lockBank,
      _lockType,
    );
  }

  Future<bool> _killTagPermanently() async {
    // Confirm kill operation
    final confirmed = await _showKillConfirmation();
    if (!confirmed) {
      setState(() {
        _status = 'Kill operation cancelled';
        _isProcessing = false;
      });
      return false;
    }

    return await uhf.killTag(
      _accessPasswordController.text, // Using access password as kill password
      _filterBank,
      _filterStartAddr,
      _filterLength,
      _filterDataController.text,
    );
  }

  Future<bool> _showKillConfirmation() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              '⚠️ Destroy Tag?',
              style: TextStyle(color: Colors.red, fontSize: 16),
            ),
            content: const Text(
              'This will PERMANENTLY destroy the tag!\n\n'
              'The tag will be unusable after this operation.\n\n'
              'Are you absolutely sure?',
              style: TextStyle(fontSize: 13),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('DESTROY TAG'),
              ),
            ],
          ),
        ) ??
        false;
  }

  bool _isValidHex(String value) {
    if (value.isEmpty) return false;
    // Check if valid hex (0-9, A-F, a-f)
    return RegExp(r'^[0-9A-Fa-f]+$').hasMatch(value);
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 3)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Write RFID Tag'), elevation: 2),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Operation Type Selection
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Operation Type',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButton<WriteOperationType>(
                      isExpanded: true,
                      value: _operationType,
                      items: WriteOperationType.values.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Text(
                            type.displayName,
                            style: const TextStyle(fontSize: 13),
                          ),
                        );
                      }).toList(),
                      onChanged: _isProcessing
                          ? null
                          : (value) {
                              if (value != null) {
                                setState(() => _operationType = value);
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Access Password
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Access Password',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _accessPasswordController,
                      decoration: InputDecoration(
                        hintText: '00000000',
                        hintStyle: const TextStyle(fontSize: 12),
                        border: const OutlineInputBorder(),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.info_outline, size: 20),
                          onPressed: () => _showSnackBar(
                            'Default password is 00000000 (8 zeros)',
                          ),
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      maxLength: 8,
                      enabled: !_isProcessing,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Filter Data (Tag Selection)
            if (_operationType != WriteOperationType.writeEpcNoFilter)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Target Tag (Filter)',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _isProcessing || _isScanning
                                ? null
                                : _isScanning
                                ? _stopScan
                                : _startScanForTag,
                            icon: Icon(
                              _isScanning ? Icons.stop : Icons.search,
                              size: 16,
                            ),
                            label: Text(
                              _isScanning ? 'Stop' : 'Scan',
                              style: const TextStyle(fontSize: 12),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _filterDataController,
                        decoration: const InputDecoration(
                          hintText: 'Scan or enter EPC to filter',
                          hintStyle: TextStyle(fontSize: 12),
                          border: OutlineInputBorder(),
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        enabled: !_isProcessing && !_isScanning,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'This filters which tag to write to',
                        style: TextStyle(fontSize: 10, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Write Data
            if (_operationType != WriteOperationType.lockTag &&
                _operationType != WriteOperationType.killTag)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Data to Write (Hex)',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _writeDataController,
                        decoration: InputDecoration(
                          hintText: 'E28011700000020123456789',
                          hintStyle: const TextStyle(fontSize: 11),
                          border: const OutlineInputBorder(),
                          helperText: _getDataLengthInfo(),
                          helperStyle: const TextStyle(fontSize: 10),
                        ),
                        style: const TextStyle(
                          fontSize: 11,
                          fontFamily: 'monospace',
                        ),
                        maxLines: 3,
                        enabled: !_isProcessing,
                      ),
                    ],
                  ),
                ),
              ),

            // Lock Settings
            if (_operationType == WriteOperationType.lockTag)
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Lock Settings',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lock Bank',
                                  style: TextStyle(fontSize: 12),
                                ),
                                DropdownButton<int>(
                                  isExpanded: true,
                                  value: _lockBank,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 0,
                                      child: Text(
                                        'Kill Password',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 1,
                                      child: Text(
                                        'Access Password',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 2,
                                      child: Text(
                                        'EPC',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 3,
                                      child: Text(
                                        'TID',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 4,
                                      child: Text(
                                        'USER',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                  onChanged: _isProcessing
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            setState(() => _lockBank = value);
                                          }
                                        },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Lock Type',
                                  style: TextStyle(fontSize: 12),
                                ),
                                DropdownButton<int>(
                                  isExpanded: true,
                                  value: _lockType,
                                  items: const [
                                    DropdownMenuItem(
                                      value: 0,
                                      child: Text(
                                        'Unlock',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DropdownMenuItem(
                                      value: 1,
                                      child: Text(
                                        'Lock',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  ],
                                  onChanged: _isProcessing
                                      ? null
                                      : (value) {
                                          if (value != null) {
                                            setState(() => _lockType = value);
                                          }
                                        },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // Advanced Settings (Expandable)
            if (_operationType != WriteOperationType.writeEpcNoFilter)
              ExpansionTile(
                title: const Text(
                  'Advanced Settings',
                  style: TextStyle(fontSize: 13),
                ),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      children: [
                        // Filter Settings
                        _buildAdvancedSetting(
                          'Filter Bank',
                          _filterBank,
                          [
                            const DropdownMenuItem(
                              value: 1,
                              child: Text('EPC'),
                            ),
                            const DropdownMenuItem(
                              value: 2,
                              child: Text('TID'),
                            ),
                            const DropdownMenuItem(
                              value: 3,
                              child: Text('USER'),
                            ),
                          ],
                          (value) => setState(() => _filterBank = value!),
                        ),
                        _buildAdvancedSetting(
                          'Filter Start (bits)',
                          _filterStartAddr,
                          List.generate(
                            10,
                            (i) => DropdownMenuItem(
                              value: i * 16,
                              child: Text('${i * 16}'),
                            ),
                          ),
                          (value) => setState(() => _filterStartAddr = value!),
                        ),
                        _buildAdvancedSetting(
                          'Filter Length (bits)',
                          _filterLength,
                          [32, 48, 64, 96, 128, 192]
                              .map(
                                (v) => DropdownMenuItem(
                                  value: v,
                                  child: Text('$v'),
                                ),
                              )
                              .toList(),
                          (value) => setState(() => _filterLength = value!),
                        ),
                        const Divider(),
                        // Target Settings
                        if (_operationType != WriteOperationType.lockTag &&
                            _operationType != WriteOperationType.killTag)
                          _buildAdvancedSetting(
                            'Target Start (words)',
                            _targetStartAddr,
                            List.generate(
                              8,
                              (i) =>
                                  DropdownMenuItem(value: i, child: Text('$i')),
                            ),
                            (value) =>
                                setState(() => _targetStartAddr = value!),
                          ),
                        if (_operationType != WriteOperationType.lockTag &&
                            _operationType != WriteOperationType.killTag)
                          _buildAdvancedSetting(
                            'Target Length (words)',
                            _targetLength,
                            [1, 2, 3, 4, 5, 6, 8, 12]
                                .map(
                                  (v) => DropdownMenuItem(
                                    value: v,
                                    child: Text('$v'),
                                  ),
                                )
                                .toList(),
                            (value) => setState(() => _targetLength = value!),
                          ),
                      ],
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 24),

            // Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _getStatusColor(),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  if (_isProcessing)
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  if (_isProcessing) const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _status,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isProcessing || _isScanning
                    ? null
                    : _performWriteOperation,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _operationType == WriteOperationType.killTag
                      ? Colors.red
                      : null,
                ),
                child: Text(
                  _isProcessing
                      ? 'Processing...'
                      : _operationType == WriteOperationType.killTag
                      ? 'DESTROY TAG ⚠️'
                      : 'Write to Tag',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Help Text
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.info_outline, size: 16, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        'Quick Guide',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildHelpText(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdvancedSetting<T>(
    String label,
    T value,
    List<DropdownMenuItem<T>> items,
    void Function(T?) onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 3,
            child: DropdownButton<T>(
              isExpanded: true,
              value: value,
              items: items,
              onChanged: _isProcessing ? null : onChanged,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpText() {
    switch (_operationType) {
      case WriteOperationType.writeEpcNoFilter:
        return const Text(
          '• Writes to any tag in range\n'
          '• No filtering applied\n'
          '• Use when only one tag is present',
          style: TextStyle(fontSize: 11),
        );
      case WriteOperationType.writeEpc:
        return const Text(
          '• Scan or enter target tag EPC\n'
          '• Writes new EPC to specific tag\n'
          '• Default: 6 words (24 hex chars)',
          style: TextStyle(fontSize: 11),
        );
      case WriteOperationType.writeUser:
        return const Text(
          '• Writes to USER memory bank\n'
          '• Custom data storage area\n'
          '• Size varies by tag manufacturer',
          style: TextStyle(fontSize: 11),
        );
      case WriteOperationType.writeTid:
        return const Text(
          '⚠️ TID is usually READ-ONLY\n'
          '• Contains unique chip ID\n'
          '• Most tags do not allow TID write',
          style: TextStyle(fontSize: 11, color: Colors.orange),
        );
      case WriteOperationType.lockTag:
        return const Text(
          '• Lock prevents writing\n'
          '• Unlock allows writing again\n'
          '• Select bank and lock type',
          style: TextStyle(fontSize: 11),
        );
      case WriteOperationType.killTag:
        return const Text(
          '⚠️ PERMANENT OPERATION\n'
          '• Tag will be destroyed forever\n'
          '• Cannot be undone!',
          style: TextStyle(fontSize: 11, color: Colors.red),
        );
    }
  }

  String _getDataLengthInfo() {
    final length = _writeDataController.text.length;
    final words = (length / 4).ceil();
    return '$length chars = $words words (${length * 4} bits)';
  }

  Color _getStatusColor() {
    if (_isProcessing) return Colors.orange;
    if (_status.contains('Success')) return Colors.green;
    if (_status.contains('Error') || _status.contains('Failed')) {
      return Colors.red;
    }
    if (_status.contains('Scanning')) return Colors.blue;
    return Colors.grey;
  }
}

enum WriteOperationType {
  writeEpcNoFilter,
  writeEpc,
  writeUser,
  writeTid,
  lockTag,
  killTag;

  String get displayName {
    switch (this) {
      case WriteOperationType.writeEpcNoFilter:
        return 'Write EPC (No Filter)';
      case WriteOperationType.writeEpc:
        return 'Write EPC (With Filter)';
      case WriteOperationType.writeUser:
        return 'Write USER Data';
      case WriteOperationType.writeTid:
        return 'Write TID (Usually Read-Only)';
      case WriteOperationType.lockTag:
        return 'Lock/Unlock Tag';
      case WriteOperationType.killTag:
        return 'Kill Tag (Destroy)';
    }
  }
}
