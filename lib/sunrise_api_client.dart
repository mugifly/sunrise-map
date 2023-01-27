import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';
import 'dart:developer';

class SunriseData {
  final DateTime sunrisedAt;
  final double sunAzimuth;

  SunriseData(this.sunrisedAt, this.sunAzimuth);

  @override
  String toString() {
    return 'SunriseData{sunrisedAt: $sunrisedAt, sunAzimuth: $sunAzimuth}';
  }
}

class SunriseApiClient {
  final String _kApiBaseUrl = 'https://labs.bitmeister.jp/ohakon/api/';

  Future<SunriseData?> getSunriseData(LatLng position) async {
    final sunriseTime = await getSunriseTime(position);
    if (sunriseTime == null) {
      return null;
    }

    final sunAzimuth = await getSunPosition(position, sunriseTime);
    if (sunAzimuth == null) {
      return null;
    }

    return SunriseData(sunriseTime, sunAzimuth);
  }

  Future<DateTime?> getSunriseTime(LatLng position) async {
    // 日時を取得
    final now = DateTime.now();

    // リクエストURLを生成
    final baseURl = Uri.parse(_kApiBaseUrl);
    final params = {
      'mode': 'sun_moon_rise_set',
      'year': now.year.toString(),
      'month': now.month.toString(),
      'day': now.day.toString(),
      'lat': position.latitude.toString(),
      'lng': position.longitude.toString(),
    };
    final url = Uri.http(baseURl.authority, baseURl.path, params);

    // リクエスト
    log('Requesting... $url', name: 'SunriseApiClient/getSunriseTime');
    final response = await http.get(url);
    final document = XmlDocument.parse(response.body.toString());
    final result = document.findElements('result');
    if (result.isEmpty) {
      return null;
    }

    final riseAndSet = result.first.findElements('rise_and_set');
    if (riseAndSet.isEmpty) {
      log('Could not get rise_and_set',
          name: 'SunriseApiClient/getSunriseTime');
      return null;
    }

    // 日の出時刻 (XX:XX )を取得
    final sunriseHm = riseAndSet.first.findElements('sunrise_hm');
    if (sunriseHm.isEmpty) {
      log('Could not get sunrise_hm', name: 'SunriseApiClient/getSunriseTime');
      return null;
    }
    log('sunriseHm = $sunriseHm', name: 'SunriseApiClient/getSunriseTime');

    // 日の出時刻をDateTimeに変換
    final sunriseTime = DateFormat('yyyy-M-d HH:mm')
        .parse('${now.year}-${now.month}-${now.day} ${sunriseHm.first.text}');
    return sunriseTime;
  }

  Future<double?> getSunPosition(LatLng position, DateTime? time) async {
    // 日時を取得
    final time_ = (time == null) ? DateTime.now() : time;

    // リクエストURLを生成
    final baseURl = Uri.parse(_kApiBaseUrl);
    final params = {
      'mode': 'sun_moon_positions',
      'year': time_.year.toString(),
      'month': time_.month.toString(),
      'day': time_.day.toString(),
      'hour': (time_.hour + (time_.minute / 60)).toString(),
      'lat': position.latitude.toString(),
      'lng': position.longitude.toString(),
    };
    final url = Uri.http(baseURl.authority, baseURl.path, params);

    // リクエスト
    log('Requesting... $url', name: 'SunriseApiClient/getSunPosition');
    final response = await http.get(url);
    final document = XmlDocument.parse(response.body.toString());
    final result = document.findElements('result');
    if (result.isEmpty) {
      return null;
    }

    final positions = result.first.findElements('positions');
    if (positions.isEmpty) {
      log('Could not get positions', name: 'SunriseApiClient/getSunPosition');
      return null;
    }

    // 太陽の角度を取得
    final sunAzimuth = positions.first.findElements('sun_azimuth');
    final sunAltitude = positions.first.findElements('sun_altitude');
    if (sunAzimuth.isEmpty || sunAltitude.isEmpty) {
      log('Could not get sun_azimuth', name: 'SunriseApiClient/getSunPosition');
      return null;
    }
    log('sunAzimuth = $sunAzimuth', name: 'SunriseApiClient/getSunPosition');

    return double.parse(sunAzimuth.first.text);
  }
}
