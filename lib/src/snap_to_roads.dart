import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

const List<LatLng> knownIntersections = [
  LatLng(39.685096169675035, -75.73921743071486),
  LatLng(39.68420955116282, -75.73923804058455),
  LatLng(39.68391710216027, -75.74207649187478),
  LatLng(39.683736804022764, -75.74430667090421),
  LatLng(39.68364411105584, -75.74552119264736),
  LatLng(39.68355382333597, -75.74670403904457),
  LatLng(39.68348439975024, -75.74747983922741),
  LatLng(39.68341299256072, -75.74843348064817),
  LatLng(39.68333960175916, -75.749335573894),
  LatLng(39.68299289995479, -75.75364820416725),
  LatLng(39.68162566077546, -75.7553070029373),
  LatLng(39.68165980511958, -75.75362615954391),
  LatLng(39.68198709577431, -75.74949199503621),
  LatLng(39.682163153861296, -75.74731359525308),
  LatLng(39.68220238412603, -75.74518463951141),
  LatLng(39.68100727864067, -75.74170363901017),
  LatLng(39.68160218518304, -75.73629968985907),
  LatLng(39.68452379754594, -75.73670215869109),
  LatLng(39.68471413799947, -75.73765583973346),
  LatLng(39.68524483189034, -75.73784553649136),
  LatLng(39.68593757806906, -75.73793250474714),
];

Future getSnapToRoads(List<LatLng> points) async {
  String url = 'https://roads.googleapis.com/v1/snapToRoads?path=';
  String yourApiKey = dotenv.get('GOOGLE_MAPS_API_KEY');

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

  Polyline route = Polyline(
    polylineId: const PolylineId('route-test'),
    color: Colors.teal,
    points: routeCoordinates,
    width: 5,
  );

  routes.add(route);
  return routes;
}

getCloserIntersection(List<LatLng> liveLatLng) {
  // calculate distance from liveLatLngs to each intersection in knownIntersections and return the closest one
  // return LatLng

  double closestDistance = double.infinity;
  LatLng closestIntersection = knownIntersections[0];
  for (int i = 0; i < knownIntersections.length; i++) {
    for (int j = 0; j < liveLatLng.length; j++) {
      double distance = Geolocator.distanceBetween(
        knownIntersections[i].latitude,
        knownIntersections[i].longitude,
        liveLatLng[j].latitude,
        liveLatLng[j].longitude,
      );
      if (distance < closestDistance) {
        closestDistance = distance;
        closestIntersection = knownIntersections[i];
      }
    }
  }
  return closestIntersection;
}

LatLng? closestIntersection(LatLng liveLatLngs, double liveDirection) {
  late LatLng closestIntersection;
  double minDistance = double.infinity;

  try {
    for (var intersection in knownIntersections) {
      double d = Geolocator.distanceBetween(liveLatLngs.latitude,
          liveLatLngs.longitude, intersection.latitude, intersection.longitude);
      double b = Geolocator.bearingBetween(liveLatLngs.latitude,
          liveLatLngs.longitude, intersection.latitude, intersection.longitude);

      if (isSameDirection(liveDirection, b) && d < minDistance) {
        minDistance = d;
        closestIntersection = intersection;
      }
    }
    return closestIntersection;
  } catch (e) {
    return null;
  }
}

bool isSameDirection(double direction1, double direction2,
    [double tolerance = 10]) {
  // Implement direction comparison here
  var difference = (direction1 - direction2).abs();
  // Normalize to the range [0, 360)
  difference = difference >= 360 ? difference % 360 : difference;
  // If the difference is greater than 180, it's shorter to go the other way
  difference = difference > 180 ? 360 - difference : difference;
  return difference <= tolerance;
}

Future<LatLng?> closestIntersectionUsingAPI(
    LatLng liveLatLngs, LatLng prevLatLng) async {
  double closestDistance = double.infinity;
  late LatLng closestIntersection;
  try {
    var distanceMatrix = await getDistanceMatrix(liveLatLngs);
    for (int i = 0; i < distanceMatrix.length; i++) {
      var polyline = await getRouteBtnPoints(prevLatLng, knownIntersections[i]);
      if (isPointOnPolyline(polyline, liveLatLngs) &&
          distanceMatrix[i]['distance']['value'].toDouble() < closestDistance) {
        closestDistance = distanceMatrix[i]['distance']['value'].toDouble();
        closestIntersection = knownIntersections[i];
      }
    }
    return closestIntersection;
  } catch (e) {
    return null;
  }
}

getDistanceMatrix(LatLng location) async {
  String url = 'https://maps.googleapis.com/maps/api/distancematrix/json?';
  String yourApiKey = dotenv.get('GOOGLE_MAPS_API_KEY');

  url += 'origins=${location.latitude},${location.longitude}';
  url += '&destinations=';
  for (int i = 0; i < knownIntersections.length; i++) {
    url +=
        '${knownIntersections[i].latitude},${knownIntersections[i].longitude}|';
  }
  url += '&key=$yourApiKey&mode=driving';

  var response = await http.get(Uri.parse(url));
  var respPoints = jsonDecode(response.body);
  return respPoints['rows'][0]['elements'];
}

bool isPointOnPolyline(List<LatLng> polyline, LatLng point) {
  double lat = point.latitude;
  double lng = point.longitude;
  int intersections = 0;

  for (int i = 0; i < polyline.length - 1; i++) {
    double startX = polyline[i].latitude;
    double startY = polyline[i].longitude;
    double endX = polyline[i + 1].latitude;
    double endY = polyline[i + 1].longitude;

    if (((startY <= lng && lng < endY) || (endY <= lng && lng < startY)) &&
        (lat < startX + (endX - startX) * (lng - startY) / (endY - startY))) {
      intersections++;
    }
  }
  return intersections % 2 != 0;
}

getRouteBtnPoints(startPoint, endPoint) async {
  var routes = await getSnapToRoads([startPoint, endPoint]);
  List<LatLng> routePoints = [];
  routes.forEach((route) {
    routePoints = route.points;
  });
  return routePoints;
}

getDirectionsBtnPoints(startPoint, endPoint) async {
  String url = 'https://maps.googleapis.com/maps/api/directions/json?';
  String yourApiKey = dotenv.get('GOOGLE_MAPS_API_KEY');

  url += 'origin=${startPoint.latitude},${startPoint.longitude}';
  url += '&destination=${endPoint.latitude},${endPoint.longitude}';
  url += '&key=$yourApiKey&mode=driving';

  var response = await http.get(Uri.parse(url));
  var respPoints = jsonDecode(response.body);
  List<LatLng> routePoints = [];
  respPoints['routes'][0]['legs'][0]['steps'].forEach((step) {
    routePoints.add(
        LatLng(step['start_location']['lat'], step['start_location']['lng']));
  });
  return routePoints;
}

Future<LatLng?> getClosestIntersectionUsingGeonamesOrg(LatLng location) async {
  try {
    String url = 'http://api.geonames.org/findNearestIntersectionJSON?';
    String username = dotenv.get('GEONAMES_USERNAME');

    url +=
        'lat=${location.latitude}&lng=${location.longitude}&username=$username';

    var response = await http.get(Uri.parse(url));
    var respPoints = jsonDecode(response.body);
    return LatLng(double.parse(respPoints['intersection']['lat']),
        double.parse(respPoints['intersection']['lng']));
  } catch (e) {
    return null;
  }
}
