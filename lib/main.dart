import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:road_intersection/src/location_on_path.dart';
import 'package:road_intersection/src/snap_to_roads.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late GoogleMapController mapController;

  late LatLng _currentPosition;
  Map<LatLng, Map<String, dynamic>?> iMap = {};
  Set<Marker> _markers = {};
  // Set<Marker> markers = {};
  Set<Polyline> _routes = {};
  Set<Polyline> routes = {};
  List<LatLng> livePoints = [];
  bool _isLoading = true;
  late StreamSubscription<Position> _positionStream;

  @override
  void initState() {
    super.initState();
    getEnvVars();
    getLocationPermission();
    getCurrentLiveLocation();
  }

  @override
  void dispose() {
    super.dispose();
    _positionStream.cancel();
  }

  void getEnvVars() async {
    await dotenv.load(fileName: 'assets/.env');
  }

  getLocationPermission() async {
    await Geolocator.requestPermission();
  }

  getCurrentLiveLocation() {
    getLocationPermission();
    const LocationSettings locationSettings =
        LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 1);
    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      setClosestIntersection(position);
    });
  }

  setClosestIntersection(position) async {
    LatLng location = LatLng(position.latitude, position.longitude);
    Set<Marker> markers = {};

    // livePoints.add(location);
    // if (!_isLoading) {
    //   if (livePoints.length >= 4) {
    //     LatLng? closestIntersection =
    //         await closestIntersectionUsingAPI(livePoints[1], livePoints[0]);
    //     livePoints.removeRange(0, 4);
    //     if (closestIntersection != null) {
    //       markers.clear();
    //       markers.add(Marker(
    //         markerId: const MarkerId('closest-intersection'),
    //         position: closestIntersection,
    //       ));
    //     }
    //   }
    // }

    // if (!_isLoading) {
    //   if (livePoints.length >= 3) {
    //     iMap = (await intersectionsMap(livePoints[0]))!;
    //     livePoints.removeRange(0, 3);
    //     if (iMap.isNotEmpty) {
    //       iMap.forEach((key, value) {
    //         markers.clear();
    //         routes.clear();
    //         markers.add(Marker(
    //           markerId: const MarkerId('closest-intersection'),
    //           position: key,
    //         ));
    //         routes.add(Polyline(
    //           polylineId: const PolylineId('closest-intersection'),
    //           color: Colors.lightBlue,
    //           points: value?['polyline'],
    //         ));
    //       });
    //     }
    //   }
    // }

    if (!_isLoading) {
      if (iMap.isEmpty) {
        iMap = (await intersectionsMap(_currentPosition))!;
      }
      if (iMap.isNotEmpty) {
        iMap.forEach((key, value) {
          bool isOnPolyline = isLocationOnPath(
              location, value?['polyline'], true,
              tolerance: 5);
          if (isOnPolyline) {
            markers.add(Marker(
              markerId: const MarkerId('closest-intersection'),
              position: key,
            ));
            // routes.clear();
            // routes.add(Polyline(
            //   polylineId: const PolylineId('closest-intersection'),
            //   color: Colors.lightBlue,
            //   points: value?['polyline'],
            // ));
          }
        });
      }
    }
    if (markers.isEmpty) {
      iMap.clear();
    }

    setState(() {
      _routes = routes;
      _currentPosition = location;
      _markers = markers;
      _isLoading = false;
    });
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: Colors.green[700],
        ),
        home: Scaffold(
          appBar: AppBar(
            title: const Text('Map'),
            actions: [
              IconButton(
                  onPressed: () {
                    setState(() {
                      _routes = {};
                      _markers = {};
                    });
                  },
                  icon: const Text('Clear'),
                  tooltip: 'Clear points and routes'),
            ],
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : Stack(children: [
                  GoogleMap(
                    polylines: _routes,
                    onMapCreated: _onMapCreated,
                    initialCameraPosition: CameraPosition(
                      target: _currentPosition,
                      zoom: 16.0,
                    ),
                    compassEnabled: true,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    markers: _markers,
                  ),
                ]),
        ));
  }
}
