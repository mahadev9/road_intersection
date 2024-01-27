import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

Future getSnapToRoads(List<LatLng> points) async {
  String url = 'https://roads.googleapis.com/v1/snapToRoads?path=';
  String yourApiKey = '';

  for (int i = 0; i < points.length; i++) {
    url += '${points[i].latitude},${points[i].longitude}|';
  }

  url = url.substring(0, url.length - 1);
  url += '&interpolate=true&key=$yourApiKey';

  var response = await http.get(Uri.parse(url));
  var respPoints = jsonDecode(response.body);
  List<LatLng> routeCoordinates = [];
  Set<Polyline> routes = {};
  respPoints['snappedPoints'].forEach((point) {
    routeCoordinates.add(
        LatLng(point['location']['latitude'], point['location']['longitude']));
  });
  PolylineId id = const PolylineId('route-test');

  Polyline route = Polyline(
    polylineId: id,
    color: Colors.teal,
    points: routeCoordinates,
    width: 3,
  );

  routes.add(route);
  return routes;
}
