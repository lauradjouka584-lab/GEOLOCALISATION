import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// File d'attente des positions pas encore envoyees (stockee sur le telephone)
class OfflineQueue {
  static const String _key = 'pending_positions';

  // Nombre de positions en attente (les ecrans l'ecoutent)
  static final ValueNotifier<int> count = ValueNotifier<int>(0);

  // Lit la file sur l'appareil
  static Future<List<Map<String, dynamic>>> read() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  // Ecrit la file et met a jour le compteur
  static Future<void> _write(List<Map<String, dynamic>> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items));
    count.value = items.length;
  }

  // Au demarrage : recompte ce qui est en attente
  static Future<void> init() async {
    count.value = (await read()).length;
  }

  // Ajoute des positions (sans doublon : meme client_uuid = ignore)
  static Future<void> add(List<Map<String, dynamic>> items) async {
    final all = await read();
    final known = all.map((e) => e['client_uuid']).toSet();
    for (final it in items) {
      if (!known.contains(it['client_uuid'])) all.add(it);
    }
    await _write(all);
  }

  // Retire les n premieres positions (celles qui viennent d'etre envoyees)
  static Future<void> removeFirst(int n) async {
    final all = await read();
    final k = n > all.length ? all.length : n;
    await _write(all.sublist(k));
  }

  // Vide la file (a la deconnexion)
  static Future<void> clear() => _write([]);
}