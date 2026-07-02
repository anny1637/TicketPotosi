import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import '../main.dart' show AppColors;

class MyTicketsScreen extends StatefulWidget {
  const MyTicketsScreen({super.key});

  @override
  State<MyTicketsScreen> createState() => _MyTicketsScreenState();
}

class _MyTicketsScreenState extends State<MyTicketsScreen> {
  List<dynamic> _tickets = [];
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadTickets();
  }

  Future<void> _loadTickets() async {
    setState(() { _isLoading = true; _hasError = false; });
    try {
      final data = await ApiService.getMyTickets();
      setState(() {
        _tickets = data;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error tickets: $e');
      setState(() { _isLoading = false; _hasError = true; });
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'paid':      return AppColors.success;
      case 'used':      return AppColors.textMuted;
      case 'cancelled': return AppColors.error;
      default:          return AppColors.warning;
    }
  }

  IconData _statusIcon(String status) {
    switch (status) {
      case 'paid':      return Icons.check_circle_rounded;
      case 'used':      return Icons.done_all_rounded;
      case 'cancelled': return Icons.cancel_rounded;
      default:          return Icons.schedule_rounded;
    }
  }

  String _statusText(String status) {
    switch (status) {
      case 'paid':      return 'Válido';
      case 'used':      return 'Usado';
      case 'cancelled': return 'Cancelado';
      case 'pending':   return 'Pendiente';
      default:          return status;
    }
  }

  void _showQR(dynamic ticket) {
    final qrData = ticket['qr_token'] ?? ticket['ticket_code'] ?? 'NO_TOKEN';
    final code = ticket['ticket_code'] ?? '—';
    final status = ticket['status'] ?? 'paid';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Container(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Drag handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Código QR',
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              ticket['event']?['title'] ?? '—',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // QR code
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 4,
                  ),
                ],
              ),
              child: QrImageView(
                data: qrData,
                version: QrVersions.auto,
                size: 200,
                backgroundColor: Colors.white,
                errorCorrectionLevel: QrErrorCorrectLevel.H,
              ),
            ),
            const SizedBox(height: 20),

            // Ticket code
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Código copiado al portapapeles'),
                    backgroundColor: AppColors.success,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.confirmation_number_outlined, size: 16, color: AppColors.primaryLight),
                    const SizedBox(width: 8),
                    Text(
                      code,
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'monospace',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(Icons.copy_rounded, size: 14, color: AppColors.textMuted),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Status badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: _statusColor(status).withOpacity(0.12),
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: _statusColor(status).withOpacity(0.35)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(_statusIcon(status), color: _statusColor(status), size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _statusText(status),
                    style: TextStyle(color: _statusColor(status), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppColors.cardBorder),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cerrar', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Mis Tickets',
                    style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${_tickets.length} entrada${_tickets.length != 1 ? 's' : ''} registrada${_tickets.length != 1 ? 's' : ''}',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Content
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary, strokeWidth: 2.5),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off_rounded, size: 64, color: AppColors.textMuted),
              const SizedBox(height: 16),
              Text(
                'Sin conexión al servidor',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'No se pudieron cargar tus tickets.',
                style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _loadTickets,
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
        ),
      );
    }

    if (_tickets.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Icon(Icons.confirmation_number_outlined, size: 50, color: AppColors.textMuted),
            ),
            const SizedBox(height: 20),
            const Text('Sin tickets todavía', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              'Explora eventos y compra tu primera entrada.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.card,
      onRefresh: _loadTickets,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: _tickets.length,
        itemBuilder: (context, i) {
          final ticket = _tickets[i];
          return _TicketCard(
            ticket: ticket,
            statusColor: _statusColor(ticket['status'] ?? 'pending'),
            statusIcon: _statusIcon(ticket['status'] ?? 'pending'),
            statusText: _statusText(ticket['status'] ?? 'pending'),
            onTap: () => _showQR(ticket),
          );
        },
      ),
    );
  }
}

