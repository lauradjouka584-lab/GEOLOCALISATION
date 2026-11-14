// Écran de démarrage : décide quelle page ouvrir (connexion ou page connectée)
import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../services/api_service.dart';
import '../services/token_storage.dart';
import 'home_screen.dart';
import 'login_screen.dart';

class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen> {
  // initState s'exécute une seule fois, quand l'écran apparaît
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    Widget next = const LoginScreen();   // par défaut : on affiche la connexion

    final token = await TokenStorage.read();   // y a-t-il un jeton en mémoire ?
    if (token != null) {
      try {
        // On demande au serveur si le jeton est encore valide
        final email = await ApiService.instance.me();
        next = HomeScreen(email: email);
      } on ApiException {
        // Jeton expiré ou serveur éteint : on reste sur la connexion
      }
    }

    if (!mounted) return;
    // pushReplacement : remplace cet écran (on ne peut pas revenir dessus)
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => next),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Pendant la vérification : un cercle qui tourne
    return const Scaffold(
      backgroundColor: AppColors.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }
}