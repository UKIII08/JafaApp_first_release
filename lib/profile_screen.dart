import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shimmer/shimmer.dart';
import 'edit_profile_screen.dart'; // <<< DODANY IMPORT

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
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllUserData();
  }

  Future<void> _loadAllUserData() async {
    if (!mounted) return;
    
    // Ustawienie isLoading na true na początku, aby pokazać shimmer przy odświeżaniu
    setState(() => _isLoading = true);

    _user = _auth.currentUser;
    if (_user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      // Pobieranie danych użytkownika (role etc.)
      final userDoc = await _firestore.collection('users').doc(_user!.uid).get();
      if (userDoc.exists) {
        _userData = userDoc.data();
      }

      // Pobieranie danych o małej grupie
      final groupQuery = await _firestore
          .collection('smallGroups')
          .where('members', arrayContains: _user!.uid)
          .limit(1)
          .get();
      if (groupQuery.docs.isNotEmpty) {
        final groupData = groupQuery.docs.first.data();
        _smallGroupName = groupData['groupName'];
      }
    } catch (e) {
      print("PROFIL: KRYTYCZNY BŁĄD podczas pobierania danych: $e");
      // Opcjonalnie: pokaż snackbar z błędem
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _logout() async {
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mój Profil'),
        actions: [IconButton(icon: const Icon(Icons.logout), onPressed: _logout)],
      ),
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
                    ],
                  ),
                ),
    );
  }

  // <<< ZAKTUALIZOWANA SEKCJA NAGŁÓWKA PROFILU >>>
  Widget _buildProfileHeader() {
    final photoUrl = _user?.photoURL;
    final displayName = _userData?['displayName'] ?? _user?.email ?? 'Użytkownik';
    final email = _user?.email ?? 'Brak adresu e-mail';

    return Stack(
      alignment: Alignment.topRight,
      children: [
        Center(
          child: Column(
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: Theme.of(context).primaryColorLight,
                backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                child: photoUrl == null
                    ? Text(displayName.substring(0, 1).toUpperCase(),
                        style: const TextStyle(fontSize: 40, color: Colors.white))
                    : null,
              ),
              const SizedBox(height: 12),
              Text(displayName, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
              Text(email, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
            ],
          ),
        ),
        // Przycisk edycji profilu
        IconButton(
          icon: const Icon(Icons.edit, color: Colors.black54),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EditProfileScreen()),
            ).then((_) {
              // Po powrocie z ekranu edycji, odśwież dane
              _loadAllUserData();
            });
          },
        ),
      ],
    );
  }
  
  Widget _buildInfoCard() {
    final roles = _userData?['roles'] as List<dynamic>? ?? [];
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    const Color iconColor = Color(0xFF00B0FF);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: iconColor, size: 24),
        const SizedBox(width: 16),
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

  Widget _buildShimmerLoading() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Center(
          child: Column(
            children: [
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: const CircleAvatar(radius: 50),
              ),
              const SizedBox(height: 12),
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(width: 200, height: 24, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(width: 250, height: 20, color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Card(child: Container(height: 120, color: Colors.white)),
        ),
      ],
    );
  }
}