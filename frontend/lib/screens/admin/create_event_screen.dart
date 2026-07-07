import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:video_player/video_player.dart';
import '../../services/api_service.dart';
import '../../main.dart' show AppColors;

class CreateEventScreen extends StatefulWidget {
  final Map<String, dynamic>? eventData; // null = crear, data = editar

  const CreateEventScreen({super.key, this.eventData});

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _customLocationCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();
  final _presalePriceCtrl = TextEditingController();

  DateTime? _eventDate;
  DateTime? _presaleStart;
  DateTime? _presaleEnd;

  String _selectedLocation = 'Teatro IV Centenario';
  String _selectedOrganizer = 'Gobernación de Potosí';
  String _selectedCategory = 'General';
  String _selectedStatus = 'active';
  String _selectedMediaPref = 'all';

  File? _imageFile;
  File? _videoFile;
  bool _isLoading = false;
  bool _isEditMode = false;

  List<Map<String, dynamic>> _ticketTypes = [
    {'name': 'General', 'price': '', 'stock': ''},
  ];

  final List<String> _locations = [
    'Teatro IV Centenario',
    'Teatro Municipal de Potosí',
    'Coliseo Ciudad de Potosí',
    'Estadio Víctor Agustín Ugarte',
    'Plaza Principal 10 de Noviembre',
    'Centro Cultural IV Centenario',
    'Casa Nacional de Moneda',
    'Campo Ferial Cantumarca',
    'Campo Ferial de la Avenida Sevilla',
    'Otro (Escribir ubicación)',
  ];

  final List<String> _categories = [
    'General', 'Conciertos', 'Deportes', 'Teatro', 'Festivales',
    'Cultura', 'Gastronomía', 'Educación',
  ];

