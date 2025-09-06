import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'doctor_settings_page.dart';
import 'notification_page.dart'; // DoctorNotificationPage
import '../auth/patient_detail_page.dart';

class DoctorDashboard extends StatefulWidget {
  final String email;
  final String doctorName;

  const DoctorDashboard({
    super.key,
    required this.email,
    required this.doctorName,
  });

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard>
    with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final _db = FirebaseDatabase.instance;
  String? _doctorKey;
  late AnimationController _animationController;
  late Animation<double> _animation;
  int _pendingRequestCount = 0;

  @override
  void initState() {
    super.initState();
    _initDoctorKey();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _animation = TweenSequence<double>([
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.0, end: 1.1),
        weight: 50,
      ),
      TweenSequenceItem<double>(
        tween: Tween<double>(begin: 1.1, end: 1.0),
        weight: 50,
      ),
    ]).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _initDoctorKey() async {
    final snap = await _db
        .ref('doctors')
        .orderByChild('email')
        .equalTo(widget.email.toLowerCase())
        .get();

    if (snap.exists) {
      setState(() {
        _doctorKey = snap.children.first.key;
      });
    }
  }

  Future<void> _openPatientDetails(
      String patientId, String patientName, String patientEmail) async {
    final removed = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailPage(
          patientId: patientId,
          patientName: patientName,
          patientEmail: patientEmail,
        ),
      ),
    );

    if (removed == true) {
      // auto refresh via StreamBuilder
    }
  }

  Widget _buildConnectedPatientsGrid() {
    if (_doctorKey == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return StreamBuilder<DatabaseEvent>(
      stream: _db.ref('doctors/$_doctorKey/connectedPatients').onValue,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data?.snapshot.value;
        if (data == null) {
          return const Center(
            child: Text(
              'No connected patients yet.',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        final patientsMap = Map<String, dynamic>.from(data as Map);
        final patients = patientsMap.entries.map((entry) {
          final map = Map<String, dynamic>.from(entry.value as Map);
          return {
            'id': entry.key,
            'name': map['name'] ?? 'Unknown',
            'email': map['email'] ?? '',
          };
        }).toList()
          ..sort((a, b) =>
              a['name'].toString().compareTo(b['name'].toString()));

        return GridView.builder(
          padding: const EdgeInsets.all(16),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
          ),
          itemCount: patients.length,
          itemBuilder: (context, index) {
            final patient = patients[index];
            return InkWell(
              onTap: () => _openPatientDetails(
                patient['id'],
                patient['name'],
                patient['email'],
              ),
              borderRadius: BorderRadius.circular(14),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                color: Colors.blue.shade50,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.blue.shade700,
                      child: const Icon(Icons.medical_services,
                          size: 32, color: Colors.white),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      patient['name'],
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      patient['email'],
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatsPage() {
    return const Center(
      child: Text(
        'Stats Page (Coming Soon)',
        style: TextStyle(fontSize: 18, color: Colors.black54),
      ),
    );
  }

  List<Widget> get _pages => [
    _buildConnectedPatientsGrid(),
    _buildStatsPage(),
  ];

  void _onItemTapped(int index) {
    if (index == 2) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DoctorSettingsPage(
            doctorId: _doctorKey ?? '',
            doctorName: widget.doctorName,
            doctorEmail: widget.email,
            connectedPatients: const [],
          ),
        ),
      );
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_doctorKey == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Loading Doctor...')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Doctor Dashboard - ${widget.email}'),
        actions: [
          StreamBuilder<DatabaseEvent>(
            stream: _db.ref('doctors/$_doctorKey/requests').onValue,
            builder: (context, snapshot) {
              _pendingRequestCount = 0;

              if (snapshot.hasData &&
                  snapshot.data!.snapshot.value != null) {
                final requests = Map<String, dynamic>.from(
                    snapshot.data!.snapshot.value as Map);

                _pendingRequestCount = requests.length;
              }

              return Stack(
                children: [
                  IconButton(
                    icon: AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _pendingRequestCount > 0
                              ? _animation.value
                              : 1.0,
                          child: Icon(
                            Icons.notifications,
                            color: _pendingRequestCount > 0
                                ? Colors.red.shade700
                                : Colors.grey.shade600,
                            size: 28,
                          ),
                        );
                      },
                    ),
                    tooltip: 'Connection requests',
                    onPressed: () async {
                      await _animationController.animateTo(0.5);
                      await _animationController.animateTo(1.0);

                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => DoctorNotificationPage(
                            doctorEmail: widget.email,
                            doctorId: _doctorKey ?? '',
                          ),
                        ),
                      );
                    },
                  ),
                  if (_pendingRequestCount > 0)
                    Positioned(
                      right: 6,
                      top: 6,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 22,
                          minHeight: 22,
                        ),
                        child: Center(
                          child: Text(
                            '$_pendingRequestCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex > 1 ? 0 : _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.person_outline), label: 'Patients'),
          BottomNavigationBarItem(
              icon: Icon(Icons.bar_chart), label: 'Stats'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}