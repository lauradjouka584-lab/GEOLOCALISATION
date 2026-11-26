import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Les reglages de l'utilisateur
class AppSettings {
  final bool autoSend; // envoi automatique actif ?
  final int intervalSeconds; // delai entre deux envois
  final bool highAccuracy; // haute precision ou economie d'energie

  const AppSettings({
    this.autoSend = false,
    this.intervalSeconds = 15,
    this.highAccuracy = true,
  });

  AppSettings copyWith({
    bool? autoSend,
    int? intervalSeconds,
    bool? highAccuracy,
  }) {
    return AppSettings(
      autoSend: autoSend ?? this.autoSend,
      intervalSeconds: intervalSeconds ?? this.intervalSeconds,
      highAccuracy: highAccuracy ?? this.highAccuracy,
    );
  }
}

class SettingsService {
  // Change a chaque sauvegarde : la carte l'ecoute pour se mettre a jour
  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  // Lit les reglages sur l'appareil
  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      autoSend: prefs.getBool('auto_send') ?? false,
      intervalSeconds: prefs.getInt('interval_s') ?? 15,
      highAccuracy: prefs.getBool('high_accuracy') ?? true,
    );
  }

  // Enregistre les reglages, puis previent ceux qui ecoutent
  static Future<void> save(AppSettings s) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_send', s.autoSend);
    await prefs.setInt('interval_s', s.intervalSeconds);
    await prefs.setBool('high_accuracy', s.highAccuracy);
    changes.value++;
  }

  // Ex : 5 -> "5 s", 60 -> "1 min"
  static String intervalLabel(int seconds) {
    if (seconds < 60) return '$seconds s';
    return '${seconds ~/ 60} min';
  }
}