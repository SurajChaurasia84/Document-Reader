import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/app_file.dart';

class DatabaseService {
  static const _dbName = 'doc_reader.db';
  static const _tableRecent = 'recent_files';

  Database? _database;

  Future<void> init() async {
    if (_database != null) {
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final dbPath = p.join(directory.path, _dbName);
    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableRecent(
            path TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            extension TEXT NOT NULL,
            size INTEGER NOT NULL,
            modified_at INTEGER NOT NULL,
            opened_at INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  Future<void> upsertRecentFile(AppFile file) async {
    await init();
    await _database!.insert(_tableRecent, <String, Object?>{
      ...file.toMap(),
      'opened_at': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<AppFile>> getRecentFiles() async {
    await init();
    final rows = await _database!.query(
      _tableRecent,
      orderBy: 'opened_at DESC',
      limit: 20,
    );
    return rows.map((row) => AppFile.fromMap(row)).toList();
  }

  Future<void> deleteRecentFile(String path) async {
    await init();
    await _database!.delete(
      _tableRecent,
      where: 'path = ?',
      whereArgs: <Object?>[path],
    );
  }
}
