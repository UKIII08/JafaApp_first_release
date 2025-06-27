// lib/edit_profile_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  
  String? _gender;
  bool _isLoading = true;
  File? _imageFile;
  String? _networkImageURL;

  int? _selectedYear;
  int? _selectedMonth;
  int? _selectedDay;

  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final ImagePicker _picker = ImagePicker();

  final List<String> _months = [ 'Styczeń', 'Luty', 'Marzec', 'Kwiecień', 'Maj', 'Czerwiec', 'Lipiec', 'Sierpień', 'Wrzesień', 'Październik', 'Listopad', 'Grudzień' ];
  late final List<int> _years;

  @override
  void initState() {
    super.initState();
    _years = List<int>.generate(100, (i) => DateTime.now().year - i);
    _loadUserData();
  }

  int _getDaysInMonth(int year, int month) {
    if (month == 2) return (year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)) ? 29 : 28;
    if ([4, 6, 9, 11].contains(month)) return 30;
    return 31;
  }

  Future<void> _loadUserData() async {
    if (_currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final docSnap = await FirebaseFirestore.instance.collection('users').doc(_currentUser.uid).get();
      if (docSnap.exists) {
        final data = docSnap.data()!;
        setState(() {
          _gender = data['gender'];
          if (data['birthDate'] != null) {
            final birthDate = (data['birthDate'] as Timestamp).toDate();
            _selectedYear = birthDate.year;
            _selectedMonth = birthDate.month;
            _selectedDay = birthDate.day;
          }
          _networkImageURL = data['photoURL'];
        });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd ładowania danych: $e')));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) setState(() => _imageFile = File(pickedFile.path));
  }

  Future<String?> _uploadImage(String userId) async {
    if (_imageFile == null) return null;
    try {
      final ref = FirebaseStorage.instance.ref().child('profile_pictures').child('$userId.jpg');
      await ref.putFile(_imageFile!);
      return await ref.getDownloadURL();
    } catch (e) {
      print("Błąd wysyłania zdjęcia: $e");
      return null;
    }
  }

  Future<void> _saveProfile() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      DateTime? birthDate;
      if (_selectedYear != null && _selectedMonth != null && _selectedDay != null) {
        birthDate = DateTime(_selectedYear!, _selectedMonth!, _selectedDay!);
      }

      try {
        String? newImageURL = _imageFile != null ? await _uploadImage(_currentUser!.uid) : null;

        final dataToUpdate = <String, dynamic>{
          'gender': _gender,
          'birthDate': birthDate != null ? Timestamp.fromDate(birthDate) : null,
          'birthDay': birthDate?.day,
          'birthMonth': birthDate?.month,
          // Usuwamy pole z wersetem
          'favoriteBibleVerse': FieldValue.delete(),
        };
        if (newImageURL != null) {
          dataToUpdate['photoURL'] = newImageURL;
        }

        await FirebaseFirestore.instance.collection('users').doc(_currentUser!.uid).update(dataToUpdate);

        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profil zaktualizowany!')));
          Navigator.pop(context);
        }
      } catch (e) {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
      } finally {
        if(mounted) setState(() => _isLoading = false);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edytuj profil')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentUser == null
              ? const Center(child: Text('Błąd: Brak użytkownika.'))
              : Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Stack(
                            children: [
                              CircleAvatar(
                                radius: 60,
                                backgroundImage: _imageFile != null
                                    ? FileImage(_imageFile!)
                                    : (_networkImageURL != null ? NetworkImage(_networkImageURL!) : null) as ImageProvider?,
                                child: _imageFile == null && _networkImageURL == null ? const Icon(Icons.person, size: 60) : null,
                              ),
                              Positioned(bottom: 0, right: 0, child: IconButton(icon: const Icon(Icons.camera_alt), onPressed: _pickImage)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        
                        DropdownButtonFormField<String>(
                          value: _gender,
                          hint: const Text('Wybierz płeć'),
                          items: const [ DropdownMenuItem(value: 'male', child: Text('Mężczyzna')), DropdownMenuItem(value: 'female', child: Text('Kobieta')) ],
                          onChanged: (value) => setState(() => _gender = value),
                          validator: (value) => value == null ? 'Proszę wybrać płeć' : null,
                          decoration: const InputDecoration(labelText: 'Płeć', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 20),
                        
                        const Text('Data urodzenia', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(flex: 2, child: DropdownButtonFormField<int>(value: _selectedYear, hint: const Text('Rok'), items: _years.map((year) => DropdownMenuItem(value: year, child: Text(year.toString()))).toList(), onChanged: (v) => setState(() { _selectedYear = v; _selectedDay = null; }), validator: (v) => v == null ? 'Wybierz' : null)),
                            const SizedBox(width: 8),
                            Expanded(flex: 3, child: DropdownButtonFormField<int>(value: _selectedMonth, hint: const Text('Miesiąc'), items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text(_months[i]))), onChanged: (v) => setState(() { _selectedMonth = v; _selectedDay = null; }), validator: (v) => v == null ? 'Wybierz' : null)),
                            const SizedBox(width: 8),
                            Expanded(flex: 2, child: DropdownButtonFormField<int>(value: _selectedDay, hint: const Text('Dzień'), items: (_selectedYear != null && _selectedMonth != null) ? List.generate(_getDaysInMonth(_selectedYear!, _selectedMonth!), (i) => DropdownMenuItem(value: i + 1, child: Text((i + 1).toString()))) : [], onChanged: (v) => setState(() => _selectedDay = v), validator: (v) => v == null ? 'Wybierz' : null)),
                          ],
                        ),
                        const SizedBox(height: 32),
                        
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _saveProfile,
                            style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                            child: const Text('Zapisz zmiany'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }
}
