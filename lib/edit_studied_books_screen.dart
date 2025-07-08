import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class EditStudiedBooksScreen extends StatefulWidget {
  final List<String> initialStudiedBooks;

  const EditStudiedBooksScreen({super.key, required this.initialStudiedBooks});

  @override
  State<EditStudiedBooksScreen> createState() => _EditStudiedBooksScreenState();
}

class _EditStudiedBooksScreenState extends State<EditStudiedBooksScreen> {
  // Lista ksiąg Biblii Tysiąclecia (katolicki kanon)
  final Map<String, List<String>> _bibleBooks = {
    'Stary Testament': [
      'Księga Rodzaju (Rdz)', 'Księga Wyjścia (Wj)', 'Księga Kapłańska (Kpł)', 'Księga Liczb (Lb)', 'Księga Powtórzonego Prawa (Pwt)',
      'Księga Jozuego (Joz)', 'Księga Sędziów (Sdz)', 'Księga Rut (Rt)', '1 Księga Samuela (1 Sm)', '2 Księga Samuela (2 Sm)',
      '1 Księga Królewska (1 Krl)', '2 Księga Królewska (2 Krl)', '1 Księga Kronik (1 Krn)', '2 Księga Kronik (2 Krn)',
      'Księga Ezdrasza (Ezd)', 'Księga Nehemiasza (Ne)', 'Księga Tobiasza (Tb)', 'Księga Judyty (Jdt)', 'Księga Estery (Est)',
      '1 Księga Machabejska (1 Mch)', '2 Księga Machabejska (2 Mch)', 'Księga Hioba (Hi)', 'Księga Psalmów (Ps)',
      'Księga Przysłów (Prz)', 'Księga Koheleta (Koh)', 'Pieśń nad Pieśniami (Pnp)', 'Księga Mądrości (Mdr)',
      'Mądrość Syracha (Syr)', 'Księga Izajasza (Iz)', 'Księga Jeremiasza (Jr)', 'Lamentacje (Lm)', 'Księga Barucha (Ba)',
      'Księga Ezechiela (Ez)', 'Księga Daniela (Dn)', 'Księga Ozeasza (Oz)', 'Księga Joela (Jl)', 'Księga Amosa (Am)',
      'Księga Abdiasza (Ab)', 'Księga Jonasza (Jon)', 'Księga Micheasza (Mi)', 'Księga Nahuma (Na)', 'Księga Habakuka (Ha)',
      'Księga Sofoniasza (So)', 'Księga Aggeusza (Ag)', 'Księga Zachariasza (Za)', 'Księga Malachiasza (Ml)'
    ],
    'Nowy Testament': [
      'Ewangelia wg św. Mateusza (Mt)', 'Ewangelia wg św. Marka (Mk)', 'Ewangelia wg św. Łukasza (Łk)', 'Ewangelia wg św. Jana (J)',
      'Dzieje Apostolskie (Dz)', 'List do Rzymian (Rz)', '1 List do Koryntian (1 Kor)', '2 List do Koryntian (2 Kor)',
      'List do Galatów (Ga)', 'List do Efezjan (Ef)', 'List do Filipian (Flp)', 'List do Kolosan (Kol)',
      '1 List do Tesaloniczan (1 Tes)', '2 List do Tesaloniczan (2 Tes)', '1 List do Tymoteusza (1 Tm)', '2 List do Tymoteusza (2 Tm)',
      'List do Tytusa (Tt)', 'List do Filemona (Flm)', 'List do Hebrajczyków (Hbr)', 'List św. Jakuba (Jk)',
      '1 List św. Piotra (1 P)', '2 List św. Piotra (2 P)', '1 List św. Jana (1 J)', '2 List św. Jana (2 J)', '3 List św. Jana (3 J)',
      'List św. Judy (Jud)', 'Apokalipsa św. Jana (Ap)'
    ]
  };

  late Set<String> _selectedBooks;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedBooks = Set<String>.from(widget.initialStudiedBooks);
  }

  Future<void> _saveSelection() async {
    setState(() => _isSaving = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Błąd: Użytkownik nie jest zalogowany.')));
      setState(() => _isSaving = false);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'studiedBooks': _selectedBooks.toList(),
      });
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zaznacz przestudiowane'),
        // ZMIANA: Usunięto przycisk zapisu z paska AppBar
      ),
      // ZMIANA: Dodajemy pływający przycisk akcji (FloatingActionButton)
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isSaving ? null : _saveSelection,
        label: Text(_isSaving ? 'Zapisywanie...' : 'Zapisz zmiany'),
        icon: _isSaving
            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.save),
        backgroundColor: const Color(0xFF00B0FF), // Używamy naszego niebieskiego koloru
      ),
      body: ListView.builder(
        // Dodajemy padding na dole, aby przycisk nie zasłaniał ostatniego elementu
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: _bibleBooks.keys.length,
        itemBuilder: (context, index) {
          String testament = _bibleBooks.keys.elementAt(index);
          List<String> books = _bibleBooks[testament]!;
          
          return ExpansionTile(
            title: Text(testament, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            initiallyExpanded: true,
            children: books.map((book) {
              return CheckboxListTile(
                title: Text(book),
                value: _selectedBooks.contains(book),
                activeColor: const Color(0xFF00B0FF), // Kolor zaznaczenia
                onChanged: (bool? value) {
                  setState(() {
                    if (value == true) {
                      _selectedBooks.add(book);
                    } else {
                      _selectedBooks.remove(book);
                    }
                  });
                },
              );
            }).toList(),
          );
        },
      ),
    );
  }
}