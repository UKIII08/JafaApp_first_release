// admin_users_screen.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {

 // --- Funkcje zarządzania rolami użytkowników (bezpośrednia modyfikacja Firestore) ---
 // Te funkcje działają teraz niezależnie w tym ekranie

 Future<void> _addRoleToUser(String userId, String role) async {
   final trimmedRole = role.trim();
   if (trimmedRole.isEmpty) {
     if(mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Nazwa roli nie może być pusta.'), backgroundColor: Colors.redAccent),
       );
     }
     return;
   }
   try {
     await FirebaseFirestore.instance.collection('users').doc(userId).update({
       'roles': FieldValue.arrayUnion([trimmedRole]),
     });
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Rola "$trimmedRole" dodana.'), backgroundColor: Colors.green),
       );
       // Nie wywołujemy już _fetchUniqueRolesAndBuildTopics() tutaj
     }
   } catch (e) {
     print('Błąd dodawania roli: $e');
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Błąd dodawania roli: $e'), backgroundColor: Colors.redAccent),
       );
     }
   }
 }

 Future<void> _removeRoleFromUser(String userId, String role) async {
   // Opcjonalnie: logika blokady usuwania pewnych ról
   // if (role == 'admin') { ... return; }
   try {
     await FirebaseFirestore.instance.collection('users').doc(userId).update({
       'roles': FieldValue.arrayRemove([role]),
     });
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Rola "$role" usunięta.'), backgroundColor: Colors.orange),
       );
       // Nie wywołujemy już _fetchUniqueRolesAndBuildTopics() tutaj
     }
   } catch (e) {
     print('Błąd usuwania roli: $e');
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Błąd usuwania roli: $e'), backgroundColor: Colors.redAccent),
       );
     }
   }
 }

 // --- Dialogi do zarządzania rolami ---
 // Te dialogi działają teraz niezależnie w tym ekranie

 Future<void> _showAddRoleDialog(BuildContext context, String userId, List<String> currentRoles) async {
   final roleToAddController = TextEditingController();
   return showDialog(
     context: context,
     builder: (dialogContext) { // Użyj innej nazwy contextu dla dialogu
       return AlertDialog(
         title: const Text('Dodaj Rolę'),
         content: TextField(
           controller: roleToAddController,
           decoration: const InputDecoration(labelText: 'Nazwa roli'),
           autofocus: true,
         ),
         actions: [
           TextButton(
             child: const Text('Anuluj'),
             onPressed: () => Navigator.of(dialogContext).pop(),
           ),
           TextButton(
             child: const Text('Dodaj'),
             onPressed: () {
               final roleToAdd = roleToAddController.text.trim();
               Navigator.of(dialogContext).pop(); // Zamknij dialog przed pokazaniem SnackBar
               if (roleToAdd.isNotEmpty) {
                 if (currentRoles.contains(roleToAdd)) {
                   if (mounted) { // Sprawdź mounted dla głównego contextu
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('Użytkownik już posiada rolę "$roleToAdd".')),
                     );
                   }
                 } else {
                   _addRoleToUser(userId, roleToAdd);
                 }
               } else if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text('Nazwa roli nie może być pusta.')),
                   );
               }
             },
           ),
         ],
       );
     },
   );
 }

 Future<void> _showRemoveRoleDialog(BuildContext context, String userId, List<String> currentRoles) async {
   if (currentRoles.isEmpty) {
     if(mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Użytkownik nie posiada ról do usunięcia.')),
       );
     }
     return;
   }

   String? selectedRoleToRemove;
   final List<String> removableRoles = List.from(currentRoles);
   // Opcjonalnie: filtracja ról niemożliwych do usunięcia
   // removableRoles.removeWhere((role) => role == 'admin');
   if (removableRoles.isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Brak ról możliwych do usunięcia.')),
        );
        return;
   }

   return showDialog(
     context: context,
     builder: (dialogContext) {
       return StatefulBuilder( // Potrzebne do aktualizacji stanu dropdowna w dialogu
         builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Usuń Rolę'),
              content: DropdownButtonFormField<String>(
                value: selectedRoleToRemove,
                items: removableRoles.map((role) => DropdownMenuItem(value: role, child: Text(role))).toList(),
                onChanged: (String? newValue) => setDialogState(() => selectedRoleToRemove = newValue),
                decoration: const InputDecoration(labelText: 'Wybierz rolę do usunięcia'),
                 validator: (value) => value == null ? 'Wybierz rolę' : null,
                 autovalidateMode: AutovalidateMode.onUserInteraction,
              ),
              actions: [
                TextButton(
                  child: const Text('Anuluj'),
                  onPressed: () => Navigator.of(dialogContext).pop(),
                ),
                TextButton(
                  onPressed: selectedRoleToRemove == null ? null : () {
                      Navigator.of(dialogContext).pop(); // Zamknij dialog przed akcją
                      _removeRoleFromUser(userId, selectedRoleToRemove!);
                  },
                  child: const Text('Usuń'),
                ),
              ],
            );
         }
       );
     },
   );
 }


 @override
 Widget build(BuildContext context) {
   return Scaffold(
     appBar: AppBar(
       title: const Text('Zarządzanie Użytkownikami'),
     ),
     // Używamy ListView bezpośrednio jako body, bo to główna zawartość tego ekranu
     body: StreamBuilder<QuerySnapshot>(
       stream: FirebaseFirestore.instance.collection('users').orderBy('email').snapshots(),
       builder: (context, snapshot) {
         if (snapshot.hasError) {
           return Center(child: Text('Błąd ładowania użytkowników: ${snapshot.error}'));
         }
         if (snapshot.connectionState == ConnectionState.waiting) {
           return const Center(child: CircularProgressIndicator());
         }
         if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
           return const Center(child: Text('Brak zarejestrowanych użytkowników.'));
         }

         // Budujemy listę użytkowników
         return ListView.builder(
           padding: const EdgeInsets.all(8.0), // Dodaj padding do listy
           itemCount: snapshot.data!.docs.length,
           itemBuilder: (context, index) {
             final userDoc = snapshot.data!.docs[index];
             final userData = userDoc.data() as Map<String, dynamic>?;

             if (userData == null) return const SizedBox.shrink(); // Pomiń, jeśli brak danych

             final userId = userDoc.id;
             // Preferuj displayName, potem email
             final displayName = userData['displayName']?.toString().isNotEmpty == true
                 ? userData['displayName']!.toString()
                 : userData['email']?.toString() ?? 'Użytkownik bez nazwy';
             final roles = List<String>.from(userData['roles'] as List<dynamic>? ?? []);
             roles.sort(); // Sortuj role alfabetycznie

             return Card(
               margin: const EdgeInsets.symmetric(vertical: 5, horizontal: 8),
               elevation: 3,
               child: ListTile(
                 leading: CircleAvatar(
                   child: Text(displayName.isNotEmpty ? displayName[0].toUpperCase() : '?'),
                   // Można dodać kolor tła na podstawie ID użytkownika dla rozróżnienia
                   // backgroundColor: Colors.primaries[userId.hashCode % Colors.primaries.length].shade100,
                 ),
                 title: Text(displayName),
                 subtitle: Text('Role: ${roles.isEmpty ? "Brak" : roles.join(', ')}', style: const TextStyle(fontSize: 12)),
                 trailing: Row(
                   mainAxisSize: MainAxisSize.min,
                   children: [
                     // Przycisk Dodaj Rolę
                     IconButton(
                       icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                       tooltip: 'Dodaj Rolę',
                       onPressed: () => _showAddRoleDialog(context, userId, roles),
                     ),
                     // Przycisk Usuń Rolę
                     IconButton(
                       icon: const Icon(Icons.remove_circle_outline, color: Colors.orange),
                       tooltip: 'Usuń Rolę',
                       // Wyłącz, jeśli nie ma ról do usunięcia (uwzględniając ewentualne filtrowanie)
                       onPressed: roles.isEmpty ? null : () => _showRemoveRoleDialog(context, userId, roles),
                     ),
                   ],
                 ),
                 // Opcjonalnie: onTap dla przyszłych akcji
                 // onTap: () { /* np. pokaż szczegóły użytkownika */ },
               ),
             );
           },
         );
       },
     ),
   );
 }
}