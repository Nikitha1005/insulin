import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_database/firebase_database.dart';

import '../auth/login_page.dart';
import 'connect_page.dart';
import 'reminder_page.dart';
import 'patient_statistics.dart';
import 'patient_settings_page.dart';

class PatientDashboard extends StatefulWidget {
  final String? patientId;
  final String? patientName;
  final String? patientEmail;

  const PatientDashboard({
    super.key,
    this.patientId,
    this.patientName,
    this.patientEmail,
  });

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _selectedIndex = 0;
  final String channelId = "YOUR_CHANNEL_ID";
  final String readApiKey = "YOUR_READ_API_KEY";

  // Firebase Realtime DB reference
  final DatabaseReference _dbRef =
  FirebaseDatabase.instance.ref().child("patients");

  double? currentTemperature;
  bool? penPresent;
  String lastUpdated = "--";
  bool scanning = false;
  bool _isLoggingOut = false;

  // Reminder list from Realtime DB
  List<Map<String, dynamic>> reminders = [];

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    _fetchRealtimePatientData();
    _fetchThingSpeakData();
    _loadReminders();
  }

  Future<void> _requestPermissions() async {
    await [
      Permission.bluetooth,
      Permission.bluetoothConnect,
      Permission.bluetoothScan,
      Permission.locationWhenInUse,
      Permission.notification
    ].request();
  }

  // Fetch pen data from Realtime DB
  void _fetchRealtimePatientData() {
    if (widget.patientEmail == null || widget.patientEmail!.isEmpty) return;
    final emailKey = widget.patientEmail!.replaceAll('.', ',');

    _dbRef.child(emailKey).onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          currentTemperature = (data["temperature"] as num?)?.toDouble();
          penPresent = data["penPresent"] as bool?;
          lastUpdated = data["lastUpdated"] ?? "--";
        });
      }
    });
  }

  // Fetch ThingSpeak data via HTTP
  Future<void> _fetchThingSpeakData() async {
    try {
      final url = Uri.parse(
          "https://api.thingspeak.com/channels/$channelId/feeds/last.json?api_key=$readApiKey");
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          currentTemperature =
              double.tryParse(data["field1"] ?? "") ?? currentTemperature;
          penPresent = (data["field2"]?.toString() == "1") ?? penPresent;
          lastUpdated = data["created_at"] ?? lastUpdated;
        });
      }
    } catch (e) {
      debugPrint("Error fetching ThingSpeak data: $e");
    }
  }

  // Load reminders from Realtime DB
  Future<void> _loadReminders() async {
    if (widget.patientEmail == null || widget.patientEmail!.isEmpty) return;
    final emailKey = widget.patientEmail!.replaceAll('.', ',');
    _dbRef.child(emailKey).child("reminders").onValue.listen((event) {
      final data = event.snapshot.value as Map?;
      if (data != null) {
        setState(() {
          reminders = data.entries.map((e) {
            final rem = e.value as Map;
            return {
              "id": e.key,
              "label": rem["label"],
              "dosage": rem["dosage"],
              "unit": rem["unit"],
              "time": rem["time"],
            };
          }).toList();
        });
      }
    });
  }

  void _startScan() {
    setState(() {
      scanning = true;
    });
    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4)).then((_) {
      setState(() {
        scanning = false;
      });
    });
  }

  void _onConnectPressed() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ConnectPage(
          patientEmail: widget.patientEmail ?? "",
          patientName: widget.patientName ?? "",
        ),
      ),
    );
  }

  Future<void> _handleLogout() async {
    setState(() {
      _isLoggingOut = true;
    });
    try {
      await FirebaseAuth.instance.signOut();
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Logout failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoggingOut = false);
    }
  }

  Widget _buildReminderCard() {
    if (reminders.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(12.0),
        child: ElevatedButton(
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    ReminderPage(patientEmail: widget.patientEmail!),
              ),
            );
            _loadReminders();
          },
          child: const Text("Set Reminder"),
        ),
      );
    }

    final sortedReminders = [...reminders];
    sortedReminders.sort((a, b) {
      final d1 = int.tryParse(a["dosage"].toString()) ?? 0;
      final d2 = int.tryParse(b["dosage"].toString()) ?? 0;
      return d1.compareTo(d2);
    });

    final maxDosage = sortedReminders.fold<int>(
        1,
            (prev, r) =>
        (int.tryParse(r["dosage"].toString()) ?? 0) > prev
            ? (int.tryParse(r["dosage"].toString()) ?? 0)
            : prev);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Padding(
              padding: EdgeInsets.all(12.0),
              child: Text("Reminders",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        ReminderPage(patientEmail: widget.patientEmail!),
                  ),
                );
                _loadReminders();
              },
              child: const Text("Edit"),
            )
          ],
        ),
        SizedBox(
          height: 160,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: sortedReminders.map((rem) {
              final dosage = int.tryParse(rem["dosage"].toString()) ?? 0;
              final brightnessFactor = (maxDosage > 0) ? (dosage / maxDosage) : 0.5;

              final Color startColor =
              Color.lerp(Colors.blue.shade900, Colors.blue.shade200, brightnessFactor)!;
              final Color endColor =
              Color.lerp(Colors.teal.shade900, Colors.teal.shade200, brightnessFactor)!;

              return Container(
                width: 180,
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [startColor, endColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(rem["label"] ?? "Dose",
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Text(rem["time"], style: const TextStyle(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text("${rem["dosage"]}${rem["unit"]}",
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
              );
            }).toList(),
          ),
        )
      ],
    );
  }

  Widget _buildTemperatureCard() {
    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Insulin Pen Status",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text(
              "Temperature: ${currentTemperature != null ? "${currentTemperature!.toStringAsFixed(1)} °C" : "--"}",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "Pen Present: ${penPresent == null ? "--" : (penPresent! ? "Yes" : "No")}",
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              "Last Updated: $lastUpdated",
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _fetchThingSpeakData,
              icon: const Icon(Icons.refresh),
              label: const Text("Refresh Data"),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildConnectButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ElevatedButton.icon(
        icon: const Icon(Icons.bluetooth_connected),
        label: const Text("Connect"),
        onPressed: _onConnectPressed,
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
    );
  }

  Widget _buildBluetoothScanButton() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: ElevatedButton.icon(
        icon: scanning
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
        )
            : const Icon(Icons.bluetooth_searching),
        label: Text(scanning ? "Scanning..." : "Start Bluetooth Scan"),
        onPressed: scanning ? null : _startScan,
        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
      ),
    );
  }

  Widget _buildSettingsPage() {
    return SingleChildScrollView(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(widget.patientName ?? "Unknown"),
            subtitle: Text(widget.patientEmail ?? "No email"),
          ),
          SwitchListTile(
            title: const Text("Enable Notifications"),
            value: true,
            onChanged: (val) {},
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              icon: _isLoggingOut
                  ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
                  : const Icon(Icons.logout),
              label: _isLoggingOut ? const Text("Logging out...") : const Text("Logout"),
              onPressed: _isLoggingOut ? null : _handleLogout,
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildDashboardContent() {
    if (_selectedIndex == 0) {
      return ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _buildReminderCard(),
          _buildTemperatureCard(),
          _buildConnectButton(),
          _buildBluetoothScanButton(),
        ],
      );
    } else if (_selectedIndex == 1) {
      return PatientStatisticsPage(
        patientId: widget.patientEmail ?? '',
        patientName: widget.patientName ?? 'Patient',
        patientEmail: widget.patientEmail ?? '',
      );
    } else {
      return PatientSettingsPage(
        patientId: widget.patientId ?? 'v',  // ✅ pass it directly
        patientName: widget.patientName ?? "Unknown",
        patientEmail: widget.patientEmail ?? "No email",
        age: "25", // <- you can fetch actual age if stored
        diabetesType: "Type 1", // <- or "Type 2", you can replace with real data
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${widget.patientName ?? "Guest"}!'),
      ),
      body: _buildDashboardContent(),
      bottomNavigationBar: BottomNavigationBar(
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: 'Settings'),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
