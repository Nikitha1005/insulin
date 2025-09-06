import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class CaregiverNotificationPage extends StatefulWidget {
  final String caregiverEmail;
  const CaregiverNotificationPage({super.key, required this.caregiverEmail});

  @override
  State<CaregiverNotificationPage> createState() => _CaregiverNotificationPageState();
}

class _CaregiverNotificationPageState extends State<CaregiverNotificationPage> {
  final _db = FirebaseDatabase.instance;
  String? _caregiverName;
  String? _caregiverKey;

  @override
  void initState() {
    super.initState();
    _loadCaregiverDetails();
  }

  Future<void> _loadCaregiverDetails() async {
    final snap = await _db
        .ref('caregivers')
        .orderByChild('email')
        .equalTo(widget.caregiverEmail.toLowerCase())
        .get();

    if (snap.exists) {
      final firstChild = snap.children.first;
      _caregiverName = firstChild.child('name').value?.toString() ?? 'Caregiver';
      _caregiverKey = firstChild.key;
      if (mounted) setState(() {});
    }
  }

  Future<void> _approve(String reqKey, Map<String, dynamic> data) async {
    if (_caregiverKey == null) return;
    final patientEmail = (data['patientEmail'] as String).toLowerCase();
    final patientKey = patientEmail.replaceAll(RegExp(r'[.#$\[\]]'), '_');

    final Map<String, dynamic> updates = {};

    // ✅ Approve connection
    updates['/connections/$patientKey'] = {
      'caregiverName': _caregiverName ?? 'Caregiver',
      'caregiverEmail': widget.caregiverEmail,
      'timestamp': ServerValue.timestamp,
    };

    updates['/caregivers/$_caregiverKey/connectedPatients/$patientKey'] = {
      'email': patientEmail,
      'name': data['patientName'] ?? 'Unknown Patient',
      'timestamp': ServerValue.timestamp,
    };

    // remove request
    updates['/caregivers/$_caregiverKey/requests/$reqKey'] = null;

    try {
      await _db.ref().update(updates);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Patient "${data['patientName'] ?? patientEmail}" approved!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to approve: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _discard(String reqKey) async {
    if (_caregiverKey == null) return;
    try {
      await _db.ref('caregivers/$_caregiverKey/requests/$reqKey').remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Request discarded.'), backgroundColor: Colors.grey),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to discard: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _acknowledgeDisconnect(String disKey) async {
    if (_caregiverKey == null) return;
    try {
      await _db.ref('caregivers/$_caregiverKey/disconnects/$disKey').remove();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Disconnect acknowledged.'), backgroundColor: Colors.blueGrey),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to acknowledge: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_caregiverKey == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<DatabaseEvent>(
        stream: _db.ref('caregivers/$_caregiverKey').onValue,
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

          final caregiverData = Map<dynamic, dynamic>.from(snap.data!.snapshot.value as Map);

          final requests = caregiverData['requests'] != null
              ? Map<dynamic, dynamic>.from(caregiverData['requests'])
              : {};
          final disconnects = caregiverData['disconnects'] != null
              ? Map<dynamic, dynamic>.from(caregiverData['disconnects'])
              : {};

          final List<Widget> items = [];

          // 🔹 Connection Requests
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

          // 🔹 Disconnect Notifications
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