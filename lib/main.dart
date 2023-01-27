import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:sunrise_map/sunrise_api_client.dart';
import 'dart:developer' as dev;

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sunrise Map',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.indigo,
      ),
      home: const MyHomePage(title: 'Sunrise Map'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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
      currentPosition = position;
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
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: _kDefaultPosition,
        myLocationEnabled: true,
        myLocationButtonEnabled: false,
        compassEnabled: true,
        polylines: _polylines,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _moveToCurrentPosition,
        tooltip: 'Increment',
        child: const Icon(Icons.gps_fixed),
      ),
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
    if (currentPosition != null &&
        currentPosition?.latitude != null &&
        currentPosition?.longitude != null) {
      final position =
          LatLng(currentPosition!.latitude, currentPosition!.longitude);
      final d = await _sunriseApiClient.getSunriseData(position);
      if (d == null) {
        dev.log('Could not get sunrise data',
            name: 'Main/_moveToCurrentPosition');
        return;
      }

      // 日の出情報を更新
      _sunriseData = d;
      dev.log('Got sunrise data... $_sunriseData',
          name: 'Main/_moveToCurrentPosition');

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
