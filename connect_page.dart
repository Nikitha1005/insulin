import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class ConnectPage extends StatefulWidget {
  final String patientEmail;
  final String patientName;

  const ConnectPage({
    super.key,
    required this.patientEmail,
    required this.patientName,
  });

  @override
  State<ConnectPage> createState() => _ConnectPageState();
}

class _ConnectPageState extends State<ConnectPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();

  String _selectedRole = 'Doctor';
  bool _sendingRequest = false;
  String? _message;

  Map<String, dynamic>? _connectedDoctor;
  Map<String, dynamic>? _connectedCaregiver;

  @override
  void initState() {
    super.initState();
    _listenForConnections();
  }

  Future<void> _sendRequest() async {
    if (!_formKey.currentState!.validate()) return;

    final emailToConnect = _emailController.text.trim();

    setState(() {
      _sendingRequest = true;
      _message = null;
    });

    try {
      final ref = FirebaseDatabase.instance.ref();
      final rolePath = '${_selectedRole.toLowerCase()}s';

      final snapshot = await ref
          .child(rolePath)
          .orderByChild('email')
          .equalTo(emailToConnect.toLowerCase())
          .get();

      if (snapshot.exists) {
        int sentCount = 0;

        for (final child in snapshot.children) {
          final key = child.key;
          if (key != null) {
            await ref.child(rolePath).child(key).child('requests').push().set({
              'patientEmail': widget.patientEmail,
              'patientName': widget.patientName,
              'status': 'pending',
              'timestamp': ServerValue.timestamp,
            });
            sentCount++;
          }
        }

        setState(() {
          _message =
          'Request sent successfully to $sentCount matching $_selectedRole(s).';
          _sendingRequest = false;
          _emailController.clear();
        });
      } else {
        setState(() {
          _message = 'No $_selectedRole found with that email.';
          _sendingRequest = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = 'Error sending request: $e';
        _sendingRequest = false;
      });
    }
  }

  /// ✅ Listen for active connections from doctor/caregiver dashboards
  void _listenForConnections() {
    final ref = FirebaseDatabase.instance.ref();

    // 🔹 Doctor side
    ref.child("doctors").onValue.listen((event) {
      final doctors = event.snapshot.value as Map?;
      if (doctors == null) return;

      Map<String, dynamic>? doctorFound;

      for (final entry in doctors.entries) {
        final data = entry.value as Map;
        final connectedPatients = data['connectedPatients'] as Map?;

        if (connectedPatients != null) {
          for (final patient in connectedPatients.entries) {
            final patientData = patient.value;
            if (patientData['email'] == widget.patientEmail) {
              doctorFound = {
                'id': entry.key,
                'name': data['name'] ?? 'Unknown',
                'email': data['email'] ?? '',
              };
            }
          }
        }
      }

      setState(() => _connectedDoctor = doctorFound);
    });

    // 🔹 Caregiver side
    ref.child("caregivers").onValue.listen((event) {
      final caregivers = event.snapshot.value as Map?;
      if (caregivers == null) return;

      Map<String, dynamic>? caregiverFound;

      for (final entry in caregivers.entries) {
        final data = entry.value as Map;
        final connectedPatients = data['connectedPatients'] as Map?;

        if (connectedPatients != null) {
          for (final patient in connectedPatients.entries) {
            final patientData = patient.value;
            if (patientData['email'] == widget.patientEmail) {
              caregiverFound = {
                'id': entry.key,
                'name': data['name'] ?? 'Unknown',
                'email': data['email'] ?? '',
              };
            }
          }
        }
      }

      setState(() => _connectedCaregiver = caregiverFound);
    });
  }

  /// ✅ Disconnect logic with real-time notification
  Future<void> _disconnect(String role) async {
    final isDoctor = role == "doctor";
    final target =
    isDoctor ? _connectedDoctor : _connectedCaregiver; // which to remove
    if (target == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Disconnect"),
        content: Text(
            "Are you sure you want to disconnect from ${target['name']} (${role.toUpperCase()})?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Disconnect"),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final ref = FirebaseDatabase.instance.ref();
      final rolePath = isDoctor ? "doctors" : "caregivers";
      final roleId = target['id'];

      // remove patient from connectedPatients
      final connectedPatientsRef =
      ref.child(rolePath).child(roleId).child("connectedPatients");
      final snapshot = await connectedPatientsRef.get();

      if (snapshot.exists) {
        for (final entry in snapshot.children) {
          final patientData = entry.value as Map;
          if (patientData['email'] == widget.patientEmail) {
            await connectedPatientsRef.child(entry.key!).remove();
          }
        }
      }

      // 🔹 push a disconnect notification in real-time
      await ref.child(rolePath).child(roleId).child("disconnects").push().set({
        "patientName": widget.patientName,
        "patientEmail": widget.patientEmail,
        "timestamp": ServerValue.timestamp,
      });

      setState(() {
        if (isDoctor) {
          _connectedDoctor = null;
        } else {
          _connectedCaregiver = null;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Disconnected from ${target['name']}")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error disconnecting: $e")),
      );
    }
  }

  Widget _buildConnectionStatus() {
    return Column(
      children: [
        Card(
          color: _connectedDoctor != null ? Colors.green[100] : Colors.grey[200],
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.medical_services, color: Colors.blue),
            title: Text(
              _connectedDoctor != null
                  ? "Connected to Dr. ${_connectedDoctor!['name']}"
                  : "Not connected to any doctor",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _connectedDoctor != null
                    ? Colors.green[800]
                    : Colors.black54,
              ),
            ),
            trailing: _connectedDoctor != null
                ? IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _disconnect("doctor"),
            )
                : null,
          ),
        ),
        Card(
          color:
          _connectedCaregiver != null ? Colors.green[100] : Colors.grey[200],
          margin: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: const Icon(Icons.people, color: Colors.green),
            title: Text(
              _connectedCaregiver != null
                  ? "Connected to Caregiver ${_connectedCaregiver!['name']}"
                  : "Not connected to any caregiver",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: _connectedCaregiver != null
                    ? Colors.green[800]
                    : Colors.black54,
              ),
            ),
            trailing: _connectedCaregiver != null
                ? IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: () => _disconnect("caregiver"),
            )
                : null,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Connection Request')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildConnectionStatus(),
            const SizedBox(height: 20),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  DropdownButtonFormField<String>(
                    value: _selectedRole,
                    items: const [
                      DropdownMenuItem(value: 'Doctor', child: Text('Doctor')),
                      DropdownMenuItem(
                          value: 'Caregiver', child: Text('Caregiver')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedRole = val;
                        });
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Select Role',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an email';
                      }
                      if (!RegExp(r'^\w+@([\w-]+\.)+\w{2,4}$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 20),
                  _sendingRequest
                      ? const CircularProgressIndicator()
                      : ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    onPressed: _sendRequest,
                    child: const Text('Send Request'),
                  ),
                  const SizedBox(height: 16),
                  if (_message != null)
                    Text(
                      _message!,
                      style: TextStyle(
                        color: _message!.startsWith('Error') ||
                            _message!.startsWith('No')
                            ? Colors.red
                            : Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}