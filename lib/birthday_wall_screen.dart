import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:simple_animations/simple_animations.dart';

class BirthdayWallScreen extends StatefulWidget {
  final String birthdayUserId;
  const BirthdayWallScreen({super.key, required this.birthdayUserId});

  @override
  State<BirthdayWallScreen> createState() => _BirthdayWallScreenState();
}

class _BirthdayWallScreenState extends State<BirthdayWallScreen> {
  final _wishController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;

  final Map<String, Map<String, dynamic>> _usersDataCache = {};

  Future<void> _sendWish() async {
    if (_wishController.text.trim().isEmpty || _currentUser == null) return;

    final wisherName = _currentUser!.displayName ?? 'Anonim';
    final wisherPhoto = _currentUser!.photoURL;

    await FirebaseFirestore.instance
        .collection('birthdayWishes')
        .doc(widget.birthdayUserId)
        .collection('wishes')
        .add({
      'message': _wishController.text.trim(),
      'wisherId': _currentUser!.uid,
      'wisherName': wisherName,
      'wisherPhotoURL': wisherPhoto,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _wishController.clear();
    FocusScope.of(context).unfocus();
  }

  Future<void> _fetchWisherData(List<DocumentSnapshot> wishDocs) async {
    final Set<String> userIdsToFetch = {};
    for (var doc in wishDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['wisherId'];
      if (userId != null && !_usersDataCache.containsKey(userId)) {
        userIdsToFetch.add(userId);
      }
    }

    if (userIdsToFetch.isEmpty) return;

    final usersSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .where(FieldPath.documentId, whereIn: userIdsToFetch.toList())
        .get();

    for (var userDoc in usersSnapshot.docs) {
      final data = userDoc.data();
      _usersDataCache[userDoc.id] = {
        'displayName': data['displayName'] ?? 'Anonim',
        'photoURL': data['photoURL'],
      };
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tablica życzeń'),
        backgroundColor: Colors.white, // Zmiana tła AppBar
        foregroundColor: Colors.black, // Zmiana koloru tekstu i ikon AppBar
        elevation: 0,
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: AnimatedBackground()), // Tło zostaje
          StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('birthdayWishes')
                .doc(widget.birthdayUserId)
                .collection('wishes')
                .orderBy('timestamp', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Text(
                    'Bądź pierwszy i złóż życzenia!',
                    style: TextStyle(color: Colors.black54, fontSize: 18),
                  ),
                );
              }

              final wishDocs = snapshot.data!.docs;
              _fetchWisherData(wishDocs);

              return ListView.builder(
                padding: const EdgeInsets.only(top: 20, bottom: 100),
                itemCount: wishDocs.length,
                itemBuilder: (context, index) {
                  final wishData =
                      wishDocs[index].data() as Map<String, dynamic>;
                  final wisherId = wishData['wisherId'];
                  final cachedData = _usersDataCache[wisherId];

                  return WishBubble(
                    key: ValueKey(wishDocs[index].id),
                    author:
                        cachedData?['displayName'] ?? wishData['wisherName'],
                    text: wishData['message'],
                    photoUrl:
                        cachedData?['photoURL'] ?? wishData['wisherPhotoURL'],
                  );
                },
              );
            },
          ),
          // Pole do wpisywania życzeń na dole
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(8.0)
                  .copyWith(bottom: MediaQuery.of(context).viewInsets.bottom + 8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, -2)),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _wishController,
                      decoration: const InputDecoration(
                        hintText: 'Wpisz swoje życzenia...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(30)),
                        ),
                        filled: true,
                        fillColor: Color(0xFFf0f0f0),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
                    onPressed: _sendWish,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WishBubble extends StatefulWidget {
  final String author;
  final String text;
  final String? photoUrl;

  const WishBubble(
      {super.key,
      required this.author,
      required this.text,
      this.photoUrl});

  @override
  _WishBubbleState createState() => _WishBubbleState();
}

class _WishBubbleState extends State<WishBubble> with TickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final Random _random = Random();
  late double _startX;

  @override
  void initState() {
    super.initState();
    _startX = _random.nextDouble() * 2 - 1;
    _controller = AnimationController(
      duration: Duration(milliseconds: 1000 + _random.nextInt(1000)),
      vsync: this,
    );
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.5),
          end: Offset.zero,
        ).animate(_animation),
        child: Container(
          margin: EdgeInsets.symmetric(
            vertical: 8,
            horizontal: 20 + _random.nextDouble() * 30,
          ).add(EdgeInsets.only(left: _startX * 20)),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ]
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage:
                    widget.photoUrl != null ? NetworkImage(widget.photoUrl!) : null,
                child: widget.photoUrl == null ? const Icon(Icons.person) : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.author,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.text,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Zmodyfikowane tło
class AnimatedBackground extends StatelessWidget {
  const AnimatedBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white, // Zmiana na białe tło
      ),
      child: Stack(
        children: List.generate(30, (index) => Particle(key: UniqueKey())),
      ),
    );
  }
}

class Particle extends StatefulWidget {
  const Particle({super.key});

  @override
  State<Particle> createState() => _ParticleState();
}

class _ParticleState extends State<Particle> {
  late double size;
  late Duration duration;
  late Duration delay;
  late double startX;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _randomize();
  }

  void _randomize() {
    size = _random.nextDouble() * 3.0 + 2.0; // Rozmiar od 2.0 do 5.0
    duration = Duration(milliseconds: 6000 + _random.nextInt(12000));
    delay = Duration(milliseconds: _random.nextInt(15000));
    startX = _random.nextDouble();
  }

  @override
  Widget build(BuildContext context) {
    return LoopAnimationBuilder<double>(
      tween: Tween(begin: 1.2, end: -0.2), 
      duration: duration,
      builder: (context, value, child) {
        return Transform.translate(
          offset: Offset(
            MediaQuery.of(context).size.width * startX,
            MediaQuery.of(context).size.height * value,
          ),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              // Zmiana koloru cząsteczek na niebieski
              color: Colors.blue.withOpacity(0.4),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}
