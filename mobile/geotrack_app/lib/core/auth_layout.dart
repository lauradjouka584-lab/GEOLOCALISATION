// Mise en page commune aux pages de connexion et d'inscription
import 'package:flutter/material.dart';

import 'app_colors.dart';

// Style des champs de saisie (fond lavande, coins arrondis, pas de bordure)
InputDecoration authFieldStyle({required String hint, required IconData icon, Widget? suffix}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.outline),
    prefixIcon: Icon(icon, color: AppColors.textSecondary),
    suffixIcon: suffix,
    filled: true,
    fillColor: AppColors.field,
    contentPadding: const EdgeInsets.symmetric(vertical: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(   // bordure bleue quand on tape dans le champ
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primary, width: 2),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.error, width: 2),
    ),
  );
}

// Le petit texte au-dessus d'un champ ("Adresse courriel", "Mot de passe"...)
class AuthLabel extends StatelessWidget {
  const AuthLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text),
    );
  }
}

// La page complète : logo, titre, carte blanche (le formulaire) et lien en bas
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,    // le titre de la page
    required this.form,     // le formulaire (dans la carte blanche)
    required this.footer,   // le lien du bas
  });

  final String title;
  final Widget form;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(   // permet de défiler quand le clavier s'ouvre
            padding: const EdgeInsets.all(20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),   // largeur max sur Chrome
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo (rond avec une icône, en attendant le vrai logo)
                  const Center(
                    child: CircleAvatar(
                      radius: 32,
                      backgroundColor: AppColors.tabBackground,
                      child: Icon(Icons.location_on, size: 34, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Titre
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                      color: AppColors.text,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Carte blanche avec le formulaire
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(color: Color(0x140F172A), blurRadius: 16, offset: Offset(0, 4)),
                      ],
                    ),
                    child: form,
                  ),
                  const SizedBox(height: 20),

                  // Lien du bas
                  footer,
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}