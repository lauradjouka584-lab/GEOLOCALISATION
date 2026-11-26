import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../core/app_colors.dart';
import '../core/app_header.dart';
import '../services/location_service.dart';
import '../services/positions_service.dart';

// Les 3 etats du trajet
enum _TrackState { idle, recording, paused }

class TrajetScreen extends StatefulWidget {
  const TrajetScreen({super.key});

  @override
  State<TrajetScreen> createState() => _TrajetScreenState();
}

class _TrajetScreenState extends State<TrajetScreen> {
  // Centre par defaut : Douala
  static const LatLng _douala = LatLng(4.0511, 9.7679);
  // Points moins precis que 100 m ignores (apres le premier)
  static const double _maxAccuracy = 100;

  final MapController _mapController = MapController();
  StreamSubscription<Position>? _sub; // abonnement au GPS
  Timer? _timer; // chronometre

  _TrackState _state = _TrackState.idle;
  final List<Position> _points = []; // les points du trajet
  final List<String> _ids = []; // un identifiant unique par point
  double _distance = 0; // distance totale en metres
  int _seconds = 0; // duree en secondes
  bool _mapReady = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    super.dispose();
  }

  // ---------- Actions ----------

  // Demarrer : permission, premier point, puis suivi continu
  Future<void> _start() async {
    setState(() => _error = null);
    try {
      await LocationService.ensurePermission();
      final first = await LocationService.currentPosition(high: true);
      if (!mounted) return;
      setState(() => _state = _TrackState.recording);
      _addPoint(first, force: true);
      _listen();
      _startTimer();
    } on LocationException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible d\'obtenir la position.');
    }
  }

  // Ecoute le GPS
  void _listen() {
    _sub = LocationService.positionStream(high: true).listen(
      (p) {
        if (_state == _TrackState.recording) _addPoint(p);
      },
      onError: (e) {
        if (mounted) setState(() => _error = 'Signal GPS perdu.');
      },
    );
  }

  // Chronometre : +1 seconde chaque seconde
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _seconds++);
    });
  }

  // Pause : on arrete le GPS et le chronometre
  void _pause() {
    _sub?.cancel();
    _timer?.cancel();
    setState(() => _state = _TrackState.paused);
  }

  // Reprendre
  void _resume() {
    setState(() => _state = _TrackState.recording);
    _listen();
    _startTimer();
  }

  // Tout effacer
  void _reset() {
    _sub?.cancel();
    _timer?.cancel();
    if (!mounted) return;
    setState(() {
      _state = _TrackState.idle;
      _points.clear();
      _ids.clear();
      _distance = 0;
      _seconds = 0;
    });
  }

  // Ajoute un point au trajet (avec un filtre contre les petits sauts du GPS)
  void _addPoint(Position p, {bool force = false}) {
    if (!force) {
      if (p.accuracy > _maxAccuracy) return; // trop imprecis
      if (_points.isNotEmpty) {
        final last = _points.last;
        final d = Geolocator.distanceBetween(
            last.latitude, last.longitude, p.latitude, p.longitude);
        // Il faut avoir bouge d'au moins 5 m (ou la moitie de la precision)
        final minMove = p.accuracy * 0.5 > 5 ? p.accuracy * 0.5 : 5.0;
        if (d < minMove) return;
        _distance += d;
      }
    }
    if (!mounted) return;
    setState(() {
      _points.add(p);
      _ids.add(PositionsService.newUuid());
    });
    // La carte suit le point actuel
    if (_mapReady) {
      _mapController.move(
        LatLng(p.latitude, p.longitude),
        _mapController.camera.zoom,
      );
    }
  }
  // Enregistrer : envoie tous les points d'un coup (POST /positions/batch)
  Future<void> _save() async {
    if (_points.length < 2) {
      _snack('Il faut au moins 2 points.', error: true);
      return;
    }
    setState(() => _saving = true);
    try {
      final n = _points.length;
      await PositionsService.sendBatch(_points, _ids);
      _snack('$n points enregistrés ✔');
      _reset();
    } on QueuedException {
      // Pas de reseau : les points sont gardes et partiront plus tard
      _snack('Hors ligne : trajet gardé, il sera envoyé au retour du réseau.');
      _reset();
    } on SendException catch (e) {
      _snack(e.message, error: true);
    } catch (_) {
      _snack('Échec de l\'enregistrement.', error: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? AppColors.error : AppColors.successDark,
    ));
  }

  // ---------- Textes ----------

  // Ex : 850 m, 1.25 km
  String _distanceText() {
    if (_distance < 1000) return '${_distance.toStringAsFixed(0)} m';
    return '${(_distance / 1000).toStringAsFixed(2)} km';
  }

  // Ex : 05:32 ou 1:05:32
  String _durationText() {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = _seconds ~/ 3600;
    final m = (_seconds % 3600) ~/ 60;
    final s = _seconds % 60;
    return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  // Vitesse moyenne en km/h
  String _speedText() {
    if (_seconds == 0) return '0.0 km/h';
    return '${(_distance / _seconds * 3.6).toStringAsFixed(1)} km/h';
  }

  // ---------- Ecran ----------

  @override
  Widget build(BuildContext context) {
    final line = _points.map((p) => LatLng(p.latitude, p.longitude)).toList();

    return Column(
      children: [
        const AppHeader(subtitle: 'Trajet'),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Column(
            children: [
              Align(alignment: Alignment.centerLeft, child: _statusPill()),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _stat('DISTANCE', _distanceText())),
                  const SizedBox(width: 8),
                  Expanded(child: _stat('DURÉE', _durationText())),
                  const SizedBox(width: 8),
                  Expanded(child: _stat('VIT. MOY.', _speedText())),
                ],
              ),
            ],
          ),
        ),
        // Carte avec le trace
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _douala,
                  initialZoom: 16,
                  onMapReady: () => _mapReady = true,
                ),
                children: [
                  TileLayer(
                    urlTemplate:
                        'https://{s}.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
                    subdomains: const ['a', 'b', 'c'],
                    userAgentPackageName: 'com.example.geotrack_app',
                  ),
                  // Le trace (ligne bleue)
                  if (line.length >= 2)
                    PolylineLayer(polylines: [
                      Polyline(
                        points: line,
                        strokeWidth: 5,
                        color: AppColors.primary,
                      ),
                    ]),
                  if (line.isNotEmpty)
                    MarkerLayer(markers: [
                      // Depart (vert)
                      Marker(
                        point: line.first,
                        width: 28,
                        height: 28,
                        child: const Icon(Icons.flag,
                            color: AppColors.successDark, size: 28),
                      ),
                      // Position actuelle (point bleu)
                      Marker(
                        point: line.last,
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
                  const RichAttributionWidget(
                    alignment: AttributionAlignment.bottomLeft,
                    attributions: [
                      TextSourceAttribution('© OpenStreetMap contributors'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        // Boutons
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.error, fontSize: 13),
                  ),
                ),
              _controls(),
            ],
          ),
        ),
      ],
    );
  }

  // Pastille d'etat
  Widget _statusPill() {
    late String text;
    late Color bg;
    late Color fg;
    switch (_state) {
      case _TrackState.idle:
        text = 'PRÊT À DÉMARRER';
        bg = const Color(0xFFDBE1FF);
        fg = AppColors.primaryDark;
        break;
      case _TrackState.recording:
        text = 'TRACÉ EN COURS • ${_points.length} POINTS';
        bg = AppColors.successLight;
        fg = AppColors.successDark;
        break;
      case _TrackState.paused:
        text = 'EN PAUSE • ${_points.length} POINTS';
        bg = const Color(0xFFFFFBEB);
        fg = const Color(0xFF92400E);
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: fg,
        ),
      ),
    );
  }

  // Une case de chiffre (distance, duree, vitesse)
  Widget _stat(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }

  // Les boutons changent selon l'etat
  Widget _controls() {
    if (_state == _TrackState.idle) {
      return SizedBox(
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
          onPressed: _start,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Démarrer le trajet'),
        ),
      );
    }

    final recording = _state == _TrackState.recording;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 52,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: recording ? _pause : _resume,
                  icon: Icon(recording ? Icons.pause : Icons.play_arrow),
                  label: Text(recording ? 'Mettre en pause' : 'Reprendre'),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: (_saving || _points.length < 2) ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.save),
                  label: Text(_saving ? 'Envoi...' : 'Enregistrer'),
                ),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: _saving ? null : _reset,
          child: const Text(
            'Effacer le trajet',
            style: TextStyle(color: AppColors.error),
          ),
        ),
      ],
    );
  }
}