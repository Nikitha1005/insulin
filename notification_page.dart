import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DoctorNotificationPage extends StatefulWidget {
  final String doctorEmail;
  const DoctorNotificationPage({super.key, required this.doctorEmail, required String doctorId});

  @override
  State<DoctorNotificationPage> createState() => _DoctorNotificationPageState();
}

class _DoctorNotificationPageState extends State<DoctorNotificationPage> {
  final _db = FirebaseDatabase.instance;
  String? _doctorName;
  String? _doctorKey;

  @override
  void initState() {
    super.initState();
    _loadDoctorDetails();
  }

  Future<void> _loadDoctorDetails() async {
    final snap = await _db
        .ref('doctors')
        .orderByChild('email')
        .equalTo(widget.doctorEmail.toLowerCase())
        .get();

    if (snap.exists) {
      final firstChild = snap.children.first;
      _doctorName = firstChild.child('name').value?.toString() ?? 'Doctor';
      _doctorKey = firstChild.key;
      if (mounted) setState(() {});
    }
  }

  Future<void> _approve(String reqKey, Map<String, dynamic> data) async {
    if (_doctorKey == null) return;
    final patientEmail = (data['patientEmail'] as String).toLowerCase();
    final patientKey = patientEmail.replaceAll(RegExp(r'[.#$\[\]]'), '_');

    final Map<String, dynamic> updates = {};

    updates['/connections/$patientKey'] = {
      'doctorName': _doctorName ?? 'Doctor',
      'doctorEmail': widget.doctorEmail,
      'timestamp': ServerValue.timestamp,
    };

    updates['/doctors/$_doctorKey/connectedPatients/$patientKey'] = {
      'email': patientEmail,
      'name': data['patientName'] ?? 'Unknown Patient',
      'timestamp': ServerValue.timestamp,
    };

    updates['/doctors/$_doctorKey/requests/$reqKey'] = null;

    try {
      await _db.ref().update(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Patient "${data['patientName'] ?? patientEmail}" approved!'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _discard(String reqKey) async {
    if (_doctorKey == null) return;
    try {
      await _db.ref('doctors/$_doctorKey/requests/$reqKey').remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request discarded.'), backgroundColor: Colors.grey));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _acknowledgeDisconnect(String disKey) async {
    if (_doctorKey == null) return;
    try {
      await _db.ref('doctors/$_doctorKey/disconnects/$disKey').remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Disconnect acknowledged.'), backgroundColor: Colors.blueGrey));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to acknowledge: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_doctorKey == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Connection Requests')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<DatabaseEvent>(
        stream: _db.ref('doctors/$_doctorKey').onValue,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return const Center(child: Text('Failed to load notifications'));
          }
          if (!snap.hasData || snap.data!.snapshot.value == null) {
            return const Center(child: Text('No notifications', style: TextStyle(fontSize: 16, color: Colors.grey)));
          }

          final doctorData = Map<dynamic, dynamic>.from(snap.data!.snapshot.value as Map);

          final requests = doctorData['requests'] != null ? Map<dynamic, dynamic>.from(doctorData['requests']) : {};
          final disconnects = doctorData['disconnects'] != null ? Map<dynamic, dynamic>.from(doctorData['disconnects']) : {};

          final List<Widget> items = [];

          // 🔹 Requests
          requests.forEach((reqKey, value) {
            final data = Map<String, dynamic>.from(value);
            items.add(Card(
              child: ListTile(
                leading: const Icon(Icons.person_add_alt_1),
                title: Text(data['patientName'] ?? 'Unknown'),
                subtitle: Text("Email: ${data['patientEmail']}"),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    ElevatedButton(
                      onPressed: () => _approve(reqKey, data),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text("Approve"),
                    ),
                    ElevatedButton(
                      onPressed: () => _discard(reqKey),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      child: const Text("Discard"),
                    ),
                  ],
                ),
              ),
            ));
          });

          // 🔹 Disconnects
          disconnects.forEach((disKey, value) {
            final data = Map<String, dynamic>.from(value);
            items.add(Card(
              color: Colors.orange.shade50,
              child: ListTile(
                leading: const Icon(Icons.link_off, color: Colors.orange),
                title: Text(data['patientName'] ?? 'Unknown'),
                subtitle: Text("Disconnected: ${data['patientEmail']}"),
                trailing: ElevatedButton(
                  onPressed: () => _acknowledgeDisconnect(disKey),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                  child: const Text("Acknowledge"),
                ),
              ),
            ));
          });

          if (items.isEmpty) {
            return const Center(child: Text("No notifications"));
          }

          return ListView(children: items);
        },
      ),
    );
  }
}