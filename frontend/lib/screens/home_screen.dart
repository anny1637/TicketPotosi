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
  bool _isAdmin = false;
  int _currentIndex = 0;
  int _selectedCategory = 0;

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

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _userName = prefs.getString('user_name') ?? 'Usuario';
        _userRole = prefs.getString('user_role') ?? 'Cliente';
        _isAdmin = (prefs.getInt('user_role_id') ?? 2) == 1;
      });
    }
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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        title: const Row(
          children: [
            Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 22),
            SizedBox(width: 8),
            Text('Notificaciones', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              _buildNotificationItem(
                '🎟️ ¡Preventa Disponible!',
                'La preventa para el concierto del año ya está activa con 20% de descuento.',
                'Hace 10 min',
              ),
              const Divider(color: Color(0xFF2A2A45), height: 16),
              _buildNotificationItem(
                '⚡ Nuevo Evento Creado',
                'Se ha publicado el Torneo Nacional de Fútbol en el Estadio Potosí.',
                'Hace 2 horas',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cerrar', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(String title, String desc, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(desc, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
        const SizedBox(height: 4),
        Text(time, style: TextStyle(color: AppColors.textMuted, fontSize: 10)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: _buildDrawer(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeBody(),
          MyTicketsScreen(key: _currentIndex == 1 ? UniqueKey() : null),
          if (_isAdmin) ScannerScreen(key: _currentIndex == 2 ? UniqueKey() : null),
          ProfileScreen(key: _currentIndex == (_isAdmin ? 3 : 2) ? UniqueKey() : null),
        ],
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen())),
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.psychology_rounded, color: Colors.white, size: 28),
            )
          : null,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            // Drawer Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.cardBorder)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(
                        _userName.isNotEmpty ? _userName[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userName,
                          style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          _userRole,
                          style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Items del Drawer
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                children: [
                  // Categorías de Eventos
                  const Padding(
                    padding: EdgeInsets.only(left: 12, bottom: 8),
                    child: Text('CATEGORÍAS', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),
                  ..._categories.asMap().entries.map((entry) {
                    final i = entry.key;
                    final cat = entry.value;
                    return ListTile(
                      leading: Icon(cat['icon'] as IconData, color: _selectedCategory == i ? AppColors.primary : AppColors.textSecondary, size: 20),
                      title: Text(cat['label'] as String, style: TextStyle(color: _selectedCategory == i ? Colors.white : AppColors.textSecondary, fontSize: 14, fontWeight: _selectedCategory == i ? FontWeight.bold : FontWeight.normal)),
                      onTap: () {
                        setState(() {
                          _selectedCategory = i;
                          _currentIndex = 0; // Cambiar a pestaña explorar
                        });
                        Navigator.pop(context);
                      },
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      selected: _selectedCategory == i,
                      selectedTileColor: AppColors.primary.withOpacity(0.1),
                    );
                  }),

                  const Padding(
                    padding: EdgeInsets.only(left: 12, top: 20, bottom: 8),
                    child: Text('ACCIONES', style: TextStyle(color: AppColors.textMuted, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  ),

                  // Si es Admin, mostrar Panel Admin y Agregar Evento
                  if (_isAdmin) ...[
                    ListTile(
                      leading: const Icon(Icons.admin_panel_settings_rounded, color: AppColors.warning, size: 20),
                      title: const Text('Panel Admin', style: TextStyle(color: Colors.white, fontSize: 14)),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.qr_code_scanner_rounded, color: AppColors.primaryLight, size: 20),
                      title: const Text('Escanear QR', style: TextStyle(color: Colors.white, fontSize: 14)),
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => _currentIndex = 2); // Ir a pestaña scanner
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.add_circle_outline_rounded, color: AppColors.success, size: 20),
                      title: const Text('Agregar Evento', style: TextStyle(color: Colors.white, fontSize: 14)),
                      onTap: () async {
                        Navigator.pop(context);
                        final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateEventScreen()));
                        if (res == true) _loadEvents();
                      },
                    ),
                  ],

                  ListTile(
                    leading: const Icon(Icons.person_rounded, color: AppColors.primaryLight, size: 20),
                    title: const Text('Mi Perfil', style: TextStyle(color: Colors.white, fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      setState(() => _currentIndex = _isAdmin ? 3 : 2); // Ir a pestaña perfil
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 20),
                    title: const Text('Asistente IA', style: TextStyle(color: Colors.white, fontSize: 14)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatbotScreen()));
                    },
                  ),
                ],
              ),
            ),

            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.cardBorder)),
              ),
              child: ListTile(
                leading: const Icon(Icons.logout_rounded, color: AppColors.error, size: 20),
                title: const Text('Cerrar Sesión', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold, fontSize: 14)),
                onTap: () {
                  Navigator.pop(context);
                  _logout();
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeBody() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerScrolled) => [
        SliverAppBar(
          backgroundColor: AppColors.surface,
          floating: true,
          snap: true,
          elevation: 0,
          leading: Builder(
            builder: (ctx) => IconButton(
              icon: const Icon(Icons.menu_rounded, color: Colors.white),
              onPressed: () => Scaffold.of(ctx).openDrawer(),
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
            // Botón de notificaciones en el AppBar
            IconButton(
              icon: const Icon(Icons.notifications_none_rounded, color: Colors.white),
              onPressed: _showNotifications,
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
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: events.length,
        itemBuilder: (context, i) => _EventCard(
          event: events[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => EventDetailScreen(event: events[i])),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav() {
    final items = <Map<String, dynamic>>[
      {'active': Icons.explore_rounded, 'inactive': Icons.explore_outlined, 'label': 'Explorar'},
      {'active': Icons.confirmation_number_rounded, 'inactive': Icons.confirmation_number_outlined, 'label': 'Mis Tickets'},
      if (_isAdmin)
        {'active': Icons.qr_code_scanner_rounded, 'inactive': Icons.qr_code_outlined, 'label': 'Scanner'},
      {'active': Icons.person_rounded, 'inactive': Icons.person_outline_rounded, 'label': 'Perfil'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.cardBorder, width: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: items.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              final isSelected = _currentIndex == i;

              return GestureDetector(
                onTap: () => setState(() => _currentIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected
                            ? item['active'] as IconData
                            : item['inactive'] as IconData,
                        color: isSelected ? AppColors.primary : AppColors.textMuted,
                        size: 24,
                      ),
                      const SizedBox(height: 4),
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
          border: Border.all(color: AppColors.cardBorder, width: 0.5),
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
                              horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppColors.success.withOpacity(0.3)),
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
                              horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryLight],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            children: [
                              Text('Ver detalles',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              SizedBox(width: 4),
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
        gradient: LinearGradient(
          colors: [Color(0xFF2A1550), Color(0xFF1A0A3D), AppColors.card],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_rounded,
                size: 48, color: AppColors.primary.withOpacity(0.7)),
            const SizedBox(height: 8),
            Text(event.title,
                style: TextStyle(
                    color: Colors.white.withOpacity(0.6), fontSize: 13),
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