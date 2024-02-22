import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Future<List<LatLng>> loadIntersectionCoordinates(fileName) async {
  final input = fileName.openRead();
  final fields = await input
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .map((line) => line.split(','))
      .toList();
  if (fields.isNotEmpty) {
    return fields
        .map((field) => LatLng(double.parse(field[1]), double.parse(field[2])))
        .toList();
  }
  return [];
}

saveLocationAndIntersections(points) async {
  String csv = const ListToCsvConverter().convert(points);
}
