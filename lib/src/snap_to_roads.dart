import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:road_intersection/src/location_on_path.dart';

const List<LatLng> knownIntersections = [
  LatLng(39.684158993061466, -75.73945768347694),
  LatLng(39.683915182897834, -75.74208016975517),
  LatLng(39.683732324704884, -75.74431250985079),
  LatLng(39.68363976666654, -75.74551814950348),
  LatLng(39.683335001532754, -75.74938734343729),
  LatLng(39.683012174776344, -75.75365255040697),
  LatLng(39.68162872797953, -75.75533936539632),
  LatLng(39.68166016098347, -75.75362766863185),
  LatLng(39.681983062909744, -75.74948766454055),
  LatLng(39.68216353816955, -75.74730663887253),
  LatLng(39.682203063094526, -75.74518384669615),
  LatLng(39.68211449291775, -75.74358551261581),
  LatLng(39.68099900157601, -75.74170239051895),
  LatLng(39.68157328262362, -75.73629745492491),
  LatLng(39.68450809794145, -75.73670954589974),
  LatLng(39.686585504233314, -75.73610836901574),
  LatLng(39.686940782238686, -75.74094776652791),
  LatLng(39.68706374931129, -75.74698696524878),
  LatLng(39.685789864967916, -75.75446549928853),
  LatLng(39.683001300651966, -75.75409421781029),
  LatLng(39.685460740663366, -75.75830520774024),
  LatLng(39.68406827434356, -75.75907126953123),
  LatLng(39.68122519983841, -75.75826113575023),
  LatLng(39.67767913811079, -75.76217630245806),
  LatLng(39.67686440359126, -75.76315856196332),
  LatLng(39.67491477820061, -75.76551045241382),
  LatLng(39.67037507502802, -75.77062633079979),
  LatLng(39.6655040769619, -75.77599710609721),
  LatLng(39.674438908566174, -75.75349261643106),
  LatLng(39.680035576536916, -75.75359139489723),
  LatLng(39.679014169503354, -75.75357134740169),
  LatLng(39.6743385415603, -75.75053830760723),
  LatLng(39.678557907849026, -75.73587917208795),
  LatLng(39.680134739389395, -75.73045826644004),
  LatLng(39.6823959586313, -75.73156241147699),
  LatLng(39.68538587443964, -75.73291357908712),
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
      // bool isOnPolyline = isPointOnPolyline(polyline, liveLatLngs);
      // var polyline = await getRouteBtnPointsUsingToolkit(
      //     prevLatLng, knownIntersections[i]);
      bool isOnPolyline = isLocationOnPath(
          LatLng(liveLatLngs.latitude, liveLatLngs.longitude), polyline, true,
          tolerance: 5);
      if (isOnPolyline &&
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

// getRouteBtnPointsUsingToolkit(startPoint, endPoint) async {
//   var points = [startPoint, endPoint];
//   String url = 'https://roads.googleapis.com/v1/snapToRoads?path=';
//   String yourApiKey = dotenv.get('GOOGLE_MAPS_API_KEY');

//   for (int i = 0; i < points.length; i++) {
//     url += '${points[i].latitude},${points[i].longitude}|';
//   }

//   url = url.substring(0, url.length - 1);
//   url += '&interpolate=true&key=$yourApiKey';

//   var response = await http.get(Uri.parse(url));
//   var respPoints = jsonDecode(response.body);
//   List<LatLng> routeCoordinates = [];
//   respPoints['snappedPoints'].forEach((point) {
//     routeCoordinates.add(
//         LatLng(point['location']['latitude'], point['location']['longitude']));
//   });
//   return routeCoordinates;
// }

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