  final List<String> _organizers = [
    'Gobernación de Potosí',
    'Alcaldía de Potosí',
    'Universidad Autónoma Tomás Frías',
    'Ministerio de Culturas',
    'Empresa Privada',
    'Organización Independiente',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.eventData != null) {
      _isEditMode = true;
      final e = widget.eventData!;
      _titleCtrl.text = e['title'] ?? '';
      _descCtrl.text = e['description'] ?? '';
      _capacityCtrl.text = '${e['capacity'] ?? ''}';
      _selectedCategory = e['category'] ?? 'General';
      _selectedStatus = e['status'] ?? 'active';
      _selectedMediaPref = e['media_preference'] ?? 'all';

      final loc = e['location'] ?? '';
      if (_locations.contains(loc)) {
        _selectedLocation = loc;
      } else {
        _selectedLocation = 'Otro (Escribir ubicación)';
        _customLocationCtrl.text = loc;
      }

      final org = e['organizer'] ?? 'Gobernación de Potosí';
      if (_organizers.contains(org)) {
        _selectedOrganizer = org;
      } else {
        _selectedOrganizer = 'Gobernación de Potosí';
      }

      if (e['event_date'] != null) {
        _eventDate = DateTime.tryParse(e['event_date']);
      }

      if (e['presale_price'] != null) {
        _presalePriceCtrl.text = '${e['presale_price']}';
      }
      if (e['presale_start'] != null) {
        _presaleStart = DateTime.tryParse(e['presale_start']);
      }
      if (e['presale_end'] != null) {
        _presaleEnd = DateTime.tryParse(e['presale_end']);
      }

      if (e['ticket_types'] != null) {
        final rawTypes = e['ticket_types'] as List;
        _ticketTypes = rawTypes.map((t) => {
          'name': t['name'] ?? '',
          'price': '${t['price'] ?? ''}',
          'stock': '${t['stock'] ?? ''}',
        }).toList();
      }
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _customLocationCtrl.dispose();
    _capacityCtrl.dispose();
    _presalePriceCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<void> _pickVideo() async {
    final picker = ImagePicker();
    final picked = await picker.pickVideo(source: ImageSource.gallery);
    if (picked != null) setState(() => _videoFile = File(picked.path));
  }

  Future<void> _pickDate(BuildContext context, {required bool isEventDate}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFF0294E3)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
        builder: (ctx, child) => Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(primary: Color(0xFF0294E3)),
          ),
          child: child!,
        ),
      );
      if (!mounted) return;
      final dt = DateTime(picked.year, picked.month, picked.day,
          time?.hour ?? 20, time?.minute ?? 0);
      setState(() {
        if (isEventDate) {
          _eventDate = dt;
        }
      });
    }
  }

  Future<void> _pickPresaleDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2030),
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: Color(0xFF0294E3)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _presaleStart = picked;
        } else {
          _presaleEnd = picked;
        }
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_eventDate == null) {
      _showMessage('Selecciona la fecha del evento', isError: true);
      return;
    }

    final finalLoc = _selectedLocation == 'Otro (Escribir ubicación)'
        ? _customLocationCtrl.text.trim()
        : _selectedLocation;

    if (finalLoc.isEmpty) {
      _showMessage('Especifica la ubicación del evento', isError: true);
      return;
    }

    if (_ticketTypes.isEmpty) {
      _showMessage('Agrega al menos un tipo de entrada', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'title': _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'location': finalLoc,
        'organizer': _selectedOrganizer,
        'category': _selectedCategory,
        'status': _selectedStatus,
        'media_preference': _selectedMediaPref,
        'event_date': _eventDate!.toIso8601String(),
        'capacity': _capacityCtrl.text.trim(),
        'ticket_types': _ticketTypes,
        if (_presaleStart != null && _presaleEnd != null &&
            _presalePriceCtrl.text.isNotEmpty) ...{
          'presale_start': _presaleStart!.toIso8601String(),
          'presale_end':   _presaleEnd!.toIso8601String(),
          'presale_price': _presalePriceCtrl.text.trim(),
        },
      };

      Map<String, dynamic> response;
      if (_isEditMode) {
        response = await ApiService.updateEvent(
          widget.eventData!['id'],
          data,
          imageFile: _imageFile,
          videoFile: _videoFile,
        );
      } else {
        response = await ApiService.createEvent(data,
            imageFile: _imageFile, videoFile: _videoFile);
      }

      if (mounted) {
        if (response['event'] != null) {
          _showMessage(
              _isEditMode ? 'Evento actualizado correctamente' : 'Evento creado correctamente');
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) Navigator.pop(context, true);
        } else {
          _showMessage(response['message'] ?? 'Error al guardar el evento', isError: true);
        }
      }
    } catch (e) {
      _showMessage('Error de conexión: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        title: Text(
          _isEditMode ? 'Editar Evento' : 'Nuevo Evento',
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _buildFieldTitle('Título del evento'),
            TextFormField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration(hint: 'Concierto de Gala'),
              validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
            ),

            _buildFieldTitle('Descripción'),
            TextFormField(
              controller: _descCtrl,
              maxLines: 4,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration(hint: 'Escribe detalles sobre el evento...'),
              validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null,
            ),

            _buildFieldTitle('Ubicación / Lugar'),
            _buildDropdownField<String>(
              value: _selectedLocation,
              items: _locations.map((loc) => DropdownMenuItem(value: loc, child: Text(loc))).toList(),
              onChanged: (v) => setState(() => _selectedLocation = v ?? ''),
            ),

            if (_selectedLocation == 'Otro (Escribir ubicación)') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _customLocationCtrl,
                style: const TextStyle(color: Colors.white, fontSize: 14),
                decoration: _inputDecoration(hint: 'Escribe el lugar personalizado'),
                validator: (v) => (v == null || v.isEmpty) ? 'Especifica la ubicación' : null,
              ),
            ],

            _buildFieldTitle('Organizador'),
            _buildDropdownField<String>(
              value: _selectedOrganizer,
              items: _organizers.map((org) => DropdownMenuItem(value: org, child: Text(org))).toList(),
              onChanged: (v) => setState(() => _selectedOrganizer = v ?? ''),
            ),

            const SizedBox(height: 4),

            // Capacidad y Categoría lado a lado
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldTitle('Capacidad Total'),
                      TextFormField(
                        controller: _capacityCtrl,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        decoration: _inputDecoration(hint: '500'),
                        validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldTitle('Categoría'),
                      _buildDropdownField<String>(
                        value: _selectedCategory,
                        items: _categories.map((cat) => DropdownMenuItem(value: cat, child: Text(cat))).toList(),
                        onChanged: (v) => setState(() => _selectedCategory = v ?? 'General'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // Estado y Preferencia de Medios lado a lado
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldTitle('Estado'),
                      _buildDropdownField<String>(
                        value: _selectedStatus,
                        items: const [
                          DropdownMenuItem(value: 'active', child: Text('🟢 Activo')),
                          DropdownMenuItem(value: 'inactive', child: Text('🟡 Inactivo')),
                          DropdownMenuItem(value: 'cancelled', child: Text('🔴 Cancelado')),
                        ],
                        onChanged: (v) => setState(() => _selectedStatus = v ?? 'active'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildFieldTitle('Preferencia de Medios'),
                      _buildDropdownField<String>(
                        value: _selectedMediaPref,
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('🎬 Todo')),
                          DropdownMenuItem(value: 'photo', child: Text('🖼️ Solo Imagen')),
                          DropdownMenuItem(value: 'video', child: Text('📹 Solo Video')),
                        ],
                        onChanged: (v) => setState(() => _selectedMediaPref = v ?? 'all'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Fecha y hora card
            GestureDetector(
              onTap: () => _pickDate(context, isEventDate: true),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0294E3).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.calendar_today_rounded,
                          color: Color(0xFF0294E3), size: 22),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fecha y Hora del Evento',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _eventDate != null
                                ? '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year} ${_eventDate!.hour}:${_eventDate!.minute.toString().padLeft(2, '0')}'
                                : 'No seleccionada',
                            style: TextStyle(
                              color: _eventDate != null ? Colors.white.withOpacity(0.7) : Colors.white.withOpacity(0.4),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar_rounded, color: Colors.white, size: 22),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Subir Imagen y Video Row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.image_rounded, color: Colors.white, size: 18),
                    label: Text(_imageFile != null ? 'Imagen Lista' : 'Subir Imagen',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0294E3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _pickVideo,
                    icon: const Icon(Icons.video_library_rounded, color: Colors.white, size: 18),
                    label: Text(_videoFile != null ? 'Video Listo' : 'Subir Video',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0294E3),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),

            if (_imageFile != null) ...[
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(_imageFile!, height: 150, width: double.infinity, fit: BoxFit.cover),
              ),
            ],

            if (_videoFile != null) ...[
              const SizedBox(height: 12),
              _VideoPreview(file: _videoFile),
            ] else if (widget.eventData?['video'] != null && (widget.eventData?['video'] as String).isNotEmpty) ...[
              const SizedBox(height: 12),
              _VideoPreview(url: widget.eventData?['video'] as String),
            ],

            const SizedBox(height: 20),

            // Sección de tipos de entrada
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tipos de Entrada',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                IconButton(
                  onPressed: () => setState(() => _ticketTypes.add({'name': '', 'price': '', 'stock': ''})),
                  icon: const Icon(Icons.add_circle_rounded, color: Color(0xFF0294E3), size: 28),
                ),
              ],
            ),

            const SizedBox(height: 8),

            ..._ticketTypes.asMap().entries.map((entry) {
              final i = entry.key;
              final tt = entry.value;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        initialValue: tt['name'],
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: _inputDecoration(hint: 'General'),
                        onChanged: (v) => _ticketTypes[i]['name'] = v,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: tt['price'],
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(hint: 'Precio'),
                        onChanged: (v) => _ticketTypes[i]['price'] = v,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if (double.tryParse(v) == null || double.parse(v) < 0) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        initialValue: tt['stock'],
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        keyboardType: TextInputType.number,
                        decoration: _inputDecoration(hint: 'Stock'),
                        onChanged: (v) => _ticketTypes[i]['stock'] = v,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Requerido';
                          if (int.tryParse(v) == null || int.parse(v) < 1) return 'Inválido';
                          return null;
                        },
                      ),
                    ),
                    if (_ticketTypes.length > 1) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        icon: const Icon(Icons.delete_rounded, color: Color(0xFFE57373), size: 22),
                        onPressed: () => setState(() => _ticketTypes.removeAt(i)),
                      ),
                    ],
                  ],
                ),
              );
            }),

            const SizedBox(height: 12),

            const Text(
              'Configurar Preventa (Opcional)',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
            ),

            const SizedBox(height: 10),

            _buildFieldTitle('Precio Especial'),
            TextFormField(
              controller: _presalePriceCtrl,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: _inputDecoration(hint: '25.0'),
            ),

            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickPresaleDate(context, true),
                    child: _buildPresaleDateCard('Inicio Preventa', _presaleStart),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pickPresaleDate(context, false),
                    child: _buildPresaleDateCard('Fin Preventa', _presaleEnd),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Botón Crear Evento
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0294E3),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5)
                    : Text(
                        _isEditMode ? 'Guardar Cambios' : 'Crear Evento',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildFieldTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDropdownField<T>({
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButtonFormField<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          dropdownColor: AppColors.card,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          ),
          icon: const Icon(Icons.arrow_drop_down_rounded, color: Colors.white),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 14),
      filled: true,
      fillColor: AppColors.card,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0294E3), width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _buildPresaleDateCard(String title, DateTime? date) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11)),
          const SizedBox(height: 4),
          Text(
            date != null ? '${date.day}/${date.month}/${date.year}' : '—',
            style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final File? file;
  final String? url;
  const _VideoPreview({super.key, this.file, this.url});

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant _VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.file != oldWidget.file || widget.url != oldWidget.url) {
      _isInitialized = false;
      _controller?.dispose();
      _initController();
    }
  }

  Future<void> _initController() async {
    try {
      if (widget.file != null) {
        _controller = VideoPlayerController.file(widget.file!);
      } else if (widget.url != null) {
        final baseUrl = await ApiService.getBaseUrl();
        final cleanBaseUrl = baseUrl.replaceAll('/api', '');
        final fullUrl = '$cleanBaseUrl/storage/${widget.url}';
        _controller = VideoPlayerController.networkUrl(Uri.parse(fullUrl));
      } else {
        return;
      }

      await _controller!.initialize();
      if (mounted) {
        setState(() {
          _isInitialized = true;
          _hasError = false;
        });
      }
    } catch (e) {
      debugPrint('Error inicializando video preview: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 28),
              SizedBox(height: 6),
              Text(
                'No se pudo cargar la vista previa del video',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isInitialized) {
      return Container(
        height: 150,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF0294E3)),
        ),
      );
    }

    final controller = _controller!;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  VideoPlayer(controller),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        controller.value.isPlaying
                            ? controller.pause()
                            : controller.play();
                      });
                    },
                    icon: Icon(
                      controller.value.isPlaying
                          ? Icons.pause_circle_filled_rounded
                          : Icons.play_circle_filled_rounded,
                      size: 45,
                      color: Colors.white.withOpacity(0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.video_file_rounded, color: Color(0xFF0294E3), size: 16),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.file != null
                        ? widget.file!.path.split(Platform.isWindows ? '\\' : '/').last
                        : widget.url!.split('/').last,
                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
