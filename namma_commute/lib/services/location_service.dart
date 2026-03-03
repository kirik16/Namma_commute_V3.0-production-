import 'package:geolocator/geolocator.dart';

class LocationService {
  static Position? _lastPosition;

  static Future<Position?> getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;

      _lastPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return _lastPosition;
    } catch (e) {
      return _lastPosition; // return last known if fails
    }
  }

  static String formatLocation(Position pos) {
    return '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
  }

  static String nearestArea(Position? pos) {
    if (pos == null) return 'Bengaluru';
    // Simple Bengaluru area mapping
    final lat = pos.latitude;
    final lon = pos.longitude;
    if (lat > 13.0) return 'Hebbal / Yelahanka';
    if (lat > 12.97 && lon < 77.58) return 'Rajajinagar';
    if (lat > 12.97 && lon > 77.64) return 'Whitefield';
    if (lat > 12.95 && lon > 77.60) return 'Indiranagar';
    if (lat > 12.95) return 'MG Road Area';
    if (lon < 77.57) return 'Jayanagar';
    if (lon > 77.65) return 'Marathahalli';
    if (lat < 12.88) return 'Electronic City';
    return 'Koramangala';
  }
}
