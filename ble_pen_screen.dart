import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:firebase_database/firebase_database.dart';

class BLEPenScreen extends StatefulWidget {
  final String patientEmail;

  const BLEPenScreen({super.key, required this.patientEmail});

  @override
  State<BLEPenScreen> createState() => _BLEPenScreenState();
}

class _BLEPenScreenState extends State<BLEPenScreen> {
  BluetoothDevice? connectedDevice;
  BluetoothCharacteristic? dosageCharacteristic;
  List<Map<String, dynamic>> dosageHistory = [];

  bool isScanning = false;
  bool isConnected = false;

  @override
  void initState() {
    super.initState();
    loadDosageHistory();
  }

  /// Load past dosage history from Firebase
  void loadDosageHistory() async {
    final ref = FirebaseDatabase.instance
        .ref("patients/${widget.patientEmail.replaceAll('.', '_')}/dosages");

    final snapshot = await ref.get();
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      setState(() {
        dosageHistory = data.entries.map((e) {
          return {
            'time': DateTime.parse(e.key),
            'dosage': e.value as double,
          };
        }).toList()
          ..sort((a, b) =>
              (a['time'] as DateTime).compareTo(b['time'] as DateTime));
      });
    }
  }

  /// Save dosage to Firebase
  Future<void> saveDosage(double dosage) async {
    final now = DateTime.now().toIso8601String();
    final ref = FirebaseDatabase.instance
        .ref("patients/${widget.patientEmail.replaceAll('.', '_')}/dosages/$now");
    await ref.set(dosage);
    setState(() {
      dosageHistory.add({'time': DateTime.parse(now), 'dosage': dosage});
    });
  }

  /// Start scanning for BLE insulin pens
  void startScan() {
    setState(() => isScanning = true);
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 5));

    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (r.device.platformName == "InsulinPen") {
          connectToDevice(r.device);
          FlutterBluePlus.stopScan();
          break;
        }
      }
    });
  }

  /// Connect to BLE device
  void connectToDevice(BluetoothDevice device) async {
    await device.connect();
    setState(() {
      connectedDevice = device;
      isConnected = true;
    });

    discoverServices(device);
  }

  /// Discover BLE services and get dosage characteristic
  void discoverServices(BluetoothDevice device) async {
    List<BluetoothService> services = await device.discoverServices();
    for (BluetoothService service in services) {
      if (service.uuid.toString() == "00001808-0000-1000-8000-00805f9b34fb") {
        for (BluetoothCharacteristic c in service.characteristics) {
          if (c.uuid.toString() == "00002a18-0000-1000-8000-00805f9b34fb") {
            dosageCharacteristic = c;
            listenForDosageUpdates();
          }
        }
      }
    }
  }

  /// Listen for dosage updates from pen
  void listenForDosageUpdates() async {
    if (dosageCharacteristic != null) {
      await dosageCharacteristic!.setNotifyValue(true);
      dosageCharacteristic!.lastValueStream.listen((value) {
        final dosage = double.tryParse(utf8.decode(value)) ?? 0.0;
        saveDosage(dosage);
      });
    }
  }

  @override
  void dispose() {
    connectedDevice?.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("BLE Insulin Pen"),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            if (!isConnected)
              ElevatedButton(
                onPressed: isScanning ? null : startScan,
                child: Text(isScanning ? "Scanning..." : "Connect to Insulin Pen"),
              ),
            if (isConnected)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  "Connected to Insulin Pen",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            const SizedBox(height: 20),
            Expanded(
              child: dosageHistory.isEmpty
                  ? const Center(child: Text("No dosage data yet"))
                  : ListView.builder(
                itemCount: dosageHistory.length,
                itemBuilder: (context, index) {
                  final entry = dosageHistory[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.medical_services),
                      title: Text(
                        "Dosage: ${entry['dosage']} units",
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        "Time: ${entry['time']}",
                        style: const TextStyle(fontSize: 12),
                      ),
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