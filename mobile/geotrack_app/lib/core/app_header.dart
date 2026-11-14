// En-tête commun à toutes les pages : logo, "GeoTrack" et le nom de la page
import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key, required this.subtitle});

  final String subtitle;   // le nom de la page : "Carte", "Trajet"...

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Color(0xFFE2E8F0))),   // fine ligne grise
      ),
      child: SafeArea(
        bottom: false,   // protège l'en-tête de l'encoche du téléphone
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.tabBackground,
                child: Icon(Icons.location_on, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'GeoTrack',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.text),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}