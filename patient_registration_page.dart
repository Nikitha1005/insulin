import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import '../patient/patient_dashboard.dart';

class PatientDetailsPage extends StatefulWidget {
  final String prefillEmail;

  const PatientDetailsPage({super.key, required this.prefillEmail});

  @override
  State<PatientDetailsPage> createState() => _PatientDetailsPageState();
}

class _PatientDetailsPageState extends State<PatientDetailsPage> {
  final FirebaseDatabase _database = FirebaseDatabase.instance;
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
  TextEditingController();
  final TextEditingController nameController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  String? selectedDiabetesType;

  @override
  void initState() {
    super.initState();
    emailController.text = widget.prefillEmail;
  }

  Future<void> _submitForm() async {
    final email = emailController.text.trim();
    final name = nameController.text.trim();

    if (email.isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty ||
        name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Passwords do not match')),
      );
      return;
    }

    try {
      final ref = _database.ref().child('patients').push();
      await ref.set({
        'email': email.toLowerCase(),
        'password': passwordController.text,
        'name': name,
        'age': ageController.text.trim(),
        'diabetesType': selectedDiabetesType ?? 'Not specified',
      });

      if (!mounted) return;

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PatientDashboard(
              patientName: name, patientEmail: email.toLowerCase()),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ✅ Remove black background
      appBar: AppBar(
        title: const Text("Patient Registration"),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Image.asset(
              'assets/images/img.png',
              height: 100,
              fit: BoxFit.contain,
            ),
            const SizedBox(height: 24),

            _buildInputField("Email", emailController),
            _buildInputField("Password", passwordController, isObscure: true),
            _buildInputField("Confirm Password", confirmPasswordController,
                isObscure: true),

            Row(
              children: [
                Expanded(child: _buildInputField("Full Name", nameController)),
                const SizedBox(width: 10),
                SizedBox(
                  width: 80,
                  child: _buildInputField("Age", ageController),
                ),
              ],
            ),

            _buildDiabetesDropdown(),

            const SizedBox(height: 24),

            // ✅ Register button now comes right after dropdown
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  "REGISTER",
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(String label, TextEditingController controller,
      {bool isObscure = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiabetesDropdown() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Diabetes Type",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: selectedDiabetesType,
                hint: const Text("Select Diabetes Type"),
                isExpanded: true,
                items: ['Type 1', 'Type 2', 'Gestational']
                    .map((type) => DropdownMenuItem(
                  value: type,
                  child: Text(type),
                ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedDiabetesType = value;
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
