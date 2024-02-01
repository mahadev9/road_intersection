import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:road_intersection/src/maps_routes.dart';
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
  List<LatLng> livePoints = [];
  Set<Polyline> _routes = {};
  Set<Marker> _markers = {};
  bool _isLoading = true;
  late StreamSubscription<Position> _positionStream;
  late StreamSubscription<List> _lengthStream;
  final StreamController<List> _lengthController = StreamController<List>();
  Set<Marker> markers = {};

  @override
  void initState() {
    super.initState();
    getEnvVars();
    getLocationPermission();
    getCurrentLiveLocation();
    // updateMarkersAndRoutes();
  }

  @override
  void dispose() {
    super.dispose();
    _positionStream.cancel();
    _lengthStream.cancel();
    _lengthController.close();
  }

  void getEnvVars() async {
    await dotenv.load(fileName: 'assets/.env');
  }

  getLocationPermission() async {
    await Geolocator.requestPermission();
  }

  getCurrentLiveLocation() {
    // getLocationPermission();
    const LocationSettings locationSettings =
        LocationSettings(accuracy: LocationAccuracy.best, distanceFilter: 1);
    _positionStream =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((Position position) {
      setClosestIntersection(position);
    });
  }

  updateMarkersAndRoutes() {
    _lengthStream = _lengthController.stream.listen((List value) {
      if (value.length > 2) {
        getRoute();
      }
    });
  }

  setClosestIntersection(position) async {
    LatLng location = LatLng(position.latitude, position.longitude);
    livePoints.add(location);
    // _lengthController.add(livePoints);

    if (!_isLoading) {
      if (livePoints.length >= 2) {
        // double liveDirection = Geolocator.bearingBetween(
        //     livePoints[0].latitude,
        //     livePoints[0].longitude,
        //     livePoints[1].latitude,
        //     livePoints[1].longitude);
        // LatLng? closestIntersection =
        //     closestIntersection(livePoints[1], liveDirection);
        // LatLng? closestIntersection =
        //     await closestIntersectionUsingAPI(livePoints[1], livePoints[0]);
        LatLng? closestIntersection =
            await getClosestIntersectionUsingGeonamesOrg(livePoints[0]);
        livePoints.removeRange(0, 1);
        if (closestIntersection != null) {
          markers.clear();
          markers.add(Marker(
            markerId: const MarkerId('closest-intersection'),
            position: closestIntersection,
          ));
        }
      }
    }

    setState(() {
      _currentPosition = location;
      _markers = markers;
      _isLoading = false;
    });
  }

  getRoute() async {
    var newRoute = await getSnapToRoads(livePoints);

    MapsRoutes route = MapsRoutes();
    await route.drawRoute(
        livePoints, 'Test', Colors.teal, dotenv.get('GOOGLE_MAPS_API_KEY'));

    setState(() {
      // _routes = route.routes;
      _routes = newRoute;
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
                      livePoints = [];
                      _markers = {};
                      _routes = {};
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
