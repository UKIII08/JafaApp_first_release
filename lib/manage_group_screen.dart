import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManageGroupScreen extends StatefulWidget {
  final String groupId;
  final List<String> currentMemberIds;

  const ManageGroupScreen({
    super.key,
    required this.groupId,
    required this.currentMemberIds,
  });

  @override
  State<ManageGroupScreen> createState() => _ManageGroupScreenState();
}

class _ManageGroupScreenState extends State<ManageGroupScreen> {
  // Funkcja usuwająca członka
  Future<void> _removeMember(String memberId) async {
    await FirebaseFirestore.instance.collection('smallGroups').doc(widget.groupId).update({
      'members': FieldValue.arrayRemove([memberId]),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Zarządzaj Grupą'),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Nawigacja do ekranu dodawania członków
        },
        child: const Icon(Icons.person_add_alt_1),
        tooltip: 'Dodaj członka',
      ),
      body: StreamBuilder<QuerySnapshot>(
        // Pobieramy dane tylko tych użytkowników, którzy są w grupie
        stream: FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: widget.currentMemberIds.isNotEmpty ? widget.currentMemberIds : ['_']) // 'whereIn' nie może być puste
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final members = snapshot.data!.docs;

          return ListView.builder(
            itemCount: members.length,
            itemBuilder: (context, index) {
              final memberData = members[index].data() as Map<String, dynamic>;
              final memberId = members[index].id;
              
              return ListTile(
                title: Text(memberData['displayName'] ?? 'Brak nazwy'),
                subtitle: Text(memberData['email'] ?? ''),
                trailing: IconButton(
                  icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                  onPressed: () => _removeMember(memberId),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
