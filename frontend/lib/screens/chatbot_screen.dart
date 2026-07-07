import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/event_model.dart';
import '../main.dart' show AppColors;

class ChatbotScreen extends StatefulWidget {
  const ChatbotScreen({super.key});

  @override
  State<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends State<ChatbotScreen> {
  final List<Map<String, dynamic>> _messages = [];
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  bool _isTyping = false;
  List<EventModel> _availableEvents = [];

  // Sugerencias rápidas
  final List<String> _suggestions = [
    '🎪 ¿Qué eventos hay hoy?',
    '🎟️ ¿Cómo imprimo mi ticket?',
    '💰 ¿Hay descuentos o preventas?',
    '❓ ¿Cómo funciona el código QR?',
  ];

  @override
  void initState() {
    super.initState();
    _loadEvents();
    // Mensaje de bienvenida inicial
    _messages.add({
      'isUser': false,
      'text': '¡Hola! Soy Potosí AI 🤖, tu asistente virtual. ¿En qué puedo ayudarte hoy? Te puedo recomendar eventos, informarte sobre preventas o ayudarte con tus tickets.',
      'time': DateTime.now(),
    });
  }

  @override
  void dispose() {
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadEvents() async {
    try {
      final data = await ApiService.getEvents();
      setState(() {
        _availableEvents = data.map((e) => EventModel.fromJson(e)).toList();
      });
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _handleSendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text,
        'time': DateTime.now(),
      });
      _isTyping = true;
    });
    _msgCtrl.clear();
    _scrollToBottom();

    // Simular retraso de procesamiento de la IA
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (!mounted) return;
      final response = _generateAIResponse(text);
      setState(() {
        _messages.add({
          'isUser': false,
          'text': response,
          'time': DateTime.now(),
        });
        _isTyping = false;
      });
      _scrollToBottom();
    });
  }

  String _generateAIResponse(String query) {
    final text = query.toLowerCase();

    // 1. Preguntas sobre eventos
    if (text.contains('evento') ||
        text.contains('que hay') ||
        text.contains('concierto') ||
        text.contains('deporte') ||
        text.contains('teatro') ||
        text.contains('lista')) {
      if (_availableEvents.isEmpty) {
        return 'Actualmente no tengo eventos registrados en la cartelera de Potosí. ¡Vuelve a consultar más tarde!';
      }
      var resp = '🎪 ¡Claro! Estos son los eventos destacados ahora mismo en Potosí:\n\n';
      for (var e in _availableEvents) {
        String rawDate = e.eventDate.replaceAll('T', ' ');
        String displayDate = rawDate.length > 16 ? rawDate.substring(0, 16) : rawDate;
        resp += '• *${e.title}*\n  📍 Lugar: ${e.location}\n  📅 Fecha: $displayDate\n';
        if (e.isPresale == true) {
          resp += '  🔥 ¡Tiene preventa disponible!\n';
        }
        resp += '\n';
      }
      resp += 'Puedes ver los detalles completos y comprar tus entradas en la pestaña principal de Explorar.';
      return resp;
    }

    // 2. Preguntas sobre impresión de tickets
    if (text.contains('ticket') ||
        text.contains('boleto') ||
        text.contains('imprimir') ||
        text.contains('descargar') ||
        text.contains('pdf')) {
      return '🎟️ Para ver e imprimir tus tickets:\n\n'
          '1. Ve a la pestaña **"Mis Tickets"** en la barra inferior de la pantalla principal.\n'
          '2. Selecciona el boleto que compraste.\n'
          '3. Verás el código QR y un botón que dice **"Imprimir PDF"**.\n'
          '4. Presiona el botón para generar el boleto digital en PDF para imprimirlo o guardarlo en tu teléfono.';
    }

    // 3. Preguntas sobre preventas y descuentos
    if (text.contains('preventa') ||
        text.contains('descuento') ||
        text.contains('promo') ||
        text.contains('cupón') ||
        text.contains('barato')) {
      final presales = _availableEvents.where((e) => e.isPresale == true).toList();
      if (presales.isEmpty) {
        return 'Actualmente no hay preventas activas en la aplicación. Sin embargo, mantente atento porque los organizadores publican ofertas regularmente.';
      }
      var resp = '💰 ¡Sí! Tenemos eventos con precios de preventa especiales ahora mismo:\n\n';
      for (var e in presales) {
        resp += '• *${e.title}* (organizado por ${e.organizer ?? 'Gobernación'})\n';
      }
      resp += '\nPara aprovecharlos, simplemente ve a los detalles del evento y dale a "Comprar". ¡El descuento se aplicará automáticamente!';
      return resp;
    }

    // 4. Preguntas sobre el QR
    if (text.contains('qr') || text.contains('validar') || text.contains('puerta') || text.contains('ingreso')) {
      return '❓ ¿Cómo funciona el código QR de ingreso?\n\n'
          '• Al comprar una entrada, se genera un código QR único para ti.\n'
          '• El día del evento, el personal encargado escaneará tu código QR.\n'
          '• **Importante**: Una vez escaneado en puerta, el QR se marcará como "Utilizado" en el sistema y no podrá reutilizarse, garantizando la seguridad del evento.';
    }

    // Respuesta por defecto
    return 'Entiendo. Como tu asistente de TicketPotosí, te sugiero que explores la cartelera de eventos o accedas a la pestaña de "Mis Tickets" si ya realizaste una compra. ¿Tienes alguna consulta específica sobre algún evento?';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.psychology_rounded, color: AppColors.primary, size: 24),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Potosí AI',
                  style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Asistente Virtual 🤖',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // Mensajes de chat
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              itemCount: _messages.length,
              itemBuilder: (ctx, i) {
                final msg = _messages[i];
                final isUser = msg['isUser'] == true;
                return _buildMessageBubble(msg['text'], isUser);
              },
            ),
          ),

          // Sugerencias rápidas (solo visibles cuando la IA no está escribiendo)
          if (!_isTyping && _messages.length < 5) _buildSuggestionsList(),

          // Indicador de "escribiendo..."
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 10),
              child: Row(
                children: [
                  Text(
                    'Potosí AI está escribiendo...',
                    style: TextStyle(color: AppColors.primary.withOpacity(0.7), fontSize: 12, fontStyle: FontStyle.italic),
                  ),
                ],
              ),
            ),

          // Campo de entrada
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(String text, bool isUser) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isUser ? AppColors.primary : AppColors.card,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: isUser ? null : Border.all(color: AppColors.cardBorder, width: 1.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white,
            fontSize: 14,
            height: 1.4,
            fontWeight: isUser ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildSuggestionsList() {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestions.length,
        itemBuilder: (ctx, i) {
          return GestureDetector(
            onTap: () => _handleSendMessage(_suggestions[i].substring(4)),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Center(
                child: Text(
                  _suggestions[i],
                  style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Pregúntale a Potosí AI...',
                hintStyle: TextStyle(color: AppColors.textMuted, fontSize: 13),
                filled: true,
                fillColor: AppColors.bg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: _handleSendMessage,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => _handleSendMessage(_msgCtrl.text),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
