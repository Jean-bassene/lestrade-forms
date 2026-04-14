// ============================================================================
// services/gps_service.dart — Capture GPS terrain
// ============================================================================

import 'package:geolocator/geolocator.dart';

class GpsResult {
  final double? latitude;
  final double? longitude;
  final double? accuracy; // mètres
  final String? error;

  bool get hasPosition => latitude != null && longitude != null;

  const GpsResult({this.latitude, this.longitude, this.accuracy, this.error});

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'gps_accuracy': accuracy,
      };
}

class GpsService {
  /// Demande la permission si nécessaire et retourne la position actuelle.
  /// Timeout 10s — ne bloque pas la soumission si le GPS est lent.
  static Future<GpsResult> getPosition() async {
    try {
      // Vérifier si le service est activé
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return const GpsResult(error: 'GPS désactivé sur cet appareil');
      }

      // Vérifier / demander la permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return const GpsResult(error: 'Permission GPS refusée');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        return const GpsResult(error: 'Permission GPS refusée définitivement');
      }

      // Obtenir la position (timeout 10s)
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      return GpsResult(
        latitude: pos.latitude,
        longitude: pos.longitude,
        accuracy: pos.accuracy,
      );
    } catch (e) {
      return GpsResult(error: e.toString());
    }
  }
}
