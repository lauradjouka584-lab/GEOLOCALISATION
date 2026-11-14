// Point de départ de l'application GeoTrack
import 'package:flutter/material.dart';

import 'screens/startup_screen.dart';

// main() est la première fonction exécutée : elle lance l'application
void main() {
  runApp(const GeoTrackApp());
}

// Le "cadre" de toute l'application
class GeoTrackApp extends StatelessWidget {
  const GeoTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'GeoTrack',
      debugShowCheckedModeBanner: false,   // enlève le bandeau "debug"
      theme: ThemeData(
        useMaterial3: true,
        // Couleur principale de la charte : bleu #2563EB
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
      ),
      // Page de départ : l'écran qui décide où aller
      home: const StartupScreen(),
    );
  }
}