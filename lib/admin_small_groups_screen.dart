import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSmallGroupsScreen extends StatefulWidget {
  const AdminSmallGroupsScreen({super.key});

  @override
  State<AdminSmallGroupsScreen> createState() => _AdminSmallGroupsScreenState();
}

class _AdminSmallGroupsScreenState extends State<AdminSmallGroupsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _groupNameController = TextEditingController();
  String? _selectedLeaderId;

  // --- FUNKCJE POMOCNICZE ---

  // Funkcja do dodawania nowej grupy (pozostaje bez zmian)
  Future<void> _addGroup() async {
    if (!_formKey.currentState!.validate()) return;
    
    await FirebaseFirestore.instance.collection('smallGroups').add({
      'groupName': _groupNameController.text.trim(),
      'leaderId': _selectedLeaderId,
      'members': [_selectedLeaderId], // Lider jest automatycznie członkiem
      'createdAt': FieldValue.serverTimestamp(),
      // Domyślne wartości dla nowych pól
      'recurringMeetingDay': 2, // Wtorek
      'recurringMeetingTime': "19:00",
      'temporaryMeetingDateTime': null,
      'currentBook': 'Ewangelia Jana',
      'currentChapter': 1,
      'currentVerse': 1,
    });

    _groupNameController.clear();
    setState(() => _selectedLeaderId = null);
    if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dodano nową grupę!')));
  }

  // NOWA FUNKCJA: Usuwanie grupy z potwierdzeniem
  Future<void> _deleteGroup(String groupId, String groupName) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Potwierdź usunięcie'),
        content: Text('Czy na pewno chcesz trwale usunąć grupę "$groupName"?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Anuluj')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Usuń', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm && mounted) {
      try {
        await FirebaseFirestore.instance.collection('smallGroups').doc(groupId).delete();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Grupa została usunięta.')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd podczas usuwania: $e')));
      }
    }
  }

  // NOWA FUNKCJA: Zmiana lidera grupy
  Future<void> _changeLeader(String groupId, String currentLeaderId) async {
    // Pobierz listę wszystkich użytkowników, aby przekazać do okna dialogowego
    final usersSnapshot = await FirebaseFirestore.instance.collection('users').orderBy('displayName').get();
    final allUsers = usersSnapshot.docs;
    
    String? newLeaderId = await showDialog<String?>(
      context: context,
      builder: (context) {
        String? dialogSelectedLeaderId = currentLeaderId;
        return AlertDialog(
          title: const Text('Zmień lidera grupy'),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return DropdownButtonFormField<String>(
                value: dialogSelectedLeaderId,
                hint: const Text('Wybierz nowego lidera'),
                items: allUsers.map((doc) {
                  return DropdownMenuItem<String>(
                    value: doc.id,
                    child: Text(doc['displayName'] ?? doc['email']),
                  );
                }).toList(),
                onChanged: (value) => setState(() => dialogSelectedLeaderId = value),
              );
            },
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(null), child: const Text('Anuluj')),
            TextButton(onPressed: () => Navigator.of(context).pop(dialogSelectedLeaderId), child: const Text('Zapisz')),
          ],
        );
      },
    );

    if (newLeaderId != null && newLeaderId != currentLeaderId) {
      try {
        await FirebaseFirestore.instance.collection('smallGroups').doc(groupId).update({
          'leaderId': newLeaderId,
          // Automatycznie dodaj nowego lidera do członków, jeśli go tam nie ma
          'members': FieldValue.arrayUnion([newLeaderId]),
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lider został zmieniony.')));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd podczas zmiany lidera: $e')));
      }
    }
  }
  
  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Zarządzaj Małymi Grupami')),
      body: Column(
        children: [
          // Formularz dodawania grupy
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dodaj nową grupę', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _groupNameController,
                    decoration: const InputDecoration(labelText: 'Nazwa grupy'),
                    validator: (value) => value == null || value.isEmpty ? 'Podaj nazwę' : null,
                  ),
                  const SizedBox(height: 12),
                  // Dropdown do wyboru lidera dla nowej grupy
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance.collection('users').orderBy('displayName').snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      var users = snapshot.data!.docs.map((doc) {
                        return DropdownMenuItem<String>(
                          value: doc.id,
                          child: Text(doc['displayName'] ?? doc['email']),
                        );
                      }).toList();
                      return DropdownButtonFormField<String>(
                        value: _selectedLeaderId,
                        hint: const Text('Wybierz lidera'),
                        items: users,
                        onChanged: (value) => setState(() => _selectedLeaderId = value),
                        validator: (value) => value == null ? 'Wybierz lidera' : null,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    icon: const Icon(Icons.add),
                    label: const Text('Dodaj Grupę'),
                    onPressed: _addGroup,
                    style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(45)),
                  ),
                ],
              ),
            ),
          ),
          const Divider(),
          // ZAKTUALIZOWANA Lista istniejących grup
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('smallGroups').orderBy('groupName').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return Center(child: Text('Wystąpił błąd: ${snapshot.error}'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                return ListView(
                  children: snapshot.data!.docs.map((doc) {
                    final groupData = doc.data() as Map<String, dynamic>;
                    final groupName = groupData['groupName'] ?? 'Brak nazwy';
                    final leaderId = groupData['leaderId'];

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      child: ListTile(
                        title: Text(groupName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: FutureBuilder<DocumentSnapshot>(
                          future: FirebaseFirestore.instance.collection('users').doc(leaderId).get(),
                          builder: (context, leaderSnapshot) {
                            if (!leaderSnapshot.hasData) return const Text('Ładowanie lidera...');
                            return Text('Lider: ${leaderSnapshot.data?['displayName'] ?? 'Brak danych'}');
                          },
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // <<< NOWY PRZYCISK DO ZMIANY LIDERA >>>
                            IconButton(
                              icon: const Icon(Icons.person_search, color: Colors.blueAccent),
                              tooltip: 'Zmień lidera',
                              onPressed: () => _changeLeader(doc.id, leaderId),
                            ),
                            // <<< NOWY PRZYCISK DO USUWANIA GRUPY >>>
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              tooltip: 'Usuń grupę',
                              onPressed: () => _deleteGroup(doc.id, groupName),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}