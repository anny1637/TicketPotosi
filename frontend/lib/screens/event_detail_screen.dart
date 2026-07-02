import 'package:flutter/material.dart';
import '../models/event_model.dart';
import '../services/api_service.dart';
import '../main.dart' show AppColors;

class EventDetailScreen extends StatefulWidget {
  final EventModel event;
  const EventDetailScreen({super.key, required this.event});

  @override
  State<EventDetailScreen> createState() => _EventDetailScreenState();
}

class _EventDetailScreenState extends State<EventDetailScreen> {
  bool _isPurchasing = false;

  Future<void> _purchaseTicket(int ticketTypeId) async {
    setState(() => _isPurchasing = true);
    try {
      final response = await ApiService.purchaseTicket(ticketTypeId);
      if (!mounted) return;

      if (response['ticket'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(children: [
              Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('¡Compra exitosa! Tu ticket está listo.', style: TextStyle(fontWeight: FontWeight.bold)),
            ]),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            margin: const EdgeInsets.all(16),
          ),
        );
        Navigator.pop(context, true);
      } else {
        _showError(response['message'] ?? 'No se pudo procesar la compra.');
      }
    } catch (e) {
      debugPrint('Error compra: $e');
      _showError('Error de conexión. Verifica el servidor e intenta de nuevo.');
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showPurchaseDialog(Map<String, dynamic> ticketType) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: AppColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white, size: 30),
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirmar Compra',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
              ),
              const SizedBox(height: 6),
              Text(
                widget.event.title,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Column(
                  children: [
                    _purchaseRow('Tipo', ticketType['name'] ?? '—'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Color(0xFF2A2A45), height: 1)),
                    _purchaseRow('Precio', 'Bs. ${(ticketType['price'] as num?)?.toStringAsFixed(2) ?? '0.00'}'),
                    const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(color: Color(0xFF2A2A45), height: 1)),
                    _purchaseRow('Disponibles', '${ticketType['stock'] ?? 0} unidades'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: AppColors.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _purchaseTicket(ticketType['id']);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 13),
                        ),
                        child: const Text('¡Comprar!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _purchaseRow(String key, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(key, style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: CustomScrollView(
        slivers: [
          // AppBar with image
          SliverAppBar(
            expandedHeight: 280,
            pinned: true,
            backgroundColor: AppColors.surface,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroImage(event),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status badge + title
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: event.status == 'active'
                              ? AppColors.success.withOpacity(0.15)
                              : Colors.orange.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: event.status == 'active'
                                ? AppColors.success.withOpacity(0.4)
                                : Colors.orange.withOpacity(0.4),
                          ),
                        ),
                        child: Text(
                          event.status == 'active' ? '● Activo' : '● ${event.status}',
                          style: TextStyle(
                            color: event.status == 'active' ? AppColors.success : Colors.orange,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.confirmation_number_outlined, size: 15, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${event.ticketsAvailable} restantes',
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    event.title,
                    style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),

                  // Info chips
                  _InfoTile(icon: Icons.location_on_rounded, label: 'Lugar', value: event.location, color: const Color(0xFFFF6B6B)),
                  const SizedBox(height: 10),
                  _InfoTile(icon: Icons.access_time_rounded, label: 'Fecha y Hora', value: event.eventDate, color: AppColors.primaryLight),
                  const SizedBox(height: 10),
                  _InfoTile(icon: Icons.people_alt_rounded, label: 'Capacidad', value: '${event.capacity} personas', color: AppColors.warning),

                  // Artists
                  if (event.artists.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _sectionTitle('Artistas'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: event.artists.map((a) {
                        final name = a['name'] ?? 'Artista';
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: AppColors.card,
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 26,
                                height: 26,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    name[0].toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(name, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ],

                  // Description
                  const SizedBox(height: 28),
                  _sectionTitle('Descripción'),
                  const SizedBox(height: 10),
                  Text(
                    event.description,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14, height: 1.7),
                  ),

                  // Ticket Types
                  if (event.ticketTypes.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    _sectionTitle('Tipos de Entrada'),
                    const SizedBox(height: 14),
                    ...event.ticketTypes.map((tt) => _TicketTypeCard(
                      ticketType: tt,
                      isPurchasing: _isPurchasing,
                      onBuy: () => _showPurchaseDialog(tt),
                    )),
                  ],

                  if (event.ticketTypes.isEmpty) ...[
                    const SizedBox(height: 24),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline_rounded, color: AppColors.textMuted, size: 22),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'No hay tipos de entrada disponibles para este evento.',
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroImage(EventModel event) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (event.image != null && event.image!.isNotEmpty)
          FutureBuilder<String>(
            future: ApiService.getBaseUrl(),
            builder: (_, snap) {
              if (!snap.hasData) return _gradientPlaceholder(event);
              final baseUrl = snap.data!.replaceAll('/api', '');
              return Image.network(
                '$baseUrl/storage/${event.image}',
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _gradientPlaceholder(event),
              );
            },
          )
        else
          _gradientPlaceholder(event),

        // Fade to bg at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 100,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, AppColors.bg],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _gradientPlaceholder(EventModel event) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2A1550), Color(0xFF1A0A3D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(Icons.event_rounded, size: 80, color: AppColors.primary.withOpacity(0.5)),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
    );
  }
}

// ─── Info Tile ─────────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Ticket Type Card ──────────────────────────────────────────────────────────
class _TicketTypeCard extends StatelessWidget {
  final Map<String, dynamic> ticketType;
  final bool isPurchasing;
  final VoidCallback onBuy;

  const _TicketTypeCard({
    required this.ticketType,
    required this.isPurchasing,
    required this.onBuy,
  });

  @override
  Widget build(BuildContext context) {
    final name = ticketType['name'] ?? 'General';
    final price = (ticketType['price'] as num?)?.toStringAsFixed(2) ?? '0.00';
    final stock = ticketType['stock'] ?? 0;
    final hasStock = stock > 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasStock ? AppColors.primary.withOpacity(0.25) : AppColors.cardBorder,
        ),
      ),
      child: Row(
        children: [
          // Left colored bar
          Container(
            width: 5,
            height: 80,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: hasStock
                    ? [AppColors.primary, AppColors.primaryLight]
                    : [AppColors.textMuted, AppColors.textMuted],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                bottomLeft: Radius.circular(18),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              hasStock ? Icons.check_circle_rounded : Icons.cancel_rounded,
                              size: 13,
                              color: hasStock ? AppColors.success : AppColors.error,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              hasStock ? '$stock disponibles' : 'Sin stock',
                              style: TextStyle(
                                color: hasStock ? AppColors.success : AppColors.error,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Bs. $price',
                        style: TextStyle(
                          color: hasStock ? AppColors.primaryLight : AppColors.textMuted,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: (hasStock && !isPurchasing) ? onBuy : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            gradient: hasStock
                                ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight])
                                : null,
                            color: hasStock ? null : AppColors.surface,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            isPurchasing ? '...' : (hasStock ? 'Comprar' : 'Agotado'),
                            style: TextStyle(
                              color: hasStock ? Colors.white : AppColors.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
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