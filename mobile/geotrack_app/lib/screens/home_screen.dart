import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../services/offline_queue.dart';
import '../services/positions_service.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';
import 'settings_screen.dart';
import 'trajet_screen.dart';

// Coque de l'application : 4 onglets en bas
class HomeScreen extends StatefulWidget {
  final String email;
  const HomeScreen({super.key, required this.email});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0; // onglet affiche
  int _historyToken = 0; // change a chaque ouverture de l'historique
  int _settingsToken = 0; // change a chaque ouverture des parametres
  Timer? _syncTimer; // synchronisation automatique

  @override
  void initState() {
    super.initState();
    // Au demarrage : on recompte la file d'attente, puis on essaie de l'envoyer
    OfflineQueue.init().then((_) => PositionsService.flushQueue());
    // Ensuite, toutes les 20 secondes s'il reste des positions en attente
    _syncTimer = Timer.periodic(const Duration(seconds: 20), (_) {
      if (OfflineQueue.count.value > 0) PositionsService.flushQueue();
    });
  }

  @override
  void dispose() {
    _syncTimer?.cancel();
    super.dispose();
  }

  // Deconnexion : on efface le jeton et la file d'attente, puis retour a la connexion
  // (la file est videe pour ne jamais envoyer ces positions sur un autre compte)
  Future<void> _logout() async {
    _syncTimer?.cancel();
    await OfflineQueue.clear();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('access_token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // IndexedStack garde chaque onglet en vie (le trajet continue en changeant d'onglet)
      body: IndexedStack(
        index: _index,
        children: [
          const MapScreen(),
          const TrajetScreen(),
          HistoryScreen(refreshToken: _historyToken),
          SettingsScreen(
            email: widget.email,
            onLogout: _logout,
            refreshToken: _settingsToken,
          ),
        ],
      ),
      // Bandeau jaune (si besoin) au-dessus de la barre d'onglets
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const _PendingBanner(),
          NavigationBar(
            selectedIndex: _index,
            backgroundColor: Colors.white,
            indicatorColor: const Color(0xFFDBE1FF),
            onDestinationSelected: (i) => setState(() {
              _index = i;
              if (i == 2) _historyToken++; // recharge l'historique
              if (i == 3) _settingsToken++; // recharge le nombre de positions
            }),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Carte'),
              NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'Trajet'),
              NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history), label: 'Historique'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Paramètres'),
            ],
          ),
        ],
      ),
    );
  }
}

// Bandeau "N positions en attente de synchronisation"
class _PendingBanner extends StatefulWidget {
  const _PendingBanner();

  @override
  State<_PendingBanner> createState() => _PendingBannerState();
}

class _PendingBannerState extends State<_PendingBanner> {
  bool _busy = false;

  // Bouton "Forcer" : on essaie d'envoyer tout de suite
  Future<void> _force() async {
    setState(() => _busy = true);
    final n = await PositionsService.flushQueue();
    if (!mounted) return;
    setState(() => _busy = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(n > 0
            ? '$n position(s) synchronisée(s) ✔'
            : 'Toujours hors ligne. Nouvelle tentative automatique.'),
        backgroundColor: n > 0 ? AppColors.successDark : AppColors.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Se met a jour tout seul quand le compteur change
    return ValueListenableBuilder<int>(
      valueListenable: OfflineQueue.count,
      builder: (context, n, _) {
        if (n == 0) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: const Color(0xFFFFFBEB),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              const Icon(Icons.cloud_off, size: 20, color: Color(0xFF92400E)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$n position(s) en attente de synchronisation',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF92400E),
                  ),
                ),
              ),
              TextButton(
                onPressed: _busy ? null : _force,
                child: _busy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Forcer'),
              ),
            ],
          ),
        );
      },
    );
  }
}