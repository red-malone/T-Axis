import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:t_axis/core/utilities/db_helper.dart';

/// Small service to push locally cached rides to Firestore and mark them
/// as synced in the local SQLite database.
class FirebaseSync {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Finds all unsynced rides in the local DB and uploads them to
  /// the `rides` collection in Firestore. Successfully uploaded rows
  /// are marked as synced locally.
  Future<void> syncUnsyncedRides() async {
    final List<Map<String, dynamic>> unsynced = await DatabaseHelper.instance
        .getUnsyncedRides();

    for (final ride in unsynced) {
      final int id = ride['id'] as int;
      try {
        final String routeJson = ride['route_json'] as String;
        final List<dynamic> route = jsonDecode(routeJson) as List<dynamic>;

        final Map<String, dynamic> doc = {
          'timestamp': ride['timestamp'] ?? DateTime.now().toIso8601String(),
          'top_speed_kmh': ride['top_speed_kmh'],
          'max_lean_angle': ride['max_lean_angle'],
          'route': route,
          'device': 'watch',
        };

        await _firestore.collection('rides').add(doc);
        await DatabaseHelper.instance.markRideAsSynced(id);
        if (kDebugMode) {
          print('[FirebaseSync] Synced ride $id to Firestore');
        }
      } catch (e) {
        // Don't rethrow — we want to continue trying other rides
        if (kDebugMode) {
          print('[FirebaseSync] Failed to sync ride $id: $e');
        }
      }
    }
  }
}
