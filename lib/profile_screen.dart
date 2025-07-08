import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'edit_studied_books_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  User? _user;
  Map<String, dynamic>? _userData;
  String? _smallGroupName;
  List<String> _studiedBooks = [];
  bool _isLoading = true;
  
  Map<String, int> _attendanceStats = {
    'smallGroup': 0, 'retreat': 0, 'saturday': 0, 'other': 0,
  };

  final int _totalBibleBooks = 73;

  @override
  void initState() {
    super.initState();
    _loadAllUserData();
  }

  Future<void> _loadAllUserData() async {
    if (!mounted) return;
    // Nie resetujemy stanu na początku, aby uniknąć migotania
    // setState(() => _isLoading = true); 

    _user = _auth.currentUser;
    if (_user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    // --- LINIA DIAGNOSTYCZNA 1 ---
    print("PROFIL: Sprawdzam dane dla użytkownika o UID: ${_user!.uid}");

    try {
      // Pobieranie danych użytkownika (role, książki etc.)
      final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
      if (userDoc.exists) {
        // --- LINIA DIAGNOSTYCZNA 2 ---
        print("PROFIL: Znaleziono dokument użytkownika. Dane: ${userDoc.data()}");
        _userData = userDoc.data();
        _studiedBooks = List<String>.from(userDoc.data()?['studiedBooks'] ?? []);
      } else {
        print("PROFIL: BŁĄD - Nie znaleziono dokumentu dla użytkownika o UID: ${_user!.uid}");
      }

      // Pobieranie danych o małej grupie
      final groupQuery = await _firestore.collection('smallGroups').where('members', arrayContains: _user!.uid).limit(1).get();
      if (groupQuery.docs.isNotEmpty) {
        final groupData = groupQuery.docs.first.data();
        // --- LINIA DIAGNOSTYCZNA 3 ---
        print("PROFIL: Znaleziono małą grupę. Dane grupy: $groupData");
        _smallGroupName = groupData['groupName'];
      } else {
         print("PROFIL: INFO - Nie znaleziono małej grupy dla tego użytkownika.");
      }

      // Pobieranie statystyk (zostawiamy bez zmian)
      _attendanceStats = await _fetchAttendanceStats();

    } catch (e) {
      print("PROFIL: KRYTYCZNY BŁĄD podczas pobierania danych: $e");
    } finally {
      // Wywołujemy setState tylko raz, na samym końcu, gdy wszystkie dane są gotowe
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Ta funkcja pozostaje bez zmian
  Future<Map<String, int>> _fetchAttendanceStats() async {
    if (_user == null) return {};
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    int retreatCount = 0, saturdayCount = 0, otherCount = 0;
    final eventsQuery = await _firestore.collection('events').where('attendees.${_user!.uid}', isEqualTo: true).where('eventDate', isGreaterThanOrEqualTo: startOfYear).get();
    for (var doc in eventsQuery.docs) {
      final data = doc.data();
      switch (data['type']) {
        case 'retreat': retreatCount++; break;
        case 'saturday': saturdayCount++; break;
        default: otherCount++; break;
      }
    }
    final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
    int smallGroupCount = 0;
    if (userDoc.exists) {
      smallGroupCount = userDoc.data()?['smallGroupAttendanceCount_${now.year}'] ?? 0;
    }
    return { 'smallGroup': smallGroupCount, 'retreat': retreatCount, 'saturday': saturdayCount, 'other': otherCount };
  }

  // Pozostałe funkcje (bez zmian)
  void _logout() async { await _auth.signOut(); }
  void _navigateToEditBooks() async {
    final result = await Navigator.push<bool>(context, MaterialPageRoute(builder: (context) => EditStudiedBooksScreen(initialStudiedBooks: _studiedBooks)));
    if (result == true && mounted) { _loadAllUserData(); }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mój Profil'), actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)]),
      body: _isLoading
          ? _buildShimmerLoading()
          : _user == null
              ? const Center(child: Text('Nie jesteś zalogowany.'))
              : RefreshIndicator(
                  onRefresh: _loadAllUserData,
                  child: ListView(
                    padding: const EdgeInsets.all(16.0),
                    children: [
                      _buildProfileHeader(),
                      const SizedBox(height: 24),
                      _buildInfoCard(),
                      const SizedBox(height: 24),
                      _buildAttendanceStatsCard(),
                      const SizedBox(height: 24),
                      _buildPersonalStatsCard(),
                    ],
                  ),
                ),
    );
  }
  
  // Widgety (buildAttendanceStatsCard, buildStatItem, etc.) pozostają bez zmian
  // ... (Wklej tutaj swoje istniejące widgety build... bez zmian)
  Widget _buildAttendanceStatsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Frekwencja w tym roku', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Mała Grupa', _attendanceStats['smallGroup'] ?? 0, Icons.groups_2_outlined),
                  const VerticalDivider(),
                  _buildStatItem('Wyjazdy', _attendanceStats['retreat'] ?? 0, Icons.directions_car_outlined),
                  const VerticalDivider(),
                  _buildStatItem('Spot. Sobotnie', _attendanceStats['saturday'] ?? 0, Icons.event_available_outlined),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatItem(String label, int count, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFF00B0FF), size: 28),
          const SizedBox(height: 8),
          Text(count.toString(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
  
  Widget _buildProfileHeader() {
    final photoUrl = _user?.photoURL; final displayName = _userData?['displayName'] ?? _user?.email ?? 'Użytkownik'; final email = _user?.email ?? 'Brak adresu e-mail';
    return Center(
      child: Column(
        children: [
          CircleAvatar(
            radius: 50, backgroundColor: Theme.of(context).primaryColorLight,
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null ? Text(displayName.substring(0, 1).toUpperCase(), style: const TextStyle(fontSize: 40, color: Colors.white)) : null,
          ),
          const SizedBox(height: 12),
          Text(displayName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
          Text(email, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
        ],
      ),
    );
  }
  Widget _buildInfoRow(IconData icon, String label, String value) {
    const Color iconColor = Color(0xFF00B0FF); 
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24), const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
              const SizedBox(height: 4),
              Text(value, style: TextStyle(color: Colors.grey.shade700, fontSize: 16)),
            ],
          ),
        ),
      ],
    );
  }
  Widget _buildPersonalStatsCard() {
    double progress = _totalBibleBooks > 0 ? _studiedBooks.length / _totalBibleBooks : 0.0;
    return Card(
      elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text('Postępy w studium', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              IconButton(icon: const Icon(Icons.edit_note, color: Color(0xFF00B0FF)), tooltip: 'Edytuj przestudiowane księgi', onPressed: _navigateToEditBooks),
            ]),
            const SizedBox(height: 16),
            Text('Przestudiowane księgi: ${_studiedBooks.length} z $_totalBibleBooks'),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(value: progress, minHeight: 12, backgroundColor: Colors.grey[300], valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00B0FF))),
            ),
            const SizedBox(height: 4),
            Align(alignment: Alignment.centerRight, child: Text('${(progress * 100).toStringAsFixed(1)}%', style: Theme.of(context).textTheme.bodySmall)),
            const Divider(height: 24),
            Text('Przerobione księgi:', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _studiedBooks.isEmpty ? const Text('Nie zaznaczono żadnych ksiąg.', style: TextStyle(color: Colors.grey)) : Wrap(
              spacing: 8.0, runSpacing: 4.0,
              children: _studiedBooks.map((book) => Chip(label: Text(book), backgroundColor: const Color(0xFF00B0FF).withOpacity(0.15), side: BorderSide.none)).toList(),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildInfoCard() {
    final roles = _userData?['roles'] as List<dynamic>? ?? [];
    return Card(
      elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(Icons.groups_outlined, 'Mała Grupa', _smallGroupName ?? 'Brak przypisanej grupy'),
            const Divider(height: 24),
            _buildInfoRow(Icons.volunteer_activism_outlined, 'Moje Służby', roles.isNotEmpty ? roles.join(', ') : 'Brak przypisanych służb'),
          ],
        ),
      ),
    );
  }
  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Center(child: Column(children: [
          Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: const CircleAvatar(radius: 50)), const SizedBox(height: 12),
          Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: Container(width: 200, height: 24, color: Colors.white)), const SizedBox(height: 8),
          Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: Container(width: 250, height: 20, color: Colors.white)),
        ])), const SizedBox(height: 24),
        Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: Card(child: Container(height: 150, color: Colors.white))), const SizedBox(height: 24),
        Shimmer.fromColors(baseColor: Colors.grey[300]!, highlightColor: Colors.grey[100]!, child: Card(child: Container(height: 200, color: Colors.white))),
      ],
    );
  }
}