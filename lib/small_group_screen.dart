import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'add_meeting_screen.dart'; 
import 'manage_group_screen.dart'; 

class SmallGroupScreen extends StatefulWidget {
  const SmallGroupScreen({super.key});

  @override
  State<SmallGroupScreen> createState() => _SmallGroupScreenState();
}

class _SmallGroupScreenState extends State<SmallGroupScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  Future<DocumentSnapshot?> _getUserGroup() async {
    if (_currentUser == null) return null;

    final querySnapshot = await FirebaseFirestore.instance
        .collection('smallGroups')
        .where('members', arrayContains: _currentUser!.uid)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return querySnapshot.docs.first;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Moja Mała Grupa'),
      ),
      body: FutureBuilder<DocumentSnapshot?>(
        future: _getUserGroup(),
        builder: (context, groupSnapshot) {
          if (groupSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!groupSnapshot.hasData || groupSnapshot.data == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('Nie jesteś jeszcze w żadnej grupie.', textAlign: TextAlign.center),
              ),
            );
          }

          final groupDoc = groupSnapshot.data!;
          final groupData = groupDoc.data() as Map<String, dynamic>;
          final bool isLeader = groupData['leaderId'] == _currentUser?.uid;

          return Column(
            children: [
              // Panel Lidera, widoczny tylko dla lidera
              if (isLeader)
                _buildManagementPanel(context, groupDoc.id, List<String>.from(groupData['members'] ?? [])),
              
              // Lista spotkań grupy
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: groupDoc.reference.collection('meetings').orderBy('date', descending: true).snapshots(),
                  builder: (context, meetingsSnapshot) {
                    if (meetingsSnapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!meetingsSnapshot.hasData || meetingsSnapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('Brak wpisów ze spotkań.'));
                    }
                    final meetings = meetingsSnapshot.data!.docs;
                    return ListView.builder(
                      padding: const EdgeInsets.all(8.0),
                      itemCount: meetings.length,
                      itemBuilder: (context, index) {
                        final meetingData = meetings[index].data() as Map<String, dynamic>;
                        final date = (meetingData['date'] as Timestamp).toDate();
                        final formattedDate = DateFormat('dd.MM.yyyy').format(date);
                        return Card(
                          child: ListTile(
                            title: Text(meetingData['progressReference'] ?? 'Brak tematu'),
                            subtitle: Text('Data: $formattedDate'),
                            onTap: () {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: Text(meetingData['progressReference']),
                                  content: SingleChildScrollView(child: Text(meetingData['notes'] ?? 'Brak notatek.')),
                                  actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Zamknij'))],
                                ),
                              );
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildManagementPanel(BuildContext context, String groupId, List<String> members) {
    return Container(
      width: double.infinity,
      color: Theme.of(context).primaryColor.withOpacity(0.1),
      padding: const EdgeInsets.all(12.0),
      child: Column(
        children: [
          Text('Panel Lidera', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.note_add_outlined),
                label: const Text('Dodaj wpis'),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => AddMeetingScreen(groupId: groupId)));
                },
              ),
              ElevatedButton.icon(
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('Zarządzaj'),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => ManageGroupScreen(groupId: groupId, currentMemberIds: members)));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
