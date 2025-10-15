import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../model/medicine_model.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  factory DatabaseHelper() => _instance;
  DatabaseHelper._internal();

  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), 'medicines.db');
    return await openDatabase(
      path,
      version: 2,
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medicines(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        dosage TEXT NOT NULL,
        type TEXT NOT NULL,
        times TEXT NOT NULL,
        frequency TEXT NOT NULL,
        pillCount INTEGER NOT NULL,
        instructions TEXT,
        intakeTime TEXT NOT NULL,
        color INTEGER NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        endDate TEXT
      )
    ''');
  }

  Future<void> _upgradeDatabase(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE medicines ADD COLUMN endDate TEXT');
    }
  }

  // Insert medicine
  Future<int> insertMedicine(Medicine medicine) async {
    final db = await database;
    return await db.insert('medicines', medicine.toMap());
  }

  // Get all medicines
  Future<List<Medicine>> getMedicines() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'medicines',
      orderBy: 'createdAt DESC',
    );
    return List.generate(maps.length, (i) {
      return Medicine.fromMap(maps[i]);
    });
  }

  // Update medicine
  Future<int> updateMedicine(Medicine medicine) async {
    final db = await database;
    return await db.update(
      'medicines',
      medicine.toMap(),
      where: 'id = ?',
      whereArgs: [medicine.id],
    );
  }

  // Delete medicine
  Future<int> deleteMedicine(int id) async {
    final db = await database;
    return await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
  }

  // Toggle medicine status
  Future<int> toggleMedicineStatus(int id, bool isActive) async {
    final db = await database;
    return await db.update(
      'medicines',
      {'isActive': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Get active medicines (for alarm scheduling)
  Future<List<Medicine>> getActiveMedicines() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'medicines',
      where: 'isActive = ?',
      whereArgs: [1],
    );
    return List.generate(maps.length, (i) {
      return Medicine.fromMap(maps[i]);
    });
  }
}
