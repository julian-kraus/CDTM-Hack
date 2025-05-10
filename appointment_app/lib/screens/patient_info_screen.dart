import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'appointment_list_screen.dart';

class PatientInfoScreen extends StatefulWidget {
  const PatientInfoScreen({Key? key}) : super(key: key);

  @override
  _PatientInfoScreenState createState() => _PatientInfoScreenState();
}

class _PatientInfoScreenState extends State<PatientInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  DateTime? _selectedBirthdate;

  Future<void> _pickBirthdate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() => _selectedBirthdate = picked);
    }
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate() && _selectedBirthdate != null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('name', _nameController.text);
      await prefs.setString('birthdate', _selectedBirthdate!.toIso8601String());
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => AppointmentListScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Enter Patient Information')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(labelText: 'Name'),
                validator: (v) => v == null || v.isEmpty ? 'Please enter your name' : null,
              ),
              SizedBox(height: 16),
              Row(
                children: [
                  Text(_selectedBirthdate == null
                      ? 'No birthdate chosen'
                      : 'Birthdate: ${_selectedBirthdate!.toLocal().toString().split(' ')[0]}'),
                  Spacer(),
                  ElevatedButton(onPressed: _pickBirthdate, child: Text('Pick Birthdate')),
                ],
              ),
              SizedBox(height: 24),
              Center(child: ElevatedButton(onPressed: _submit, child: Text('Submit'))),
            ],
          ),
        ),
      ),
    );
  }
} 