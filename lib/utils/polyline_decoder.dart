// lib/utils/polyline_decoder.dart
class PolylinePoint {
  final double latitude;
  final double longitude;

  PolylinePoint(this.latitude, this.longitude);

  @override
  String toString() => 'PolylinePoint($latitude, $longitude)';
}

class PolylineDecoder {
  /// Decode a polyline string into a list of PolylinePoint points
  static List<PolylinePoint> decode(String polyline) {
    List<PolylinePoint> points = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < polyline.length) {
      int b;
      int shift = 0;
      int result = 0;

      // Decode latitude
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      // Decode longitude
      do {
        b = polyline.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(PolylinePoint(lat / 1E5, lng / 1E5));
    }

    return points;
  }

  /// Encode a list of PolylinePoint points into a polyline string
  static String encode(List<PolylinePoint> points) {
    String encodedPolyline = '';
    int prevLat = 0;
    int prevLng = 0;

    for (PolylinePoint point in points) {
      int lat = (point.latitude * 1E5).round();
      int lng = (point.longitude * 1E5).round();

      int dLat = lat - prevLat;
      int dLng = lng - prevLng;

      encodedPolyline += _encodeValue(dLat);
      encodedPolyline += _encodeValue(dLng);

      prevLat = lat;
      prevLng = lng;
    }

    return encodedPolyline;
  }

  static String _encodeValue(int value) {
    value = value < 0 ? ~(value << 1) : (value << 1);
    String encoded = '';

    while (value >= 0x20) {
      encoded += String.fromCharCode((0x20 | (value & 0x1f)) + 63);
      value >>= 5;
    }

    encoded += String.fromCharCode(value + 63);
    return encoded;
  }
}
