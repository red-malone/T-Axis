import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RideDetailScreen extends StatefulWidget {
  final QueryDocumentSnapshot<Map<String, dynamic>> rideDoc;

  const RideDetailScreen({super.key, required this.rideDoc});

  @override
  State<RideDetailScreen> createState() => _RideDetailScreenState();
}

class _RideDetailScreenState extends State<RideDetailScreen> {
  late final Map<String, dynamic> _data = Map<String, dynamic>.from(
    widget.rideDoc.data(),
  );

  List<LatLng> get _points {
    final route = (_data['route'] as List<dynamic>?) ?? const [];
    return route
        .map<LatLng>(
          (p) => LatLng(
            (p['lat'] as num).toDouble(),
            (p['lng'] as num).toDouble(),
          ),
        )
        .toList();
  }

  double get _distanceKm {
    final pts = _points;
    if (pts.length < 2) return 0;
    const distance = Distance();
    double meters = 0;
    for (var i = 0; i < pts.length - 1; i++) {
      meters += distance(pts[i], pts[i + 1]);
    }
    return meters / 1000;
  }

  String get _title {
    final label = (_data['label'] as String?)?.trim();
    if (label != null && label.isNotEmpty) return label;
    return 'Ride';
  }

  String _formatTimestamp(String? iso) {
    if (iso == null || iso.isEmpty) return 'Unknown date';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return iso;
    final local = dt.toLocal();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year} · $h:$m';
  }

  Future<void> _renameRide() async {
    final controller = TextEditingController(
      text: (_data['label'] as String?) ?? '',
    );
    final newLabel = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename ride'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'e.g. Sunday hill climb',
          ),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (newLabel == null) return;
    final trimmed = newLabel.trim();
    try {
      await widget.rideDoc.reference.update({'label': trimmed});
      if (!mounted) return;
      setState(() => _data['label'] = trimmed);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not rename: $e')));
    }
  }

  Future<void> _deleteRide() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete ride?'),
        content: const Text(
          'This permanently removes the ride from the cloud. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    try {
      await widget.rideDoc.reference.delete();
      if (!mounted) return;
      Navigator.of(context).pop(); // back to the list
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not delete: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final points = _points;
    final hasRoute = points.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Rename',
            onPressed: _renameRide,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: _deleteRide,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(flex: 3, child: _buildMap(points, hasRoute)),
          Expanded(flex: 2, child: _buildStats()),
        ],
      ),
    );
  }

  Widget _buildMap(List<LatLng> points, bool hasRoute) {
    if (!hasRoute) {
      return Container(
        color: const Color(0xFF1E1E1E),
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.location_off, color: Colors.white38, size: 40),
              SizedBox(height: 8),
              Text(
                'No route recorded for this ride',
                style: TextStyle(color: Colors.white54),
              ),
            ],
          ),
        ),
      );
    }

    return FlutterMap(
      options: MapOptions(
        // Auto-fit the camera so the entire route is visible, with padding.
        initialCameraFit: CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.all(40),
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.t_axis',
        ),
        PolylineLayer(
          polylines: [
            Polyline(
              points: points,
              strokeWidth: 4.0,
              color: Colors.redAccent,
            ),
          ],
        ),
        MarkerLayer(
          markers: [
            _endpointMarker(points.first, Colors.green, Icons.trip_origin),
            if (points.length > 1)
              _endpointMarker(points.last, Colors.red, Icons.flag),
          ],
        ),
      ],
    );
  }

  Marker _endpointMarker(LatLng pt, Color color, IconData icon) {
    return Marker(
      point: pt,
      width: 30,
      height: 30,
      child: Icon(icon, color: color, size: 26),
    );
  }

  Widget _buildStats() {
    final top = (_data['top_speed_kmh'] as num?)?.toDouble() ?? 0;
    final lean = (_data['max_lean_angle'] as num?)?.toDouble() ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.event, size: 18, color: Colors.white54),
            const SizedBox(width: 8),
            Text(
              _formatTimestamp(_data['timestamp'] as String?),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            _statCard(
              icon: Icons.speed,
              label: 'Top speed',
              value: '${top.toStringAsFixed(1)} km/h',
              color: Colors.orangeAccent,
            ),
            const SizedBox(width: 12),
            _statCard(
              icon: Icons.motorcycle,
              label: 'Max lean',
              value: '${lean.toStringAsFixed(0)}°',
              color: Colors.redAccent,
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _statCard(
              icon: Icons.route,
              label: 'Distance',
              value: '${_distanceKm.toStringAsFixed(2)} km',
              color: Colors.blueAccent,
            ),
            const SizedBox(width: 12),
            _statCard(
              icon: Icons.place,
              label: 'GPS points',
              value: '${_points.length}',
              color: Colors.tealAccent,
            ),
          ],
        ),
      ],
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(height: 10),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}
