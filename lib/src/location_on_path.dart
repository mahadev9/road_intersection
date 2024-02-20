/*
  Source: https://github.com/googlemaps/android-maps-utils/blob/main/library/src/main/java/com/google/maps/android/PolyUtil.java
  Code is converted from Java to Dart.
*/
import 'dart:math';

import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:vector_math/vector_math.dart';

double hav(double x) {
  var sinHalf = sin(x * 0.5);
  return sinHalf * sinHalf;
}

havDistance(double lat1, double lat2, double dLng) {
  return hav(lat1 - lat2) + hav(dLng) * cos(lat1) * cos(lat2);
}

sinDeltaBearing(double lat1, double lng1, double lat2, double lng2, double lat3,
    double lng3) {
  double sinLat1 = sin(lat1);
  double cosLat2 = cos(lat2);
  double cosLat3 = cos(lat3);
  double lat31 = lat3 - lat1;
  double lng31 = lng3 - lng1;
  double lat21 = lat2 - lat1;
  double lng21 = lng2 - lng1;
  double a = sin(lng31) * cosLat3;
  double c = sin(lng21) * cosLat2;
  double b = sin(lat31) + 2 * sinLat1 * cosLat3 * hav(lng31);
  double d = sin(lat21) + 2 * sinLat1 * cosLat2 * hav(lng21);
  double denom = (a * a + b * b) * (c * c + d * d);
  return denom <= 0 ? 1.0 : (a * d - b * c) / sqrt(denom);
}

sinFromHav(double h) {
  return 2 * sqrt(h * (1 - h));
}

havFromSin(double x) {
  double x2 = x * x;
  return x2 / (1 + sqrt(1 - x2)) * .5;
}

sinSumFromHav(double x, double y) {
  double a = sqrt(x * (1 - x));
  double b = sqrt(y * (1 - y));
  return 2 * (a + b - 2 * (a * y + b * x));
}

mercator(double lat) {
  return log(tan(lat * 0.5 + pi / 4));
}

inverseMercator(double y) {
  return 2 * atan(exp(y)) - pi / 2;
}

wrap(double n, double min, double max) {
  return (n >= min && n < max) ? n : (mod(n - min, max - min) + min);
}

mod(double x, double m) {
  return ((x % m) + m) % m;
}

clamp(double x, double low, double high) {
  return x < low ? low : (x > high ? high : x);
}

isOnSegmentGC(double lat1, double lng1, double lat2, double lng2, double lat3,
    double lng3, double havTolerance) {
  double havDist13 = havDistance(lat1, lat3, lng1 - lng3);
  if (havDist13 <= havTolerance) {
    return true;
  }
  double havDist23 = havDistance(lat2, lat3, lng2 - lng3);
  if (havDist23 <= havTolerance) {
    return true;
  }
  double sinBearing = sinDeltaBearing(lat1, lng1, lat2, lng2, lat3, lng3);
  double sinDist13 = sinFromHav(havDist13);
  double havCrossTrack = havFromSin(sinDist13 * sinBearing);
  if (havCrossTrack > havTolerance) {
    return false;
  }
  double havDist12 = havDistance(lat1, lat2, lng1 - lng2);
  double term = havDist12 + havCrossTrack * (1 - 2 * havDist12);
  if (havDist13 > term || havDist23 > term) {
    return false;
  }
  if (havDist12 < 0.74) {
    return true;
  }
  double cosCrossTrack = 1 - 2 * havCrossTrack;
  double havAlongTrack13 = (havDist13 - havCrossTrack) / cosCrossTrack;
  double havAlongTrack23 = (havDist23 - havCrossTrack) / cosCrossTrack;
  double sinSumAlongTrack = sinSumFromHav(havAlongTrack13, havAlongTrack23);
  return sinSumAlongTrack > 0;
}

bool isLocationOnPath(LatLng point, List<LatLng> polyline, bool geodesic,
    {double tolerance = 0.1}) {
  var polySize = polyline.length;
  if (polySize == 0) {
    return false;
  }
  const earthRadius = 6371009.0;
  var toleranceEarth = tolerance / earthRadius;
  var havTolerance = hav(toleranceEarth);
  var lat3 = radians(point.latitude);
  var lng3 = radians(point.longitude);
  var prev = polyline[0];
  var lat1 = radians(prev.latitude);
  var lng1 = radians(prev.longitude);
  var idx = 0;
  if (geodesic) {
    for (var point2 in polyline) {
      double lat2 = radians(point2.latitude);
      double lng2 = radians(point2.longitude);
      if (isOnSegmentGC(lat1, lng1, lat2, lng2, lat3, lng3, havTolerance)) {
        return max<int>(0, idx - 1) >= 0;
      }
      lat1 = lat2;
      lng1 = lng2;
      idx += 1;
    }
  } else {
    double minAcceptable = lat3 - tolerance;
    double maxAcceptable = lat3 + tolerance;
    double y1 = mercator(lat1);
    double y3 = mercator(lat3);
    List<double> xTry = List.filled(3, 0);
    for (var point2 in polyline) {
      double lat2 = radians(point2.latitude);
      double y2 = mercator(lat2);
      double lng2 = radians(point2.longitude);
      if (max<double>(lat1, lat2) >= minAcceptable &&
          min<double>(lat1, lat2) <= maxAcceptable) {
        double x2 = wrap(lng2 - lng1, -pi, pi);
        double x3Base = wrap(lng3 - lng1, -pi, pi);
        xTry[0] = x3Base;
        xTry[1] = x3Base + 2 * pi;
        xTry[2] = x3Base - 2 * pi;
        for (var x3 in xTry) {
          double dy = y2 - y1;
          double len2 = x2 * x2 + dy * dy;
          double t =
              len2 <= 0 ? 0 : clamp((x3 * x2 + (y3 - y1) * dy) / len2, 0, 1);
          double xClosest = t * x2;
          double yClosest = y1 + t * dy;
          double latClosest = inverseMercator(yClosest);
          double havDist = havDistance(lat3, latClosest, x3 - xClosest);
          if (havDist < havTolerance) {
            return max<int>(0, idx - 1) >= 0;
          }
        }
      }
      lat1 = lat2;
      lng1 = lng2;
      y1 = y2;
      idx += 1;
    }
  }
  return false;
}
