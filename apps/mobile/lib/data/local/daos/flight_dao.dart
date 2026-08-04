// Flight DAO — VSP Mobile App
//
// SQLite Data Access Object for Flight entities.
// Provides CRUD operations on the flights table.
//
// Story 5.3 — Slice 2: Score SQLite Persistence

import 'package:sqflite/sqflite.dart';

import '../../../domain/models/flight.dart';
import '../tables/flights_table.dart';

/// Data Access Object for Flight persistence.
class FlightDao {
  static const String _dbName = 'vsp_round.db';
  static const int _dbVersion = 1;

  Database? _db;

  Future<Database> get _database async {
    if (_db != null) return _db!;
    _db = await _initDb();
    return _db!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = '$dbPath/$_dbName';
    return openDatabase(path, version: _dbVersion, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute(kFlightsTableCreateSql);
    await db.execute(kFlightsTableRoundIndexSql);
  }

  /// Insert a new flight. Fails if ID already exists.
  Future<void> insert(Flight flight) async {
    final db = await _database;
    await db.insert(
      kFlightsTableName,
      flight.toMap(),
      conflictAlgorithm: ConflictAlgorithm.fail,
    );
  }

  /// Update an existing flight by ID.
  Future<void> update(Flight flight) async {
    final db = await _database;
    final updated = flight.copyWith(updatedAt: DateTime.now());
    await db.update(
      kFlightsTableName,
      updated.toMap(),
      where: 'id = ?',
      whereArgs: [flight.id],
    );
  }

  /// Delete a flight by ID.
  Future<void> delete(String id) async {
    final db = await _database;
    await db.delete(kFlightsTableName, where: 'id = ?', whereArgs: [id]);
  }

  /// Retrieve a flight by ID.
  Future<Flight?> getById(String id) async {
    final db = await _database;
    final rows = await db.query(
      kFlightsTableName,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return Flight.fromMap(rows.first);
  }

  /// Retrieve all flights for a round, ordered by flight_index.
  Future<List<Flight>> getByRoundId(String roundId) async {
    final db = await _database;
    final rows = await db.query(
      kFlightsTableName,
      where: 'round_id = ?',
      whereArgs: [roundId],
      orderBy: 'flight_index ASC',
    );
    return rows.map((row) => Flight.fromMap(row)).toList();
  }

  /// Close the database connection.
  Future<void> close() async {
    final db = await _database;
    await db.close();
    _db = null;
  }
}
