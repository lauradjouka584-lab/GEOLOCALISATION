// Tout ce qui parle à l'API : inscription, connexion, profil
import 'package:dio/dio.dart';

import '../core/config.dart';
import 'token_storage.dart';

// Une erreur avec un message déjà lisible par l'utilisateur
class ApiException implements Exception {
  final String message;
  ApiException(this.message);
}

class ApiService {
  // "Singleton" : une seule instance partagée par toute l'application
  ApiService._();
  static final ApiService instance = ApiService._();

  // Dio = l'outil qui envoie les requêtes (comme un navigateur)
  final Dio _dio = Dio(BaseOptions(
    baseUrl: AppConfig.apiBaseUrl,
    connectTimeout: const Duration(seconds: 10),   // abandon après 10 s
    receiveTimeout: const Duration(seconds: 10),
    contentType: 'application/json',
  ));

  // Crée un compte (POST /register)
  Future<void> register(String email, String password) async {
    try {
      await _dio.post('/register', data: {'email': email, 'password': password});
    } on DioException catch (e) {
      throw ApiException(_errorMessage(e));
    }
  }

  // Se connecte (POST /login) et garde le jeton
  Future<void> login(String email, String password) async {
    try {
      final response = await _dio.post('/login', data: {'email': email, 'password': password});
      await TokenStorage.save(response.data['access_token'] as String);
    } on DioException catch (e) {
      throw ApiException(_errorMessage(e));
    }
  }

  // Lit le profil (GET /me) en montrant le jeton. Renvoie l'email.
  Future<String> me() async {
    final token = await TokenStorage.read();
    try {
      final response = await _dio.get(
        '/me',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      return response.data['email'] as String;
    } on DioException catch (e) {
      throw ApiException(_errorMessage(e));
    }
  }

  // Transforme une erreur technique en message en français
  String _errorMessage(DioException e) {
    final code = e.response?.statusCode;
    if (code == null) {
      return 'Impossible de joindre le serveur. Vérifiez votre connexion.';
    }
    final data = e.response?.data;
    // Le serveur renvoie déjà un message clair pour 400 et 401
    if ((code == 400 || code == 401) && data is Map && data['detail'] is String) {
      return data['detail'] as String;
    }
    if (code == 422) return 'Données invalides. Vérifiez les champs.';
    return 'Erreur du serveur ($code).';
  }
}