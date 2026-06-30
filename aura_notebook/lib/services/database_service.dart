import 'dart:io';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../screens/class_mode/class_pages/class_data.dart';

class DatabaseService {
  static final DatabaseService instance = DatabaseService._init();
  static Database? _database;

  DatabaseService._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('aura_classes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    if (Platform.isLinux || Platform.isWindows) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(path, version: 1, onCreate: _createDB);
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE classes (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  section TEXT NOT NULL,
  subject TEXT NOT NULL,
  teacher TEXT NOT NULL,
  students INTEGER NOT NULL
)
''');
  }

  Future<int> createClass(ClassData classData) async {
    final db = await instance.database;
    return await db.insert('classes', classData.toMap());
  }

  Future<List<ClassData>> readAllClasses() async {
    final db = await instance.database;
    final result = await db.query('classes', orderBy: 'id DESC');
    return result.map((json) => ClassData.fromMap(json)).toList();
  }

  Future<int> deleteClass(int id) async {
    final db = await instance.database;
    return await db.delete('classes', where: 'id = ?', whereArgs: [id]);
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
