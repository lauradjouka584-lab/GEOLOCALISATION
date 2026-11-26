import 'package:flutter/foundation.dart';

class AppConfig {
  // Adresse du serveur en ligne
  static const String prodUrl = 'https://A-REMPLIR-APRES-DEPLOIEMENT';

  // Test sur telephone en developpement :
  // '127.0.0.1' avec le cable USB 
  static const String phoneTestIp = '127.0.0.1';

  static String get apiBaseUrl {
    // APK final (mode release) : on utilise le serveur en ligne
    if (kReleaseMode) return prodUrl;
    if (kIsWeb) return 'http://127.0.0.1:8000'; // Chrome
    if (phoneTestIp.isNotEmpty) return 'http://$phoneTestIp:8000'; // telephone
    return 'http://10.0.2.2:8000'; // emulateur Android
  }
}