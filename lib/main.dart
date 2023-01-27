import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

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
  void _moveToCurrentPosition() {
    if (currentPosition == null) {
      return;
    }
    _mapController.animateCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(currentPosition!.latitude, currentPosition!.longitude),
        zoom: 14,
      ),
    ));
  }
}
