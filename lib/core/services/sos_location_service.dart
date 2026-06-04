import 'package:geolocator/geolocator.dart';

class SosLocationCapture {
  static Future<({Position? position, String? message})> capture() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return (position: null, message: 'Konum servisi kapalı. Ayarlardan açın.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied) {
      return (position: null, message: 'Konum izni verilmedi.');
    }
    if (permission == LocationPermission.deniedForever) {
      return (position: null, message: 'Konum izni kalıcı kapalı. Uygulama ayarlarından açın.');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return (position: position, message: null);
    } catch (_) {
      return (position: null, message: 'Konum alınamadı.');
    }
  }
}

String formatSosCoordinates(double? lat, double? lng) {
  if (lat == null || lng == null) return 'Konum yok';
  return '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

String? sosMapsUrl(double? lat, double? lng) {
  if (lat == null || lng == null) return null;
  return 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
}
