// Tout ce qui concerne le GPS : permissions et positions
import 'package:geolocator/geolocator.dart';

// Une erreur GPS avec un message lisible par l'utilisateur
class LocationException implements Exception {
  final String message;
  LocationException(this.message);
}

class LocationService {
  // Vérifie que le GPS est actif et que l'utilisateur a donné son accord.
  // Si ce n'est pas le cas, lève une LocationException.
  static Future<void> ensurePermission() async {
    // 1) Le GPS de l'appareil est-il allumé ?
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      throw LocationException('Le GPS est désactivé. Activez la localisation.');
    }

    // 2) L'application a-t-elle la permission ?
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();   // affiche la demande à l'utilisateur
    }
    if (permission == LocationPermission.denied) {
      throw LocationException('Permission de localisation refusée.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw LocationException('Localisation bloquée. Autorisez-la dans les réglages.');
    }
  }

  // La position actuelle (une seule fois)
  static Future<Position> currentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );
  }

  // Un flux de positions : un nouvel élément à chaque déplacement d'au moins 5 mètres
  static Stream<Position> positionStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
      ),
    );
  }
}