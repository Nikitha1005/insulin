import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_page.dart';

class PatientSettingsPage extends StatefulWidget {
  final String patientId;
  final String patientName;
  final String patientEmail;
  final String age;
  final String diabetesType;

  const PatientSettingsPage({
    super.key,
    required this.patientId,
    required this.patientName,
    required this.patientEmail,
    required this.age,
    required this.diabetesType,
  });

  @override
  State<PatientSettingsPage> createState() => _PatientSettingsPageState();
}

class _PatientSettingsPageState extends State<PatientSettingsPage> {
  bool notificationsEnabled = true;
  bool shareHealthData = true;
  bool twoFactorAuth = false;

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        backgroundColor: Colors.blueAccent,
      ),
      body: ListView(
        children: [
          // Profile
          ListTile(
            leading: const CircleAvatar(
              radius: 25,
              child: Icon(Icons.person, size: 30),
            ),
            title: Text(widget.patientName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(widget.patientEmail),
          ),
          const Divider(),

          // Account & Profile
          ListTile(
            leading: const Icon(Icons.lock),
            title: const Text("Change Password"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ChangePasswordPage(),
                ),
              );
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text("Enable Notifications"),
            value: notificationsEnabled,
            onChanged: (value) {
              setState(() => notificationsEnabled = value);
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.favorite, color: Colors.pink),
            title: const Text("Share Health Data"),
            value: shareHealthData,
            onChanged: (value) {
              setState(() => shareHealthData = value);
            },
          ),
          const Divider(),

          // Security
          SwitchListTile(
            secondary: const Icon(Icons.security, color: Colors.red),
            title: const Text("Two-Factor Authentication"),
            value: twoFactorAuth,
            onChanged: (value) {
              setState(() => twoFactorAuth = value);
            },
          ),
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text("Manage Sessions"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          const Divider(),

          // Logout
          Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                padding:
                const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text("Logout"),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

//
// Reuse same Change Password Page
//
class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  void _changePassword() {
    if (_newPasswordController.text == _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Password changed successfully")),
      );
      Navigator.pop(context);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Passwords do not match")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Change Password")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _oldPasswordController,
              decoration: const InputDecoration(labelText: "Old Password"),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _newPasswordController,
              decoration: const InputDecoration(labelText: "New Password"),
              obscureText: true,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmPasswordController,
              decoration: const InputDecoration(labelText: "Confirm Password"),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _changePassword,
              child: const Text("Update Password"),
            )
          ],
        ),
      ),
    );
  }
}
