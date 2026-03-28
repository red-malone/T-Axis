// lib/core/db_helper.dart

import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  // 1. Singleton Setup
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // 2. Open the Database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('t_axis_rides.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Creates the database if it doesn't exist
    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  // 3. Create the Schema
  Future _createDB(Database db, int version) async {
    // We use a TEXT field for the route to store it as a JSON string
    // 'is_synced' helps us know if we've pushed it to Firebase yet
    await db.execute('''
      CREATE TABLE rides (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        top_speed_kmh REAL NOT NULL,
        max_lean_angle REAL NOT NULL,
        route_json TEXT NOT NULL,
        is_synced INTEGER NOT NULL DEFAULT 0 
      )
    ''');
  }

  // 4. Save a Ride (The Flight Recorder)
  Future<int> insertRide({
    required double topSpeed,
    required double maxLean,
    required List<Map<String, double>> routeData,
  }) async {
    final db = await instance.database;

    // Convert the List of GPS points into a single JSON string
    String routeJsonString = jsonEncode(routeData);

    final data = {
      'timestamp': DateTime.now().toIso8601String(),
      'top_speed_kmh': topSpeed,
      'max_lean_angle': maxLean,
      'route_json': routeJsonString,
      'is_synced': 0, // 0 = Not synced to Firebase yet
    };

    return await db.insert('rides', data);
  }

  // 5. Get Unsynced Rides (For when you connect to Wi-Fi)
  Future<List<Map<String, dynamic>>> getUnsyncedRides() async {
    final db = await instance.database;
    return await db.query('rides', where: 'is_synced = ?', whereArgs: [0]);
  }

  // 6. Mark as Synced
  Future<int> markRideAsSynced(int id) async {
    final db = await instance.database;
    return await db.update(
      'rides',
      {'is_synced': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}