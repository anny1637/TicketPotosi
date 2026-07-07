import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io' as io;
import 'package:path_provider/path_provider.dart' as path_provider;

class ApiService {
  static const String defaultLocalhostUrl = 'http://127.0.0.1:8000/api';
  static const String defaultEmulatorUrl  = 'http://10.0.2.2:8000/api';
  static const String defaultNetworkUrl   = 'http://192.168.0.9:8000/api';
  static const Duration _timeout = Duration(seconds: 20);

  static String? _customBaseUrl;

  // ─── MOCK / DEMO MODE ─────────────────────────────────────────────────────
  static const bool useMock = true; // Activa el funcionamiento 100% offline

  static final List<Map<String, dynamic>> _mockUsers = [
    {
      'id': 1,
      'name': 'Administrador',
      'email': 'admin@ticketpotosi.com',
      'password': 'admin123',
      'phone': '70000001',
      'role_id': 1,
      'role': {'name': 'Administrador'},
      'active': true,
    },
    {
      'id': 2,
      'name': 'Juan Pérez',
      'email': 'cliente@ticketpotosi.com',
      'password': 'cliente123',
      'phone': '70000002',
      'role_id': 2,
      'role': {'name': 'Cliente'},
      'active': true,
    }
  ];

  static List<Map<String, dynamic>> _mockEvents = [];

  static List<Map<String, dynamic>> _mockTickets = [];

  static Future<void> _loadMockDataFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    
    final usersJson = prefs.getString('local_mock_users');
    if (usersJson != null) {
      try {
        final decoded = jsonDecode(usersJson) as List;
        _mockUsers.clear();
        _mockUsers.addAll(decoded.map((e) => Map<String, dynamic>.from(e as Map)));
      } catch (e) {
        debugPrint('Error loading mock users: $e');
      }
    }
    
    final eventsJson = prefs.getString('local_mock_events');
    if (eventsJson != null) {
      try {
        final decoded = jsonDecode(eventsJson) as List;
        _mockEvents = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (e) {
        debugPrint('Error loading mock events: $e');
      }
    } else {
      _mockEvents = [];
    }

    final ticketsJson = prefs.getString('local_mock_tickets');
    if (ticketsJson != null) {
      try {
        final decoded = jsonDecode(ticketsJson) as List;
        _mockTickets = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (e) {
        debugPrint('Error loading mock tickets: $e');
      }
    } else {
      _mockTickets = [];
    }
  }

  static Future<void> _saveMockUsersToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_mock_users', jsonEncode(_mockUsers));
  }

