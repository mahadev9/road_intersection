import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:road_intersection/src/show_toast.dart';

Future<String> getExternalDocumentPath() async {
  Directory directory = Directory("");
  if (Platform.isAndroid) {
    // Redirects it to download folder in android
    directory = Directory("/storage/emulated/0/Download");
  } else {
    directory = await getApplicationDocumentsDirectory();
  }

  final exPath = directory.path;
  await Directory(exPath).create(recursive: true);
  return exPath;
}

Future<Map<String, LatLng>> loadIntersectionCoordinates(fileName) async {
  Map<String, LatLng> points = {};
  try {
    final input = fileName.openRead();
    final fields = await input
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .map((line) => line.split(','))
        .toList();
    if (fields.isNotEmpty) {
      for (var i = 1; i < fields.length; i++) {
        points[fields[i][0]] =
            LatLng(double.parse(fields[i][1]), double.parse(fields[i][2]));
      }
    }
    return points;
  } catch (e) {
    showToast('Could not parse file.');
  }
  return points;
}

saveLocationAndIntersections(points) async {
  var today = DateTime.now();
  String dateFormat =
      '${today.year.toString()}_${today.month.toString().padLeft(2, '0')}_${today.day.toString().padLeft(2, '0')}_${today.hour.toString().padLeft(2, '0')}_${today.minute.toString().padLeft(2, '0')}';
  String fileName = 'location_and_intersections_$dateFormat.csv';
  final directory = await getExternalDocumentPath();
  String csv = const ListToCsvConverter().convert(points);
  File file = File('$directory/$fileName');
  file.writeAsString(csv);
  showToast('File saved to $directory as $fileName');
}
