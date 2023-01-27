import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:xml/xml.dart';
import 'dart:developer';

import 'sunrise_api_cache.dart';
import 'sunrise_data.dart';

class SunPosition {
  final double azimuth;
  final double altitude;

  SunPosition(this.azimuth, this.altitude);
}

class SunriseApiClient {
  final String _kApiBaseUrl = 'https://labs.bitmeister.jp/ohakon/api/';
  final SunriseApiCache _cache = SunriseApiCache();

  Future<SunriseData?> getSunriseData(LatLng position) async {
    final date = DateTime.now();

    // キャッシュを確認
    final cachedData = await _cache.findNearCache(position, 1.0);
    if (cachedData != null) {
      log('Found cache... $cachedData',
          name: 'SunriseApiClient/getSunriseData');
      return cachedData;
    }

    // 日の出時刻を取得
    final sunriseTime = await getSunriseTime(position, date);
    if (sunriseTime == null) {
      return null;
    }

    // 日の出位置を取得
    final sunPosition = await getSunPosition(position, sunriseTime);
    if (sunPosition == null) {
      return null;
    }

    // キャッシュを保存
    final data = SunriseData(
        position, sunriseTime, sunPosition.azimuth, sunPosition.altitude);
    await _cache.save(data);

    // 完了
    return data;
  }

  Future<DateTime?> getSunriseTime(LatLng position, DateTime date) async {
    // リクエストURLを生成
    final baseURl = Uri.parse(_kApiBaseUrl);
    final params = {
      'mode': 'sun_moon_rise_set',
      'year': date.year.toString(),
      'month': date.month.toString(),
      'day': date.day.toString(),
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
    final sunriseTime = DateFormat('yyyy-M-d HH:mm').parse(
        '${date.year}-${date.month}-${date.day} ${sunriseHm.first.text}');
    return sunriseTime;
  }

  Future<SunPosition?> getSunPosition(LatLng position, DateTime? time) async {
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

    return SunPosition(double.parse(sunAzimuth.first.text),
        double.parse(sunAltitude.first.text));
  }
}
