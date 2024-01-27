import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:road_intersection/src/maps_routes.dart';
import 'package:road_intersection/src/snap_to_roads.dart';

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
  Set<Polyline> _routes = {};
  Set<Marker> _markers = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    getLocation();
  }

  getLocation() async {
    LocationPermission permission;
    permission = await Geolocator.requestPermission();

    Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best);
    double lat = position.latitude;
    double long = position.longitude;

    LatLng location = LatLng(lat, long);

    List<LatLng> points = [
      const LatLng(37.785834, -122.406417),
      // const LatLng(37.78622400812657, -122.40671740948903),
      // const LatLng(37.78614769686907, -122.40606295050391),
      // const LatLng(37.78533370521908, -122.40764008936969),
      // const LatLng(37.78522347649389, -122.40919577056383),
      // const LatLng(37.785621994953786, -122.40987168722059),
      // const LatLng(37.78488431015448, -122.41025792531016),
      // const LatLng(37.785800055698736, -122.40932451659367),
      // const LatLng(37.785305001085234, -122.40818549583503),
      // const LatLng(37.78379690600689, -122.41237080095591),

      const LatLng(37.78584978516292, -122.40771031962375),
      const LatLng(37.78580245331416, -122.40816698459558),
      const LatLng(37.78518713652197, -122.4084589507251),
      const LatLng(37.78566045758605, -122.4093348491137),
      const LatLng(37.785110221562725, -122.40752316184839),
      const LatLng(37.78561312561605, -122.4110716732689),
      const LatLng(37.78477297810418, -122.4103080695455),
      const LatLng(37.784512648767965, -122.41086954287152),
      const LatLng(37.78542971394599, -122.41271866169191),
      const LatLng(37.7844830658308, -122.41231440089717),
      const LatLng(37.783335238726885, -122.41231440089717),
    ];

    Set<Marker> markers = points
        .map((LatLng point) => Marker(
              markerId: MarkerId(point.toString()),
              position: point,
            ))
        .toSet();

    var newRoute = await getSnapToRoads(points);

    MapsRoutes route = MapsRoutes();
    await route.drawRoute(
        points, "Test", Colors.teal, "AIzaSyDLYCobbK3iETuVT0tMgj_bEiYygRZN2rQ");

    setState(() {
      _currentPosition = location;
      // _routes = route.routes;
      _routes = newRoute;
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
          ),
          body: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
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
        ));
  }
}
