import 'dart:async';
import 'dart:math';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/config.dart';
import 'offline_queue.dart';

// Erreur avec un message deja pret a afficher a l'utilisateur
class SendException implements Exception {
  final String message;
  SendException(this.message);

  @override
  String toString() => message;
}

// Cas particulier : pas de reseau, la position est gardee en attente
class QueuedException extends SendException {
  QueuedException() : super('Hors ligne : position mise en attente.');
}

class PositionsService {
  // Client HTTP (dio) : adresse de base + delai maximum d'attente
  static final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 20),
  ));

  static bool _flushing = false; // une synchronisation a la fois

  // Fabrique un identifiant unique (format UUID v4)
  // Le serveur s'en sert pour ignorer les doublons
  static String newUuid() {
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

  // Transforme une position GPS en JSON pour l'API
  static Map<String, dynamic> _toJson(Position p, String id) {
    return {
      'client_uuid': id,
      'latitude': p.latitude,
      'longitude': p.longitude,
      'accuracy': _opt(p.accuracy),
      'speed': _opt(p.speed), // en m/s
      'altitude': p.altitude.isNaN ? null : p.altitude,
      'heading': _opt(p.heading, max: 360),
      'recorded_at': p.timestamp.toUtc().toIso8601String(),
    };
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
  // Si le reseau est coupe : on la garde en attente (QueuedException)
  static Future<void> send(Position p) async {
    final token = await _token();
    final body = _toJson(p, newUuid());
    try {
      await _dio.post(
        '/positions',
        data: body,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      if (e.response == null) {
        await OfflineQueue.add([body]);
        throw QueuedException();
      }
      throw _fail(e);
    }
    // Le reseau marche : on en profite pour vider la file d'attente
    if (OfflineQueue.count.value > 0) unawaited(flushQueue());
  }

  // Envoie plusieurs positions d'un coup : POST /positions/batch
  // (500 maximum par envoi, donc on coupe en paquets)
  static Future<void> sendBatch(List<Position> ps, List<String> ids) async {
    final token = await _token();
    for (var i = 0; i < ps.length; i += 500) {
      final end = min(i + 500, ps.length);
      final body = [
        for (var j = i; j < end; j++) _toJson(ps[j], ids[j]),
      ];
      try {
        await _dio.post(
          '/positions/batch',
          data: body,
          options: Options(headers: {'Authorization': 'Bearer $token'}),
        );
      } on DioException catch (e) {
        if (e.response == null) {
          // Reseau coupe : on garde tout ce qui reste en attente
          await OfflineQueue.add([
            for (var j = i; j < ps.length; j++) _toJson(ps[j], ids[j]),
          ]);
          throw QueuedException();
        }
        throw _fail(e);
      }
    }
  }

  // Envoie la file d'attente au serveur. Renvoie le nombre de positions envoyees.
  static Future<int> flushQueue() async {
    if (_flushing) return 0;
    _flushing = true;
    var synced = 0;
    try {
      final token = await _token();
      while (true) {
        final items = await OfflineQueue.read();
        if (items.isEmpty) break;
        final chunk = items.take(500).toList();
        try {
          await _dio.post(
            '/positions/batch',
            data: chunk,
            options: Options(headers: {'Authorization': 'Bearer $token'}),
          );
        } on DioException catch (e) {
          if (e.response?.statusCode == 422) {
            // Donnees invalides : inutile de reessayer, on les retire
            await OfflineQueue.removeFirst(chunk.length);
            continue;
          }
          break; // reseau coupe ou session expiree : on reessaiera plus tard
        }
        await OfflineQueue.removeFirst(chunk.length);
        synced += chunk.length;
      }
    } on SendException {
      // pas de jeton : rien a faire
    } finally {
      _flushing = false;
    }
    return synced;
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

  // Supprime TOUTES mes positions avec DELETE /positions
  static Future<void> deleteAll() async {
    final token = await _token();
    try {
      await _dio.delete(
        '/positions',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
    } on DioException catch (e) {
      throw _fail(e);
    }
  }
}