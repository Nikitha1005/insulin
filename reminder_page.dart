import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:intl/intl.dart';

class ReminderPage extends StatefulWidget {
  final String patientEmail;

  const ReminderPage({super.key, required this.patientEmail});

  @override
  State<ReminderPage> createState() => _ReminderPageState();
}

class _ReminderPageState extends State<ReminderPage> {
  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();
  Map<String, dynamic> reminders = {};

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  void _loadReminders() {
    final emailKey = widget.patientEmail.replaceAll('.', ',');
    _dbRef.child('patients/$emailKey/reminders').onValue.listen((event) {
      final data = event.snapshot.value;
      setState(() {
        if (data != null) {
          reminders = Map<String, dynamic>.from(data as Map);
        } else {
          reminders = {};
        }
      });
    });
  }

  void _deleteReminder(String id) {
    final emailKey = widget.patientEmail.replaceAll('.', ',');
    _dbRef.child('patients/$emailKey/reminders/$id').remove();
  }

  void _showAddReminderDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 350),
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: AddReminderForm(patientEmail: widget.patientEmail),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reminderList = reminders.entries
        .map((e) => {"id": e.key, ...Map<String, dynamic>.from(e.value)})
        .toList();
    reminderList.sort((a, b) => a['time'].compareTo(b['time']));

    return Scaffold(
      appBar: AppBar(
        title: const Text("Medication Reminders"),
        centerTitle: true,
      ),
      body: reminderList.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.alarm_off_outlined,
                size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text("No Reminders Set",
                style:
                TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("Tap the '+' button to add a new reminder.",
                style: TextStyle(fontSize: 16, color: Colors.grey[600])),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8),
        itemCount: reminderList.length,
        itemBuilder: (context, index) {
          final rem = reminderList[index];
          return Card(
            elevation: 3,
            margin:
            const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
            child: ListTile(
              leading: const CircleAvatar(
                child: Icon(Icons.medication_liquid_outlined),
              ),
              title: Text(rem["label"],
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 16)),
              subtitle: Text("${rem["dosage"]} ${rem["unit"]}"),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(rem["time"],
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Theme.of(context).primaryColor)),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteReminder(rem['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 20.0), // lift FAB a bit
        child: FloatingActionButton(
          onPressed: _showAddReminderDialog,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}

class AddReminderForm extends StatefulWidget {
  final String patientEmail;

  const AddReminderForm({super.key, required this.patientEmail});

  @override
  State<AddReminderForm> createState() => _AddReminderFormState();
}

class _AddReminderFormState extends State<AddReminderForm> {
  final _formKey = GlobalKey<FormState>();
  final _dosageController = TextEditingController();
  String _selectedUnit = "ML";
  TimeOfDay? _selectedTime;
  String? _nextDosageLabel;

  final DatabaseReference _dbRef = FirebaseDatabase.instance.ref();

  @override
  void initState() {
    super.initState();
    _fetchNextDosageLabel();
  }

  Future<void> _fetchNextDosageLabel() async {
    final emailKey = widget.patientEmail.replaceAll('.', ',');
    final snapshot = await _dbRef.child('patients/$emailKey/reminders').get();
    final usedLabels = <String>{};
    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      for (var r in data.values) {
        usedLabels.add(r["label"]);
      }
    }
    for (int i = 1; i <= 5; i++) {
      final label = "Dosage $i";
      if (!usedLabels.contains(label)) {
        setState(() => _nextDosageLabel = label);
        break;
      }
    }
  }

  Future<void> _saveReminder() async {
    if (!_formKey.currentState!.validate() ||
        _selectedTime == null ||
        _nextDosageLabel == null) return;

    final formattedTime = DateFormat("hh:mm a").format(DateTime(
        2025, 1, 1, _selectedTime!.hour, _selectedTime!.minute));
    final reminderId = DateTime.now().millisecondsSinceEpoch.toString();
    final reminderData = {
      "time": formattedTime,
      "label": _nextDosageLabel,
      "dosage": _dosageController.text,
      "unit": _selectedUnit,
    };

    final emailKey = widget.patientEmail.replaceAll('.', ',');
    await _dbRef
        .child('patients/$emailKey/reminders/$reminderId')
        .set(reminderData);

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Text(
                  "Add ${_nextDosageLabel ?? 'Dosage'}",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _dosageController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                    labelText: "Dosage", border: OutlineInputBorder()),
                validator: (val) =>
                val == null || val.isEmpty ? "Required" : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                value: _selectedUnit,
                onChanged: (v) => setState(() => _selectedUnit = v!),
                items: ["ML", "Units", "Pills"]
                    .map((e) =>
                    DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                decoration:
                const InputDecoration(border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              ElevatedButton.icon(
                onPressed: () async {
                  final picked = await showTimePicker(
                      context: context, initialTime: TimeOfDay.now());
                  if (picked != null) setState(() => _selectedTime = picked);
                },
                icon: const Icon(Icons.access_time),
                label: Text(_selectedTime == null
                    ? "Pick a Time"
                    : "Time: ${_selectedTime!.format(context)}"),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 45),
                ),
              ),
              const SizedBox(height: 20),

              ElevatedButton(
                onPressed: _saveReminder,
                child: const Text("✅ Save Reminder"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
