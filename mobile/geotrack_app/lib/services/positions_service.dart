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
  // (NaN, negative ou trop grande). Le serveur accepte null.
  static double? _opt(double v, {double min = 0, double max = 1e9}) {
    if (v.isNaN || v < min || v > max) return null;
    return v;
  }

  // Envoie une position a POST /positions
  static Future<void> send(Position p) async {
    // 1. On relit le jeton de connexion
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('access_token');
    if (token == null) {
      throw SendException('Session expirée. Reconnectez-vous.');
    }

    // On prepare le corps JSON
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

    //  On envoie avec l'en-tete Authorization: Bearer <jeton>
    try {
      await _dio.post(
        '/positions',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      // 4. On traduit les erreurs en messages simples
      final code = e.response?.statusCode;
      if (code == null) {
        throw SendException('Impossible de joindre le serveur.');
      }
      if (code == 401) {
        throw SendException('Session expirée. Reconnectez-vous.');
      }
      if (code == 422) {
        throw SendException('Position refusée : données invalides.');
      }
      throw SendException('Erreur serveur ($code).');
    }
  }
}