// lib/screens/manage_area_leaders_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageAreaLeadersScreen extends StatefulWidget {
  const ManageAreaLeadersScreen({super.key});

  @override
  State<ManageAreaLeadersScreen> createState() => _ManageAreaLeadersScreenState();
}

class _ManageAreaLeadersScreenState extends State<ManageAreaLeadersScreen> {
  // Przechowuje listę wszystkich unikalnych ról (służb)
  List<String> _allRoles = [];
  // Przechowuje dane o służbach, które już mają dokument w kolekcji 'services'
  Map<String, DocumentSnapshot> _servicesData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  // Funkcja do wczytania wszystkich niezbędnych danych na starcie
  Future<void> _loadInitialData() async {
    await _fetchUniqueRoles();
    await _fetchServicesData();
    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Pobiera unikalne role (służby) z kolekcji użytkowników
  Future<void> _fetchUniqueRoles() async {
    try {
      final usersSnapshot = await FirebaseFirestore.instance.collection('users').get();
      final Set<String> uniqueRoles = {};
      for (var doc in usersSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('roles') && data['roles'] is List) {
          final rolesList = List<dynamic>.from(data['roles']);
          for (var role in rolesList) {
            // Wykluczamy rolę 'admin' z listy służb do zarządzania
            if (role is String && role.trim().isNotEmpty && role.toLowerCase() != 'admin') {
              uniqueRoles.add(role.trim());
            }
          }
        }
      }
      if (mounted) {
        setState(() {
          _allRoles = uniqueRoles.toList()..sort();
        });
      }
    } catch (e) {
      print("Błąd podczas pobierania ról: $e");
    }
  }

  // Pobiera istniejące dokumenty służb, aby sprawdzić, kto jest liderem
  Future<void> _fetchServicesData() async {
    try {
      final servicesSnapshot = await FirebaseFirestore.instance.collection('services').get();
      final Map<String, DocumentSnapshot> servicesMap = {};
      for (var doc in servicesSnapshot.docs) {
        final data = doc.data();
        if (data.containsKey('name')) {
          servicesMap[data['name']] = doc;
        }
      }
      if (mounted) {
        setState(() {
          _servicesData = servicesMap;
        });
      }
    } catch (e) {
      print("Błąd podczas pobierania danych służb: $e");
    }
  }
  
  // Otwiera okno do zmiany lub przypisania lidera dla danej służby
  Future<void> _showChangeLeaderDialog(String roleName) async {
    final serviceDoc = _servicesData[roleName];
    final currentLeaderId = serviceDoc != null ? serviceDoc['leaderId'] as String? : null;

    final usersSnapshot = await FirebaseFirestore.instance.collection('users').orderBy('displayName').get();
    
    String? newLeaderId = await showDialog<String?>(
      context: context,
      builder: (context) {
        String? dialogSelectedLeaderId = currentLeaderId;
        return AlertDialog(
          title: Text('Zarządzaj liderem: $roleName'),
          content: StatefulBuilder(
            builder: (context, setState) {
              return DropdownButtonFormField<String>(
                value: dialogSelectedLeaderId,
                hint: const Text('Wybierz lidera'),
                items: [
                  // Opcja do usunięcia lidera
                  const DropdownMenuItem<String>(
                    value: null,
                    child: Text('Brak lidera', style: TextStyle(fontStyle: FontStyle.italic)),
                  ),
                  ...usersSnapshot.docs.map((doc) {
                    return DropdownMenuItem<String>(
                      value: doc.id,
                      child: Text(doc['displayName'] ?? doc['email']),
                    );
                  })
                ],
                onChanged: (value) => setState(() => dialogSelectedLeaderId = value),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
            ElevatedButton(onPressed: () => Navigator.of(context).pop(dialogSelectedLeaderId), child: const Text('Zapisz')),
          ],
        );
      },
    );

    // Jeśli wybrano jakąś opcję (nawet usunięcie lidera)
    if (newLeaderId != currentLeaderId) {
      // Jeśli dokument służby już istnieje, zaktualizuj go
      if (serviceDoc != null) {
        await FirebaseFirestore.instance.collection('services').doc(serviceDoc.id).update({'leaderId': newLeaderId});
      } else {
        // Jeśli dokument nie istnieje, utwórz go
        await FirebaseFirestore.instance.collection('services').add({
          'name': roleName,
          'leaderId': newLeaderId,
        });
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaktualizowano lidera.')));
        // Odśwież dane, aby zobaczyć zmiany
        _loadInitialData();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zarządzaj Liderami Służb'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Odśwież dane',
            onPressed: _loadInitialData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allRoles.isEmpty
              ? const Center(child: Text('Nie znaleziono żadnych służb do zarządzania.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(8),
                  itemCount: _allRoles.length,
                  itemBuilder: (context, index) {
                    final roleName = _allRoles[index];
                    final serviceDoc = _servicesData[roleName];
                    final leaderId = serviceDoc?['leaderId'] as String?;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      child: ListTile(
                        title: Text(roleName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: leaderId == null
                            ? const Text('Brak lidera', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.redAccent))
                            : FutureBuilder<DocumentSnapshot>(
                                future: FirebaseFirestore.instance.collection('users').doc(leaderId).get(),
                                builder: (context, userSnapshot) {
                                  if (!userSnapshot.hasData) return const Text('Ładowanie...');
                                  return Text('Lider: ${userSnapshot.data?['displayName'] ?? 'Brak nazwy'}');
                                },
                              ),
                        trailing: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                        onTap: () => _showChangeLeaderDialog(roleName),
                      ),
                    );
                  },
                ),
    );
  }
}