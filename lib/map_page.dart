import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:sunrise_map/sunrise_api_client.dart';
import 'dart:developer' as dev;

import 'sunrise_data.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  // Google Maps を制御するためのコントローラ
  late GoogleMapController _mapController;

  // 現在地
  Position? currentPosition;
  late StreamSubscription<Position> positionSubscription;

  // 位置情報取得の設定
  final LocationSettings _locationSettings = const LocationSettings(
    accuracy: LocationAccuracy.high,
    distanceFilter: 10,
  );

  // 初期位置
  final CameraPosition _kDefaultPosition = const CameraPosition(
    target: LatLng(34.7024, 135.4959),
    zoom: 14,
  );

  // ポリライン
  final Set<Polyline> _polylines = {};

  // 日の出APIクライアント
  final SunriseApiClient _sunriseApiClient = SunriseApiClient();

  // 日の出情報
  late SunriseData _sunriseData;
  String _sunriseText = '日の出:  --:--';

  @override
  void initState() {
    super.initState();

    // 位置情報取得のための権限を取得
    Future(() async {
      LocationPermission perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied) {
        // 権限がない場合は、設定を開く
        await Geolocator.openLocationSettings();
      }
    });

    // 現在地取得の開始
    positionSubscription =
        Geolocator.getPositionStream(locationSettings: _locationSettings)
            .listen((Position position) {
      final isFirst = currentPosition == null;
      currentPosition = position;

      if (isFirst) {
        // 自動的に現在地へ移動 (初回のみ)
        _moveToCurrentPosition();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.gps_fixed),
            tooltip: '現在地を表示',
            onPressed: () {
              _moveToCurrentPosition();
            },
          )
        ],
      ),
      body: Column(children: <Widget>[
        SizedBox(
          height: 50,
          child: Container(
              alignment: AlignmentDirectional.center,
              padding: const EdgeInsets.all(10.0),
              child: Text(
                _sunriseText,
                style: const TextStyle(fontSize: 17),
              )),
        ),
        Expanded(
          child: GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: _kDefaultPosition,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            compassEnabled: true,
            polylines: _polylines,
          ),
        )
      ]),
    );
  }

  // Google Maps が読み込まれたときに呼ばれるイベントハンドラ
  void _onMapCreated(GoogleMapController controller) async {
    _mapController = controller;
  }

  // 現在地へ移動
  void _moveToCurrentPosition() async {
    if (currentPosition == null) {
      return;
    }

    // 現在地へ移動
    _mapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
        zoom: 14,
      ),
    ));

    // 現在地の日の出情報を取得
    await _updateSunriseInfo();
  }

  _updateSunriseInfo() async {
    if (currentPosition == null ||
        currentPosition?.latitude == null ||
        currentPosition?.longitude == null) {
      return;
    }

    // 日の出情報を取得
    final position =
        LatLng(currentPosition!.latitude, currentPosition!.longitude);
    final data = await _sunriseApiClient.getSunriseData(position);
    if (data == null) {
      dev.log('Could not get sunrise data', name: 'Main/_updateSunriseInfo');
      return;
    }

    // 日の出情報を更新
    _sunriseData = data;
    dev.log('Got sunrise data... $_sunriseData',
        name: 'Main/_updateSunriseInfo');

    // 日の出情報を表示
    setState(() {
      final sunriseTimeStr =
          DateFormat('HH:mm').format(_sunriseData.sunrisedAt);
      _sunriseText = '日の出:  $sunriseTimeStr';
    });

    // 現在地から90度方向の緯度経度を取得
    final LatLng latLng = await _getLatLngFromBearing(position, 90, 1000.0);

    // 線を引く
    setState(() {
      _polylines.add(Polyline(
          polylineId: const PolylineId('1'),
          points: [position, latLng],
          color: Colors.green));
    });
  }

  _getLatLngFromBearing(LatLng position, int angle, distanceKilometers) {
    const double radius = 6371;
    final double lat1 = position.latitude * pi / 180;
    final double lon1 = position.longitude * pi / 180;
    final double lat2 = asin(sin(lat1) * cos(distanceKilometers / radius) +
        cos(lat1) * sin(distanceKilometers / radius) * cos(angle));
    final double lon2 = lon1 +
        atan2(sin(angle) * sin(distanceKilometers / radius) * cos(lat1),
            cos(distanceKilometers / radius) - sin(lat1) * sin(lat2));
    return LatLng(lat2 * 180 / pi, lon2 * 180 / pi);
  }
}
