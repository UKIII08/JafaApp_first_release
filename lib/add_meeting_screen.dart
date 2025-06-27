import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddMeetingScreen extends StatefulWidget {
  final String groupId;
  const AddMeetingScreen({super.key, required this.groupId});

  @override
  State<AddMeetingScreen> createState() => _AddMeetingScreenState();
}

class _AddMeetingScreenState extends State<AddMeetingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _notesController = TextEditingController();
  
  String? _selectedBook;
  int? _selectedChapter;
  int? _selectedVerse;

  bool _isLoading = false;

  final Map<String, int> _chaptersInBook = {
    "Rodzaju": 50, "Wyjścia": 40, "Kapłańska": 27, "Liczb": 36, "Powtórzonego Prawa": 34, "Jozuego": 24, "Sędziów": 21, "Rut": 4, "1 Samuela": 31, "2 Samuela": 24, "1 Królewska": 22, "2 Królewska": 25, "1 Kronik": 29, "2 Kronik": 36, "Ezdrasza": 10, "Nehemiasza": 13, "Tobiasza": 14, "Judyty": 16, "Estery": 10, "1 Machabejska": 16, "2 Machabejska": 15, "Hioba": 42, "Psalmów": 150, "Przysłów": 31, "Koheleta": 12, "Pieśń nad Pieśniami": 8, "Mądrości": 19, "Syracha": 51, "Izajasza": 66, "Jeremiasza": 52, "Lamentacje": 5, "Barucha": 6, "Ezechiela": 48, "Daniela": 14, "Ozeasza": 14, "Joela": 4, "Amosa": 9, "Abdiasza": 1, "Jonasza": 4, "Micheasza": 7, "Nahuma": 3, "Habakuka": 3, "Sofoniasza": 3, "Aggeusza": 2, "Zachariasza": 14, "Malachiasza": 3,
    "Mateusza": 28, "Marka": 16, "Łukasza": 24, "Jana": 21, "Dzieje Apostolskie": 28, "Rzymian": 16, "1 Koryntian": 16, "2 Koryntian": 13, "Galatów": 6, "Efezjan": 6, "Filipian": 4, "Kolosan": 4, "1 Tesaloniczan": 5, "2 Tesaloniczan": 3, "1 Tymoteusza": 6, "2 Tymoteusza": 4, "Tytusa": 3, "Filemona": 1, "Hebrajczyków": 13, "Jakuba": 5, "1 Piotra": 5, "2 Piotra": 3, "1 Jana": 5, "2 Jana": 1, "3 Jana": 1, "Judy": 1, "Apokalipsa": 22
  };
  final List<String> _bibleBooks = ["Rodzaju", "Wyjścia", "Kapłańska", "Liczb", "Powtórzonego Prawa", "Jozuego", "Sędziów", "Rut", "1 Samuela", "2 Samuela", "1 Królewska", "2 Królewska", "1 Kronik", "2 Kronik", "Ezdrasza", "Nehemiasza", "Tobiasza", "Judyty", "Estery", "1 Machabejska", "2 Machabejska", "Hioba", "Psalmów", "Przysłów", "Koheleta", "Pieśń nad Pieśniami", "Mądrości", "Syracha", "Izajasza", "Jeremiasza", "Lamentacje", "Barucha", "Ezechiela", "Daniela", "Ozeasza", "Joela", "Amosa", "Abdiasza", "Jonasza", "Micheasza", "Nahuma", "Habakuka", "Sofoniasza", "Aggeusza", "Zachariasza", "Malachiasza", "Mateusza", "Marka", "Łukasza", "Jana", "Dzieje Apostolskie", "Rzymian", "1 Koryntian", "2 Koryntian", "Galatów", "Efezjan", "Filipian", "Kolosan", "1 Tesaloniczan", "2 Tesaloniczan", "1 Tymoteusza", "2 Tymoteusza", "Tytusa", "Filemona", "Hebrajczyków", "Jakuba", "1 Piotra", "2 Piotra", "1 Jana", "2 Jana", "3 Jana", "Judy", "Apokalipsa"];


  Future<void> _saveMeeting() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      
      final leaderId = FirebaseAuth.instance.currentUser?.uid;
      if (leaderId == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Błąd: Brak zalogowanego lidera.')));
        setState(() => _isLoading = false);
        return;
      }
      
      final progressReference = '$_selectedBook $_selectedChapter:$_selectedVerse';
      
      try {
        await FirebaseFirestore.instance
            .collection('smallGroups')
            .doc(widget.groupId)
            .collection('meetings')
            .add({
          'date': Timestamp.now(),
          'progressReference': progressReference,
          'notes': _notesController.text.trim(),
          'leaderId': leaderId,
        });

        if(mounted) {
          Navigator.pop(context);
        }
      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
        }
      } finally {
        if(mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }
  
  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dodaj wpis ze spotkania')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Omawiany fragment', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                hint: const Text('Wybierz Księgę'),
                value: _selectedBook,
                items: _bibleBooks.map((book) => DropdownMenuItem(value: book, child: Text(book))).toList(),
                onChanged: (v) => setState(() { _selectedBook = v; _selectedChapter = null; _selectedVerse = null; }),
                validator: (v) => v == null ? 'Wybierz księgę' : null,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      hint: const Text('Rozdział'),
                      value: _selectedChapter,
                      items: List.generate(_chaptersInBook[_selectedBook] ?? 1, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                      onChanged: (v) => setState(() { _selectedChapter = v; _selectedVerse = null; }),
                      validator: (v) => v == null ? 'Wybierz rozdział' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      hint: const Text('Werset'),
                      value: _selectedVerse,
                      items: List.generate(180, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1}'))),
                      onChanged: (v) => setState(() => _selectedVerse = v),
                      validator: (v) => v == null ? 'Wybierz werset' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notatki ze spotkania',
                  border: OutlineInputBorder(),
                ),
                maxLines: 8,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveMeeting,
                  child: _isLoading ? const CircularProgressIndicator() : const Text('Zapisz wpis'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

