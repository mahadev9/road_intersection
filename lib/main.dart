import 'dart:async';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:road_intersection/src/csvFile.dart';
import 'package:road_intersection/src/location_on_path.dart';
import 'package:road_intersection/src/showToast.dart';
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
  Set<Polyline> _routes = {};
  Set<Polyline> routes = {};
  List<List<dynamic>> livePoints = [];
  bool _isLoading = true;
  late StreamSubscription<Position> _positionStream;
  List<LatLng> knownIntersections = [];

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
    setState(() {
      _isLoading = false;
    });
  }

  getStoragePermission() async {
    var status = await Permission.storage.status;
    if (!status.isGranted) {
      await Permission.storage.request();
    }
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

    livePoints.add([
      location.latitude,
      location.longitude,
      markers.isEmpty ? null : markers.first.position.latitude,
      markers.isEmpty ? null : markers.first.position.longitude
    ]);

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

  onSaveButton() async {
    await getStoragePermission();
    saveLocationAndIntersections(livePoints);
  }

  onLoadButton() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result != null) {
      File file = File(result.files.single.path!);
      var ki = await loadIntersectionCoordinates(file);
      if (ki.isEmpty) {
        showToast("Selected csv file is empty. Please select another file.");
      }
      setState(() {
        knownIntersections = ki;
      });
    } else {
      showToast("Please select a csv file.");
    }
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
                onPressed: onLoadButton,
                icon: const Text('Load'),
                tooltip: 'Load intersection coordinates from a given csv file',
              ),
              IconButton(
                onPressed: onSaveButton,
                icon: const Text('Save'),
                tooltip: 'Save Location and Intersection Coordinates',
              ),
              // IconButton(
              //     onPressed: () {
              //       setState(() {
              //         _routes = {};
              //         _markers = {};
              //       });
              //     },
              //     icon: const Text('Clear'),
              //     tooltip: 'Clear points and routes'),
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
