// lib/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importy ekranów
import 'edit_profile_screen.dart';
import 'birthday_wall_screen.dart'; 

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? _currentUser = FirebaseAuth.instance.currentUser;

  String _calculateAge(Timestamp? birthDate) {
    if (birthDate == null) return 'wiek nieznany';
    final birthDateTime = birthDate.toDate();
    final today = DateTime.now();
    int age = today.year - birthDateTime.year;
    if (today.month < birthDateTime.month ||
        (today.month == birthDateTime.month && today.day < birthDateTime.day)) {
      age--;
    }
    return '$age lat';
  }
  
  // NOWA FUNKCJA: Sprawdza, czy dzisiaj są urodziny użytkownika
  bool _isBirthdayToday(Timestamp? birthDate) {
    if (birthDate == null) return false;
    final now = DateTime.now();
    final birthday = birthDate.toDate();
    return now.month == birthday.month && now.day == birthday.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Moje konto'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Colors.black87,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'edit') {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const EditProfileScreen()),
                );
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'edit',
                child: Text('Edytuj profil'),
              ),
            ],
          ),
        ],
      ),
      body: _currentUser == null
          ? const Center(child: Text('Musisz być zalogowany.'))
          : StreamBuilder<DocumentSnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(_currentUser!.uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final displayName = _currentUser!.displayName ?? 'Brak nazwy';
                final photoURL = userData['photoURL'] ?? _currentUser!.photoURL;
                final birthDate = userData['birthDate'] as Timestamp?;

                // Sprawdzamy, czy dzisiaj są urodziny
                final bool isBirthday = _isBirthdayToday(birthDate);

                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundImage: photoURL != null ? NetworkImage(photoURL) : null,
                          child: photoURL == null
                              ? const Icon(Icons.person, size: 40, color: Colors.grey)
                              : null,
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(displayName, style: theme.textTheme.headlineSmall),
                            Text(_calculateAge(birthDate), style: theme.textTheme.titleMedium?.copyWith(color: Colors.grey.shade600)),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 32),
                    
                    // KONDYCYJNY PRZYCISK: Pokazuje się tylko w dniu urodzin
                    if (isBirthday)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.cake_rounded),
                          label: const Text('Zobacz swoją tablicę życzeń!'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.pink[300],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BirthdayWallScreen(
                                  birthdayUserId: _currentUser!.uid,
                                ),
                              ),
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
}
