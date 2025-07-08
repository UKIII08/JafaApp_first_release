// lib/screens/sluzba_screen.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'service_meetings_screen.dart';
import 'add_announcement_screen.dart';

// --- Niestandardowy widget ExpansionTile (bez zmian) ---
class CustomGradientExpansionTile extends StatefulWidget {
  final String title;
  final List<Widget> children;
  final List<Color> gradientColors;
  final EdgeInsets childrenPadding;
  final CrossAxisAlignment expandedCrossAxisAlignment;
  final Duration animationDuration;
  final Key? expansionKey;

  const CustomGradientExpansionTile({
    required this.title,
    required this.children,
    required this.gradientColors,
    this.childrenPadding = const EdgeInsets.all(16.0),
    this.expandedCrossAxisAlignment = CrossAxisAlignment.center,
    this.animationDuration = const Duration(milliseconds: 200),
    this.expansionKey,
    super.key,
  });

  @override
  State<CustomGradientExpansionTile> createState() => _CustomGradientExpansionTileState();
}

class _CustomGradientExpansionTileState extends State<CustomGradientExpansionTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _iconTurns;
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.animationDuration, vsync: this);
    _iconTurns = Tween<double>(begin: 0.0, end: 0.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
      if (widget.expansionKey != null) {
        _isExpanded = PageStorage.of(context).readState(context, identifier: widget.expansionKey) as bool? ?? false;
        if (_isExpanded) {
          _controller.value = 1.0;
        }
      }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTap() {
    setState(() {
      _isExpanded = !_isExpanded;
      if (_isExpanded) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
      if (widget.expansionKey != null) {
        PageStorage.of(context).writeState(context, _isExpanded, identifier: widget.expansionKey);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget header = InkWell(
      onTap: _handleTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 16.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                widget.title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            RotationTransition(
              turns: _iconTurns,
              child: const Icon(
                Icons.expand_more,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );

    Widget expandableContent = AnimatedCrossFade(
      firstChild: Container(height: 0.0),
      secondChild: Container(
          color: theme.cardColor,
          width: double.infinity,
          padding: widget.childrenPadding,
          child: Column(
            crossAxisAlignment: widget.expandedCrossAxisAlignment,
            children: widget.children,
          ),
        ),
      crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
      duration: widget.animationDuration,
      sizeCurve: Curves.easeInOut,
      firstCurve: Curves.easeInOut,
      secondCurve: Curves.easeInOut,
    );


    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        header,
        ClipRect(
          child: expandableContent,
        ),
      ],
    );
  }
}

// --- Główny ekran Służby ---

class SluzbaScreen extends StatefulWidget {
  const SluzbaScreen({super.key});

  @override
  State<SluzbaScreen> createState() => _SluzbaScreenState();
}

class _SluzbaScreenState extends State<SluzbaScreen> {
  bool _isLoading = true;
  List<String> _userRoles = [];

  @override
  void initState() {
    super.initState();
    _fetchUserRoles();
  }

  Future<void> _fetchUserRoles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) { if (mounted) { setState(() { _isLoading = false; _userRoles = []; }); } return; }
    try { 
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && mounted) {
        final data = userDoc.data();
        final rolesFromDb = data?['roles'];
        if (rolesFromDb is List) {
          _userRoles = rolesFromDb.whereType<String>().toList();
        } else {
          _userRoles = [];
        }
      }
    } catch (e) {
      print("Błąd podczas pobierania ról użytkownika: $e");
      if (mounted) _userRoles = [];
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _buildNoRolesView(BuildContext context) {
    return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.center, children: [ Icon( Icons.info_outline, size: 60, color: Colors.grey[400], ), const SizedBox(height: 20), const Text( "Nie jesteś jeszcze nigdzie zaangażowany?", style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600), textAlign: TextAlign.center, ), const SizedBox(height: 10), Text( "Wypełnij formularz zgłoszeniowy, a my włączymy Cię do służby!", style: TextStyle(fontSize: 16, color: Colors.grey[600]), textAlign: TextAlign.center, ), const SizedBox(height: 30), ElevatedButton.icon( icon: const Icon(Icons.description_outlined), label: const Text("Wypełnij formularz"), onPressed: _handleFormAction, style: ElevatedButton.styleFrom( padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15), textStyle: const TextStyle(fontSize: 16), ), ), ], ), ), );
  }

  Widget _buildRolesView(BuildContext context) {
    const List<Color> gradientColors = [
      Color.fromARGB(255, 109, 196, 223),
      Color.fromARGB(255, 133, 221, 235),
    ];
    
    return FutureBuilder<QuerySnapshot>(
      future: FirebaseFirestore.instance.collection('services').get(),
      builder: (context, servicesSnapshot) {
        
        if (servicesSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (servicesSnapshot.hasError) {
          return _buildErrorText('Błąd ładowania danych o służbach.');
        }

        final allServices = { for (var doc in servicesSnapshot.data!.docs) doc['name']: doc };
        final List<String> validRoles = _userRoles.where((role) => allServices.containsKey(role)).toList();

        if (validRoles.isEmpty) {
           return _buildNoRolesView(context);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12.0),
          itemCount: validRoles.length,
          itemBuilder: (context, index) {
            final roleName = validRoles[index];
            final serviceDoc = allServices[roleName]!;
            final serviceId = serviceDoc.id;
            final serviceData = serviceDoc.data() as Map<String, dynamic>;
            final leaderId = serviceData['leaderId'] ?? '';
            final isUserLeader = FirebaseAuth.instance.currentUser?.uid == leaderId;

            return Card(
              elevation: 1.5,
              margin: const EdgeInsets.only(bottom: 12.0),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              clipBehavior: Clip.antiAlias,
              child: CustomGradientExpansionTile(
                expansionKey: PageStorageKey<String>(roleName),
                title: roleName,
                gradientColors: gradientColors,
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0).copyWith(top: 8.0),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle(context, "Ogłoszenia"),
                  const SizedBox(height: 8),
                  _buildAnnouncements(roleName),
                  
                  const Divider(height: 24.0, thickness: 0.5),

                  _buildSectionTitle(context, "Nadchodzące spotkania"),
                  const SizedBox(height: 8),
                  _buildMeetingsList(serviceId),

                  if (isUserLeader) ...[
                    const Divider(height: 24.0, thickness: 0.5),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add_alert_outlined, size: 18),
                          label: const Text('Ogłoszenie'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AddAnnouncementScreen(
                                  targetRole: roleName,
                                ),
                              ),
                            );
                          },
                        ),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.edit_calendar_outlined, size: 18),
                          label: const Text('Spotkania'),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ServiceMeetingsScreen(
                                  serviceId: serviceId,
                                  serviceName: roleName,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                     const SizedBox(height: 8),
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildAnnouncements(String roleName) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('ogloszenia').where('rolaDocelowa', isEqualTo: roleName).orderBy('publishDate', descending: true).snapshots(),
      builder: (context, announcementSnapshot) {
        if (announcementSnapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding( padding: EdgeInsets.symmetric(vertical: 16.0), child: CircularProgressIndicator(strokeWidth: 2.0)));
        if (announcementSnapshot.hasError) return _buildErrorText('Nie można załadować ogłoszeń.');
        if (!announcementSnapshot.hasData || announcementSnapshot.data!.docs.isEmpty) return _buildNoDataText("Brak aktualnych ogłoszeń.");
        final announcementDocs = announcementSnapshot.data!.docs;
        return Column(
          children: announcementDocs.map((doc) {
            final data = doc.data() as Map<String, dynamic>? ?? {};
            final title = data['title'] as String? ?? 'Brak tytułu'; final content = data['content'] as String? ?? 'Brak treści'; final timestamp = data['publishDate'] as Timestamp?;
            String formattedDate = ''; if (timestamp != null) { formattedDate = DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate()); }
            return Card(elevation: 0.5, color: Theme.of(context).colorScheme.surfaceContainerLow, margin: const EdgeInsets.only(bottom: 12.0), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              child: Padding(padding: const EdgeInsets.all(12.0),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    if (formattedDate.isNotEmpty) Padding( padding: const EdgeInsets.only(top: 4.0, bottom: 8.0), child: Text( formattedDate, style: TextStyle( fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7)), ), )
                    else if (content.isNotEmpty) const SizedBox(height: 8),
                    Text(content, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildMeetingsList(String serviceId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('services')
          .doc(serviceId)
          .collection('meetings')
          .where('date', isGreaterThanOrEqualTo: DateTime.now().subtract(const Duration(days: 1)))
          .orderBy('date')
          .limit(5)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildNoDataText("Brak nadchodzących spotkań.");
        }

        return Column(
          children: snapshot.data!.docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final date = (data['date'] as Timestamp).toDate();
            final linkUrl = data['googleDriveLink'] as String?;
            
            return Card(
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.calendar_month_outlined),
                title: Text(data['title'], style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(DateFormat('EEEE, d MMMM, HH:mm', 'pl_PL').format(date)),
                trailing: (linkUrl != null && linkUrl.isNotEmpty) 
                  ? const Icon(Icons.attachment, color: Colors.blueAccent) 
                  : null,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(data['title']),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text("Data: ${DateFormat('d MMMM yyyy, HH:mm', 'pl_PL').format(date)}"),
                          if (data['location'] != null && data['location'].isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text("Miejsce: ${data['location']}"),
                            ),
                          const SizedBox(height: 20),
                          if (linkUrl != null && linkUrl.isNotEmpty)
                            ElevatedButton.icon(
                              icon: const Icon(Icons.link),
                              label: const Text("Otwórz materiały"),
                              onPressed: () => _launchURL(linkUrl),
                            )
                          else
                            const Text("Brak dołączonych materiałów."),
                        ],
                      ),
                      actions: [ TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text("Zamknij")) ],
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    IconData sectionIcon;
    if (title == "Ogłoszenia") {
      sectionIcon = Icons.campaign_outlined;
    } else if (title == "Nadchodzące spotkania") {
      sectionIcon = Icons.event_note_outlined;
    } else {
      sectionIcon = Icons.article_outlined;
    }
    return Padding( padding: const EdgeInsets.symmetric(vertical: 8.0), child: Row( children: [ Icon(sectionIcon, size: 20, color: Theme.of(context).colorScheme.secondary), const SizedBox(width: 8), Text( title, style: Theme.of(context).textTheme.titleMedium?.copyWith( fontWeight: FontWeight.w600, color: Theme.of(context).colorScheme.secondary, ), ), ], ), );
  }

  Widget _buildErrorText(String message) {
    return Padding( padding: const EdgeInsets.symmetric(vertical: 16.0), child: Row( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error, size: 18), const SizedBox(width: 8), Text(message, style: TextStyle(color: Theme.of(context).colorScheme.error)), ], ), );
  }

  Widget _buildNoDataText(String message) {
    return Padding( padding: const EdgeInsets.symmetric(vertical: 16.0), child: Row( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon(Icons.info_outline, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6), size: 18), const SizedBox(width: 8), Text(message, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7))), ], ), );
  }
  
  Future<void> _launchURL(String? urlString) async {
    if (urlString == null) return;
    final Uri url = Uri.parse(urlString);
    try {
      if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
        throw 'Could not launch $url';
      }
    } catch (e) {
      print('Błąd otwierania URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Nie można otworzyć linku: $urlString')));
      }
    }
  }

  void _handleFormAction() async {
    const String googleFormUrl = 'https://docs.google.com/forms/d/e/1FAIpQLSd9YNdZei9U0HnEs9ApPm6_mDcTuWJjN7sycOj9cxz2fENlng/viewform?usp=dialog';
    await _launchURL(googleFormUrl);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Służba"),
        backgroundColor: Theme.of(context).colorScheme.surface,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0.5,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userRoles.isEmpty
              ? _buildNoRolesView(context)
              : _buildRolesView(context),
    );
  }
}