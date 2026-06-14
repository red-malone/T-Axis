import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RideDetailScreen extends StatelessWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> rideDoc;

  const RideDetailScreen({super.key, required this.rideDoc});

  @override
  Widget build(BuildContext context) {
    final data = rideDoc.data();
    final route = (data['route'] as List<dynamic>?) ?? [];

    final points = route.map<LatLng>((p) {
      final lat = (p['lat'] as num).toDouble();
      final lng = (p['lng'] as num).toDouble();
      return LatLng(lat, lng);
    }).toList();

    final center = points.isNotEmpty ? points[0] : LatLng(0, 0);

    return Scaffold(
      appBar: AppBar(title: const Text('Ride Detail')),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: center,
                initialZoom: 15.0,
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                ),
                if (points.isNotEmpty)
                  PolylineLayer(
                    polylines: [
                      Polyline(
                        points: points,
                        strokeWidth: 4.0,
                        color: Colors.blueAccent,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: points
                      .map(
                        (pt) => Marker(
                          point: pt,
                          width: 8,
                          height: 8,
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.redAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Timestamp: ${data['timestamp'] ?? ''}'),
                Text('Top speed: ${data['top_speed_kmh'] ?? 0} km/h'),
                Text('Max lean: ${data['max_lean_angle'] ?? 0}°'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
