// lib/screens/service_meetings_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ServiceMeetingsScreen extends StatefulWidget {
  final String serviceId;
  final String serviceName;

  const ServiceMeetingsScreen({
    super.key,
    required this.serviceId,
    required this.serviceName,
  });

  @override
  State<ServiceMeetingsScreen> createState() => _ServiceMeetingsScreenState();
}

class _ServiceMeetingsScreenState extends State<ServiceMeetingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _driveLinkController = TextEditingController(); 

  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  bool _isSaving = false;

  // Wszystkie funkcje pomocnicze (_addMeeting, _deleteMeeting, itd.) pozostają bez zmian
  Future<void> _addMeeting() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null || _selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Musisz wybrać datę i godzinę spotkania.')));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final meetingDateTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _selectedTime!.hour, _selectedTime!.minute);
      await FirebaseFirestore.instance.collection('services').doc(widget.serviceId).collection('meetings').add({
        'title': _titleController.text.trim(),
        'location': _locationController.text.trim(),
        'date': Timestamp.fromDate(meetingDateTime),
        'createdAt': FieldValue.serverTimestamp(),
        'googleDriveLink': _driveLinkController.text.trim(),
      });
      _titleController.clear();
      _locationController.clear();
      _driveLinkController.clear();
      setState(() {
        _selectedDate = null;
        _selectedTime = null;
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dodano nowe spotkanie!')));
    } catch (e) {
       if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Błąd dodawania spotkania: $e")));
    } finally {
       if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _deleteMeeting(String meetingId) async {
    final confirm = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: const Text('Potwierdź usunięcie'), content: const Text('Czy na pewno chcesz usunąć to spotkanie?'), actions: [TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anuluj')), TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Usuń', style: TextStyle(color: Colors.red))) ] )) ?? false;
    if (confirm) { await FirebaseFirestore.instance.collection('services').doc(widget.serviceId).collection('meetings').doc(meetingId).delete(); }
  }
  
  Future<void> _pickDate() async {
    final date = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
    if (date != null) setState(() => _selectedDate = date);
  }

  Future<void> _pickTime() async {
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.now(), builder: (BuildContext context, Widget? child) { return MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!); });
    if (time != null) setState(() => _selectedTime = time);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _driveLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isWorshipTeam = widget.serviceName.toLowerCase().contains('uwielbienia');

    return Scaffold(
      appBar: AppBar(
        title: Text('Spotkania: ${widget.serviceName}'),
      ),
      // ZMIANA: Cała zawartość jest teraz w SingleChildScrollView
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dodaj nowe spotkanie', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 16),
                    TextFormField(controller: _titleController, decoration: const InputDecoration(labelText: 'Cel/Tytuł spotkania', border: OutlineInputBorder()), validator: (value) => value!.isEmpty ? 'Podaj tytuł' : null),
                    const SizedBox(height: 12),
                    TextFormField(controller: _locationController, decoration: const InputDecoration(labelText: 'Miejsce (opcjonalnie)', border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    // ZMIANA: Uproszczony wygląd wyboru daty i godziny
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.calendar_today, size: 18),
                            label: Text(_selectedDate == null ? 'Wybierz datę' : DateFormat('d MMM yy').format(_selectedDate!)),
                            onPressed: _pickDate,
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                           child: OutlinedButton.icon(
                            icon: const Icon(Icons.access_time, size: 18),
                            label: Text(_selectedTime == null ? 'Wybierz godzinę' : _selectedTime!.format(context)),
                            onPressed: _pickTime,
                            style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                           ),
                        ),
                      ],
                    ),
                    if (isWorshipTeam) ...[
                      const SizedBox(height: 12),
                      TextFormField(controller: _driveLinkController, decoration: const InputDecoration(labelText: 'Link do materiałów (np. Dysk Google)', border: OutlineInputBorder(), prefixIcon: Icon(Icons.link)), keyboardType: TextInputType.url),
                    ],
                    const SizedBox(height: 20),
                    if (_isSaving)
                      const Center(child: CircularProgressIndicator())
                    else
                      ElevatedButton.icon(
                        onPressed: _addMeeting,
                        icon: const Icon(Icons.add),
                        label: const Text('Dodaj spotkanie'),
                        style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50)),
                      )
                  ],
                ),
              ),
            ),
            const Divider(),
            // ZMIANA: Lista jest teraz wewnątrz `Column`
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text("Nadchodzące spotkania", style: Theme.of(context).textTheme.titleMedium),
            ),
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('services').doc(widget.serviceId).collection('meetings').where('date', isGreaterThanOrEqualTo: DateTime.now()).orderBy('date').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                if (snapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Brak zaplanowanych spotkań.')));

                return ListView(
                  // Ważne: te dwie właściwości są potrzebne, gdy ListView jest wewnątrz SingleChildScrollView
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  children: snapshot.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    final date = (data['date'] as Timestamp).toDate();
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        title: Text(data['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${DateFormat('EEEE, d MMMM, HH:mm', 'pl_PL').format(date)}\n${data['location'] ?? 'Brak lokalizacji'}'),
                        isThreeLine: true,
                        trailing: IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _deleteMeeting(doc.id)),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
             const SizedBox(height: 20), // Dodatkowy odstęp na dole
          ],
        ),
      ),
    );
  }
}