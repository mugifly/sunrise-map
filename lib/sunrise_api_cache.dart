import 'dart:math' as math;
import 'package:vector_math/vector_math.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sunrise_map/sunrise_data.dart';
import 'dart:developer';

class SunriseApiCache {
  static const _kDatabaseName = 'sunrise_api_cache.db';
  static const _kDatabaseVer = 1;

  late Database _database;

  SunriseApiCache() {
    _openDatabase();
  }

  Future<SunriseData?> findNearCache(
      LatLng position, double maxRangeKilometers) async {
    await _deleteOldCaches();

    final latitude = position.latitude;
    final longitude = position.longitude;
    double kmCos = math.cos(maxRangeKilometers / 6371);
    double radLatitude = radians(latitude);
    double radLongitude = radians(longitude);
    double qSinLatitude = math.sin(radLatitude);
    double qCosLatitude = math.cos(radLatitude);
    double qSinLongitude = math.sin(radLongitude);
    double qCosLongitude = math.cos(radLongitude);

    final result_ = await _database.query('cache');
    if (result_.isEmpty) {
      log('Cache empty', name: 'SunriseApiCache/findNearCache');
      return null;
    }

    final query = '''
      SELECT 
        latitude, longitude, sunrisedAt, sunAzimuth, sunAltitude, createdAt,
        (sinLatitude * $qSinLatitude +
        cosLatitude * $qCosLatitude *
        (sinLongitude * $qSinLongitude + cosLongitude * $qCosLongitude)) AS cosDistance
      FROM cache
      WHERE cosDistance > $kmCos
      ORDER BY cosDistance DESC
    ''';

    final result = await _database.rawQuery(query);
    if (result.isEmpty) {
      log('Cache not found', name: 'SunriseApiCache/findNearCache');
      return null;
    }

    final data = result.first;
    return SunriseData(
      LatLng(data['latitude'] as double, data['longitude'] as double),
      DateTime.fromMillisecondsSinceEpoch(data['sunrisedAt'] as int),
      data['sunAzimuth'] as double,
      data['sunAltitude'] as double,
    );
  }

  Future<void> save(SunriseData data) async {
    await _database.insert(
      'cache',
      {
        'latitude': data.currentPosition.latitude,
        'longitude': data.currentPosition.longitude,
        'sinLatitude': math.sin(radians(data.currentPosition.latitude)),
        'cosLatitude': math.cos(radians(data.currentPosition.latitude)),
        'sinLongitude': math.sin(radians(data.currentPosition.longitude)),
        'cosLongitude': math.cos(radians(data.currentPosition.longitude)),
        'sunrisedAt': data.sunrisedAt.millisecondsSinceEpoch,
        'sunAzimuth': data.sunAzimuth,
        'sunAltitude': data.sunAltitude,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      },
    );
  }

  Future<void> _openDatabase() async {
    _database = await openDatabase(
      _kDatabaseName,
      version: _kDatabaseVer,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cache (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            sinLatitude REAL NOT NULL,
            cosLatitude REAL NOT NULL,
            sinLongitude REAL NOT NULL,
            cosLongitude REAL NOT NULL,
            sunrisedAt INTEGER NOT NULL,
            sunAzimuth REAL NOT NULL,
            sunAltitude REAL NOT NULL,
            createdAt INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<int> _deleteOldCaches() async {
    final now = DateTime.now();

    final today = DateTime(now.year, now.month, now.day, 0, 0, 0, 0, 0);
    final deleted = await _database.delete(
      'cache',
      where: 'createdAt < ?',
      whereArgs: [today.millisecondsSinceEpoch],
    );
    log('Deleted $deleted caches', name: 'SunriseApiCache/_deleteOldCaches');
    return deleted;
  }
}
