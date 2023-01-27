import 'package:google_maps_flutter/google_maps_flutter.dart';

class SunriseData {
  final DateTime sunrisedAt;
  final double sunAzimuth;
  final double sunAltitude;
  final LatLng currentPosition;

  SunriseData(
      this.currentPosition, this.sunrisedAt, this.sunAzimuth, this.sunAltitude);

  @override
  String toString() {
    return 'SunriseData{sunrisedAt: $sunrisedAt, sunAzimuth: $sunAzimuth, sunAltitude: $sunAltitude}, currentPosition: $currentPosition';
  }
}
