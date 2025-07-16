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
  final _formKey = GlobalKey<FormState>();
  final _bookController = TextEditingController();
  final _chapterController = TextEditingController();
  final _verseController = TextEditingController();
  int? _selectedDay;
  TimeOfDay? _selectedTime;
  DateTime? _temporaryDateTime;
  bool _isSaving = false;
  final List<String> _weekdays = ['Poniedziałek', 'Wtorek', 'Środa', 'Czwartek', 'Piątek', 'Sobota', 'Niedziela'];

  static const Color primaryAccent = Color(0xFF00A9FF);
  static const Color lightBlueBackground = Color(0xFFF0F8FF);
  static const Color darkTextColor = Color(0xFF333333);
  static const Color lightTextColor = Color(0xFF666666);

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

  void _showAttendanceDetailsDialog(List<String> absentMembers) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              children: [
                Icon(Icons.people_alt_outlined, color: primaryAccent),
                SizedBox(width: 10),
                Text("Obecność na najbliższym spotkaniu"),
              ],
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: absentMembers.isEmpty
                ? const ListTile(
                    leading: Icon(Icons.check_circle, color: Colors.green),
                    title: Text("Wygląda na to, że wszyscy będą obecni!"),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Osoby, które zgłosiły nieobecność:", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: absentMembers.length,
                          itemBuilder: (context, index) {
                            return FutureBuilder<DocumentSnapshot>(
                              future: FirebaseFirestore.instance.collection('users').doc(absentMembers[index]).get(),
                              builder: (context, userSnapshot) {
                                if (!userSnapshot.hasData) {
                                  return const ListTile(title: Text("Ładowanie..."));
                                }
                                final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
                                return ListTile(
                                  leading: const Icon(Icons.person_off_outlined, color: Colors.redAccent),
                                  title: Text(userData?['displayName'] ?? 'Brak nazwy'),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text("Zamknij", style: TextStyle(color: primaryAccent)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _markAbsence() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    await FirebaseFirestore.instance.collection('smallGroups').doc(widget.groupId).update({
      'absentNextMeeting': FieldValue.arrayUnion([userId])
    });
  }

  Future<void> _cancelAbsence() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;
    await FirebaseFirestore.instance.collection('smallGroups').doc(widget.groupId).update({
      'absentNextMeeting': FieldValue.arrayRemove([userId])
    });
  }

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
        // Konwersja DateTime na Timestamp jest kluczowa dla zapisu
        'temporaryMeetingDateTime': _temporaryDateTime != null ? Timestamp.fromDate(_temporaryDateTime!) : null,
      });
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zmiany zapisane!')));
        // Resetujemy stan po zapisie, aby odświeżył się z nowymi danymi z bazy
        setState(() {
          _selectedDay = null; 
        });
      }
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
        'authorName': user?.displayName ?? 'Prowadzący grupy',
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
  
  DateTime _calculateNextMeetingDate(int weekDay, String time) {
    DateTime now = DateTime.now();
    final timeParts = time.split(':');
    DateTime nextMeetingDate = DateTime(now.year, now.month, now.day, int.parse(timeParts[0]), int.parse(timeParts[1]));
    while (nextMeetingDate.weekday != weekDay || nextMeetingDate.isBefore(now)) {
      nextMeetingDate = nextMeetingDate.add(const Duration(days: 1));
    }
    return nextMeetingDate;
  }
  
  // ✅ POPRAWIONY FORMAT CZASU (24h)
  Future<void> _pickTemporaryDate() async {
    final date = await showDatePicker(context: context, initialDate: _temporaryDateTime ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 90)));
    if (date == null) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_temporaryDateTime ?? DateTime.now()),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (time != null) {
      setState(() => _temporaryDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
    }
  }

  // ✅ POPRAWIONY FORMAT CZASU (24h)
  Future<void> _pickRecurringTime() async {
      final time = await showTimePicker(
        context: context,
        initialTime: _selectedTime ?? TimeOfDay.now(),
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
            child: child!,
          );
        },
      );
      if (time != null) setState(() => _selectedTime = time);
  }
  

  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Moja Mała Grupa'),
        backgroundColor: Colors.white,
        foregroundColor: darkTextColor,
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('smallGroups').doc(widget.groupId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: primaryAccent));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('Nie jesteś przypisany/a do żadnej grupy.', textAlign: TextAlign.center)));
          }

          final groupData = snapshot.data!.data() as Map<String, dynamic>;
          final bool isLeader = groupData['leaderId'] == currentUserId;
          final List<String> absentMembers = List<String>.from(groupData['absentNextMeeting'] ?? []);

          // ✅ POPRAWIONA LOGIKA: Inicjalizuj stan tylko raz, aby nie nadpisywać zmian użytkownika
          if (isLeader && _selectedDay == null) {
            _bookController.text = groupData['currentBook'] ?? '';
            _chapterController.text = (groupData['currentChapter'] ?? 1).toString();
            _verseController.text = (groupData['currentVerse'] ?? 1).toString();
            _selectedDay = groupData['recurringMeetingDay'] as int? ?? 2;
            final timeParts = (groupData['recurringMeetingTime'] as String? ?? '18:00').split(':');
            _selectedTime = TimeOfDay(hour: int.parse(timeParts[0]), minute: int.parse(timeParts[1]));
            _temporaryDateTime = (groupData['temporaryMeetingDateTime'] as Timestamp?)?.toDate();
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupData['groupName'] ?? '',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: darkTextColor,
                    ),
                  ),
                  const SizedBox(height: 30),

                  _buildSectionHeader('Najbliższe spotkanie', Icons.calendar_today_outlined),
                  _buildMeetingInfo(groupData, absentMembers),
                  const SizedBox(height: 12),
                  _buildMyAttendanceSection(absentMembers),
                  
                  if (isLeader) ...[
                    const SizedBox(height: 8),
                    _buildLeaderControlsForMeeting(),
                  ],
                  _buildDivider(),
                  
                  _buildSectionHeader(
                    'Ogłoszenia grupowe', 
                    Icons.campaign_outlined,
                    action: isLeader 
                      ? IconButton(
                          icon: const Icon(Icons.add_circle_outline, color: primaryAccent),
                          tooltip: 'Dodaj ogłoszenie grupowe',
                          onPressed: _showAddAnnouncementDialog,
                        )
                      : null,
                  ),
                  _buildAnnouncementsList(),
                  _buildDivider(),
                  
                  _buildSectionHeader('Materiał do studium', Icons.menu_book_outlined),
                  if (!isLeader) _buildReadOnlyMaterialInfo(groupData),
                  if (isLeader) _buildLeaderMaterialControls(),
                  _buildDivider(),
                  
                  _buildSectionHeader('Członkowie', Icons.groups_outlined),
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
              backgroundColor: primaryAccent,
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  // --- WIDGETY ---

  Widget _buildDivider() => const Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: Divider(color: Colors.black12, height: 1));

  Widget _buildSectionHeader(String title, IconData icon, {Widget? action}) {
    return Padding(padding: const EdgeInsets.only(bottom: 12.0), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Icon(icon, color: darkTextColor, size: 22), const SizedBox(width: 10), Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkTextColor))]), if (action != null) action]));
  }
  
  Widget _buildMeetingInfo(Map<String, dynamic> data, List<String> absentMembers) {
    final temporaryMeeting = (data['temporaryMeetingDateTime'] as Timestamp?)?.toDate();
    final isTemporary = temporaryMeeting != null && temporaryMeeting.isAfter(DateTime.now().subtract(const Duration(hours: 3)));
    final DateTime meetingDate = isTemporary ? temporaryMeeting : _calculateNextMeetingDate(data['recurringMeetingDay'] ?? 2, data['recurringMeetingTime'] ?? '18:00');

    return InkWell(
      onTap: () => _showAttendanceDetailsDialog(absentMembers),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: lightBlueBackground, borderRadius: BorderRadius.circular(12), border: Border.all(color: isTemporary ? Colors.orange.withOpacity(0.5) : Colors.transparent, width: 1.5)),
        child: Row(children: [
          Icon(Icons.access_time_filled, color: isTemporary ? Colors.orange : primaryAccent, size: 30),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(DateFormat('EEEE, d MMMM', 'pl_PL').format(meetingDate), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: darkTextColor)),
            Text('godzina ${DateFormat('HH:mm').format(meetingDate)}', style: const TextStyle(fontSize: 16, color: lightTextColor)),
          ])),
          const Icon(Icons.arrow_forward_ios, size: 16, color: lightTextColor),
        ]),
      ),
    );
  }

  Widget _buildMyAttendanceSection(List<dynamic> absentList) {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return const SizedBox.shrink();
    final bool isAbsent = absentList.contains(userId);
    if (!isAbsent) {
      return Center(child: TextButton.icon(icon: const Icon(Icons.sentiment_very_dissatisfied, size: 20), label: const Text('Nie będzie mnie na spotkaniu'), onPressed: _markAbsence, style: TextButton.styleFrom(foregroundColor: Colors.red.shade600, padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8))));
    } else {
      return Center(child: Container(padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 6.0), decoration: BoxDecoration(color: Colors.red.withOpacity(0.05), borderRadius: BorderRadius.circular(20)), child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.check_circle_outline, color: Colors.red, size: 20), const SizedBox(width: 8), const Text('Zgłoszono nieobecność', style: TextStyle(fontWeight: FontWeight.bold, color: darkTextColor)), const SizedBox(width: 4), TextButton(onPressed: _cancelAbsence, child: const Text('Anuluj', style: TextStyle(color: primaryAccent)))])));
    }
  }

  Widget _buildAnnouncementsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('smallGroups').doc(widget.groupId).collection('announcements').orderBy('createdAt', descending: true).limit(5).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: primaryAccent));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: Text('Brak ogłoszeń grupowych.', style: TextStyle(color: Colors.grey))));
        return ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: snapshot.data!.docs.length, separatorBuilder: (context, index) => const SizedBox(height: 10), itemBuilder: (context, index) {
          final doc = snapshot.data!.docs[index];
          final data = doc.data() as Map<String, dynamic>;
          final date = (data['createdAt'] as Timestamp?)?.toDate();
          return Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(data['content'] ?? '', style: const TextStyle(fontSize: 15, color: darkTextColor, height: 1.4)), const SizedBox(height: 10), Align(alignment: Alignment.bottomRight, child: Text(date != null ? 'Dodano ${DateFormat('d MMM, HH:mm', 'pl_PL').format(date)}' : '', style: const TextStyle(color: lightTextColor, fontSize: 12)))]));
        });
      },
    );
  }

  Widget _buildLeaderControlsForMeeting() {
    return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Panel Prowadzącego: Termin spotkania", style: TextStyle(fontWeight: FontWeight.bold, color: darkTextColor)), const SizedBox(height: 8), const Text("Regularny termin:", style: TextStyle(color: lightTextColor)), Row(children: [Expanded(child: DropdownButton<int>(isExpanded: true, value: _selectedDay, items: _weekdays.asMap().entries.map((e) => DropdownMenuItem(value: e.key + 1, child: Text(e.value))).toList(), onChanged: (val) => setState(() => _selectedDay = val))), const SizedBox(width: 16), ElevatedButton(onPressed: _pickRecurringTime, child: Text(_selectedTime?.format(context) ?? 'Ustaw'))]), const Divider(height: 16), const Text("Jednorazowa zmiana:", style: TextStyle(color: lightTextColor)), const SizedBox(height: 4), Row(children: [ElevatedButton(onPressed: _pickTemporaryDate, child: Text(_temporaryDateTime == null ? 'Ustaw...' : DateFormat('d MMM, HH:mm').format(_temporaryDateTime!))), if (_temporaryDateTime != null) IconButton(icon: const Icon(Icons.clear, color: Colors.red), onPressed: () => setState(() => _temporaryDateTime = null))])]));
  }

  Widget _buildLeaderMaterialControls() {
    return Column(children: [TextFormField(controller: _bookController, decoration: const InputDecoration(labelText: 'Księga / Temat', border: OutlineInputBorder(), isDense: true)), const SizedBox(height: 10), Row(children: [Expanded(child: TextFormField(controller: _chapterController, decoration: const InputDecoration(labelText: 'Rozdział', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number)), const SizedBox(width: 10), Expanded(child: TextFormField(controller: _verseController, decoration: const InputDecoration(labelText: 'Werset', border: OutlineInputBorder(), isDense: true), keyboardType: TextInputType.number))])]);
  }

  Widget _buildReadOnlyMaterialInfo(Map<String, dynamic> data) {
    return Container(padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20), decoration: BoxDecoration(color: lightBlueBackground, borderRadius: BorderRadius.circular(12)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${data['currentBook'] ?? 'Brak'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: darkTextColor)), Text(' ${data['currentChapter'] ?? ''}:${data['currentVerse'] ?? ''}', style: const TextStyle(fontSize: 20, color: primaryAccent, fontWeight: FontWeight.bold))]));
  }

  Widget _buildMembersList(List<String> memberIds, String leaderId) {
    return ListView.builder(
      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
      itemCount: memberIds.length,
      itemBuilder: (context, index) {
        final memberId = memberIds[index];
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance.collection('users').doc(memberId).get(),
          builder: (context, userSnapshot) {
            if (!userSnapshot.hasData) return const SizedBox.shrink(); 
            final userData = userSnapshot.data!.data() as Map<String, dynamic>;
            final bool isLeader = memberId == leaderId;
            final photoUrl = userData['photoURL'] as String?;
            return Container(margin: const EdgeInsets.symmetric(vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.08), blurRadius: 10, offset: const Offset(0, 4))]), child: ListTile(leading: CircleAvatar(backgroundColor: lightBlueBackground, backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null, child: photoUrl == null ? Text((userData['displayName'] ?? 'U')[0].toUpperCase(), style: const TextStyle(fontWeight: FontWeight.bold, color: primaryAccent)) : null), title: Text(userData['displayName'] ?? 'Użytkownik bez nazwy', style: TextStyle(fontWeight: isLeader ? FontWeight.bold : FontWeight.normal, color: darkTextColor)), trailing: isLeader ? Chip(label: const Text('Prowadzący'), backgroundColor: primaryAccent, labelStyle: const TextStyle(color: Colors.white), padding: const EdgeInsets.symmetric(horizontal: 8)) : null));
          },
        );
      },
    );
  }
}