  static Future<void> _saveMockEventsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_mock_events', jsonEncode(_mockEvents));
  }

  static Future<void> _saveMockTicketsToPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('local_mock_tickets', jsonEncode(_mockTickets));
  }

  static Future<List<Map<String, dynamic>>> getNotifications(bool isAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    final key = isAdmin ? 'notifications_admin' : 'notifications_client';
    final jsonStr = prefs.getString(key);
    if (jsonStr == null) {
      return [];
    }
    try {
      final decoded = jsonDecode(jsonStr) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addNotification(bool isAdmin, String title, String desc) async {
    final prefs = await SharedPreferences.getInstance();
    final key = isAdmin ? 'notifications_admin' : 'notifications_client';
    
    List<Map<String, dynamic>> list = [];
    final jsonStr = prefs.getString(key);
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr) as List;
        list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      } catch (_) {}
    }

    list.insert(0, {
      'id': DateTime.now().millisecondsSinceEpoch,
      'title': title,
      'desc': desc,
      'time': 'Hace un momento',
      'isRead': false,
    });

    await prefs.setString(key, jsonEncode(list));
  }

  static Future<void> markNotificationsAsRead(bool isAdmin) async {
    final prefs = await SharedPreferences.getInstance();
    final key = isAdmin ? 'notifications_admin' : 'notifications_client';
    
    List<Map<String, dynamic>> list = [];
    final jsonStr = prefs.getString(key);
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr) as List;
        list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        for (var item in list) {
          item['isRead'] = true;
        }
        await prefs.setString(key, jsonEncode(list));
      } catch (_) {}
    }
  }

  static Future<void> markNotificationIdAsRead(bool isAdmin, int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = isAdmin ? 'notifications_admin' : 'notifications_client';
    
    List<Map<String, dynamic>> list = [];
    final jsonStr = prefs.getString(key);
    if (jsonStr != null) {
      try {
        final decoded = jsonDecode(jsonStr) as List;
        list = decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        final idx = list.indexWhere((n) => n['id'] == id);
        if (idx != -1) {
          list[idx]['isRead'] = true;
        }
        await prefs.setString(key, jsonEncode(list));
      } catch (_) {}
    }
  }

  static final List<Map<String, dynamic>> _mockPromotions = [
    {
      'id': 1,
      'code': 'PROMO20',
      'discount_percentage': 20,
      'status': 'active',
    },
    {
      'id': 2,
      'code': 'BIENVENIDO',
      'discount_percentage': 10,
      'status': 'active',
    }
  ];

  static final List<String> _usedPaymentTokens = [];

  // ─── Platform-aware default URL ───────────────────────────────────────────
  static String get defaultBaseUrl {
    if (!kIsWeb && io.Platform.isAndroid) return defaultNetworkUrl;
    return defaultLocalhostUrl;
  }

  // ─── Base URL management ──────────────────────────────────────────────────
  static Future<String> getBaseUrl() async {
    if (_customBaseUrl != null) return _customBaseUrl!;
    final prefs = await SharedPreferences.getInstance();
    _customBaseUrl = prefs.getString('api_base_url') ?? defaultBaseUrl;
    return _customBaseUrl!;
  }

  static Future<void> setBaseUrl(String url) async {
    final trimmed = url.trim().replaceAll(RegExp(r'/$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('api_base_url', trimmed);
    _customBaseUrl = trimmed;
  }

  static void clearUrlCache() => _customBaseUrl = null;

  static Future<String?> scanAndSaveServerIp() async {
    if (useMock) return 'http://192.168.0.9:8000/api';
    try {
      final List<io.NetworkInterface> interfaces = await io.NetworkInterface.list(
        includeLoopback: false,
        type: io.InternetAddressType.IPv4,
      );

      String? activeSubnet;
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') || ip.startsWith('10.')) {
            final parts = ip.split('.');
            activeSubnet = '${parts[0]}.${parts[1]}.${parts[2]}';
            break;
          }
        }
        if (activeSubnet != null) break;
      }

      if (activeSubnet == null) return null;

      final List<Future<String?>> tasks = [];
      final client = io.HttpClient()..connectionTimeout = const Duration(milliseconds: 300);

      for (int i = 1; i <= 254; i++) {
        final targetIp = '$activeSubnet.$i';
        tasks.add(Future(() async {
          try {
            final uri = Uri.parse('http://$targetIp:8000/api/events');
            final req = await client.getUrl(uri);
            final resp = await req.close();
            if (resp.statusCode == 200) {
              final newUrl = 'http://$targetIp:8000/api';
              await setBaseUrl(newUrl);
              return newUrl;
            }
          } catch (_) {}
          return null;
        }));
      }

      final results = await Future.wait(tasks);
      for (var res in results) {
        if (res != null) return res;
      }
    } catch (e) {
      debugPrint('[ApiService.scanAndSaveServerIp] Error: $e');
    }
    return null;
  }

  // ─── Token management ─────────────────────────────────────────────────────
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('token', token);
  }

  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('user_name');
    await prefs.remove('user_email');
    await prefs.remove('user_role');
    await prefs.remove('user_role_id');
    await prefs.remove('user_id');
  }

  static Future<void> saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    if (user.containsKey('name') && user['name'] != null) {
      await prefs.setString('user_name', user['name'].toString());
    }
    if (user.containsKey('email') && user['email'] != null) {
      await prefs.setString('user_email', user['email'].toString());
    }
    if (user.containsKey('phone') && user['phone'] != null) {
      await prefs.setString('user_phone', user['phone'].toString());
    }
    if (user.containsKey('photo') && user['photo'] != null) {
      await prefs.setString('user_photo', user['photo'].toString());
    }
    if (user.containsKey('id') && user['id'] != null) {
      await prefs.setInt('user_id', int.tryParse(user['id'].toString()) ?? 0);
    }
    
    if (user.containsKey('role_id') && user['role_id'] != null) {
      final int roleId = user['role_id'] is int
          ? user['role_id'] as int
          : (int.tryParse(user['role_id']?.toString() ?? '') ?? 2);
      await prefs.setInt('user_role_id', roleId);
      if (!user.containsKey('role') || user['role'] == null) {
        await prefs.setString('user_role', roleId == 1 ? 'Admin' : 'Cliente');
      }
    }
    
    if (user.containsKey('role') && user['role'] != null) {
      final roleName = user['role'] is Map 
          ? (user['role']['name'] ?? '')
          : user['role'].toString();
      if (roleName.isNotEmpty) {
        await prefs.setString('user_role', roleName);
      }
    }
  }

  static Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_role_id') == 1;
  }

  static Future<Map<String, String>> authHeaders() async {
    final token = await getToken();
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, String> get _jsonHeaders => const {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  static dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return {};
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return {'message': 'Respuesta inválida del servidor (${res.statusCode})'};
    }
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> forgotPassword(
      String email, String phone, String newPassword) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      return {'status': 'success', 'message': 'Contraseña restablecida correctamente.'};
    }
    final url = await getBaseUrl();
    try {
      final res = await http.post(
        Uri.parse('$url/forgot-password'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'email': email,
          'phone': phone,
          'new_password': newPassword,
        }),
      ).timeout(_timeout);
      return _decode(res) as Map<String, dynamic>;
    } on TimeoutException {
      throw Exception('El servidor no responde.');
    } catch (e) {
      debugPrint('[ApiService.forgotPassword] $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> login(String login, String password) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      final normalized = login.trim().toLowerCase();
      final user = _mockUsers.firstWhere(
        (u) => u['email'] == normalized,
        orElse: () => {
          'id': 999,
          'name': normalized.contains('admin') ? 'Administrador Potosí' : 'Cliente Demo',
          'email': normalized,
          'role_id': normalized.contains('admin') ? 1 : 2,
          'role': {'name': normalized.contains('admin') ? 'Administrador' : 'Cliente'},
          'phone': '70000000'
        },
      );
      return {
        'token': 'mock-jwt-token-xyz',
        'user': user,
      };
    }
    final url = await getBaseUrl();
    try {
      final res = await http.post(
        Uri.parse('$url/login'),
        headers: _jsonHeaders,
        body: jsonEncode({'login': login, 'password': password}),
      ).timeout(_timeout);
      return _decode(res) as Map<String, dynamic>;
    } on TimeoutException {
      throw Exception('El servidor no responde. Verifica la configuración en ⚙️');
    } catch (e) {
      debugPrint('[ApiService.login] $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> register(
      String name, String email, String password, String phone) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      final newUser = {
        'id': _mockUsers.length + 1,
        'name': name,
        'email': email,
        'phone': phone,
        'role_id': 2,
        'role': {'name': 'Cliente'},
        'active': true,
      };
      _mockUsers.add(newUser);
      await _saveMockUsersToPrefs();
      await addNotification(true, '👤 Nuevo Usuario Registrado', 'El usuario "$name" ($email) se ha registrado en la aplicación.');
      return {
        'token': 'mock-jwt-token-new',
        'user': newUser,
      };
    }
    final url = await getBaseUrl();
    try {
      final res = await http.post(
        Uri.parse('$url/register'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'name': name, 'email': email,
          'password': password, 'phone': phone,
        }),
      ).timeout(_timeout);
      return _decode(res) as Map<String, dynamic>;
    } on TimeoutException {
      throw Exception('El servidor no responde. Verifica la configuración en ⚙️');
    } catch (e) {
      debugPrint('[ApiService.register] $e');
      rethrow;
    }
  }

  static Future<void> logout() async {
    if (useMock) {
      await deleteToken();
      return;
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    try {
      await http.post(Uri.parse('$url/logout'), headers: headers).timeout(_timeout);
    } catch (e) {
      debugPrint('[ApiService.logout] $e');
    } finally {
      await deleteToken();
    }
  }

  static Future<Map<String, dynamic>> getProfile() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      final prefs = await SharedPreferences.getInstance();
      final name = prefs.getString('user_name') ?? 'Invitado Potosí';
      final email = prefs.getString('user_email') ?? 'cliente@ticketpotosi.com';
      final roleId = prefs.getInt('user_role_id') ?? 2;
      return {
        'id': prefs.getInt('user_id') ?? 2,
        'name': name,
        'email': email,
        'phone': '70000000',
        'role_id': roleId,
        'role': {'name': prefs.getString('user_role') ?? (roleId == 1 ? 'Administrador' : 'Cliente')},
      };
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/profile'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateProfile(String name, String phone, {io.File? photoFile}) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('user_name', name);
      await prefs.setString('user_phone', phone);
      final userId = prefs.getInt('user_id') ?? 2;
      
      String photoPath = prefs.getString('user_photo') ?? '';
      if (photoFile != null) {
        try {
          final appDir = await path_provider.getApplicationDocumentsDirectory();
          final String localPath = '${appDir.path}/profile_avatar_$userId.png';
          final io.File localFile = io.File(localPath);
          if (await localFile.exists()) {
            await localFile.delete();
          }
          await photoFile.copy(localPath);
          photoPath = localPath;
          await prefs.setString('user_photo', photoPath);
        } catch (e) {
          debugPrint('Error guardando avatar local persistente: $e');
          photoPath = 'local_mock_photo.png';
          await prefs.setString('user_photo', photoPath);
        }
      }
      
      return {
        'status': 'success',
        'user': {
          'name': name,
          'phone': phone,
          'photo': photoPath,
        }
      };
    }
    final url = await getBaseUrl();
    final token = await getToken();

    if (photoFile != null) {
      final request = http.MultipartRequest('POST', Uri.parse('$url/profile'));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields['_method'] = 'PUT';
      request.fields['name'] = name;
      request.fields['phone'] = phone;
      request.files.add(await http.MultipartFile.fromPath('photo', photoFile.path));

      final streamed = await request.send().timeout(const Duration(seconds: 45));
      final res = await http.Response.fromStream(streamed);
      return _decode(res) as Map<String, dynamic>;
    } else {
      final headers = await authHeaders();
      final res = await http.put(
        Uri.parse('$url/profile'),
        headers: headers,
        body: jsonEncode({'name': name, 'phone': phone}),
      ).timeout(_timeout);
      return _decode(res) as Map<String, dynamic>;
    }
  }

  static Future<Map<String, dynamic>> changePassword(
      String current, String newPass) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      return {'status': 'success', 'message': 'Contraseña cambiada con éxito.'};
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.put(
      Uri.parse('$url/change-password'),
      headers: headers,
      body: jsonEncode({'current_password': current, 'new_password': newPass}),
    ).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  // ─── EVENTS ───────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getEvents({String? category}) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _loadMockDataFromPrefs();
      if (category != null && category != 'Todos') {
        return _mockEvents.where((e) => e['category'].toString().toLowerCase() == category.toLowerCase()).toList();
      }
      return _mockEvents;
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final uri = Uri.parse('$url/events').replace(
      queryParameters: category != null && category != 'Todos'
          ? {'category': category} : null,
    );
    try {
      final res = await http.get(uri, headers: headers).timeout(_timeout);
      final data = _decode(res);
      return data is List ? data : [];
    } on TimeoutException {
      throw Exception('Timeout al cargar eventos');
    } catch (e) {
      debugPrint('[ApiService.getEvents] $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> getEvent(int id) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      await _loadMockDataFromPrefs();
      return _mockEvents.firstWhere((e) => e['id'] == id, orElse: () => {});
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/events/$id'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createEvent(Map<String, dynamic> data,
      {io.File? imageFile, io.File? videoFile}) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadMockDataFromPrefs();
      final newId = _mockEvents.isEmpty ? 1 : (_mockEvents.map((e) => e['id'] as int).reduce((a, b) => a > b ? a : b) + 1);
      
      final List<Map<String, dynamic>> tTypes = [];
      if (data['ticket_types'] is List) {
        for (var t in (data['ticket_types'] as List)) {
          tTypes.add({
            'id': tTypes.length + newId * 10,
            'name': t['name']?.toString() ?? 'General',
            'price': double.tryParse(t['price']?.toString() ?? '50') ?? 50.0,
            'stock': int.tryParse(t['stock']?.toString() ?? '100') ?? 100
          });
        }
      } else {
        tTypes.add({'id': newId * 10 + 1, 'name': 'Entrada General', 'price': 50.0, 'stock': 100});
      }

      final newEv = {
        'id': newId,
        'title': data['title'] ?? 'Nuevo Evento',
        'description': data['description'] ?? '',
        'location': data['location'] ?? 'Potosí',
        'organizer': data['organizer'] ?? 'Gobernación de Potosí',
        'event_date': data['event_date'] ?? '2026-12-12 19:00',
        'category': data['category'] ?? 'Otros',
        'capacity': int.tryParse(data['capacity']?.toString() ?? '100') ?? 100,
        'tickets_available': int.tryParse(data['capacity']?.toString() ?? '100') ?? 100,
        'image': imageFile != null ? imageFile.path : '',
        'video': videoFile != null ? videoFile.path : '',
        'is_presale': data['presale_price'] != null,
        'ticket_types': tTypes,
        if (data['presale_price'] != null)
          'presale': {
            'start_date': data['presale_start'] ?? '',
            'end_date': data['presale_end'] ?? '',
            'presale_price': double.tryParse(data['presale_price']?.toString() ?? '') ?? 0.0,
          }
      };
      _mockEvents.add(newEv);
      await _saveMockEventsToPrefs();
      await addNotification(false, '⚡ Nuevo Evento Creado', 'Se ha publicado "${newEv['title']}" en Potosí. ¡Compra tu entrada!');
      return {'status': 'success', 'event': newEv};
    }
    final url = await getBaseUrl();
    final token = await getToken();

    final request = http.MultipartRequest('POST', Uri.parse('$url/events'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    data.forEach((key, value) {
      if (value != null) {
        if (value is List) {
          for (int i = 0; i < value.length; i++) {
            (value[i] as Map).forEach((k, v) {
              request.fields['ticket_types[$i][$k]'] = v.toString();
            });
          }
        } else {
          request.fields[key] = value.toString();
        }
      }
    });

    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }
    if (videoFile != null) {
      request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateEvent(int id, Map<String, dynamic> data,
      {io.File? imageFile, io.File? videoFile}) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 500));
      await _loadMockDataFromPrefs();
      final idx = _mockEvents.indexWhere((e) => e['id'] == id);
      if (idx != -1) {
        final List<Map<String, dynamic>> tTypes = [];
        if (data['ticket_types'] is List) {
          for (var t in (data['ticket_types'] as List)) {
            tTypes.add({
              'id': tTypes.length + id * 10,
              'name': t['name']?.toString() ?? 'General',
              'price': double.tryParse(t['price']?.toString() ?? '50') ?? 50.0,
              'stock': int.tryParse(t['stock']?.toString() ?? '100') ?? 100
            });
          }
        }

        _mockEvents[idx] = {
          ..._mockEvents[idx],
          'title': data['title'] ?? _mockEvents[idx]['title'],
          'description': data['description'] ?? _mockEvents[idx]['description'],
          'location': data['location'] ?? _mockEvents[idx]['location'],
          'organizer': data['organizer'] ?? _mockEvents[idx]['organizer'],
          'event_date': data['event_date'] ?? _mockEvents[idx]['event_date'],
          'category': data['category'] ?? _mockEvents[idx]['category'],
          'capacity': int.tryParse(data['capacity']?.toString() ?? '') ?? _mockEvents[idx]['capacity'] ?? 100,
          'tickets_available': int.tryParse(data['capacity']?.toString() ?? '') ?? _mockEvents[idx]['tickets_available'] ?? 100,
          if (imageFile != null) 'image': imageFile.path,
          if (videoFile != null) 'video': videoFile.path,
          'is_presale': data['presale_price'] != null,
          if (tTypes.isNotEmpty) 'ticket_types': tTypes,
          if (data['presale_price'] != null)
            'presale': {
              'start_date': data['presale_start'] ?? '',
              'end_date': data['presale_end'] ?? '',
              'presale_price': double.tryParse(data['presale_price']?.toString() ?? '') ?? 0.0,
            }
        };

        await _saveMockEventsToPrefs();
        return {'status': 'success', 'event': _mockEvents[idx]};
      }
      return {'status': 'error', 'message': 'Evento no encontrado'};
    }
    final url = await getBaseUrl();
    final token = await getToken();

    final request = http.MultipartRequest('POST', Uri.parse('$url/events/$id'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    request.fields['_method'] = 'PUT';

    data.forEach((key, value) {
      if (value != null) request.fields[key] = value.toString();
    });

    if (imageFile != null) {
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    }
    if (videoFile != null) {
      request.files.add(await http.MultipartFile.fromPath('video', videoFile.path));
    }

    final streamed = await request.send().timeout(const Duration(seconds: 60));
    final res = await http.Response.fromStream(streamed);
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> deleteEvent(int id) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _loadMockDataFromPrefs();
      _mockEvents.removeWhere((e) => e['id'] == id);
      await _saveMockEventsToPrefs();
      return {'status': 'success'};
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.delete(Uri.parse('$url/events/$id'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  // ─── TICKETS ──────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getMyTickets() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _loadMockDataFromPrefs();
      // Obtener el user_id del usuario autenticado actualmente
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getInt('user_id') ?? 2;
      // Filtrar solo los tickets del usuario actual
      return _mockTickets.where((t) => t['user_id'] == currentUserId).toList();
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    try {
      final res = await http.get(Uri.parse('$url/tickets/my-tickets'), headers: headers).timeout(_timeout);
      final data = _decode(res);
      return data is List ? data : [];
    } on TimeoutException {
      throw Exception('Timeout al cargar tickets');
    } catch (e) {
      debugPrint('[ApiService.getMyTickets] $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> purchaseTicket(
      int ticketTypeId, {String? promoCode, String? paymentMethod}) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      await _loadMockDataFromPrefs();
      Map<String, dynamic>? selectedType;
      Map<String, dynamic>? selectedEvent;
      for (var ev in _mockEvents) {
        final tTypes = ev['ticket_types'] as List;
        for (var t in tTypes) {
          if (t['id'] == ticketTypeId) {
            selectedType = t as Map<String, dynamic>;
            selectedEvent = ev;
            break;
          }
        }
        if (selectedType != null) break;
      }

      if (selectedType == null || selectedEvent == null) {
        return {'status': 'error', 'message': 'Tipo de ticket no válido'};
      }

      final currentAvail = selectedEvent['tickets_available'] as int;
      if (currentAvail <= 0) {
        return {'status': 'error', 'message': 'Entradas agotadas para este evento.'};
      }
      selectedEvent['tickets_available'] = currentAvail - 1;

      double basePrice = double.tryParse(selectedType['price']?.toString() ?? '0') ?? 0.0;
      double finalPrice = basePrice;
      if (promoCode != null && promoCode.isNotEmpty) {
        final promo = _mockPromotions.firstWhere(
          (p) => p['code'].toString().toUpperCase() == promoCode.trim().toUpperCase(),
          orElse: () => {},
        );
        if (promo.isNotEmpty) {
          final pct = double.tryParse(promo['discount_percentage']?.toString() ?? '0') ?? 0.0;
          finalPrice = basePrice - (basePrice * (pct / 100));
        }
      }

      final newTicketId = _mockTickets.length + 101;
      final status = (paymentMethod == 'efectivo') ? 'pending' : 'paid';
      // Leer usuario real de SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final currentUserId = prefs.getInt('user_id') ?? 2;
      final currentUserName = prefs.getString('user_name') ?? 'Cliente';
      final newTicket = {
        'id': newTicketId,
        'ticket_type_id': ticketTypeId,
        'user_id': currentUserId,
        'user_name': currentUserName,
        'qr_token': 'TICKET-POTOSI-MOCK-$newTicketId',
        'ticket_code': 'TKT-${newTicketId.toString().padLeft(6, '0')}',
        'status': status,
        'payment_method': paymentMethod ?? 'Código QR',
        'created_at': DateTime.now().toString().split(' ')[0],
        'event': {
          'id': selectedEvent['id'],
          'title': selectedEvent['title'],
          'location': selectedEvent['location'],
          'event_date': selectedEvent['event_date'],
          'organizer': selectedEvent['organizer'],
        },
        'ticket_type': {
          'id': ticketTypeId,
          'name': selectedType['name'],
          'price': finalPrice,
          'event': {
            'id': selectedEvent['id'],
            'title': selectedEvent['title'],
            'location': selectedEvent['location'],
            'event_date': selectedEvent['event_date'],
            'organizer': selectedEvent['organizer'],
          }
        }
      };
      _mockTickets.add(newTicket);
      await _saveMockEventsToPrefs();
      await _saveMockTicketsToPrefs();
      await addNotification(true, '🎟️ Entrada Vendida', 'Se ha vendido 1 entrada ${selectedType['name']} para "${selectedEvent['title']}" por $currentUserName (Total: Bs. ${finalPrice.toStringAsFixed(2)}).');
      return {'status': 'success', 'message': '¡Compra realizada con éxito!', 'ticket': newTicket};
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    try {
      final Map<String, dynamic> body = {
        'ticket_type_id': ticketTypeId,
        if (paymentMethod != null) 'payment_method': paymentMethod,
      };
      if (promoCode != null) body['promo_code'] = promoCode;
      final res = await http.post(
        Uri.parse('$url/tickets/purchase'),
        headers: headers,
        body: jsonEncode(body),
      ).timeout(_timeout);
      return _decode(res) as Map<String, dynamic>;
    } on TimeoutException {
      throw Exception('Timeout al procesar compra');
    } catch (e) {
      debugPrint('[ApiService.purchaseTicket] $e');
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> validateQR(String qrToken) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 600));
      await _loadMockDataFromPrefs();
      
      // Caso 1: Código QR de Pago interactivo
      if (qrToken.contains('PAGO-QR-')) {
        final regExp = RegExp(r'PAGO-QR-\d+');
        final match = regExp.firstMatch(qrToken);
        final token = match != null ? match.group(0)! : qrToken;

        if (_usedPaymentTokens.contains(token)) {
          return {
            'valid': false,
            'is_payment': true,
            'status': 'already_used',
            'message': 'Error: Este código QR de pago ya fue utilizado anteriormente.',
          };
        }
        
        _usedPaymentTokens.add(token);
        return {
          'valid': true,
          'is_payment': true,
          'status': 'success',
          'message': '¡PAGO VÁLIDO!\nEl pago fue verificado y registrado con éxito.',
        };
      }

      // Caso 2: Código QR de Entrada de Evento
      final idx = _mockTickets.indexWhere((t) => t['qr_token'].toString().trim() == qrToken.trim());
      if (idx != -1) {
        final ticket = _mockTickets[idx];
        if (ticket['status'] == 'Utilizado') {
          return {
            'valid': false,
            'status': 'already_used',
            'message': 'Este ticket ya fue validado en puerta y está utilizado.',
            'ticket': ticket,
          };
        }
        _mockTickets[idx]['status'] = 'Utilizado';
        await _saveMockTicketsToPrefs();
        return {
          'valid': true,
          'status': 'success',
          'message': '¡Ingreso VÁLIDO!\nCódigo QR verificado con éxito en el sistema.',
          'ticket': _mockTickets[idx],
        };
      }
      return {
        'valid': false,
        'status': 'error',
        'message': 'Código QR inválido o no reconocido por el sistema.',
      };
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.post(
      Uri.parse('$url/tickets/validate-qr'),
      headers: headers,
      body: jsonEncode({'qr_token': qrToken}),
    ).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getAllTickets() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      await _loadMockDataFromPrefs();
      return _mockTickets;
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/admin/tickets'), headers: headers).timeout(_timeout);
    final data = _decode(res);
    return data is List ? data : [];
  }

  // ─── ADMIN ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboard() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      await _loadMockDataFromPrefs();
      double revenue = 0;
      for (var t in _mockTickets) {
        final priceStr = t['ticket_type']?['price']?.toString() ?? '0';
        revenue += double.tryParse(priceStr) ?? 0.0;
      }
      
      final int usedCount = _mockTickets
          .where((t) => t['status'] == 'Utilizado' || t['status'] == 'used')
          .length;

      final List<Map<String, dynamic>> recent = [];
      for (var ev in _mockEvents.take(3)) {
        final sold = _mockTickets.where((t) => t['ticket_type']?['event']?['id'] == ev['id']).length;
        recent.add({
          'id': ev['id'],
          'title': ev['title'],
          'location': ev['location'],
          'tickets_sold': sold,
        });
      }

      final List<Map<String, dynamic>> salesByDayMock = [];
      final now = DateTime.now();
      for (int i = 6; i >= 0; i--) {
        final dateStr = now.subtract(Duration(days: i)).toIso8601String().substring(0, 10);
        final count = _mockTickets.where((t) => t['created_at'].toString().startsWith(dateStr)).length;
        salesByDayMock.add({
          'date': dateStr,
          'total': count,
        });
      }

      return {
        'total_tickets': _mockTickets.length,
        'total_tickets_sold': _mockTickets.length,
        'used_tickets': usedCount,
        'total_revenue': revenue,
        'total_events': _mockEvents.length,
        'total_users': _mockUsers.length,
        'recent_events': recent,
        'sales_by_day': salesByDayMock,
      };
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/admin/dashboard'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getUsers() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _mockUsers;
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/admin/users'), headers: headers).timeout(_timeout);
    final data = _decode(res);
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> toggleUserStatus(int userId) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      final idx = _mockUsers.indexWhere((u) => u['id'] == userId);
      if (idx != -1) {
        final currentActive = _mockUsers[idx]['active'] ?? true;
        _mockUsers[idx]['active'] = !currentActive;
        return {
          'status': 'success',
          'message': 'Estado del usuario actualizado correctamente.',
          'user': _mockUsers[idx],
        };
      }
      return {'status': 'error', 'message': 'Usuario no encontrado'};
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.put(
      Uri.parse('$url/admin/users/$userId/toggle'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  // ─── PROMOCIONES ──────────────────────────────────────────────────────────
  static Future<List<dynamic>> getActivePromotions() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _mockPromotions;
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/promotions/active'), headers: headers).timeout(_timeout);
    final data = _decode(res);
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> validatePromoCode(String code) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      final codeUpper = code.trim().toUpperCase();
      final promo = _mockPromotions.firstWhere(
        (p) => p['code'].toString().toUpperCase() == codeUpper,
        orElse: () => {},
      );
      if (promo.isNotEmpty) {
        return {
          'status': 'valid',
          'promo_code': promo,
          'message': 'Código promocional aplicado con éxito.'
        };
      }
      return {
        'status': 'invalid',
        'message': 'Código promocional no válido o vencido.'
      };
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.post(
      Uri.parse('$url/promotions/validate'),
      headers: headers,
      body: jsonEncode({'code': code}),
    ).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getAdminPromotions() async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      return _mockPromotions;
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/admin/promotions'), headers: headers).timeout(_timeout);
    final data = _decode(res);
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> createPromotion(Map<String, dynamic> data) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      final newId = _mockPromotions.length + 1;
      final newPromo = {
        'id': newId,
        'code': data['code']?.toString().toUpperCase() ?? 'NUEVAPROMO',
        'discount_percentage': int.tryParse(data['discount_percentage']?.toString() ?? '10') ?? 10,
        'status': 'active',
      };
      _mockPromotions.add(newPromo);
      return {'status': 'success', 'promotion': newPromo};
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.post(
      Uri.parse('$url/admin/promotions'),
      headers: headers,
      body: jsonEncode(data),
    ).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> deletePromotion(int id) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      _mockPromotions.removeWhere((p) => p['id'] == id);
      return {'status': 'success'};
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.delete(Uri.parse('$url/admin/promotions/$id'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  // ─── REPORTES ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getGeneralReport({String? timeframe}) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 300));
      
      // Filtrar tickets por fecha si es necesario
      List<Map<String, dynamic>> filteredTickets = List.from(_mockTickets);
      final now = DateTime.now();

      if (timeframe == 'week') {
        filteredTickets = _mockTickets.where((t) {
          try {
            final date = DateTime.parse(t['created_at'].toString());
            return now.difference(date).inDays <= 7;
          } catch (_) {
            return true;
          }
        }).toList();
      } else if (timeframe == 'month') {
        filteredTickets = _mockTickets.where((t) {
          try {
            final date = DateTime.parse(t['created_at'].toString());
            return date.year == now.year && date.month == now.month;
          } catch (_) {
            return true;
          }
        }).toList();
      }

      final List<Map<String, dynamic>> report = [];
      for (var ev in _mockEvents) {
        final evTickets = filteredTickets.where((t) => t['ticket_type']?['event']?['id'] == ev['id']).toList();
        int sold = evTickets.length;
        int used = evTickets.where((t) => t['status'] == 'Utilizado' || t['status'] == 'used').length;
        double earnings = 0;
        for (var t in evTickets) {
          earnings += double.tryParse(t['ticket_type']?['price']?.toString() ?? '0') ?? 0.0;
        }
        report.add({
          'id': ev['id'],
          'title': ev['title'],
          'organizer': ev['organizer'] ?? 'Organizador',
          'tickets_sold': sold,
          'tickets_used': used,
          'revenue': earnings,
        });
      }
      return report;
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final uri = Uri.parse('$url/admin/reports/general').replace(
      queryParameters: timeframe != null ? {'timeframe': timeframe} : null,
    );
    final res = await http.get(uri, headers: headers).timeout(_timeout);
    final data = _decode(res);
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> getEventReport(int eventId, {String? timeframe}) async {
    if (useMock) {
      await Future.delayed(const Duration(milliseconds: 200));
      final ev = _mockEvents.firstWhere((e) => e['id'] == eventId, orElse: () => _mockEvents.first);
      
      List<Map<String, dynamic>> evTickets = _mockTickets
          .where((t) => t['ticket_type']?['event']?['id'] == eventId)
          .toList();

      final now = DateTime.now();
      if (timeframe == 'week') {
        evTickets = evTickets.where((t) {
          try {
            final date = DateTime.parse(t['created_at'].toString());
            return now.difference(date).inDays <= 7;
          } catch (_) {
            return true;
          }
        }).toList();
      } else if (timeframe == 'month') {
        evTickets = evTickets.where((t) {
          try {
            final date = DateTime.parse(t['created_at'].toString());
            return date.year == now.year && date.month == now.month;
          } catch (_) {
            return true;
          }
        }).toList();
      }

      int sold = evTickets.length;
      int used = evTickets.where((t) => t['status'] == 'Utilizado' || t['status'] == 'used').length;
      double earnings = 0;
      for (var t in evTickets) {
        earnings += double.tryParse(t['ticket_type']?['price']?.toString() ?? '0') ?? 0.0;
      }

      return {
        'event': ev,
        'summary': {
          'total_sold': sold,
          'total_used': used,
          'total_revenue': earnings,
        },
        'tickets': evTickets,
      };
    }
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final uri = Uri.parse('$url/admin/reports/event/$eventId').replace(
      queryParameters: timeframe != null ? {'timeframe': timeframe} : null,
    );
    final res = await http.get(
      Uri.parse('$url/admin/reports/event/$eventId'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  // ─── URL pública de media ─────────────────────────────────────────────────
  static Future<String> getMediaUrl(String path) async {
    if (useMock) return '';
    final base = await getBaseUrl();
    final serverBase = base.replaceAll('/api', '');
    return '$serverBase/storage/$path';
  }

  // ─── Compatibility alias ──────────────────────────────────────────────────
  static Future<Map<String, String>> getHeaders() => authHeaders();
}