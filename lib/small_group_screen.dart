import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

class SmallGroupScreen extends StatefulWidget {
  final String groupId;

  const SmallGroupScreen({super.key, required this.groupId});

  @override
  State<SmallGroupScreen> createState() => _SmallGroupScreenState();
}

class _SmallGroupScreenState extends State<SmallGroupScreen> {
  // Kontrolery do edycji (dla lidera)
  final _formKey = GlobalKey<FormState>();
  final _bookController = TextEditingController();
  final _chapterController = TextEditingController();
  final _verseController = TextEditingController();

  // Zmienne stanu do zarządzania terminami
  int? _selectedDay;
  TimeOfDay? _selectedTime;
  DateTime? _temporaryDateTime;

  bool _isSaving = false;

  final List<String> _weekdays = ['Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota', 'Niedziela'];

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('pl_PL');
  }

  @override
  void dispose() {
    _bookController.dispose();
    _chapterController.dispose();
    _verseController.dispose();
    super.dispose();
  }

  // --- Funkcje Lidera ---

  Future<void> _saveChanges(BuildContext context) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      await FirebaseFirestore.instance.collection('smallGroups').doc(widget.groupId).update({
        'currentBook': _bookController.text.trim(),
        'currentChapter': int.tryParse(_chapterController.text.trim()) ?? 1,
        'currentVerse': int.tryParse(_verseController.text.trim()) ?? 1,
        'recurringMeetingDay': _selectedDay,
        'recurringMeetingTime': _selectedTime != null ? '${_selectedTime!.hour.toString().padLeft(2,'0')}:${_selectedTime!.minute.toString().padLeft(2,'0')}' : "18:00",
        'temporaryMeetingDateTime': _temporaryDateTime,
      });
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zmiany zapisane!')));
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Błąd zapisu: $e')));
    } finally {
      if(mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _addAnnouncement(String content) async {
    if (content.trim().isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance
      .collection('smallGroups')
      .doc(widget.groupId)
      .collection('announcements')
      .add({
        'content': content.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'authorId': user?.uid,
        'authorName': user?.displayName ?? 'Lider grupy',
      });
  }

  void _showAddAnnouncementDialog() {
    final announcementController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text('Nowe ogłoszenie grupowe'),
          content: TextField(
            controller: announcementController,
            decoration: const InputDecoration(labelText: 'Treść ogłoszenia', border: OutlineInputBorder()),
            autofocus: true,
            maxLines: 4,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Anuluj')),
            ElevatedButton(
              onPressed: () {
                _addAnnouncement(announcementController.text);
                Navigator.of(context).pop();
              },
              child: const Text('Opublikuj'),
            ),
          ],
        );
      },
    );
  }

  // --- Pozostałe funkcje pomocnicze ---

  DateTime _calculateNextMeetingDate(int weekDay, String time) {
    DateTime now = DateTime.now();
    final timeParts = time.split(':');
    DateTime nextMeetingDate = DateTime(now.year, now.month, now.day, int.parse(timeParts[0]), int.parse(timeParts[1]));
    while (nextMeetingDate.weekday != weekDay || nextMeetingDate.isBefore(now)) {
      nextMeetingDate = nextMeetingDate.add(const Duration(days: 1));
    }
    return nextMeetingDate;
  }
  
  Future<void> _pickTemporaryDate() async {
    final date = await showDatePicker(context: context, initialDate: _temporaryDateTime ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
    if (date == null) return;
    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_temporaryDateTime ?? DateTime.now()));
    if (time != null) {
      setState(() => _temporaryDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }
  }

  Future<void> _pickRecurringTime() async {
      final time = await showTimePicker(context: context, initialTime: _selectedTime ?? TimeOfDay.now());
      if (time != null) setState(() => _selectedTime = time);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moja Mała Grupa'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('smallGroups').doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Nie jesteś przypisany/a do żadnej grupy.', textAlign: TextAlign.center)));
          }

          final groupData = snapshot.data!.data() as Map<String, dynamic>;
          final bool isLeader = groupData['leaderId'] == currentUserId;

          if (isLeader) {
            _bookController.text = groupData['currentBook'] ?? '';
            _chapterController.text = (groupData['currentChapter'] ?? 1).toString();
            _verseController.text = (groupData['currentVerse'] ?? 1).toString();
            _selectedDay = groupData['recurringMeetingDay'] as int? ?? 2;
            final timeParts = (groupData['recurringMeetingTime'] as String? ?? '18:00').split(':');
            _selectedTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
            _temporaryDateTime = (groupData['temporaryMeetingDateTime'] as Timestamp?)?.toDate();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(child: Text(groupData['groupName'] ?? '', style: Theme.of(context).textTheme.headlineMedium)),
                  const SizedBox(height: 24),

                  _buildSectionHeader('Najbliższe spotkanie', Icons.calendar_today),
                  _buildMeetingInfo(groupData),
                  if (isLeader) ...[
                    const SizedBox(height: 8),
                    _buildLeaderControlsForMeeting(),
                  ],
                  const Divider(height: 32),
                  
                  // ZMIANA: Przycisk dodawania jest teraz w nagłówku sekcji, widoczny tylko dla lidera
                  _buildSectionHeader(
                    'Ogłoszenia grupowe', 
                    Icons.campaign_outlined,
                    action: isLeader 
                      ? IconButton(
                          icon: const Icon(Icons.add_comment_outlined),
                          tooltip: 'Dodaj ogłoszenie grupowe',
                          onPressed: _showAddAnnouncementDialog,
                        )
                      : null,
                  ),
                  _buildAnnouncementsList(),
                  const Divider(height: 32),
                  
                  _buildSectionHeader('Materiał do studium', Icons.menu_book),
                  if (!isLeader) _buildReadOnlyMaterialInfo(groupData),
                  if (isLeader) ...[
                    TextFormField(controller: _bookController, decoration: const InputDecoration(labelText: 'Księga / Temat')),
                    Row(children: [
                      Expanded(child: TextFormField(controller: _chapterController, decoration: const InputDecoration(labelText: 'Rozdział'), keyboardType: TextInputType.number)),
                      const SizedBox(width: 16),
                      Expanded(child: TextFormField(controller: _verseController, decoration: const InputDecoration(labelText: 'Werset'), keyboardType: TextInputType.number)),
                    ]),
                  ],
                  const Divider(height: 32),
                  
                  _buildSectionHeader('Członkowie', Icons.group),
                  _buildMembersList(List<String>.from(groupData['members'] ?? []), groupData['leaderId']),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('smallGroups').doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData || !(snapshot.data!.data() as Map).containsKey('leaderId')) {
            return const SizedBox.shrink();
          }
          if ((snapshot.data!.data() as Map)['leaderId'] == currentUserId) {
            return FloatingActionButton.extended(
              onPressed: _isSaving ? null : () => _saveChanges(context),
              label: Text(_isSaving ? 'Zapisywanie...' : 'Zapisz zmiany'),
              icon: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Icon(Icons.save),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // --- WIDGETY POMOCNICZE ---

  Widget _buildAnnouncementsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('smallGroups')
          .doc(widget.groupId)
          .collection('announcements')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text('Brak ogłoszeń grupowych.', style: TextStyle(color: Colors.grey)),
          ));
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['createdAt'] as Timestamp?)?.toDate();

            return Card(
              elevation: 1,
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['content'] ?? ''),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        date != null ? DateFormat('d MMM yy, HH:mm', 'pl_PL').format(date) : '',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ZMIANA: Nagłówek sekcji akceptuje teraz opcjonalny przycisk "action"
  Widget _buildSectionHeader(String title, IconData icon, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
            ],
          ),
          if (action != null) action, // Dodaj przycisk, jeśli został przekazany
        ],
      ),
    );
  }

  Widget _buildMeetingInfo(Map<String, dynamic> data) {
    final temporaryMeeting = (data['temporaryMeetingDateTime'] as Timestamp?)?.toDate();
    final isTemporary = temporaryMeeting != null;
    
    final DateTime meetingDate = isTemporary 
      ? temporaryMeeting
      : _calculateNextMeetingDate(data['recurringMeetingDay'] ?? 2, data['recurringMeetingTime'] ?? '18:00');

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: isTemporary ? Colors.red : Colors.transparent, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        title: Text(
          DateFormat('EEEE, d MMMM, HH:mm', 'pl_PL').format(meetingDate),
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: isTemporary ? Colors.red.shade700 : null),
        ),
        subtitle: Text(isTemporary ? 'Termin jednorazowy (zastępuje regularny)' : 'Regularne spotkanie'),
      ),
    );
  }
  
  Widget _buildReadOnlyMaterialInfo(Map<String, dynamic> data) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(
          '${data['currentBook'] ?? 'Brak'} ${data['currentChapter'] ?? ''}:${data['currentVerse'] ?? ''}',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildLeaderControlsForMeeting() {
    return Card(
      elevation: 0,
      color: Colors.blue.withOpacity(0.05),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Edytuj regularny termin:", style: Theme.of(context).textTheme.titleSmall),
            Row(children: [
              Expanded(
                flex: 3,
                child: DropdownButton<int>(
                  isExpanded: true,
                  value: _selectedDay,
                  items: _weekdays.asMap().entries.map((e) => DropdownMenuItem(value: e.key + 1, child: Text(e.value))).toList(),
                  onChanged: (val) => setState(() => _selectedDay = val),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                flex: 2,
                child: ActionChip(
                  avatar: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(_selectedTime?.format(context) ?? 'Ustaw'),
                  onPressed: _pickRecurringTime,
                ),
              ),
            ]),
            const Divider(),
            Text("Ustaw termin jednorazowy:", style: Theme.of(context).textTheme.titleSmall),
            Row(children: [
              ActionChip(
                avatar: Icon(Icons.add, size: 16, color: Colors.red.shade700),
                label: Text(_temporaryDateTime == null ? 'Ustaw...' : DateFormat('d MMM, HH:mm').format(_temporaryDateTime!)),
                onPressed: _pickTemporaryDate,
                backgroundColor: Colors.red.withOpacity(0.1),
              ),
              if (_temporaryDateTime != null)
                IconButton(icon: Icon(Icons.clear, color: Colors.red.shade700), tooltip: "Anuluj termin jednorazowy", onPressed: () => setState(() => _temporaryDateTime = null)),
            ]),
          ],
        ),
      ),
    );
  }
  
  Widget _buildMembersList(List<String> memberIds, String leaderId) {
     return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: memberIds.length,
      itemBuilder: (context, index) {
        final memberId = memberIds[index];
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return const LinearProgressIndicator();
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final bool isLeader = memberId == leaderId;
            return Card(
              elevation: 1,
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isLeader ? Theme.of(context).primaryColorLight : Colors.grey.shade300,
                  child: Text((userData['displayName'] ?? 'U')[0].toUpperCase()),
                ),
                title: Text(userData['displayName'] ?? 'Użytkownik bez nazwy', style: TextStyle(fontWeight: isLeader ? FontWeight.bold : FontWeight.normal)),
                trailing: isLeader ? const Chip(label: Text('Prowadzący'), padding: EdgeInsets.symmetric(horizontal: 4, vertical: 0)) : null,
              ),
            );
          },
        );
      },
    );
  }
}