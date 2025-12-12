import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class RouteService {
  static const _osrmBase = 'https://router.project-osrm.org';

  /// Get route polyline points between waypoints using OSRM
  /// Returns a list of LatLng points for drawing on the map
  static Future<List<LatLng>> getRoute({
    required LatLng start,
    required LatLng end,
    List<LatLng>? waypoints,
  }) async {
    // Build coordinates string: lon,lat;lon,lat;...
    final coords = <String>[];
    coords.add('${start.longitude},${start.latitude}');
    
    if (waypoints != null) {
      for (final wp in waypoints) {
        coords.add('${wp.longitude},${wp.latitude}');
      }
    }
    
    coords.add('${end.longitude},${end.latitude}');
    
    final coordsString = coords.join(';');
    final url = '$_osrmBase/route/v1/driving/$coordsString'
        '?overview=full&geometries=polyline';

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          return _decodePolyline(geometry);
        }
      }
    } catch (e) {
      // Fall back to straight line if OSRM fails
    }

    // Return straight line as fallback
    return _straightLine(start, end, waypoints);
  }

  /// Decode Google-style polyline encoding
  static List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result = 0;

      // Decode latitude
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;

      // Decode longitude
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);

      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    return points;
  }

  /// Generate a straight line with intermediate points
  static List<LatLng> _straightLine(LatLng start, LatLng end, List<LatLng>? waypoints) {
    final points = <LatLng>[start];
    
    if (waypoints != null) {
      points.addAll(waypoints);
    }
    
    points.add(end);
    return points;
  }

  /// Get route information (distance and duration)
  static Future<Map<String, dynamic>?> getRouteInfo({
    required LatLng start,
    required LatLng end,
  }) async {
    final url = '$_osrmBase/route/v1/driving/'
        '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
        '?overview=false';

    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['code'] == 'Ok' && data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];
          return {
            'distance_m': route['distance'], // meters
            'duration_s': route['duration'], // seconds
            'distance_km': (route['distance'] / 1000).toStringAsFixed(1),
            'duration_min': (route['duration'] / 60).ceil(),
          };
        }
      }
    } catch (e) {
      // Return null on error
    }
    return null;
  }
}

