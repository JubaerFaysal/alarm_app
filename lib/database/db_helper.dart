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
      version: 4, // Incremented version number
      onCreate: _createDatabase,
      onUpgrade: _upgradeDatabase,
    );
  }

  Future<void> _createDatabase(Database db, int version) async {
    await db.execute('''
      CREATE TABLE medicines(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        medicineNames TEXT NOT NULL,
        dosage TEXT NOT NULL,
        type TEXT NOT NULL,
        times TEXT NOT NULL,
        frequency TEXT NOT NULL,
        pillCount INTEGER NOT NULL,
        instructions TEXT,
        intakeTime TEXT NOT NULL,
        color INTEGER NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        isTaken INTEGER NOT NULL DEFAULT 0,
        createdAt TEXT NOT NULL,
        endDate TEXT NOT NULL
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
    if (oldVersion < 3) {
      await db.execute(
        'ALTER TABLE medicines ADD COLUMN isTaken INTEGER NOT NULL DEFAULT 0',
      );
    }
    if (oldVersion < 4) {
      // Add the missing name column and medicineNames column
      await db.execute('ALTER TABLE medicines ADD COLUMN name TEXT');
      await db.execute('ALTER TABLE medicines ADD COLUMN medicineNames TEXT');

      // Migrate existing data: copy old data to new columns
      final medicines = await db.query('medicines');
      for (final medicine in medicines) {
        // For existing records, set name to a default value and medicineNames as empty array
        await db.update(
          'medicines',
          {
            'name': 'Medicine', // Default name for existing records
            'medicineNames': '[]', // Empty array for existing records
          },
          where: 'id = ?',
          whereArgs: [medicine['id']],
        );
      }
    }
  }

  Future<int> insertMedicine(Medicine medicine) async {
    try {
      final db = await database;
      return await db.insert('medicines', medicine.toMap());
    } catch (e) {
      print('❌ Error inserting medicine: $e');
      rethrow;
    }
  }

  Future<List<Medicine>> getMedicines() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'medicines',
        orderBy: 'createdAt DESC',
      );
      return List.generate(maps.length, (i) => Medicine.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error getting medicines: $e');
      rethrow;
    }
  }

  Future<int> updateMedicine(Medicine medicine) async {
    try {
      final db = await database;
      return await db.update(
        'medicines',
        medicine.toMap(),
        where: 'id = ?',
        whereArgs: [medicine.id],
      );
    } catch (e) {
      print('❌ Error updating medicine: $e');
      rethrow;
    }
  }

  Future<int> deleteMedicine(int id) async {
    try {
      final db = await database;
      return await db.delete('medicines', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      print('❌ Error deleting medicine: $e');
      rethrow;
    }
  }

  Future<int> toggleMedicineStatus(int id, bool isActive) async {
    try {
      final db = await database;
      return await db.update(
        'medicines',
        {'isActive': isActive ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Error toggling medicine status: $e');
      rethrow;
    }
  }

  Future<int> markMedicineAsTaken(int id, bool isTaken) async {
    try {
      final db = await database;
      return await db.update(
        'medicines',
        {'isTaken': isTaken ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      print('❌ Error marking medicine as taken: $e');
      rethrow;
    }
  }

  Future<List<Medicine>> getActiveMedicines() async {
    try {
      final db = await database;
      final List<Map<String, dynamic>> maps = await db.query(
        'medicines',
        where: 'isActive = ?',
        whereArgs: [1],
      );
      return List.generate(maps.length, (i) => Medicine.fromMap(maps[i]));
    } catch (e) {
      print('❌ Error getting active medicines: $e');
      rethrow;
    }
  }

  // Add this method to reset database if needed
  Future<void> resetDatabase() async {
    try {
      final db = await database;
      await db.close();
      _database = null;

      String path = join(await getDatabasesPath(), 'medicines.db');
      await deleteDatabase(path);

      // Reinitialize database
      _database = await _initDatabase();
      print('✅ Database reset successfully');
    } catch (e) {
      print('❌ Error resetting database: $e');
    }
  }
}
