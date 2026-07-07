import 'dart:io' as io;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../models/event_model.dart';
import 'login_screen.dart';
import 'event_detail_screen.dart';
import 'my_tickets_screen.dart';
import 'scanner_screen.dart';
import 'profile_screen.dart';
import 'admin_panel_screen.dart';
import 'admin/create_event_screen.dart';
import 'admin/admin_events_screen.dart';
import 'admin/admin_users_screen.dart';
import 'admin/admin_promotions_screen.dart';
import 'admin/admin_reports_screen.dart';
import 'chatbot_screen.dart';
import '../main.dart' show AppColors;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<EventModel> _events = [];
  bool _isLoading = true;
  bool _hasError = false;
  String _userName = '';
  String _userRole = '';
  String _userPhoto = '';
  bool _isAdmin = false;
  int _currentIndex = 0;
  int _selectedCategory = 0;
  List<Map<String, dynamic>> _notifications = [];

  final List<Map<String, dynamic>> _categories = [
    {'label': 'Todos', 'icon': Icons.apps_rounded},
    {'label': 'Conciertos', 'icon': Icons.music_note_rounded},
    {'label': 'Deportes', 'icon': Icons.sports_soccer_rounded},
    {'label': 'Teatro', 'icon': Icons.theater_comedy_rounded},
    {'label': 'Festivales', 'icon': Icons.celebration_rounded},
    {'label': 'Cultura', 'icon': Icons.account_balance_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadNotifications() async {
    final list = await ApiService.getNotifications(_isAdmin);
    if (mounted) {
      setState(() {
        _notifications = list;
      });
    }
  }

  int get _unreadNotificationCount => _notifications.where((n) => !n['isRead']).length;

  Future<void> _loadUserDataOnly() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Usuario';
        _userRole = prefs.getString('user_role') ?? 'Cliente';
        _userPhoto = prefs.getString('user_photo') ?? '';
      });
    }
    await _loadNotifications();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Usuario';
        _userRole = prefs.getString('user_role') ?? 'Cliente';
        _userPhoto = prefs.getString('user_photo') ?? '';
        _isAdmin = (prefs.getInt('user_role_id') ?? 2) == 1;
      });
    }
    await _loadNotifications();
    await _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (mounted) setState(() { _isLoading = true; _hasError = false; });
    try {
      final data = await ApiService.getEvents();
      if (mounted) {
        setState(() {
          _events = data.map((e) => EventModel.fromJson(e)).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error eventos: $e');
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  List<EventModel> get _filtered {
    if (_selectedCategory == 0) return _events;
    final cat = _categories[_selectedCategory]['label'].toString().toLowerCase();
    return _events.where((e) {
      final combined = '${e.title} ${e.description} ${e.category ?? ''}'.toLowerCase();
      if (cat == 'conciertos') return combined.contains('concierto') || combined.contains('música') || combined.contains('musica') || combined.contains('show') || combined.contains('banda');
      if (cat == 'deportes') return combined.contains('deporte') || combined.contains('fútbol') || combined.contains('futbol') || combined.contains('torneo');
      if (cat == 'teatro') return combined.contains('teatro') || combined.contains('obra') || combined.contains('drama');
      if (cat == 'festivales') return combined.contains('festival') || combined.contains('feria');
      if (cat == 'cultura') return combined.contains('cultura') || combined.contains('arte') || combined.contains('museo');
      return true;
    }).toList();
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        title: const Text('Cerrar sesión',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('¿Seguro que deseas salir de tu cuenta?',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancelar', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Salir', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try { await ApiService.logout(); } catch (_) {}
      Navigator.pushReplacement(
        context,
        PageRouteBuilder(
          pageBuilder: (_, __, ___) => const LoginScreen(),
          transitionsBuilder: (_, anim, __, child) => FadeTransition(opacity: anim, child: child),
          transitionDuration: const Duration(milliseconds: 400),
        ),
      );
    }
  }

  void _showNotifications() {
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.cardBorder),
            ),
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Text('Notificaciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                if (_unreadNotificationCount > 0)
                  TextButton(
                    onPressed: () async {
                      await ApiService.markNotificationsAsRead(_isAdmin);
                      await _loadNotifications();
                      setDialogState(() {});
                    },
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Marcar todo leído', style: TextStyle(color: AppColors.primary, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: _notifications.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Text('No tienes notificaciones', style: TextStyle(color: AppColors.textSecondary), textAlign: TextAlign.center),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: _notifications.length,
                      separatorBuilder: (_, __) => Divider(color: AppColors.cardBorder.withOpacity(0.5), height: 16),
                      itemBuilder: (context, idx) {
                        final item = _notifications[idx];
                        final bool isRead = item['isRead'] == true;
                        return InkWell(
                          onTap: () async {
                            final itemId = item['id'];
                            if (itemId != null) {
                              await ApiService.markNotificationIdAsRead(_isAdmin, itemId as int);
                              await _loadNotifications();
                              setDialogState(() {});
                            }
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 4, right: 10),
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isRead ? Colors.transparent : AppColors.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title'] ?? '',
                                        style: TextStyle(
                                          color: isRead ? AppColors.textSecondary : Colors.white,
                                          fontSize: 13,
                                          fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['desc'] ?? '',
                                        style: TextStyle(
                                          color: isRead ? AppColors.textMuted : AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item['time'] ?? '',
                                        style: TextStyle(color: AppColors.textMuted, fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pantallas fijas en orden: 0=Explorar, 1=MisTickets, 2=Scanner(solo admin), 3=Perfil
    final List<Widget> screens = [
      _buildHomeBody(),
      const MyTicketsScreen(),
      const ScannerScreen(), // siempre en index 2
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: _buildDrawer(),
      body: Stack(
        children: [
          IndexedStack(
            index: _currentIndex,
            children: screens,
          ),
          // FAB del chatbot
          if (_currentIndex == 0)
            Positioned(
              right: 20,
              bottom: 90,
              child: FloatingActionButton(
                heroTag: 'chatbot_fab',
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ChatbotScreen()),
                ),
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 28),
              ),
            ),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF0E1626),
      child: Column(
        children: [
          // Drawer Header con gradiente azul y sin SafeArea interna para que ocupe todo el espacio superior
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, MediaQuery.of(context).padding.top + 20, 20, 24),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0294E3), Color(0xFF00B0FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 70,
                  height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF132038),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(35),
                    child: _buildDrawerAvatarImage(),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _userName,
                  style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _userRole,
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 14),
                ),
              ],
            ),
          ),

          // Items del Drawer
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                ListTile(
                  leading: const Icon(Icons.explore_rounded, color: AppColors.primary, size: 22),
                  title: const Text('Explorar Eventos', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  onTap: () {
                    setState(() => _currentIndex = 0);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.confirmation_number_rounded, color: AppColors.primary, size: 22),
                  title: const Text('Mis Tickets', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  onTap: () {
                    setState(() => _currentIndex = 1);
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 22),
                  title: const Text('Asistente Potosí AI', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.person_rounded, color: AppColors.primary, size: 22),
                  title: const Text('Mi Perfil', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                  onTap: () {
                    setState(() => _currentIndex = _isAdmin ? 3 : 2);
                    Navigator.pop(context);
                  },
                ),
                Divider(color: Colors.white.withOpacity(0.08), height: 32),
                if (_isAdmin) ...[
                  Padding(
                    padding: const EdgeInsets.only(left: 16, bottom: 8),
                    child: Text(
                      'ADMINISTRACIÓN',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.4),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.primary, size: 22),
                    title: const Text('Dashboard / Estadísticas', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.event_rounded, color: AppColors.primary, size: 22),
                    title: const Text('Gestionar Eventos', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    onTap: () async {
                      Navigator.pop(context);
                      final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminEventsScreen()));
                      if (res == true) _loadEvents();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.people_rounded, color: AppColors.primary, size: 22),
                    title: const Text('Gestionar Usuarios', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminUsersScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.discount_rounded, color: AppColors.primary, size: 22),
                    title: const Text('Gestionar Promociones', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPromotionsScreen()));
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.bar_chart_rounded, color: AppColors.primary, size: 22),
                    title: const Text('Reportes de Ventas', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminReportsScreen()));
                    },
                  ),
                  Divider(color: Colors.white.withOpacity(0.08), height: 32),
                ],
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: AppColors.error, size: 22),
                  title: const Text('Cerrar Sesión', style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.bold)),
                  onTap: () {
                    Navigator.pop(context);
                    _logout();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeBody() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerScrolled) => [
        SliverAppBar(
          backgroundColor: AppColors.bg,
          floating: true,
          snap: true,
          centerTitle: true,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: () {
                _loadUserDataOnly();
                Scaffold.of(ctx).openDrawer();
              },
            ),
          ),
          title: const Text(
            'TicketPotosí',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.5,
            ),
          ),
          actions: [
            Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications_rounded, color: Colors.white),
                  onPressed: _showNotifications,
                ),
                if (_unreadNotificationCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        '$_unreadNotificationCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: Colors.white),
              onPressed: _loadEvents,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ],
      body: _buildEventsList(),
    );
  }

  Widget _buildEventsList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
            const SizedBox(height: 16),
            Text('Cargando eventos...', style: TextStyle(color: AppColors.textSecondary)),
          ],
        ),
      );
    }

    if (_hasError) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('Sin conexión al servidor',
                style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Verifica la configuración del servidor',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _loadEvents,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      );
    }

    final events = _filtered;

    if (events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_busy_rounded, size: 64, color: AppColors.textMuted),
            const SizedBox(height: 16),
            Text('Sin eventos en esta categoría',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: _loadEvents,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
        itemCount: events.length,
        itemBuilder: (context, i) => Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 650),
            child: _EventCard(
              event: events[i],
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => EventDetailScreen(event: events[i])),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final List<Map<String, dynamic>> items = [
      {'active': Icons.explore_rounded, 'inactive': Icons.explore_outlined, 'label': 'Explorar', 'index': 0},
      {'active': Icons.confirmation_number_rounded, 'inactive': Icons.confirmation_number_outlined, 'label': 'Mis Tickets', 'index': 1},
      if (_isAdmin)
        {'active': Icons.qr_code_scanner_rounded, 'inactive': Icons.qr_code_outlined, 'label': 'Scanner', 'index': 2},
      {'active': Icons.person_rounded, 'inactive': Icons.person_outline_rounded, 'label': 'Perfil', 'index': 3},
    ];

    return SafeArea(
      top: false,
      child: Container(
        height: 72,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        decoration: BoxDecoration(
          color: const Color(0xFF070B14).withOpacity(0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppColors.cardBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.45),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: items.map((item) {
            final idx = item['index'] as int;
            final isSelected = _currentIndex == idx;
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (!mounted) return;
                setState(() => _currentIndex = idx);
                _loadUserDataOnly();
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary.withOpacity(0.12)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isSelected
                          ? item['active'] as IconData
                          : item['inactive'] as IconData,
                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                      size: 24,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['label'] as String,
                      style: TextStyle(
                        color: isSelected ? AppColors.primary : AppColors.textMuted,
                        fontSize: 10,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildDrawerAvatarImage() {
    if (kIsWeb) {
      if (_userPhoto.isNotEmpty) {
        return Image.network(
          _userPhoto == 'local_mock_photo.png'
              ? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=250&q=80'
              : _userPhoto,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _buildDrawerInitials(),
        );
      }
      return _buildDrawerInitials();
    }

    if (_userPhoto.isNotEmpty) {
      final file = io.File(_userPhoto);
      if (file.existsSync()) {
        return Image.file(file, fit: BoxFit.cover);
      }
      return FutureBuilder<String>(
        future: ApiService.getBaseUrl(),
        builder: (context, snap) {
          if (!snap.hasData) return _buildDrawerInitials();
          final baseUrl = snap.data!.replaceAll('/api', '');
          final fullUrl = _userPhoto == 'local_mock_photo.png'
              ? 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?auto=format&fit=crop&w=250&q=80'
              : '$baseUrl/storage/$_userPhoto';
          return Image.network(
            fullUrl,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDrawerInitials(),
          );
        },
      );
    }
    return _buildDrawerInitials();
  }

  Widget _buildDrawerInitials() {
    return Center(
      child: Text(
        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
        style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }
}

// ─── Event Card ───────────────────────────────────────────────────────────────
class _EventCard extends StatelessWidget {
  final EventModel event;
  final VoidCallback onTap;

  const _EventCard({required this.event, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.cardBorder, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImageHeader(),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(event.title,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ),
                        if (event.isPresale == true)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.warning.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: AppColors.warning.withOpacity(0.4)),
                            ),
                            child: const Text('PREVENTA',
                                style: TextStyle(
                                    color: AppColors.warning,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                    if (event.organizer != null && event.organizer!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.business_rounded,
                              size: 12, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              event.organizer!,
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    _infoChip(Icons.location_on_rounded, event.location),
                    const SizedBox(height: 6),
                    _infoChip(Icons.access_time_rounded, event.eventDate),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                                color: AppColors.success.withOpacity(0.5)),
                          ),
                          child: Text(
                            '${event.ticketsAvailable} disponibles',
                            style: const TextStyle(
                                color: AppColors.success,
                                fontSize: 12,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Row(
                            children: [
                              Text('Ver detalles',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_rounded,
                                  color: Colors.white, size: 14),
                            ],
                          ),
                        ),
                      ],
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

  Widget _buildImageHeader() {
    return Stack(
      children: [
        if (event.image != null && event.image!.isNotEmpty)
          FutureBuilder<String>(
            future: ApiService.getBaseUrl(),
            builder: (context, snap) {
              if (!snap.hasData) return _gradientHeader();
              final baseUrl = snap.data!.replaceAll('/api', '');
              final imageUrl = '$baseUrl/storage/${event.image}';
              return Image.network(
                imageUrl,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _gradientHeader(),
                loadingBuilder: (_, child, progress) =>
                    progress == null ? child : _gradientHeader(),
              );
            },
          )
        else
          _gradientHeader(),
        Container(
          height: 170,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.transparent, Colors.black.withOpacity(0.5)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                const Icon(Icons.local_activity_rounded,
                    size: 12, color: AppColors.primaryLight),
                const SizedBox(width: 4),
                Text(
                  '${event.ticketsAvailable} tickets',
                  style: const TextStyle(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _gradientHeader() {
    return Container(
      height: 170,
      decoration: const BoxDecoration(
        color: Color(0xFF070B14),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.theater_comedy_rounded,
                size: 54, color: Color(0xFFFFD54F)),
            const SizedBox(height: 12),
            Text(event.title,
                style: const TextStyle(
                    color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.primary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}