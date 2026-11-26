import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_header.dart';
import '../services/positions_service.dart';
import '../services/settings_service.dart';

class SettingsScreen extends StatefulWidget {
  final String email;
  final VoidCallback onLogout;
  // Quand ce nombre change, l'ecran recharge le nombre de positions
  final int refreshToken;
  const SettingsScreen({
    super.key,
    required this.email,
    required this.onLogout,
    required this.refreshToken,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Les 5 frequences proposees (en secondes)
  static const List<int> _intervals = [5, 15, 30, 60, 300];

  AppSettings _s = const AppSettings();
  int? _count; // nombre de positions sur le serveur (null = inconnu)
  bool _clearing = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadCount();
  }

  @override
  void didUpdateWidget(covariant SettingsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _loadCount();
  }

  Future<void> _loadSettings() async {
    final s = await SettingsService.load();
    if (mounted) setState(() => _s = s);
  }

  // Compte les positions du serveur
  Future<void> _loadCount() async {
    try {
      final items = await PositionsService.list();
      if (mounted) setState(() => _count = items.length);
    } catch (_) {
      if (mounted) setState(() => _count = null);
    }
  }

  // Applique et enregistre un changement de reglage
  Future<void> _update(AppSettings next) async {
    setState(() => _s = next);
    await SettingsService.save(next);
  }

  // Impact sur la batterie selon la frequence
  String _battery(int seconds) {
    switch (seconds) {
      case 5:
        return 'Consommation élevée';
      case 15:
        return 'Usage équilibré';
      case 30:
        return 'Consommation modérée';
      case 60:
        return 'Consommation faible';
      default:
        return 'Consommation très faible';
    }
  }

  // Confirmation puis suppression de toutes les positions
  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vider l\'historique ?'),
        content: const Text(
            'Toutes vos positions enregistrées seront supprimées définitivement.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Vider',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _clearing = true);
    try {
      await PositionsService.deleteAll();
      await _loadCount();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Historique vidé'),
          backgroundColor: AppColors.successDark,
        ),
      );
    } on SendException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    } finally {
      if (mounted) setState(() => _clearing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const AppHeader(subtitle: 'Paramètres'),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'CONFIGURATION SYSTÈME',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Paramètres',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Personnalisez l\'envoi de votre position et votre compte.',
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              _geoCard(),
              const SizedBox(height: 16),
              _accountCard(),
              const SizedBox(height: 16),
              // Bouton de deconnexion
              SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    backgroundColor: const Color(0xFFFEF2F2),
                    side: const BorderSide(color: Color(0xFFFECACA)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: widget.onLogout,
                  icon: const Icon(Icons.logout),
                  label: const Text('Se déconnecter'),
                ),
              ),
              const SizedBox(height: 16),
              const Center(
                child: Text(
                  'GeoTrack • version 1.0',
                  style: TextStyle(fontSize: 12, color: AppColors.outline),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Carte 1 : Geolocalisation & Envoi
  Widget _geoCard() {
    return _card(
      title: 'Géolocalisation & Envoi',
      icon: Icons.my_location,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Interrupteur d'envoi automatique
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Envoi automatique',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Envoie votre position au serveur à intervalles réguliers.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _s.autoSend,
                activeTrackColor: AppColors.primary,
                activeThumbColor: Colors.white,
                onChanged: (v) => _update(_s.copyWith(autoSend: v)),
              ),
            ],
          ),
          const Divider(height: 28),

          // Frequence d'emission
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Fréquence d\'émission',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFDBE1FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  SettingsService.intervalLabel(_s.intervalSeconds),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'Délai entre deux envois de position.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.tabBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: _intervals.map(_intervalChip).toList(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Impact batterie : ${_battery(_s.intervalSeconds)}',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const Divider(height: 28),

          // Precision du capteur
          const Text(
            'Précision du capteur',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _accuracyOption(
                  'Haute précision',
                  'GPS complet',
                  Icons.gps_fixed,
                  true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _accuracyOption(
                  'Éco-énergie',
                  'Moins précis',
                  Icons.battery_saver,
                  false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Un choix de frequence (5 s, 15 s, 30 s, 1 min, 5 min)
  Widget _intervalChip(int seconds) {
    final selected = _s.intervalSeconds == seconds;
    return Expanded(
      child: GestureDetector(
        onTap: () => _update(_s.copyWith(intervalSeconds: seconds)),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            SettingsService.intervalLabel(seconds),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  // Un choix de precision (haute ou eco)
  Widget _accuracyOption(
      String title, String sub, IconData icon, bool high) {
    final selected = _s.highAccuracy == high;
    return GestureDetector(
      onTap: () => _update(_s.copyWith(highAccuracy: high)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFFDBE1FF) : AppColors.field,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: AppColors.primary),
                const Spacer(),
                if (selected)
                  const Icon(Icons.check_circle,
                      size: 18, color: AppColors.primary),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.text,
              ),
            ),
            Text(
              sub,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Carte 2 : Compte & Stockage
  Widget _accountCard() {
    final initial =
        widget.email.isEmpty ? '?' : widget.email[0].toUpperCase();
    return _card(
      title: 'Compte & Stockage',
      icon: Icons.person_outline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Email de l'utilisateur
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFDBE1FF),
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.email,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.text,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 28),

          // Nombre de positions + bouton Vider
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'POSITIONS SUR LE SERVEUR',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _count == null ? '—' : '$_count',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.text,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: (_clearing || _count == null || _count == 0)
                    ? null
                    : _clearAll,
                child: _clearing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Vider'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Carte blanche avec un titre
  Widget _card({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}