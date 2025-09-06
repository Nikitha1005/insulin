import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../caregiver/caregiver_dashboard.dart';
import '../doctor/doctor_dashboard.dart';
import '../patient/patient_dashboard.dart';
import 'caregiver_registration_page.dart';
import 'doctor_registration_page.dart';
import 'patient_registration_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final FirebaseDatabase _database = FirebaseDatabase.instance;

  String? selectedRole;
  bool isRegisteredUser = false;
  bool isLoading = false;
  bool rememberMe = false;
  String? emailError; // error message shown only after pressing button

  @override
  void initState() {
    super.initState();
    _autoLoginIfRemembered();
  }

  Future<void> _autoLoginIfRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    final rememberedEmail = prefs.getString('remembered_email');
    final rememberedRole = prefs.getString('remembered_role');

    if (rememberedEmail != null && rememberedRole != null) {
      setState(() {
        emailController.text = rememberedEmail;
        selectedRole = rememberedRole;
        isRegisteredUser = true;
        rememberMe = true;
      });
      _login(auto: true);
    }
  }

  // ✅ Gmail validation
  bool _isValidGmail(String email) {
    final gmailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@gmail\.com$');
    return gmailRegex.hasMatch(email);
  }

  void _checkUserRegistration() async {
    final email = emailController.text.trim();

    if (email.isEmpty || selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    // ✅ Show error only when button is pressed
    if (!_isValidGmail(email)) {
      setState(() => emailError = "Enter a valid Gmail");
      return;
    } else {
      setState(() => emailError = null);
    }

    setState(() => isLoading = true);

    try {
      String path = _getDatabasePath();
      final snapshot = await _database
          .ref(path)
          .orderByChild('email')
          .equalTo(email.toLowerCase())
          .get();

      setState(() {
        isLoading = false;
        isRegisteredUser = snapshot.exists;
      });

      if (!snapshot.exists) _showRegistrationPrompt();
    } catch (e) {
      setState(() => isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  void _showRegistrationPrompt() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Account Not Found'),
        content: const Text('Do you want to register as a new user?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToRegistration();
            },
            child: const Text('Register'),
          ),
        ],
      ),
    );
  }

  void _navigateToRegistration() {
    final email = emailController.text.trim();
    if (selectedRole == 'Patient') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => PatientDetailsPage(prefillEmail: email)));
    } else if (selectedRole == 'Caregiver') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => CaregiverRegistrationPage(email: email)));
    } else if (selectedRole == 'Doctor') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorRegistrationPage(email: email)));
    }
  }

  void _login({bool auto = false}) async {
    final email = emailController.text.trim();

    if (email.isEmpty || selectedRole == null) {
      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all fields')),
        );
      }
      return;
    }

    if (!_isValidGmail(email)) {
      if (!auto) setState(() => emailError = "Enter a valid Gmail");
      return;
    } else {
      setState(() => emailError = null);
    }

    setState(() => isLoading = true);

    try {
      String path = _getDatabasePath();
      final snapshot = await _database
          .ref(path)
          .orderByChild('email')
          .equalTo(email.toLowerCase())
          .get();

      if (snapshot.exists) {
        final data = snapshot.value as Map;
        final userKey = data.keys.first;
        final user = data[userKey] as Map;
        final name = user['name'] ?? '';

        final prefs = await SharedPreferences.getInstance();

        if (rememberMe) {
          await prefs.setString('remembered_email', email);
          await prefs.setString('remembered_role', selectedRole!);
        }

        if (selectedRole == 'Patient') {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => PatientDashboard(patientName: name, patientEmail: email),
          ));
        } else if (selectedRole == 'Caregiver') {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => CaregiverDashboard(email: email, profileName: name),
          ));
        } else if (selectedRole == 'Doctor') {
          Navigator.pushReplacement(context, MaterialPageRoute(
            builder: (_) => DoctorDashboard(email: email, doctorName: name),
          ));
        }
      } else {
        if (!auto) {
          _showRegistrationPrompt();
        }
      }
    } catch (e) {
      setState(() => isLoading = false);
      if (!auto) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Login error: $e')),
        );
      }
    }
  }

  String _getDatabasePath() {
    if (selectedRole == 'Patient') return 'patients';
    if (selectedRole == 'Caregiver') return 'caregivers';
    return 'doctors';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Image.asset('assets/images/img.png', height: 120),
              const SizedBox(height: 20),
              _buildInputField("Email", emailController),
              if (emailError != null) // 🔴 show only when user presses button
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 4),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      emailError!,
                      style: const TextStyle(color: Colors.red, fontSize: 12),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              _buildRoleDropdown(),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text("Remember Me"),
                value: rememberMe,
                onChanged: (val) => setState(() => rememberMe = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
              ),
              const SizedBox(height: 16),
              isLoading
                  ? const CircularProgressIndicator()
                  : isRegisteredUser
                  ? _buildButton("LOGIN", () => _login())
                  : _buildButton("CONTINUE", _checkUserRegistration),
              if (!isRegisteredUser && selectedRole != null)
                TextButton(
                  onPressed: _navigateToRegistration,
                  child: const Text("Don't have an account? Register"),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton(String text, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue[800],
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
        child: Text(text, style: const TextStyle(color: Color(0xFFF0F4F7),),),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller, {bool isObscure = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isObscure,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.blue.shade100,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Select Role", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedRole,
              isExpanded: true,
              hint: const Text("Select Role"),
              items: ['Patient', 'Caregiver', 'Doctor']
                  .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedRole = value;
                  isRegisteredUser = false;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}