// ─── Ticket Card with physical look ───────────────────────────────────────────
class _TicketCard extends StatelessWidget {
  final dynamic ticket;
  final Color statusColor;
  final IconData statusIcon;
  final String statusText;
  final VoidCallback onTap;

  const _TicketCard({
    required this.ticket,
    required this.statusColor,
    required this.statusIcon,
    required this.statusText,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final eventTitle = ticket['event']?['title'] ?? 'Evento';
    final location   = ticket['event']?['location'] ?? '—';
    final eventDate  = ticket['event']?['event_date'] ?? '—';
    final ticketType = ticket['ticket_type']?['name'] ?? 'General';
    final code       = ticket['ticket_code'] ?? '—';
    final status     = ticket['status'] ?? 'paid';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        child: CustomPaint(
          painter: _TicketPainter(
            color: AppColors.card,
            borderColor: AppColors.cardBorder,
            notchColor: AppColors.bg,
          ),
          child: Column(
            children: [
              // Top section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withOpacity(0.3)),
                          ),
                          child: Row(
                            children: [
                              Icon(statusIcon, color: statusColor, size: 12),
                              const SizedBox(width: 4),
                              Text(statusText, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ticketType,
                            style: const TextStyle(color: AppColors.primaryLight, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      eventTitle,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(Icons.location_on_rounded, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Expanded(child: Text(location, style: TextStyle(color: AppColors.textSecondary, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 13, color: AppColors.textMuted),
                        const SizedBox(width: 4),
                        Text(eventDate, style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),

              // Dashed divider line
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: List.generate(
                    35,
                    (i) => Expanded(
                      child: Container(
                        height: 1,
                        color: i.isEven ? AppColors.cardBorder : Colors.transparent,
                      ),
                    ),
                  ),
                ),
              ),

              // Bottom section
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Código', style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                          const SizedBox(height: 4),
                          Text(
                            code,
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: 'monospace',
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: status == 'paid'
                            ? const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight])
                            : null,
                        color: status == 'paid' ? null : AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.qr_code_rounded,
                            color: status == 'paid' ? Colors.white : AppColors.textMuted,
                            size: 18,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Ver QR',
                            style: TextStyle(
                              color: status == 'paid' ? Colors.white : AppColors.textMuted,
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
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

// ─── Custom Painter for ticket shape ─────────────────────────────────────────
class _TicketPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final Color notchColor;

  const _TicketPainter({
    required this.color,
    required this.borderColor,
    required this.notchColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const radius = 16.0;
    const notchRadius = 12.0;
    // Estimate separator at ~65% height
    final notchY = size.height * 0.64;

    final fillPaint = Paint()..color = color;
    final borderPaint = Paint()
      ..color = borderColor
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    final path = Path()
      ..moveTo(radius, 0)
      ..lineTo(size.width - radius, 0)
      ..arcToPoint(Offset(size.width, radius), radius: const Radius.circular(radius))
      ..lineTo(size.width, notchY - notchRadius)
      ..arcToPoint(Offset(size.width, notchY + notchRadius),
          radius: const Radius.circular(notchRadius), clockwise: false)
      ..lineTo(size.width, size.height - radius)
      ..arcToPoint(Offset(size.width - radius, size.height), radius: const Radius.circular(radius))
      ..lineTo(radius, size.height)
      ..arcToPoint(Offset(0, size.height - radius), radius: const Radius.circular(radius))
      ..lineTo(0, notchY + notchRadius)
      ..arcToPoint(Offset(0, notchY - notchRadius),
          radius: const Radius.circular(notchRadius), clockwise: false)
      ..lineTo(0, radius)
      ..arcToPoint(const Offset(radius, 0), radius: const Radius.circular(radius))
      ..close();

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(_TicketPainter old) =>
      old.color != color || old.borderColor != borderColor;
}