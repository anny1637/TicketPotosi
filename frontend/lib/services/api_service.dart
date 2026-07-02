import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'dart:io' as io;

class ApiService {
  static const String defaultLocalhostUrl = 'http://127.0.0.1:8000/api';
  static const String defaultEmulatorUrl  = 'http://10.0.2.2:8000/api';
  // IP de tu PC en la red local (celular físico con WiFi):
  static const String defaultNetworkUrl   = 'http://192.168.0.9:8000/api';
  static const Duration _timeout = Duration(seconds: 20);

  static String? _customBaseUrl;

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

  // ─── Guardar datos del usuario ────────────────────────────────────────────
  static Future<void> saveUserData(Map<String, dynamic> user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', user['name'] ?? '');
    await prefs.setString('user_email', user['email'] ?? '');
    await prefs.setInt('user_id', user['id'] ?? 0);
    await prefs.setInt('user_role_id', user['role_id'] ?? 2);
    final roleName = user['role']?['name'] ?? (user['role_id'] == 1 ? 'Admin' : 'Cliente');
    await prefs.setString('user_role', roleName);
  }

  // ─── Verificar si es admin ────────────────────────────────────────────────
  static Future<bool> isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('user_role_id') == 1;
  }

  // ─── Headers ──────────────────────────────────────────────────────────────
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

  // ─── Safe JSON decoder ────────────────────────────────────────────────────
  static dynamic _decode(http.Response res) {
    if (res.body.isEmpty) return {};
    try {
      return jsonDecode(res.body);
    } catch (_) {
      return {'message': 'Respuesta inválida del servidor (${res.statusCode})'};
    }
  }

  // ─── AUTH ─────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> login(String login, String password) async {
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
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/profile'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> updateProfile(String name, String phone) async {
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.put(
      Uri.parse('$url/profile'),
      headers: headers,
      body: jsonEncode({'name': name, 'phone': phone}),
    ).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> changePassword(
      String current, String newPass) async {
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
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/events/$id'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<Map<String, dynamic>> createEvent(Map<String, dynamic> data,
      {io.File? imageFile, io.File? videoFile}) async {
    final url = await getBaseUrl();
    final token = await getToken();

    final request = http.MultipartRequest('POST', Uri.parse('$url/events'));
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';

    // Añadir campos de texto
    data.forEach((key, value) {
      if (value != null) {
        if (value is List) {
          // Para ticket_types array
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
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.delete(Uri.parse('$url/events/$id'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  // ─── TICKETS ──────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getMyTickets() async {
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
      int ticketTypeId, {String? promoCode}) async {
    final url = await getBaseUrl();
    final headers = await authHeaders();
    try {
      final body = {'ticket_type_id': ticketTypeId};
      if (promoCode != null) body['promo_code'] = promoCode as Object;
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
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/admin/tickets'), headers: headers).timeout(_timeout);
    final data = _decode(res);
    return data is List ? data : [];
  }

  // ─── ADMIN ────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>> getDashboard() async {
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/admin/dashboard'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  static Future<List<dynamic>> getUsers() async {
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/admin/users'), headers: headers).timeout(_timeout);
    final data = _decode(res);
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> toggleUserStatus(int userId) async {
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.put(
      Uri.parse('$url/admin/users/$userId/toggle'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  // ─── PROMOCIONES ──────────────────────────────────────────────────────────
  static Future<List<dynamic>> getActivePromotions() async {
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/promotions/active'), headers: headers).timeout(_timeout);
    final data = _decode(res);
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> validatePromoCode(String code) async {
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
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/admin/promotions'), headers: headers).timeout(_timeout);
    final data = _decode(res);
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> createPromotion(Map<String, dynamic> data) async {
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
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.delete(Uri.parse('$url/admin/promotions/$id'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  // ─── REPORTES ─────────────────────────────────────────────────────────────
  static Future<List<dynamic>> getGeneralReport() async {
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(Uri.parse('$url/admin/reports/general'), headers: headers).timeout(_timeout);
    final data = _decode(res);
    return data is List ? data : [];
  }

  static Future<Map<String, dynamic>> getEventReport(int eventId) async {
    final url = await getBaseUrl();
    final headers = await authHeaders();
    final res = await http.get(
      Uri.parse('$url/admin/reports/event/$eventId'), headers: headers).timeout(_timeout);
    return _decode(res) as Map<String, dynamic>;
  }

  // ─── URL pública de media ─────────────────────────────────────────────────
  static Future<String> getMediaUrl(String path) async {
    final base = await getBaseUrl();
    final serverBase = base.replaceAll('/api', '');
    return '$serverBase/storage/$path';
  }

  // ─── Compatibility alias ──────────────────────────────────────────────────
  static Future<Map<String, String>> getHeaders() => authHeaders();
}