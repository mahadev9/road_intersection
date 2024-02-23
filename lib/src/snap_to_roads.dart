import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

// const List<LatLng> knownIntersections = [
//   LatLng(39.684158993061466, -75.73945768347694),
//   LatLng(39.683915182897834, -75.74208016975517),
//   LatLng(39.683732324704884, -75.74431250985079),
//   LatLng(39.68363976666654, -75.74551814950348),
//   LatLng(39.683335001532754, -75.74938734343729),
//   LatLng(39.683012174776344, -75.75365255040697),
//   LatLng(39.68162872797953, -75.75533936539632),
//   LatLng(39.68166016098347, -75.75362766863185),
//   LatLng(39.681983062909744, -75.74948766454055),
//   LatLng(39.68216353816955, -75.74730663887253),
//   LatLng(39.682203063094526, -75.74518384669615),
//   LatLng(39.68211449291775, -75.74358551261581),
//   LatLng(39.68099900157601, -75.74170239051895),
//   LatLng(39.68157328262362, -75.73629745492491),
//   LatLng(39.68450809794145, -75.73670954589974),
//   LatLng(39.686585504233314, -75.73610836901574), // *
//   LatLng(39.686940782238686, -75.74094776652791), // *
//   LatLng(39.68706374931129, -75.74698696524878), // *
//   LatLng(39.685789864967916, -75.75446549928853), // *
//   LatLng(39.683001300651966, -75.75409421781029),
//   LatLng(39.685460740663366, -75.75830520774024), // *
//   LatLng(39.68406827434356, -75.75907126953123), // *
//   LatLng(39.68122519983841, -75.75826113575023),
//   LatLng(39.67767913811079, -75.76217630245806),
//   LatLng(39.67686440359126, -75.76315856196332),
//   LatLng(39.67491477820061, -75.76551045241382),
//   LatLng(39.67037507502802, -75.77062633079979), // *
//   LatLng(39.6655040769619, -75.77599710609721), // *
//   LatLng(39.674438908566174, -75.75349261643106),
//   LatLng(39.680035576536916, -75.75359139489723),
//   LatLng(39.679014169503354, -75.75357134740169),
//   LatLng(39.6743385415603, -75.75053830760723),
//   LatLng(39.678557907849026, -75.73587917208795),
//   LatLng(39.680134739389395, -75.73045826644004), // *
//   LatLng(39.6823959586313, -75.73156241147699), // *
//   LatLng(39.68538587443964, -75.73291357908712), // *
// ];

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

Future<Map<LatLng, Map<String, dynamic>>?> intersectionsMap(
    LatLng liveLatLngs, intersections) async {
  Map<LatLng, Map<String, dynamic>> iMap = {};
  try {
    var distanceMatrix = await getDistanceMatrix(liveLatLngs, intersections);
    int minIndex = 0;
    for (int i = 0; i < distanceMatrix.length; i++) {
      if (distanceMatrix[i]['distance']['value'] <=
          distanceMatrix[minIndex]['distance']['value']) {
        minIndex = i;
      }
    }
    var polyline =
        await getRouteBtnPoints(liveLatLngs, intersections[minIndex]);
    // var polyline =
    //     await getSnapToRoads([liveLatLngs, intersections[minIndex]]);
    iMap[intersections[minIndex]] = {
      'distance': distanceMatrix[minIndex]['distance']['value'].toDouble(),
      'polyline': polyline
    };
    // for (int i = 0; i < distanceMatrix.length; i++) {
    //   var polyline =
    //       await getRouteBtnPoints(liveLatLngs, intersections[i]);
    //   print(polyline);
    //   iMap[intersections[i]] = {
    //     'distance': distanceMatrix[i]['distance']['value'].toDouble(),
    //     'polyline': polyline
    //   };
    // }
    // iMap = Map.fromEntries(iMap.entries.toList()
    //   ..sort((e1, e2) => e1.value['distance'].compareTo(e2.value['distance'])));
    return iMap;
  } catch (e) {
    return null;
  }
}

getDistanceMatrix(LatLng location, intersections) async {
  String url = 'https://maps.googleapis.com/maps/api/distancematrix/json?';
  String yourApiKey = dotenv.get('GOOGLE_MAPS_API_KEY');

  url += 'origins=${location.latitude},${location.longitude}';
  url += '&destinations=';
  for (int i = 0; i < intersections.length; i++) {
    url += '${intersections[i].latitude},${intersections[i].longitude}|';
  }
  url += '&key=$yourApiKey&mode=driving';

  var response = await http.get(Uri.parse(url));
  var respPoints = jsonDecode(response.body);
  return respPoints['rows'][0]['elements'];
}

getRouteBtnPoints(startPoint, endPoint) async {
  var routes = await getSnapToRoads([startPoint, endPoint]);
  List<LatLng> routePoints = [];
  routes.forEach((route) {
    routePoints = route.points;
  });
  return routePoints;
}
