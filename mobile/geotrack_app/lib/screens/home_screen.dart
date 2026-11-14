// Cadre de l'application : les 4 onglets et la barre de navigation du bas
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_header.dart';
import '../services/token_storage.dart';
import 'login_screen.dart';
import 'map_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.email});

  final String email;   // l'email de l'utilisateur connecté

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _index = 0;   // l'onglet affiché : 0 = Carte, 1 = Trajet, 2 = Historique, 3 = Paramètres

  // Déconnexion : on efface le jeton et on revient à la connexion
  Future<void> _logout() async {
    await TokenStorage.clear();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,   // efface toutes les pages précédentes
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // IndexedStack garde tous les onglets en vie : la carte ne se recharge pas quand on change d'onglet
      body: IndexedStack(
        index: _index,
        children: [
          const MapScreen(),
          const _ComingSoon(title: 'Trajet'),
          const _ComingSoon(title: 'Historique'),
          _SettingsPlaceholder(email: widget.email, onLogout: _logout),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Colors.white,
        indicatorColor: AppColors.tabBackground,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: AppColors.primary),
            label: 'Carte',
          ),
          NavigationDestination(
            icon: Icon(Icons.route_outlined),
            selectedIcon: Icon(Icons.route, color: AppColors.primary),
            label: 'Trajet',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            selectedIcon: Icon(Icons.history, color: AppColors.primary),
            label: 'Historique',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: AppColors.primary),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}

// Page provisoire (Trajet, Historique) : sera remplacée aux jours suivants
class _ComingSoon extends StatelessWidget {
  const _ComingSoon({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AppHeader(subtitle: title),
        const Expanded(
          child: Center(
            child: Text('Bientôt disponible', style: TextStyle(color: AppColors.textSecondary)),
          ),
        ),
      ],
    );
  }
}

// Paramètres provisoires : l'email et le bouton de déconnexion
class _SettingsPlaceholder extends StatelessWidget {
  const _SettingsPlaceholder({required this.email, required this.onLogout});

  final String email;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppHeader(subtitle: 'Paramètres'),
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(email, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFFFDAD6),   // rouge clair, comme ta maquette
                  foregroundColor: AppColors.error,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}