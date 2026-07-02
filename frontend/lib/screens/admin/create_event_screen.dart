import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
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
  final _titleCtrl    = TextEditingController();
  final _descCtrl     = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _organizerCtrl = TextEditingController();
  final _capacityCtrl = TextEditingController();

  DateTime? _eventDate;
  DateTime? _presaleStart;
  DateTime? _presaleEnd;
  final _presalePriceCtrl = TextEditingController();

  String _selectedCategory = 'General';
  String _selectedStatus   = 'active';
  File? _imageFile;
  File? _videoFile;
  bool _isLoading = false;
  bool _isEditMode = false;

  List<Map<String, dynamic>> _ticketTypes = [
    {'name': 'General', 'price': '', 'stock': ''},
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
      _titleCtrl.text     = e['title'] ?? '';
      _descCtrl.text      = e['description'] ?? '';
      _locationCtrl.text  = e['location'] ?? '';
      _organizerCtrl.text = e['organizer'] ?? 'Gobernación de Potosí';
      _capacityCtrl.text  = '${e['capacity'] ?? ''}';
      _selectedCategory   = e['category'] ?? 'General';
      _selectedStatus     = e['status'] ?? 'active';
      if (e['event_date'] != null) {
        _eventDate = DateTime.tryParse(e['event_date']);
      }
    } else {
      _organizerCtrl.text = 'Gobernación de Potosí';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose(); _descCtrl.dispose();
    _locationCtrl.dispose(); _organizerCtrl.dispose();
    _capacityCtrl.dispose(); _presalePriceCtrl.dispose();
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
          colorScheme: const ColorScheme.dark(primary: AppColors.primary),
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
            colorScheme: const ColorScheme.dark(primary: AppColors.primary),
          ),
          child: child!,
        ),
      );
      if (!mounted) return;
      final dt = DateTime(picked.year, picked.month, picked.day,
          time?.hour ?? 20, time?.minute ?? 0);
      setState(() {
        if (isEventDate) _eventDate = dt;
        else if (_presaleStart == null) _presaleStart = dt;
        else _presaleEnd = dt;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_eventDate == null) {
      _showMessage('Selecciona la fecha del evento', isError: true);
      return;
    }
    if (_ticketTypes.isEmpty) {
      _showMessage('Agrega al menos un tipo de entrada', isError: true);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final data = {
        'title':       _titleCtrl.text.trim(),
        'description': _descCtrl.text.trim(),
        'location':    _locationCtrl.text.trim(),
        'organizer':   _organizerCtrl.text.trim(),
        'category':    _selectedCategory,
        'status':      _selectedStatus,
        'event_date':  _eventDate!.toIso8601String(),
        'capacity':    _capacityCtrl.text.trim(),
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
        if (response['event'] != null || response['message'] != null) {
          _showMessage(
              _isEditMode ? 'Evento actualizado correctamente' : 'Evento creado correctamente');
          await Future.delayed(const Duration(milliseconds: 800));
          if (mounted) Navigator.pop(context, true);
        } else {
          _showMessage(response['message'] ?? 'Error al guardar', isError: true);
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
        backgroundColor: AppColors.surface,
        elevation: 0,
        title: Text(
          _isEditMode ? 'Editar Evento' : 'Crear Evento',
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
          padding: const EdgeInsets.all(16),
          children: [
            // Imagen del evento
            _buildImagePicker(),
            const SizedBox(height: 16),

            // Campos básicos
            _buildSection(
              title: '📋 Información del Evento',
              children: [
                _buildTextField(_titleCtrl, 'Título del evento',
                    Icons.title_rounded, required: true),
                const SizedBox(height: 12),
                _buildTextField(_descCtrl, 'Descripción',
                    Icons.description_rounded, maxLines: 3, required: true),
                const SizedBox(height: 12),
                _buildTextField(_locationCtrl, 'Lugar / Ubicación',
                    Icons.location_on_rounded, required: true),
                const SizedBox(height: 12),

                // Organizador
                DropdownButtonFormField<String>(
                  value: _organizers.contains(_organizerCtrl.text)
                      ? _organizerCtrl.text
                      : null,
                  decoration: _inputDecoration('Organizador', Icons.business_rounded),
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: Colors.white),
                  items: _organizers
                      .map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) => setState(() => _organizerCtrl.text = v ?? ''),
                  hint: Text('Seleccionar organizador',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                ),
                const SizedBox(height: 12),

                // Categoría
                DropdownButtonFormField<String>(
                  value: _selectedCategory,
                  decoration: _inputDecoration('Categoría', Icons.category_rounded),
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: Colors.white),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v ?? 'General'),
                ),
                const SizedBox(height: 12),

                // Estado
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: _inputDecoration('Estado', Icons.toggle_on_rounded),
                  dropdownColor: AppColors.card,
                  style: const TextStyle(color: Colors.white),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('🟢 Activo')),
                    DropdownMenuItem(value: 'inactive', child: Text('🟡 Inactivo')),
                    DropdownMenuItem(value: 'cancelled', child: Text('🔴 Cancelado')),
                  ],
                  onChanged: (v) => setState(() => _selectedStatus = v ?? 'active'),
                ),
                const SizedBox(height: 12),

                // Capacidad
                _buildTextField(_capacityCtrl, 'Capacidad total',
                    Icons.people_rounded,
                    keyboardType: TextInputType.number, required: true),
              ],
            ),
            const SizedBox(height: 16),

            // Fecha del evento
            _buildSection(
              title: '📅 Fecha y Hora',
              children: [
                GestureDetector(
                  onTap: () => _pickDate(context, isEventDate: true),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded,
                            color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _eventDate != null
                                ? '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year} ${_eventDate!.hour}:${_eventDate!.minute.toString().padLeft(2, '0')}'
                                : 'Seleccionar fecha y hora del evento',
                            style: TextStyle(
                              color: _eventDate != null
                                  ? Colors.white
                                  : AppColors.textMuted,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AppColors.textMuted),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Tipos de entrada
            _buildSection(
              title: '🎫 Tipos de Entrada',
              children: [
                ..._ticketTypes.asMap().entries.map((entry) {
                  final i = entry.key;
                  final tt = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Tipo ${i + 1}',
                                  style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13)),
                            ),
                            if (_ticketTypes.length > 1)
                              GestureDetector(
                                onTap: () => setState(() => _ticketTypes.removeAt(i)),
                                child: const Icon(Icons.remove_circle_rounded,
                                    color: AppColors.error, size: 20),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                initialValue: tt['name'],
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                decoration: _inputDecoration('Nombre', Icons.label_rounded),
                                onChanged: (v) => _ticketTypes[i]['name'] = v,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: tt['price'],
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('Precio Bs', Icons.attach_money_rounded),
                                onChanged: (v) => _ticketTypes[i]['price'] = v,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextFormField(
                                initialValue: tt['stock'],
                                style: const TextStyle(color: Colors.white, fontSize: 13),
                                keyboardType: TextInputType.number,
                                decoration: _inputDecoration('Stock', Icons.inventory_rounded),
                                onChanged: (v) => _ticketTypes[i]['stock'] = v,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
                TextButton.icon(
                  onPressed: () => setState(() => _ticketTypes.add({'name': '', 'price': '', 'stock': ''})),
                  icon: const Icon(Icons.add_rounded, color: AppColors.primary),
                  label: const Text('Agregar tipo de entrada',
                      style: TextStyle(color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Preventa
            _buildSection(
              title: '⏰ Preventa (opcional)',
              children: [
                _buildTextField(_presalePriceCtrl, 'Precio de preventa (Bs)',
                    Icons.sell_rounded, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime.now(),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _presaleStart = picked);
                        },
                        child: _dateChip(
                          _presaleStart != null
                              ? '${_presaleStart!.day}/${_presaleStart!.month}/${_presaleStart!.year}'
                              : 'Inicio preventa',
                          Icons.play_arrow_rounded,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _presaleStart ?? DateTime.now(),
                            firstDate: _presaleStart ?? DateTime.now(),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) setState(() => _presaleEnd = picked);
                        },
                        child: _dateChip(
                          _presaleEnd != null
                              ? '${_presaleEnd!.day}/${_presaleEnd!.month}/${_presaleEnd!.year}'
                              : 'Fin preventa',
                          Icons.stop_rounded,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Video promo
            _buildSection(
              title: '🎬 Video Promocional (opcional)',
              children: [
                GestureDetector(
                  onTap: _pickVideo,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _videoFile != null
                            ? AppColors.success
                            : AppColors.cardBorder,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.video_library_rounded,
                          color: _videoFile != null
                              ? AppColors.success
                              : AppColors.primary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _videoFile != null
                                ? '✅ Video seleccionado'
                                : 'Seleccionar video del evento',
                            style: TextStyle(
                              color: _videoFile != null
                                  ? AppColors.success
                                  : AppColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        const Icon(Icons.upload_rounded,
                            color: AppColors.textMuted, size: 18),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Botón guardar
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: AppColors.primary.withOpacity(0.4),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5)
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isEditMode ? Icons.save_rounded : Icons.add_circle_rounded,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isEditMode ? 'Guardar cambios' : 'Crear Evento',
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePicker() {
    return GestureDetector(
      onTap: _pickImage,
      child: Container(
        height: 180,
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _imageFile != null ? AppColors.primary : AppColors.cardBorder,
            width: _imageFile != null ? 2 : 1,
          ),
        ),
        child: _imageFile != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_photo_alternate_rounded,
                      size: 48, color: AppColors.primary.withOpacity(0.7)),
                  const SizedBox(height: 8),
                  Text('Toca para agregar imagen del evento',
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                ],
              ),
      ),
    );
  }

  Widget _buildSection({required String title, required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String label, IconData icon,
      {bool required = false, int maxLines = 1, TextInputType? keyboardType}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      validator: required
          ? (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null
          : null,
      decoration: _inputDecoration(label, icon),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 18),
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.cardBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColors.cardBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }

  Widget _dateChip(String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: AppColors.primary, size: 14),
          const SizedBox(width: 6),
          Expanded(
            child: Text(label,
                style: TextStyle(
                    color: label.contains('/')
                        ? Colors.white
                        : AppColors.textMuted,
                    fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
