import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_colors.dart';
import '../services/positions_service.dart';

class DetailScreen extends StatefulWidget {
  // La position a afficher (une ligne renvoyee par le serveur)
  final Map<String, dynamic> position;
  const DetailScreen({super.key, required this.position});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  bool _deleting = false;

  Map<String, dynamic> get _m => widget.position;

  // Lit un nombre optionnel (null si absent)
  double? _num(dynamic v) => v is num ? v.toDouble() : null;

  // Convertit un texte ISO du serveur en heure locale
  DateTime _parse(dynamic raw) {
    var s = (raw ?? '').toString();
    // Si le serveur n'indique pas de fuseau, on suppose UTC
    final hasZone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$').hasMatch(s);
    if (!hasZone) s = '${s}Z';
    final d = DateTime.tryParse(s) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return d.toLocal();
  }

  String _two(int n) => n.toString().padLeft(2, '0');
  String _time(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}:${_two(d.second)}';
  String _day(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';

  // Degres-minutes-secondes : 4° 6' 10.1" N
  String _dms(double v, String pos, String neg) {
    final hemi = v >= 0 ? pos : neg;
    final a = v.abs();
    final deg = a.floor();
    final minFull = (a - deg) * 60;
    final min = minFull.floor();
    final sec = (minFull - min) * 60;
    return '$deg° $min\' ${sec.toStringAsFixed(1)}" $hemi';
  }

  // Direction a partir du cap en degres (0 = Nord, 90 = Est...)
  String _cardinal(double heading) {
    const dirs = [
      'Nord', 'Nord-Est', 'Est', 'Sud-Est',
      'Sud', 'Sud-Ouest', 'Ouest', 'Nord-Ouest'
    ];
    final i = ((heading + 22.5) / 45).floor() % 8;
    return dirs[i];
  }

  // Qualite du signal selon la precision (en metres)
  (String, Color) _quality(double? acc) {
    if (acc == null) return ('Non disponible', AppColors.textSecondary);
    if (acc <= 10) return ('Excellente', AppColors.success);
    if (acc <= 30) return ('Moyenne', const Color(0xFFF59E0B));
    return ('Faible', const Color(0xFFEF4444));
  }

  // Copie un texte dans le presse-papiers
  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copié'),
        backgroundColor: AppColors.successDark,
      ),
    );
  }

  // Demande confirmation puis supprime la position
  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce relevé ?'),
        content: const Text('Cette action est définitive.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _deleting = true);
    try {
      await PositionsService.delete((_m['id'] as num).toInt());
      if (!mounted) return;
      // true = "supprime" : l'historique se recharge
      Navigator.pop(context, true);
    } on SendException catch (e) {
      if (!mounted) return;
      setState(() => _deleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final lat = (_m['latitude'] as num).toDouble();
    final lng = (_m['longitude'] as num).toDouble();
    final acc = _num(_m['accuracy']);
    final speed = _num(_m['speed']); // en m/s
    final alt = _num(_m['altitude']);
    final heading = _num(_m['heading']);
    final when = _parse(_m['recorded_at']);
    final received = _parse(_m['created_at']);
    final (qLabel, qColor) = _quality(acc);
    final point = LatLng(lat, lng);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _header(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // --- 1. Mini-carte ---
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 220,
                    child: Stack(
                      children: [
                        FlutterMap(
                          options: MapOptions(
                            initialCenter: point,
                            initialZoom: 16,
                            // Carte fixe : evite de bloquer le defilement de la page
                            interactionOptions: const InteractionOptions(
                              flags: InteractiveFlag.none,
                            ),
                          ),
                          children: [
                            TileLayer(
                              urlTemplate:
                                  'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
                              subdomains: const ['a', 'b', 'c'],
                              userAgentPackageName: 'com.example.geotrack_app',
                            ),
                            if (acc != null)
                              CircleLayer(circles: [
                                CircleMarker(
                                  point: point,
                                  radius: acc,
                                  useRadiusInMeter: true,
                                  color: const Color(0x262563EB),
                                  borderColor: AppColors.primary,
                                  borderStrokeWidth: 1,
                                ),
                              ]),
                            MarkerLayer(markers: [
                              Marker(
                                point: point,
                                width: 22,
                                height: 22,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AppColors.primary,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                        color: Colors.white, width: 3),
                                    boxShadow: const [
                                      BoxShadow(
                                          color: Colors.black26, blurRadius: 4),
                                    ],
                                  ),
                                ),
                              ),
                            ]),
                            const RichAttributionWidget(
                              alignment: AttributionAlignment.bottomLeft,
                              attributions: [
                                TextSourceAttribution(
                                    '© OpenStreetMap contributors'),
                              ],
                            ),
                          ],
                        ),
                        // Pastille de qualite (en haut a gauche)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                      color: qColor, shape: BoxShape.circle),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Précision : $qLabel',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.text,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Numero du releve (en haut a droite)
                        Positioned(
                          top: 12,
                          right: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.text,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              'Relevé #${_m['id']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // --- 2. Telemetrie ---
                _card(
                  title: 'Télémétrie',
                  icon: Icons.show_chart,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _tile(
                              'PRÉCISION',
                              acc == null ? '—' : '± ${acc.toStringAsFixed(1)} m',
                              qLabel,
                              subColor: qColor,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _tile(
                              'VITESSE',
                              speed == null
                                  ? '—'
                                  : '${(speed * 3.6).toStringAsFixed(1)} km/h',
                              speed == null ? 'Non disponible' : 'Vitesse GPS',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _tile(
                              'ALTITUDE',
                              alt == null ? '—' : '${alt.toStringAsFixed(0)} m',
                              alt == null
                                  ? 'Non disponible'
                                  : 'Au-dessus de la mer',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _tile('HORODATAGE', _time(when), _day(when)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- 3. Coordonnees ---
                _card(
                  title: 'Coordonnées',
                  icon: Icons.location_on_outlined,
                  child: Column(
                    children: [
                      _copyRow(
                        'WGS84 DÉCIMALES',
                        '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}',
                      ),
                      const SizedBox(height: 12),
                      _copyRow(
                        'DEGRÉS MINUTES SECONDES',
                        '${_dms(lat, 'N', 'S')}, ${_dms(lng, 'E', 'O')}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- 4. Contexte ---
                _card(
                  title: 'Contexte',
                  icon: Icons.info_outline,
                  child: Column(
                    children: [
                      _infoRow(
                        'Cap',
                        heading == null
                            ? 'Non disponible'
                            : '${heading.toStringAsFixed(0)}° ${_cardinal(heading)}',
                      ),
                      const Divider(height: 24),
                      _infoRow(
                        'Reçu par le serveur',
                        '${_day(received)} à ${_time(received)}',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // --- 5. Supprimer ---
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
                    onPressed: _deleting ? null : _delete,
                    icon: _deleting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.delete_outline),
                    label: const Text('Supprimer ce relevé définitivement'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // En-tete : fleche retour + titre
  Widget _header() {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.text),
                onPressed: () => Navigator.pop(context),
              ),
              const SizedBox(width: 4),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Détail du relevé',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                    ),
                  ),
                  Text(
                    'GeoTrack',
                    style: TextStyle(
                      fontSize: 12,
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
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  // Case de telemetrie : etiquette, grande valeur, petit texte
  Widget _tile(String label, String value, String sub, {Color? subColor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.field,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            sub,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: subColor ?? AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  // Ligne de coordonnees avec bouton copier
  Widget _copyRow(String title, String value) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
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
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
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
            onPressed: () => _copy(value),
          ),
        ],
      ),
    );
  }

  // Ligne "etiquette ........ valeur"
  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ),
      ],
    );
  }
}