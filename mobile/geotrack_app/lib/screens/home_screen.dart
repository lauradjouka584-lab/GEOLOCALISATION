import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_colors.dart';
import '../core/app_header.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'map_screen.dart';

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

  // Deconnexion : on efface le jeton puis retour a la connexion
  Future<void> _logout() async {
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
      // IndexedStack garde chaque onglet en vie (la carte ne se recharge pas)
      body: IndexedStack(
        index: _index,
        children: [
          const MapScreen(),
          const _ComingSoon(title: 'Trajet'),
          HistoryScreen(refreshToken: _historyToken),
          _SettingsPlaceholder(email: widget.email, onLogout: _logout),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFDBE1FF),
        onDestinationSelected: (i) => setState(() {
          _index = i;
          if (i == 2) _historyToken++; // recharge l'historique
        }),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Carte'),
          NavigationDestination(icon: Icon(Icons.route_outlined), selectedIcon: Icon(Icons.route), label: 'Trajet'),
          NavigationDestination(icon: Icon(Icons.history), selectedIcon: Icon(Icons.history), label: 'Historique'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Paramètres'),
        ],
      ),
    );
  }
}

// Page temporaire pour les ecrans pas encore faits
class _ComingSoon extends StatelessWidget {
  final String title;
  const _ComingSoon({required this.title});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(subtitle: title),
        Expanded(
          child: Center(
            child: Text(
              '$title : bientôt disponible',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
        ),
      ],
    );
  }
}

// Parametres provisoires : email + deconnexion
class _SettingsPlaceholder extends StatelessWidget {
  final String email;
  final VoidCallback onLogout;
  const _SettingsPlaceholder({required this.email, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppHeader(subtitle: 'Paramètres'),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    'Connecté : $email',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                    ),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: onLogout,
                    child: const Text('Se déconnecter'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}