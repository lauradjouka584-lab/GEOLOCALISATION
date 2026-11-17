import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/app_colors.dart';
import '../core/app_header.dart';
import '../services/positions_service.dart';
import 'detail_screen.dart';

// Les 3 onglets de filtre
enum _Period { today, week, all }

class HistoryScreen extends StatefulWidget {
  // Quand ce nombre change, l'ecran recharge la liste
  final int refreshToken;
  const HistoryScreen({super.key, required this.refreshToken});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _all = []; // toutes les positions du serveur
  bool _loading = true;
  String? _error;
  _Period _period = _Period.today;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Recharge quand on revient sur l'onglet Historique
  @override
  void didUpdateWidget(covariant HistoryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) _load();
  }

  // Lit les positions sur le serveur
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await PositionsService.list();
      items.sort((a, b) => _date(b).compareTo(_date(a))); // recent d'abord
      if (!mounted) return;
      setState(() {
        _all = items;
        _loading = false;
      });
    } on SendException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Impossible de charger l\'historique.';
        _loading = false;
      });
    }
  }

  // Ouvre l'ecran Detail ; si la position est supprimee, on recharge
  Future<void> _open(Map<String, dynamic> m) async {
    final deleted = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => DetailScreen(position: m)),
    );
    if (deleted == true) _load();
  }

  // Date de la position, convertie en heure locale
  DateTime _date(Map<String, dynamic> m) {
    var s = (m['recorded_at'] ?? '').toString();
    // Si le serveur n'indique pas de fuseau, on suppose UTC
    final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(s);
    if (!hasZone) s = '${s}Z';
    final d = DateTime.tryParse(s) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return d.toLocal();
  }

  // Positions de l'onglet choisi
  List<Map<String, dynamic>> get _filtered {
    final now = DateTime.now();
    final startToday = DateTime(now.year, now.month, now.day);
    final startWeek = startToday.subtract(const Duration(days: 6));
    return _all.where((m) {
      final d = _date(m);
      switch (_period) {
        case _Period.today:
          return !d.isBefore(startToday);
        case _Period.week:
          return !d.isBefore(startWeek);
        case _Period.all:
          return true;
      }
    }).toList();
  }

  // Ex : "Aujourd'hui à 14:30:15", "Hier à 18:45:52", "12/11/2026 à 09:10:03"
  String _label(DateTime d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final time = '${two(d.hour)}:${two(d.minute)}:${two(d.second)}';
    if (day == today) return 'Aujourd\'hui à $time';
    if (day == today.subtract(const Duration(days: 1))) return 'Hier à $time';
    return '${two(d.day)}/${two(d.month)}/${d.year} à $time';
  }

  // Ex : Lat: 4.1028° N, Long: 9.7557° E
  String _coords(double lat, double lng) {
    final ns = lat >= 0 ? 'N' : 'S';
    final ew = lng >= 0 ? 'E' : 'O';
    return 'Lat: ${lat.abs().toStringAsFixed(4)}° $ns, Long: ${lng.abs().toStringAsFixed(4)}° $ew';
  }

  // Ex : ± 3.2 m
  String _accuracy(dynamic v) {
    if (v is! num) return 'Précision : non disponible';
    final a = v.toDouble();
    final txt = a < 10 ? a.toStringAsFixed(1) : a.toStringAsFixed(0);
    return 'Précision : ± $txt m';
  }

  // Copie les coordonnees dans le presse-papiers
  Future<void> _copy(double lat, double lng) async {
    await Clipboard.setData(
      ClipboardData(text: '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}'),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Coordonnées copiées'),
        backgroundColor: AppColors.successDark,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Column(
      children: [
        const AppHeader(subtitle: 'Historique'),
        Expanded(
          // Tirer vers le bas = recharger
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              children: [
                _titleRow(),
                const SizedBox(height: 16),
                _tabs(),
                const SizedBox(height: 16),
                if (_loading && _all.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _message(_error!, retry: true)
                else if (items.isEmpty)
                  _message('Aucune position pour cette période.')
                else
                  ...items.map(_card),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Titre + compteur + bouton actualiser
  Widget _titleRow() {
    final n = _all.length;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Historique des positions',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: AppColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$n ${n > 1 ? 'relevés synchronisés' : 'relevé synchronisé'}',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Bouton actualiser
        Material(
          color: AppColors.field,
          shape: const CircleBorder(),
          child: IconButton(
            icon: const Icon(Icons.sync, color: AppColors.primary),
            onPressed: _loading ? null : _load,
          ),
        ),
      ],
    );
  }

  // Les 3 onglets : Aujourd'hui / Cette semaine / Tout (N)
  Widget _tabs() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.tabBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _tab('Aujourd\'hui', _Period.today),
          _tab('Cette semaine', _Period.week),
          _tab('Tout (${_all.length})', _Period.all),
        ],
      ),
    );
  }

  Widget _tab(String label, _Period p) {
    final selected = _period == p;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _period = p),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            label,
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

  // Message (vide ou erreur), avec bouton reessayer si besoin
  Widget _message(String text, {bool retry = false}) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Column(
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: retry ? AppColors.error : AppColors.textSecondary,
            ),
          ),
          if (retry)
            TextButton(onPressed: _load, child: const Text('Réessayer')),
        ],
      ),
    );
  }

  // Une carte = une position (toucher = ouvrir le detail)
  Widget _card(Map<String, dynamic> m) {
    final lat = (m['latitude'] as num).toDouble();
    final lng = (m['longitude'] as num).toDouble();

    return GestureDetector(
      onTap: () => _open(m),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ligne 1 : date + badge "Envoye"
            Row(
              children: [
                const Icon(Icons.schedule, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _label(_date(m)),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.successLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Envoyé',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.successDark,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Ligne 2 : coordonnees + bouton copier
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.field,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'COORDONNÉES WGS84',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _coords(lat, lng),
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy, size: 20),
                    color: AppColors.textSecondary,
                    onPressed: () => _copy(lat, lng),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Ligne 3 : precision + lien vers le detail
            Row(
              children: [
                const Icon(Icons.gps_fixed, size: 16, color: AppColors.success),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _accuracy(m['accuracy']),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                const Text(
                  'Détails & Carte',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const Icon(Icons.chevron_right,
                    size: 18, color: AppColors.primary),
              ],
            ),
          ],
        ),
      ),
    );
  }
}