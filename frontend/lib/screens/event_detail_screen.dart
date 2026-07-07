import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isAdmin = (prefs.getInt('user_role_id') ?? 2) == 1;
      });
    }
  }

  Future<void> _openMap(String location) async {
    final query = Uri.encodeComponent('$location, Potosí, Bolivia');
    final geoUri = Uri.parse('geo:0,0?q=$query');
    final webUri = Uri.parse('https://www.google.com/maps/search/?api=1&query=$query');
    try {
      // Intentar primero con el esquema nativo geo: (abre la app de mapas directamente)
      bool launched = await launchUrl(geoUri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Si no se puede, intentar con la URL de Google Maps web (abre navegador o app)
        launched = await launchUrl(webUri, mode: LaunchMode.externalApplication);
      }
      if (!launched) {
        throw 'No se pudo lanzar ninguna URL';
      }
    } catch (e) {
      debugPrint('Error abriendo mapa: $e');
      // Fallback de último recurso
      try {
        await launchUrl(webUri, mode: LaunchMode.externalApplication);
      } catch (innerError) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo abrir el mapa en Google Maps.'),
              backgroundColor: Colors.redAccent,
            ),
          );
        }
      }
    }
  }

  Future<void> _purchaseTicket(int ticketTypeId, {String? promoCode, String? paymentMethod}) async {
    setState(() => _isPurchasing = true);
    try {
      final response = await ApiService.purchaseTicket(
        ticketTypeId,
        promoCode: promoCode,
        paymentMethod: paymentMethod,
      );
      if (!mounted) return;

      if (response['ticket'] != null) {
        final isPending = response['ticket']['status'] == 'pending';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                isPending
                    ? '¡Reserva realizada! Paga en boletería física.'
                    : '¡Compra exitosa! Tu ticket está listo.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ]),
            backgroundColor: isPending ? AppColors.warning : AppColors.success,
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
    final promoCtrl = TextEditingController();
    double discountPercentage = 0.0;
    String promoMessage = '';
    bool isPromoValid = false;
    bool isValidatingPromo = false;
    final basePrice = double.tryParse('${ticketType['price']}') ?? 0.0;

    // Métodos de pago interactivos
    String paymentMethod = 'qr'; // 'qr', 'banco', 'efectivo'
    String uniquePaymentToken = 'PAGO-QR-${DateTime.now().millisecondsSinceEpoch}';
    String? selectedReceiptPath;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final finalPrice = basePrice * (1.0 - (discountPercentage / 100.0));

          return Dialog(
            backgroundColor: AppColors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: AppColors.cardBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icono de cabecera
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.shopping_cart_checkout_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Confirmar Compra',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.event.title,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 14),

                    // Detalles de compra
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          _purchaseRow('Tipo', ticketType['name'] ?? '—'),
                          const SizedBox(height: 6),
                          _purchaseRow('Precio Base', 'Bs. ${basePrice.toStringAsFixed(2)}'),
                          if (isPromoValid) ...[
                            const SizedBox(height: 6),
                            _purchaseRow('Descuento', '-${discountPercentage.toStringAsFixed(0)}%'),
                          ],
                          const Padding(padding: EdgeInsets.symmetric(vertical: 6), child: Divider(color: AppColors.cardBorder, height: 1)),
                          _purchaseRow('Total a Pagar', 'Bs. ${finalPrice.toStringAsFixed(2)}', isTotal: true),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Campo de Cupón
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: TextField(
                            controller: promoCtrl,
                            style: const TextStyle(color: Colors.white, fontSize: 12),
                            decoration: InputDecoration(
                              hintText: 'Código promocional',
                              hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 12),
                              filled: true,
                              fillColor: AppColors.surface,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide(color: AppColors.cardBorder),
                              ),
                              enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: AppColors.cardBorder)),
                              focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: AppColors.primary)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        ElevatedButton(
                          onPressed: isValidatingPromo
                              ? null
                              : () async {
                                  final code = promoCtrl.text.trim();
                                  if (code.isEmpty) return;
                                  setDialogState(() => isValidatingPromo = true);
                                  try {
                                    final res = await ApiService.validatePromoCode(code);
                                    setDialogState(() {
                                      if (res['valid'] == true) {
                                        isPromoValid = true;
                                        discountPercentage = double.tryParse('${res['discount_percentage']}') ?? 0.0;
                                        promoMessage = res['message'] ?? 'Código aplicado';
                                      } else {
                                        isPromoValid = false;
                                        discountPercentage = 0.0;
                                        promoMessage = res['message'] ?? 'Código no válido';
                                      }
                                    });
                                  } catch (e) {
                                    setDialogState(() {
                                      isPromoValid = false;
                                      discountPercentage = 0.0;
                                      promoMessage = 'Código incorrecto';
                                    });
                                  } finally {
                                    setDialogState(() => isValidatingPromo = false);
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          child: isValidatingPromo
                              ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 1.5))
                              : const Text('Aplicar', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    if (promoMessage.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        promoMessage,
                        style: TextStyle(
                          color: isPromoValid ? AppColors.success : AppColors.error,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    const SizedBox(height: 14),

                    // Selección de Método de Pago
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Método de Pago',
                        style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _payMethodBtn('Pago QR', 'qr', paymentMethod, () {
                          setDialogState(() {
                            paymentMethod = 'qr';
                          });
                        }),
                        const SizedBox(width: 6),
                        _payMethodBtn('Banco', 'banco', paymentMethod, () {
                          setDialogState(() {
                            paymentMethod = 'banco';
                          });
                        }),
                        const SizedBox(width: 6),
                        _payMethodBtn('Efectivo', 'efectivo', paymentMethod, () {
                          setDialogState(() {
                            paymentMethod = 'efectivo';
                          });
                        }),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Área dinámica de información del pago
                    if (paymentMethod == 'qr') ...[
                      const Text(
                        'Escanea este código QR desde tu app bancaria:',
                        style: TextStyle(color: AppColors.primaryLight, fontSize: 11),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: QrImageView(
                          data: 'Bs.${finalPrice.toStringAsFixed(2)} - $uniquePaymentToken',
                          version: QrVersions.auto,
                          size: 140,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        uniquePaymentToken,
                        style: const TextStyle(color: Colors.grey, fontSize: 10, fontFamily: 'monospace'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                          if (image != null) {
                            setDialogState(() {
                              selectedReceiptPath = image.path;
                            });
                          }
                        },
                        icon: Icon(
                          selectedReceiptPath != null ? Icons.check_circle_rounded : Icons.image_rounded,
                          size: 16,
                        ),
                        label: Text(
                          selectedReceiptPath != null
                              ? 'Comprobante cargado ✓'
                              : 'Cargar Comprobante (Galería)',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: selectedReceiptPath != null
                              ? AppColors.success.withOpacity(0.2)
                              : AppColors.primary.withOpacity(0.2),
                          foregroundColor: selectedReceiptPath != null
                              ? AppColors.success
                              : AppColors.primaryLight,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                      ),
                      if (selectedReceiptPath != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.file(
                            File(selectedReceiptPath!),
                            height: 80,
                            width: 80,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ],
                    ] else if (paymentMethod == 'banco') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Transferencia Bancaria:', style: TextStyle(color: AppColors.warning, fontSize: 12, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('Banco: Banco Unión S.A.', style: TextStyle(color: Colors.white, fontSize: 11)),
                            Text('Cuenta: 100000348271', style: TextStyle(color: Colors.white, fontSize: 11)),
                            Text('Titular: Gobernación de Potosí', style: TextStyle(color: Colors.white, fontSize: 11)),
                            SizedBox(height: 4),
                            Text('Envía tu comprobante al ingresar al evento.', style: TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic)),
                          ],
                        ),
                      ),
                    ] else if (paymentMethod == 'efectivo') ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.cardBorder),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: AppColors.success, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Deberás pagar en efectivo en boletería el día del evento. Tu ticket se guardará como Pendiente.',
                                style: TextStyle(color: Colors.white, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: AppColors.cardBorder),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            child: Text('Cancelar', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.pop(context);
                                _purchaseTicket(
                                  ticketType['id'],
                                  promoCode: isPromoValid ? promoCtrl.text.trim() : null,
                                  paymentMethod: paymentMethod,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              child: const Text('¡Comprar!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
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
        },
      ),
    );
  }

  Widget _payMethodBtn(String label, String code, String current, VoidCallback onTap) {
    final isSel = code == current;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSel ? AppColors.primary : AppColors.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: isSel ? AppColors.primaryLight : AppColors.cardBorder),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                color: isSel ? Colors.white : AppColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _purchaseRow(String key, String value, {bool isTotal = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(key,
            style: TextStyle(
                color: isTotal ? Colors.white : AppColors.textMuted,
                fontSize: isTotal ? 14 : 13,
                fontWeight: isTotal ? FontWeight.bold : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                color: isTotal ? AppColors.primaryLight : Colors.white,
                fontSize: isTotal ? 16 : 13,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: CustomScrollView(
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

                      // Info chips (date and capacity)
                      _InfoTile(icon: Icons.access_time_rounded, label: 'Fecha y Hora', value: event.eventDate, color: AppColors.primaryLight),
                      const SizedBox(height: 10),
                      _InfoTile(icon: Icons.people_alt_rounded, label: 'Capacidad', value: '${event.capacity} personas', color: AppColors.warning),
                      const SizedBox(height: 24),

                      // Sección de Ubicación Premium
                      _sectionTitle('📍 Ubicación del Evento'),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: AppColors.card,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppColors.cardBorder, width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Simulación visual de mapa interactivo
                            Container(
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF0F172A),
                                    AppColors.card.withOpacity(0.8),
                                    const Color(0xFF1E293B),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Stack(
                                children: [
                                  // Gridlines de mapa simuladas
                                  Positioned.fill(
                                    child: Opacity(
                                      opacity: 0.1,
                                      child: GridPaper(
                                        color: AppColors.primaryLight,
                                        divisions: 2,
                                        subdivisions: 1,
                                        interval: 50,
                                        child: Container(),
                                      ),
                                    ),
                                  ),
                                  // Círculos concéntricos de sonar para el marcador
                                  Center(
                                    child: Container(
                                      width: 80,
                                      height: 80,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: AppColors.primary.withOpacity(0.15),
                                      ),
                                      child: Center(
                                        child: Container(
                                          width: 45,
                                          height: 45,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: AppColors.primary.withOpacity(0.25),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Marcador de ubicación
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: const BoxDecoration(
                                        color: Colors.white,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.location_on_rounded,
                                        color: Color(0xFFFF3B30),
                                        size: 26,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Detalles de ubicación
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.location,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(Icons.map_outlined, color: AppColors.textSecondary, size: 14),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Potosí, Bolivia',
                                        style: TextStyle(
                                          color: AppColors.textSecondary,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 14),
                                  // Botón de Google Maps Premium
                                  SizedBox(
                                    width: double.infinity,
                                    height: 46,
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          colors: [Color(0xFF34A853), Color(0xFF4285F4)], // Colores estilo Google Maps
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF4285F4).withOpacity(0.25),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: ElevatedButton.icon(
                                        onPressed: () => _openMap(event.location),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.transparent,
                                          shadowColor: Colors.transparent,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                        ),
                                        icon: const Icon(Icons.directions_rounded, color: Colors.white, size: 20),
                                        label: const Text(
                                          '¿Cómo llegar? (Abrir Google Maps)',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

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

                      // Ticket Types — solo visible para clientes (no admin)
                      if (event.ticketTypes.isNotEmpty) ...[
                        const SizedBox(height: 32),
                        _sectionTitle('Tipos de Entrada'),
                        const SizedBox(height: 14),
                        if (_isAdmin)
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.admin_panel_settings_rounded,
                                    color: AppColors.primary, size: 22),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Como administrador no puedes comprar tickets. Solo los clientes pueden adquirir entradas.',
                                    style: TextStyle(
                                        color: AppColors.textSecondary,
                                        fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
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
        ),
      ),
    );
  }

  Widget _buildHeroImage(EventModel event) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (event.video != null && event.video!.isNotEmpty)
          _DetailVideoPlayer(videoPath: event.video!)
        else if (event.image != null && event.image!.isNotEmpty)
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
          colors: [Color(0xFF0C1D3A), Color(0xFF080D1A)],
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
  final VoidCallback? onTap;
  final Widget? trailing;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: onTap != null ? color.withOpacity(0.4) : AppColors.cardBorder,
            width: onTap != null ? 1.2 : 1.0,
          ),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: AppColors.textMuted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
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
    final double priceVal = ticketType['price'] is num
        ? (ticketType['price'] as num).toDouble()
        : double.tryParse(ticketType['price']?.toString() ?? '') ?? 0.0;
    final price = priceVal.toStringAsFixed(2);
    final int stock = ticketType['stock'] is int
        ? ticketType['stock'] as int
        : int.tryParse(ticketType['stock']?.toString() ?? '') ?? 0;
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

class _DetailVideoPlayer extends StatefulWidget {
  final String videoPath;
  const _DetailVideoPlayer({super.key, required this.videoPath});

  @override
  State<_DetailVideoPlayer> createState() => _DetailVideoPlayerState();
}

class _DetailVideoPlayerState extends State<_DetailVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future<void> _initPlayer() async {
    try {
      final path = widget.videoPath;
      
      // Detectar si es una ruta local de archivo (modo mock / subida desde celular)
      final bool isLocalFile = !kIsWeb &&
          (path.startsWith('/') || path.startsWith('file://') ||
           RegExp(r'^[A-Za-z]:\\').hasMatch(path));

      if (isLocalFile) {
        final localFile = File(path);
        if (await localFile.exists()) {
          _controller = VideoPlayerController.file(localFile);
        } else {
          if (mounted) setState(() => _hasError = true);
          return;
        }
      } else if (path.startsWith('http://') || path.startsWith('https://')) {
        // URL completa directa
        _controller = VideoPlayerController.networkUrl(Uri.parse(path));
      } else {
        // Ruta relativa del servidor (ej: "videos/mi-video.mp4")
        final baseUrl = await ApiService.getBaseUrl();
        final cleanBase = baseUrl.replaceAll('/api', '');
        final fullUrl = '$cleanBase/storage/$path';
        _controller = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
      }

      await _controller.initialize();
      _controller.setLooping(true);
      _controller.setVolume(1.0);
      await _controller.play();

      if (mounted) setState(() => _isInitialized = true);
    } catch (e) {
      debugPrint('Error cargando video: $e');
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Icon(Icons.videocam_off_rounded, color: Colors.white30, size: 50),
      );
    }
    
    if (!_isInitialized) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF0294E3)),
      );
    }

    return GestureDetector(
      onTap: () {
        setState(() {
          _controller.value.isPlaying ? _controller.pause() : _controller.play();
        });
      },
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.value.size.width,
              height: _controller.value.size.height,
              child: VideoPlayer(_controller),
            ),
          ),
          if (!_controller.value.isPlaying)
            Container(
              color: Colors.black38,
              child: const Center(
                child: Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 64,
                ),
              ),
            ),
          Positioned(
            bottom: 12,
            right: 12,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(
                  _controller.value.volume > 0.0 ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                  color: Colors.white,
                  size: 18,
                ),
                onPressed: () {
                  setState(() {
                    if (_controller.value.volume > 0.0) {
                      _controller.setVolume(0.0);
                    } else {
                      _controller.setVolume(1.0);
                    }
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}