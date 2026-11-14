import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_colors.dart';
import '../core/app_header.dart';
import '../services/location_service.dart';
import '../services/positions_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  // Centre par defaut de la carte : Douala
  static const LatLng _douala = LatLng(4.0511, 9.7679);

  final MapController _mapController = MapController(); // pilote la carte
  StreamSubscription<Position>? _sub; // abonnement au flux GPS
  Position? _position; // derniere position connue
  String? _error; // message d'erreur GPS
  bool _mapReady = false; // la carte est-elle prete ?
  bool _centered = false; // a-t-on deja centre sur moi ?
  bool _sending = false; // envoi en cours ?

  @override
  void initState() {
    super.initState();
    _startTracking();
  }

  @override
  void dispose() {
    _sub?.cancel(); // on arrete le suivi quand l'ecran disparait
    super.dispose();
  }

  // Demande la permission, puis suit la position en continu
  Future<void> _startTracking() async {
    try {
      await LocationService.ensurePermission();
      // Premiere position rapide, puis flux continu
      final first = await LocationService.currentPosition();
      _onPosition(first);
      _sub = LocationService.positionStream().listen(
        _onPosition,
        onError: (e) {
          if (mounted) setState(() => _error = 'Signal GPS perdu.');
        },
      );
    } on LocationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible d\'obtenir la position.');
    }
  }

  // Appelee a chaque nouvelle position
  void _onPosition(Position p) {
    if (!mounted) return;
    setState(() {
      _position = p;
      _error = null;
    });
    // Premier centrage automatique
    if (!_centered && _mapReady) {
      _centerOnMe();
      _centered = true;
    }
  }

  // Recentre la carte sur ma position
  void _centerOnMe() {
    final p = _position;
    if (p == null) return;
    _mapController.move(LatLng(p.latitude, p.longitude), 16);
  }

  // Petit message en bas de l'ecran (vert = ok, rouge = erreur)
  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.error : AppColors.successDark,
    ));
  }

  // Envoie la position actuelle au serveur
  Future<void> _sendPosition() async {
    final p = _position;
    if (p == null) {
      _snack('Position pas encore disponible.', error: true);
      return;
    }
    setState(() => _sending = true); // affiche le chargement
    try {
      await PositionsService.send(p);
      _snack('Position envoyée ✔');
    } on SendException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack('Échec de l\'envoi.', error: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  // Zoom avant (+1) ou arriere (-1)
  void _zoom(double delta) {
    final cam = _mapController.camera;
    _mapController.move(cam.center, cam.zoom + delta);
  }

  // Couleur de fond, couleur du point et texte selon la precision (en metres)
  (Color, Color, String) _signal() {
    final p = _position;
    if (_error != null) {
      return (const Color(0xFFFEF2F2), const Color(0xFFEF4444), 'Aucun signal');
    }
    if (p == null) {
      return (const Color(0xFFEEF2FF), AppColors.primary, 'Recherche du signal...');
    }
    if (p.accuracy <= 10) {
      return (AppColors.successLight, AppColors.success, 'Signal fort');
    }
    if (p.accuracy <= 30) {
      return (const Color(0xFFFFFBEB), const Color(0xFFF59E0B), 'Signal moyen');
    }
    return (const Color(0xFFFEF2F2), const Color(0xFFEF4444), 'Signal faible');
  }

  // Texte des coordonnees, ex : 4.0511° N, 9.7679° E
  String _coords() {
    final p = _position;
    if (p == null) return '-- ° N, -- ° E';
    final ns = p.latitude >= 0 ? 'N' : 'S';
    final ew = p.longitude >= 0 ? 'E' : 'O';
    return '${p.latitude.abs().toStringAsFixed(4)}° $ns, ${p.longitude.abs().toStringAsFixed(4)}° $ew';
  }

  @override
  Widget build(BuildContext context) {
    final p = _position;
    final me = p == null ? null : LatLng(p.latitude, p.longitude);
    final (chipBg, chipDot, chipText) = _signal();

    return Column(
      children: [
        const AppHeader(subtitle: 'Carte en direct'),
        Expanded(
          // Stack = on superpose les elements sur la carte
          child: Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _douala,
                  initialZoom: 13,
                  onMapReady: () {
                    _mapReady = true;
                    if (_position != null && !_centered) {
                      _centerOnMe();
                      _centered = true;
                    }
                  },
                ),
                children: [
                  // Les images de la carte (tuiles officielles OpenStreetMap)
                TileLayer(
                  urlTemplate: 'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.example.geotrack_app',
                ),
                  // Cercle de precision (rayon en metres)
                  if (me != null)
                    CircleLayer(circles: [
                      CircleMarker(
                        point: me,
                        radius: p!.accuracy,
                        useRadiusInMeter: true,
                        color: const Color(0x262563EB),
                        borderColor: AppColors.primary,
                        borderStrokeWidth: 1,
                      ),
                    ]),
                  // Point bleu = ma position
                  if (me != null)
                    MarkerLayer(markers: [
                      Marker(
                        point: me,
                        width: 22,
                        height: 22,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: const [
                              BoxShadow(color: Colors.black26, blurRadius: 4),
                            ],
                          ),
                        ),
                      ),
                    ]),
                  // Mention obligatoire d'OpenStreetMap
                  const RichAttributionWidget(
                    alignment: AttributionAlignment.bottomLeft,
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),

              // Pastille de signal (en haut a gauche)
              Positioned(
                top: 12,
                left: 16,
                child: Container(
                  height: 28,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: chipBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration:
                            BoxDecoration(color: chipDot, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        chipText,
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

              // Message d'erreur eventuel
              if (_error != null)
                Positioned(
                  top: 52,
                  left: 16,
                  right: 16,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
                    ),
                  ),
                ),

              // Zoom + bouton "me localiser" (en bas a droite)
              Positioned(
                right: 16,
                bottom: 24,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Column(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add),
                            onPressed: () => _zoom(1),
                          ),
                          const Divider(height: 1, indent: 8, endIndent: 8),
                          IconButton(
                            icon: const Icon(Icons.remove),
                            onPressed: () => _zoom(-1),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Material(
                      color: Colors.white,
                      shape: const CircleBorder(
                        side: BorderSide(color: Color(0xFFE2E8F0)),
                      ),
                      elevation: 2,
                      child: IconButton(
                        iconSize: 22,
                        icon: const Icon(Icons.my_location, color: AppColors.text),
                        onPressed: _centerOnMe,
                      ),
                    ),
                  ],
                ),
              ),

              // Coordonnees (en bas a gauche, au-dessus de l'attribution)
              Positioned(
                left: 16,
                bottom: 40,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Text(
                    _coords(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.text,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Barre du bas : bouton d'envoi (hors de la carte, l'attribution reste visible)
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              // Bouton desactive pendant l'envoi
              onPressed: _sending ? null : _sendPosition,
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(_sending ? 'Envoi...' : 'Envoyer ma position'),
            ),
          ),
        ),
      ],
    );
  }
}