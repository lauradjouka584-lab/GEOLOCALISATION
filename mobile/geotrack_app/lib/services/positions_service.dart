import 'dart:math';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';

// Erreur avec un message deja pret a afficher a l'utilisateur
class SendException implements Exception {
  final String message;
  SendException(this.message);

  @override
  String toString() => message;
}

class PositionsService {
  // Client HTTP (dio) : adresse de base + delai maximum d'attente
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
  ));

  // Fabrique un identifiant unique (format UUID v4)
  // Le serveur s'en sert pour ignorer les doublons
  static String _uuid() {
    final r = Random.secure();
    final b = List<int>.generate(16, (_) => r.nextInt(256));
    b[6] = (b[6] & 0x0f) | 0x40; // marque la version 4
    b[8] = (b[8] & 0x3f) | 0x80; // marque la variante
    String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
    final s = List.generate(16, h).join();
    return '${s.substring(0, 8)}-${s.substring(8, 12)}-${s.substring(12, 16)}-${s.substring(16, 20)}-${s.substring(20)}';
  }

  // Valeur optionnelle : renvoie null si le GPS ne la donne pas
  static double? _opt(double v, {double min = 0, double max = 1e9}) {
    if (v.isNaN || v < min || v > max) return null;
    return v;
  }

  // Relit le jeton de connexion (ou arrete si absent)
  static Future<String> _token() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw SendException('Session expirée. Reconnectez-vous.');
    }
    return token;
  }

  // Transforme une erreur reseau en message simple
  static SendException _fail(DioException e) {
    final code = e.response?.statusCode;
    if (code == null) {
      return SendException('Impossible de joindre le serveur.');
    }
    if (code == 401) {
      return SendException('Session expirée. Reconnectez-vous.');
    }
    if (code == 404) {
      return SendException('Relevé introuvable.');
    }
    if (code == 422) {
      return SendException('Données invalides.');
    }
    return SendException('Erreur serveur ($code).');
  }

  // Envoie une position a POST /positions
  static Future<void> send(Position p) async {
    final token = await _token();

    final body = {
      'client_uuid': _uuid(),
      'latitude': p.latitude,
      'longitude': p.longitude,
      'accuracy': _opt(p.accuracy),
      'speed': _opt(p.speed), // en m/s
      'altitude': p.altitude.isNaN ? null : p.altitude,
      'heading': _opt(p.heading, max: 360),
      'recorded_at': p.timestamp.toUtc().toIso8601String(),
    };

    try {
      await _dio.post(
        '/positions',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw _fail(e);
    }
  }

  // Lit mes positions avec GET /positions (les plus recentes d'abord)
  static Future<List<Map<String, dynamic>>> list({int limit = 1000}) async {
    final token = await _token();
    try {
      final res = await _dio.get(
        '/positions',
        queryParameters: {'limit': limit},
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = res.data;
      // Accepte une liste directe ou un objet qui contient la liste
      final List raw = data is List
          ? data
          : (data is Map ? (data['items'] ?? data['positions'] ?? []) : []);
      return raw.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } on DioException catch (e) {
      throw _fail(e);
    }
  }

  // Supprime une position avec DELETE /positions/{id}
  static Future<void> delete(int id) async {
    final token = await _token();
    try {
      await _dio.delete(
        '/positions/$id',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw _fail(e);
    }
  }
}