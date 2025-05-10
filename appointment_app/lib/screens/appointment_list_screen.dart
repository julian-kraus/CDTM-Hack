import 'package:flutter/material.dart';
import '../models/appointment.dart';

class AppointmentListScreen extends StatelessWidget {
  final List<Appointment> appointments = [
    Appointment(reason: 'Dentist appointment', date: DateTime.now().add(Duration(days: 1))),
    Appointment(reason: 'Meeting with Bob', date: DateTime.now().add(Duration(days: 2))),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Appointments')),
      body: ListView.builder(
        itemCount: appointments.length,
        itemBuilder: (context, index) {
          final appointment = appointments[index];
          return ListTile(
            title: Text(appointment.reason),
            subtitle: Text(appointment.date.toLocal().toString()),
          );
        },
      ),
    );
  }
} 