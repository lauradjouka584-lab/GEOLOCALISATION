// Mémorise le jeton de connexion dans l'appareil
import 'package:shared_preferences/shared_preferences.dart';

class TokenStorage {
  static const _key = 'access_token';   // le nom sous lequel on range le jeton

  // Enregistre le jeton
  static Future<void> save(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, token);
  }

  // Lit le jeton (null s'il n'y en a pas)
  static Future<String?> read() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_key);
  }

  // Efface le jeton (déconnexion)
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}