import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../auth/login_page.dart';

class CaregiverSettingsPage extends StatefulWidget {
  final String caregiverName;
  final String caregiverEmail;

  const CaregiverSettingsPage({
    super.key,
    required this.caregiverName,
    required this.caregiverEmail, required List connectedPatients, required String caregiverId,
  });

  @override
  State<CaregiverSettingsPage> createState() => _CaregiverSettingsPageState();
}

class _CaregiverSettingsPageState extends State<CaregiverSettingsPage> {
  bool notificationsEnabled = true;
  bool availableStatus = true;
  bool twoFactorEnabled = false;

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
        backgroundColor: Colors.blue,
      ),
      body: ListView(
        children: [
          // Profile info
          ListTile(
            leading: const CircleAvatar(
              radius: 25,
              child: Icon(Icons.person, size: 30),
            ),
            title: Text(
              widget.caregiverName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(widget.caregiverEmail),
          ),
          const Divider(),

          // Change password
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

          // Notifications toggle
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text("Enable Notifications"),
            value: notificationsEnabled,
            onChanged: (value) {
              setState(() => notificationsEnabled = value);
            },
          ),

          // Available status toggle
          SwitchListTile(
            secondary: const Icon(Icons.circle, color: Colors.green),
            title: const Text("Available Status"),
            value: availableStatus,
            onChanged: (value) {
              setState(() => availableStatus = value);
            },
          ),

          // 🔹 Divider line after Available Status
          const Divider(),

          // Two-factor authentication
          SwitchListTile(
            secondary: const Icon(Icons.shield, color: Colors.red),
            title: const Text("Two-Factor Authentication"),
            value: twoFactorEnabled,
            onChanged: (value) {
              setState(() => twoFactorEnabled = value);
            },
          ),

          // Manage sessions
          ListTile(
            leading: const Icon(Icons.devices),
            title: const Text("Manage Sessions"),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Manage sessions tapped")),
              );
            },
          ),
          const Divider(),

          // Logout button
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

// Change Password Page (same as before)
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
