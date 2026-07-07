import 'package:flutter/material.dart';
import '../../services/api_service.dart';
import '../../main.dart' show AppColors;
import 'create_event_screen.dart';

class AdminEventsScreen extends StatefulWidget {
  const AdminEventsScreen({super.key});

  @override
  State<AdminEventsScreen> createState() => _AdminEventsScreenState();
}

class _AdminEventsScreenState extends State<AdminEventsScreen> {
  List<dynamic> _events = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoading = true);
    try {
      final data = await ApiService.getEvents();
      if (mounted) setState(() { _events = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteEvent(int id, String title) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar evento',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text('¿Deseas eliminar "$title"? Esta acción no se puede deshacer.',
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
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ApiService.deleteEvent(id);
        _showMessage('Evento eliminado');
        _loadEvents();
      } catch (e) {
        _showMessage('Error al eliminar', isError: true);
      }
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AppColors.error : AppColors.success,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  String _formatStatus(String? status) {
    switch (status) {
      case 'active': return '🟢 Activo';
      case 'inactive': return '🟡 Inactivo';
      case 'cancelled': return '🔴 Cancelado';
      default: return status ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: const Text('Gestión de Eventos',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            onPressed: _loadEvents,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateEventScreen()),
          );
          if (result == true) _loadEvents();
        },
        backgroundColor: const Color(0xFF0294E3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text('Nuevo Evento',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _events.isEmpty
              ? _buildEmpty()
              : RefreshIndicator(
                  onRefresh: _loadEvents,
                  color: AppColors.primary,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                    itemCount: _events.length,
                    itemBuilder: (ctx, i) => _buildEventCard(_events[i]),
                  ),
                ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_busy_rounded, size: 64, color: AppColors.textMuted),
          const SizedBox(height: 16),
          Text('No hay eventos',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 16)),
          const SizedBox(height: 8),
          Text('Crea el primer evento con el botón +',
              style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event) {
    final types = (event['ticket_types'] as List?) ?? [];
    final minPrice = types.isNotEmpty
        ? types.map((t) => double.tryParse('${t['price']}') ?? 0).reduce((a, b) => a < b ? a : b)
        : 0.0;

    final isActive = event['status'] != 'inactive' && event['status'] != 'Inactivo';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0294E3).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_today_rounded,
                      color: Color(0xFF0294E3), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event['title'] ?? '',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 3),
                      Text(event['organizer'] ?? 'Gobernación de Potosí',
                          style: const TextStyle(
                              color: Color(0xFF0294E3), fontSize: 13, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: isActive ? const Color(0xFF00E676) : Colors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(isActive ? 'Activo' : 'Inactivo',
                              style: TextStyle(
                                  color: Colors.white.withOpacity(0.6), fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Info row
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Icon(Icons.location_on_rounded,
                    size: 14, color: Colors.white.withOpacity(0.4)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(event['location'] ?? '',
                      style: TextStyle(
                          color: Colors.white.withOpacity(0.6), fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00E676).withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFF00E676).withOpacity(0.4), width: 1),
                  ),
                  child: Text(
                    'Bs. ${minPrice.toStringAsFixed(2)}+',
                    style: const TextStyle(
                        color: Color(0xFF00E676),
                        fontSize: 12,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // Botones
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.cardBorder)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => CreateEventScreen(eventData: event),
                        ),
                      );
                      if (result == true) _loadEvents();
                    },
                    icon: const Icon(Icons.edit_rounded,
                        size: 16, color: Color(0xFF0294E3)),
                    label: const Text('Editar',
                        style: TextStyle(color: Color(0xFF0294E3), fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
                Container(width: 1, height: 40, color: AppColors.cardBorder),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () =>
                        _deleteEvent(event['id'], event['title'] ?? ''),
                    icon: const Icon(Icons.delete_rounded,
                        size: 16, color: Color(0xFFE57373)),
                    label: const Text('Eliminar',
                        style: TextStyle(color: Color(0xFFE57373), fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
