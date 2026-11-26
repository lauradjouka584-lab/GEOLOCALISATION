import 'package:geolocator/geolocator.dart';

// Erreur avec un message deja pret a afficher a l'utilisateur
class LocationException implements Exception {
  final String message;
  LocationException(this.message);

  @override
  String toString() => message;
}

class LocationService {
  // Verifie que le GPS est actif et que la permission est accordee
  static Future<void> ensurePermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw LocationException('Le GPS est désactivé. Activez-le puis réessayez.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Affiche la fenetre "Autoriser / Bloquer"
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      throw LocationException('Permission de localisation refusée.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException(
          'Permission bloquée. Autorisez la localisation dans les réglages du navigateur ou du téléphone.');
    }
  }

  // Haute precision = GPS complet ; sinon economie d'energie (moins precis)
  static LocationAccuracy _accuracy(bool high) {
    return high ? LocationAccuracy.high : LocationAccuracy.medium;
  }

  // Une seule position, a la demande (15 s maximum d'attente)
  static Future<Position> currentPosition({bool high = true}) async {
    await ensurePermission();
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy: _accuracy(high),
        timeLimit: const Duration(seconds: 15),
      ),
    );
  }

  // Flux continu : une nouvelle position tous les 5 metres environ
  static Stream<Position> positionStream({bool high = true}) {
    return Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: _accuracy(high),
        distanceFilter: 5,
      ),
    );
  }
}