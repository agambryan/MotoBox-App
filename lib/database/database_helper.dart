import 'dart:async';
import 'dart:io' show Platform;
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;
import '../services/lifespan_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;
  static DatabaseFactory? _factory;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    try {
      if (_factory == null) {
        if (kIsWeb) {
          throw UnsupportedError('Web is not supported');
        } else if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
          ffi.sqfliteFfiInit();
          _factory = ffi.databaseFactoryFfi;
          databaseFactory = ffi.databaseFactoryFfi;
        } else {
          _factory = databaseFactory;
        }
      }

      String path = join(await _factory!.getDatabasesPath(), 'motobox.db');

      return await _factory!.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 12,
          onCreate: _onCreate,
          onUpgrade: _onUpgrade,
        ),
      );
    } catch (e) {
      debugPrint('Database error: $e');
      rethrow;
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS motor_initialization(
        motor_id TEXT PRIMARY KEY,
        components_initialized INTEGER DEFAULT 0,
        initialized_at TEXT,
        FOREIGN KEY (motor_id) REFERENCES motors(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS motors(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        nama TEXT NOT NULL,
        merk TEXT NOT NULL,
        model TEXT NOT NULL,
        category TEXT,
        start_odometer INTEGER DEFAULT 0,
        gambar TEXT,
        gambar_url TEXT,
        harga INTEGER DEFAULT 0,
        odometer INTEGER DEFAULT 0,
        odometer_last_update INTEGER DEFAULT 0,
        fuel_level REAL DEFAULT 0,
        fuel_last_update TEXT,
        fuel_last_refill_date TEXT,
        fuel_last_refill_percent REAL,
        fuel_last_refill_odometer INTEGER,
        fuel_tank_volume_liters REAL,
        fuel_type TEXT,
        fuel_efficiency REAL DEFAULT 0,
        fuel_efficiency_source TEXT DEFAULT 'default',
        auto_increment_enabled INTEGER DEFAULT 0,
        daily_km INTEGER DEFAULT 0,
        auto_increment_enabled_date TEXT,
        location_tracking_enabled INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS motor_photos(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        motor_id TEXT NOT NULL,
        photo_path TEXT NOT NULL,
        is_primary INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        FOREIGN KEY (motor_id) REFERENCES motors(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS components(
        id TEXT PRIMARY KEY,
        user_id TEXT,
        motor_id TEXT NOT NULL,
        nama TEXT NOT NULL,
        lifespan_km INTEGER NOT NULL DEFAULT 0,
        lifespan_days INTEGER NOT NULL DEFAULT 0,
        lifespan_source TEXT NOT NULL DEFAULT 'default',
        last_replacement_km INTEGER DEFAULT 0,
        last_replacement_date TEXT,
        keterangan TEXT,
        is_active INTEGER DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (motor_id) REFERENCES motors(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS odometer_history(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        motor_id TEXT NOT NULL,
        odometer_value INTEGER NOT NULL,
        source TEXT NOT NULL,
        location_lat REAL,
        location_lng REAL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (motor_id) REFERENCES motors(id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS user_profile(
        id INTEGER PRIMARY KEY CHECK (id = 1),
        user_id TEXT UNIQUE,
        name TEXT,
        nim TEXT,
        place_of_birth TEXT,
        date_of_birth TEXT,
        hobbies TEXT,
        photo_path TEXT,
        updated_at TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS feedback_entries(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id TEXT,
        category TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<bool> isComponentsInitialized(String motorId) async {
    final db = await database;
    final result = await db.query(
      'motor_initialization',
      where: 'motor_id = ?',
      whereArgs: [motorId],
    );
    return result.isNotEmpty && result.first['components_initialized'] == 1;
  }

  Future<void> markComponentsInitialized(String motorId) async {
    final db = await database;
    await db.insert('motor_initialization', {
      'motor_id': motorId,
      'components_initialized': 1,
      'initialized_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // PENTING: Hanya handle versi terbaru (7-12). User di versi lama (<7) akan otomatis recreate via onCreate

    if (oldVersion < 7) {
      try {
        await db.execute("ALTER TABLE components ADD COLUMN lifespan_source TEXT NOT NULL DEFAULT 'default'");
      } catch (_) {}
    }

    if (oldVersion < 8) {
      try {
        await db.execute('ALTER TABLE motors ADD COLUMN category TEXT');
      } catch (_) {}
    }

    if (oldVersion < 9) {
      try { await db.execute('ALTER TABLE motors ADD COLUMN user_id TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE motor_photos ADD COLUMN user_id TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE feedback_entries ADD COLUMN user_id TEXT'); } catch (_) {}
    }

    if (oldVersion < 10) {
      try { await db.execute('ALTER TABLE components ADD COLUMN user_id TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE odometer_history ADD COLUMN user_id TEXT'); } catch (_) {}
    }

    if (oldVersion < 11) {
      try { await db.execute('ALTER TABLE motors ADD COLUMN start_odometer INTEGER DEFAULT 0'); } catch (_) {}
      try { await db.execute('ALTER TABLE motors ADD COLUMN fuel_last_refill_date TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE motors ADD COLUMN fuel_last_refill_percent REAL'); } catch (_) {}
      try { await db.execute('ALTER TABLE motors ADD COLUMN fuel_last_refill_odometer INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE motors ADD COLUMN fuel_tank_volume_liters REAL'); } catch (_) {}
      try { await db.execute('ALTER TABLE motors ADD COLUMN fuel_type TEXT'); } catch (_) {}
      try { await db.execute('ALTER TABLE motors ADD COLUMN fuel_efficiency REAL'); } catch (_) {}
      try { await db.execute('ALTER TABLE motors ADD COLUMN fuel_efficiency_source TEXT'); } catch (_) {}
    }

    if (oldVersion < 12) {
      debugPrint('Migrating motors table to snake_case (v12)');
      try {
        await db.execute('ALTER TABLE motors RENAME COLUMN odometerLastUpdate TO odometer_last_update');
      } catch (e) { debugPrint('Migration odometer_last_update: $e'); }

      try {
        await db.execute('ALTER TABLE motors RENAME COLUMN fuelLevel TO fuel_level');
      } catch (e) { debugPrint('Migration fuel_level: $e'); }

      try {
        await db.execute('ALTER TABLE motors RENAME COLUMN fuelLastUpdate TO fuel_last_update');
      } catch (e) { debugPrint('Migration fuel_last_update: $e'); }

      try {
        await db.execute('ALTER TABLE motors RENAME COLUMN autoIncrementEnabled TO auto_increment_enabled');
      } catch (e) { debugPrint('Migration auto_increment_enabled: $e'); }

      try {
        await db.execute('ALTER TABLE motors RENAME COLUMN dailyKm TO daily_km');
      } catch (e) { debugPrint('Migration daily_km: $e'); }

      try {
        await db.execute('ALTER TABLE motors RENAME COLUMN autoIncrementEnabledDate TO auto_increment_enabled_date');
      } catch (e) { debugPrint('Migration auto_increment_enabled_date: $e'); }

      try {
        await db.execute('ALTER TABLE motors RENAME COLUMN locationTrackingEnabled TO location_tracking_enabled');
      } catch (e) { debugPrint('Migration location_tracking_enabled: $e'); }

      try {
        await db.execute('ALTER TABLE motors RENAME COLUMN createdAt TO created_at');
      } catch (e) { debugPrint('Migration created_at: $e'); }

      try {
        await db.execute('ALTER TABLE motors RENAME COLUMN updatedAt TO updated_at');
      } catch (e) { debugPrint('Migration updated_at: $e'); }

      debugPrint('Schema migration to snake_case completed');
    }
  }

  Future<Map<String, dynamic>?> getUserProfile({required String userId}) async {
    final db = await database;
    final rows = await db.query(
      'user_profile',
      where: 'user_id = ?',
      whereArgs: [userId],
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  Future<void> upsertUserProfile({
    required String userId,
    String? name,
    String? nim,
    String? placeOfBirth,
    String? dateOfBirth,
    String? hobbies,
    String? photoPath,
  }) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final existing = await getUserProfile(userId: userId);
    final data = {
      'id': 1,
      'user_id': userId,
      'name': name ?? existing?['name'],
      'nim': nim ?? existing?['nim'],
      'place_of_birth': placeOfBirth ?? existing?['place_of_birth'],
      'date_of_birth': dateOfBirth ?? existing?['date_of_birth'],
      'hobbies': hobbies ?? existing?['hobbies'],
      'photo_path': photoPath ?? existing?['photo_path'],
      'updated_at': now,
    };
    await db.insert('user_profile', data, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> listFeedback({String? category}) async {
    final db = await database;
    final userId = _currentUserId();
    return await db.query(
      'feedback_entries',
      where: category != null ? 'category = ? AND user_id = ?' : 'user_id = ?',
      whereArgs: category != null ? [category, userId] : [userId],
      orderBy: 'updated_at DESC',
    );
  }

  Future<int> addFeedback({required String category, required String content}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final userId = _currentUserId();
    return await db.insert('feedback_entries', {
      'user_id': userId,
      'category': category,
      'content': content,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<int> updateFeedback({required int id, required String content}) async {
    final db = await database;
    final now = DateTime.now().toIso8601String();
    final userId = _currentUserId();
    return await db.update(
      'feedback_entries',
      {
        'content': content,
        'updated_at': now,
      },
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
    );
  }

  Future<int> deleteFeedback(int id) async {
    final db = await database;
    final userId = _currentUserId();
    return await db.delete('feedback_entries', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);
  }

  Future<int> insertMotor(Map<String, dynamic> motor) async {
    final db = await database;
    final userId = _currentUserId();
    final result = await db.insert('motors', {
      ...motor,
      'user_id': userId,
    });

    if (userId != 'local') {
      _syncMotorToCloud(motor, userId);
    }

    return result;
  }

  void _syncMotorToCloud(Map<String, dynamic> motor, String userId) {
    Future(() async {
      try {
        final supabase = Supabase.instance.client;
        final cloudData = _mapMotorToCloud(motor);
        cloudData['user_id'] = userId;
        await supabase.from('motors').upsert(cloudData, onConflict: 'id');
      } catch (e) {
        debugPrint('Failed to sync motor to cloud: $e');
      }
    });
  }

  Map<String, dynamic> _mapMotorToCloud(Map<String, dynamic> motor) {
    return motor;
  }

  Map<String, dynamic> _mapMotorFromCloud(Map<String, dynamic> motor) {
    return motor;
  }

  Future<List<Map<String, dynamic>>> getMotors() async {
    final db = await database;
    final userId = _currentUserId();
    return await db.query('motors', where: 'user_id = ?', whereArgs: [userId], orderBy: 'created_at DESC');
  }

  Future<Map<String, dynamic>?> getMotor(String id) async {
    final db = await database;
    final userId = _currentUserId();
    final results = await db.query(
      'motors',
      where: 'id = ? AND user_id = ?',
      whereArgs: [id, userId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> updateMotor(Map<String, dynamic> motor) async {
    final db = await database;
    final userId = _currentUserId();
    final result = await db.update(
      'motors',
      motor,
      where: 'id = ? AND user_id = ?',
      whereArgs: [motor['id'], userId],
    );

    if (userId != 'local') {
      _syncMotorToCloud(motor, userId);
    }

    return result;
  }

  Future<int> deleteMotor(String id) async {
    final db = await database;
    final userId = _currentUserId();
    final result = await db.delete('motors', where: 'id = ? AND user_id = ?', whereArgs: [id, userId]);

    if (userId != 'local') {
      Future(() async {
        try {
          final supabase = Supabase.instance.client;
          await supabase
              .from('motors')
              .delete()
              .eq('id', id)
              .eq('user_id', userId);
        } catch (e) {
          debugPrint('Failed to sync motor deletion to cloud: $e');
        }
      });
    }

    return result;
  }

  /// Restore semua motor dari Supabase ke database lokal
  Future<void> restoreMotorsFromCloud() async {
    final userId = _currentUserId();
    if (userId == 'local') {
      debugPrint('User not logged in, skipping restore');
      return;
    }

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('motors')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final motors = List<Map<String, dynamic>>.from(response);

      if (motors.isEmpty) {
        debugPrint('No motors found in cloud');
        return;
      }

      final db = await database;
      final batch = db.batch();

      for (var motor in motors) {
        final localData = _mapMotorFromCloud(motor);
        batch.insert(
          'motors',
          localData,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      debugPrint('Restored ${motors.length} motors from cloud');

      for (var motor in motors) {
        await restoreComponentsFromCloud(motor['id']);
      }
    } catch (e) {
      debugPrint('Error restoring motors from cloud: $e');
    }
  }

  /// Restore komponen untuk motor tertentu dari Supabase
  Future<void> restoreComponentsFromCloud(String motorId) async {
    final userId = _currentUserId();
    if (userId == 'local') return;

    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('components')
          .select()
          .eq('motor_id', motorId)
          .eq('user_id', userId);

      final components = List<Map<String, dynamic>>.from(response);

      if (components.isEmpty) {
        debugPrint('No components found in cloud for motor $motorId');
        return;
      }

      final db = await database;
      final batch = db.batch();

      for (var component in components) {
        batch.insert(
          'components',
          component,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      await batch.commit(noResult: true);
      debugPrint('Restored ${components.length} components for motor $motorId');
    } catch (e) {
      debugPrint('Error restoring components from cloud: $e');
    }
  }

  Future<int> insertMotorPhoto(Map<String, dynamic> photo) async {
    final db = await database;
    final userId = _currentUserId();
    return await db.insert('motor_photos', {
      ...photo,
      'user_id': userId,
    });
  }

  Future<List<Map<String, dynamic>>> getMotorPhotos(String motorId) async {
    final db = await database;
    final userId = _currentUserId();
    return await db.query(
      'motor_photos',
      where: 'motor_id = ? AND user_id = ?',
      whereArgs: [motorId, userId],
      orderBy: 'is_primary DESC, created_at DESC',
    );
  }

  Future<Map<String, dynamic>?> getPrimaryPhoto(String motorId) async {
    final db = await database;
    final results = await db.query(
      'motor_photos',
      where: 'motor_id = ? AND is_primary = 1',
      whereArgs: [motorId],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  Future<int> setPrimaryPhoto(int photoId, String motorId) async {
    final db = await database;
    await db.update(
      'motor_photos',
      {'is_primary': 0},
      where: 'motor_id = ?',
      whereArgs: [motorId],
    );
    return await db.update(
      'motor_photos',
      {'is_primary': 1},
      where: 'id = ?',
      whereArgs: [photoId],
    );
  }

  Future<int> deleteMotorPhoto(int photoId) async {
    final db = await database;
    final userId = _currentUserId();
    return await db.delete(
      'motor_photos',
      where: 'id = ? AND user_id = ?',
      whereArgs: [photoId, userId],
    );
  }

  Future<void> insertDefaultComponents(String motorId) async {
    final isInitialized = await isComponentsInitialized(motorId);
    if (isInitialized) {
      return;
    }

    final db = await database;
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();
    final userId = _currentUserId();

    final defaultComponents = [
      {
        'id': makeComponentId(motorId, 'ban'),
        'user_id': userId,
        'motor_id': motorId,
        'nama': 'Ban',
        'lifespan_km': 25000,
        'lifespan_days': 730,
        'lifespan_source': 'default',
        'last_replacement_km': 0,
        'last_replacement_date': null,
        'keterangan': null,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': makeComponentId(motorId, 'oli_mesin'),
        'user_id': userId,
        'motor_id': motorId,
        'nama': 'Oli Mesin',
        'lifespan_km': 3000,
        'lifespan_days': 180,
        'lifespan_source': 'default',
        'last_replacement_km': 0,
        'last_replacement_date': null,
        'keterangan': null,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': makeComponentId(motorId, 'kampas_rem_depan'),
        'user_id': userId,
        'motor_id': motorId,
        'nama': 'Kampas Rem Depan',
        'lifespan_km': 20000,
        'lifespan_days': 730,
        'lifespan_source': 'default',
        'last_replacement_km': 0,
        'last_replacement_date': null,
        'keterangan': null,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
      {
        'id': makeComponentId(motorId, 'oli_gardan'),
        'user_id': userId,
        'motor_id': motorId,
        'nama': 'Oli Gardan',
        'lifespan_km': 20000,
        'lifespan_days': 365,
        'lifespan_source': 'default',
        'last_replacement_km': 0,
        'last_replacement_date': null,
        'keterangan': null,
        'is_active': 1,
        'created_at': now,
        'updated_at': now,
      },
    ];

    for (var component in defaultComponents) {
      batch.insert(
        'components',
        component,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }

    await batch.commit(noResult: true);
    await markComponentsInitialized(motorId);
  }

  Future<int> insertComponent(Map<String, dynamic> component) async {
    final db = await database;
    final userId = _currentUserId();

    final motorId = component['motor_id'];
    final componentType = component['component_type'] ?? getComponentTypeFromId(component['id'] ?? '');
    final uniqueId = makeComponentId(motorId, componentType);

    final dbComponent = {
      'id': uniqueId,
      'user_id': component['user_id'] ?? userId,
      'motor_id': motorId,
      'nama': component['nama'],
      'lifespan_km': component['lifespanKm'] ?? component['lifespan_km'] ?? 0,
      'lifespan_days':
          component['lifespanDays'] ?? component['lifespan_days'] ?? 0,
      'lifespan_source': component['lifespan_source'] ?? 'default',
      'last_replacement_km':
          component['lastReplacementKm'] ??
          component['last_replacement_km'] ??
          0,
      'last_replacement_date':
          component['lastReplacementDate'] ??
          component['last_replacement_date'],
      'keterangan': component['keterangan'],
      'is_active': component['is_active'] ?? 1,
      'created_at': component['created_at'] ?? DateTime.now().toIso8601String(),
      'updated_at': component['updated_at'] ?? DateTime.now().toIso8601String(),
    };

    final result = await db.insert(
      'components',
      dbComponent,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (userId != 'local') {
      _syncComponentToCloud(dbComponent, userId);
    }

    return result;
  }

  void _syncComponentToCloud(Map<String, dynamic> component, String userId) {
    Future(() async {
      try {
        final supabase = Supabase.instance.client;
        await supabase.from('components').upsert({
          ...component,
          'user_id': userId,
        }, onConflict: 'id');
      } catch (e) {
        debugPrint('Failed to sync component to cloud: $e');
      }
    });
  }

  Future<List<Map<String, dynamic>>> getComponents(String motorId) async {
    final db = await database;
    final userId = _currentUserId();
    return await db.query(
      'components',
      where: 'motor_id = ? AND user_id = ?',
      whereArgs: [motorId, userId],
      orderBy: 'is_active DESC, nama ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getActiveComponents(String motorId) async {
    final db = await database;
    final userId = _currentUserId();
    return await db.query(
      'components',
      where: 'motor_id = ? AND user_id = ? AND is_active = 1',
      whereArgs: [motorId, userId],
      orderBy: 'nama ASC',
    );
  }

  Future<int> updateComponent(Map<String, dynamic> component) async {
    final db = await database;
    final userId = _currentUserId();

    final existingRows = await db.query(
      'components',
      where: 'id = ? AND motor_id = ? AND user_id = ?',
      whereArgs: [component['id'], component['motor_id'], userId],
      limit: 1,
    );

    final existing = existingRows.isNotEmpty ? existingRows.first : <String, dynamic>{};

    final merged = <String, dynamic>{
      'nama': component['nama'] ?? existing['nama'],
      'lifespan_km': (component['lifespanKm'] ?? component['lifespan_km'] ?? existing['lifespan_km'] ?? 0),
      'lifespan_days': (component['lifespanDays'] ?? component['lifespan_days'] ?? existing['lifespan_days'] ?? 0),
      'last_replacement_km': (component['lastReplacementKm'] ?? component['last_replacement_km'] ?? existing['last_replacement_km'] ?? 0),
      'last_replacement_date': component.containsKey('lastReplacementDate')
          ? component['lastReplacementDate']
          : (component.containsKey('last_replacement_date')
              ? component['last_replacement_date']
              : existing['last_replacement_date']),
      'keterangan': component.containsKey('keterangan') ? component['keterangan'] : existing['keterangan'],
      'is_active': component.containsKey('is_active') ? component['is_active'] : existing['is_active'],
      'updated_at': DateTime.now().toIso8601String(),
    };

    final providedKm = component['lifespanKm'] ?? component['lifespan_km'];
    final providedDays = component['lifespanDays'] ?? component['lifespan_days'];
    if (providedKm != null || providedDays != null) {
      merged['lifespan_source'] = 'custom';
    }

    final result = await db.update(
      'components',
      merged,
      where: 'id = ? AND motor_id = ? AND user_id = ?',
      whereArgs: [component['id'], component['motor_id'], userId],
    );

    if (userId != 'local') {
      _syncComponentToCloud({
        ...existing,
        ...merged,
        'id': component['id'],
        'motor_id': component['motor_id'],
      }, userId);
    }

    return result;
  }

  Future<int> toggleComponent(
    String motorId,
    String componentId,
    bool isActive,
  ) async {
    final db = await database;
    return await db.update(
      'components',
      {'is_active': isActive ? 1 : 0},
      where: 'id = ? AND motor_id = ? AND user_id = ?',
      whereArgs: [componentId, motorId, _currentUserId()],
    );
  }

  Future<int> deleteComponent(String componentId, String motorId) async {
    final db = await database;
    return await db.delete(
      'components',
      where: 'id = ? AND motor_id = ? AND user_id = ?',
      whereArgs: [componentId, motorId, _currentUserId()],
    );
  }

  Future<int> insertOdometerHistory(Map<String, dynamic> history) async {
    final db = await database;
    final userId = _currentUserId();
    return await db.insert('odometer_history', {
      ...history,
      'user_id': history['user_id'] ?? userId,
    });
  }

  Future<List<Map<String, dynamic>>> getOdometerHistory(
    String motorId, {
    int? limit,
  }) async {
    final db = await database;
    final userId = _currentUserId();
    return await db.query(
      'odometer_history',
      where: 'motor_id = ? AND user_id = ?',
      whereArgs: [motorId, userId],
      orderBy: 'created_at DESC',
      limit: limit,
    );
  }

  Future<void> saveMotorcycleFromApi(
    Map<String, dynamic> apiData,
    String motorId,
  ) async {
    final db = await database;

    try {
      await db.transaction((txn) async {
        await txn.update(
          'motors',
          {
            'merk': apiData['make'] ?? '',
            'model': apiData['model'] ?? '',
            'category': LifespanService.mapTypeToCategory(
              type: apiData['type'] as String?,
              engineCapacity: apiData['engine_capacity'] as int?,
            ),
            'updatedAt': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND user_id = ?',
          whereArgs: [motorId, _currentUserId()],
        );
      });

      try {
        await LifespanService.applyFromApiData(motorId: motorId, apiData: apiData);
      } catch (_) {}
    } catch (e) {
      debugPrint('Error saving motorcycle API data: $e');
      rethrow;
    }
  }

  /// PENTING: Digunakan saat logout untuk cleanup data user
  Future<void> clearUserData(String userId) async {
    try {
      final db = await database;

      debugPrint('Clearing all data for user: $userId');

      await db.delete('odometer_history', where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('components', where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('motor_photos', where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('motor_initialization', where: 'motor_id IN (SELECT id FROM motors WHERE user_id = ?)', whereArgs: [userId]);
      await db.delete('motors', where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('feedback_entries', where: 'user_id = ?', whereArgs: [userId]);
      await db.delete('user_profile', where: 'user_id = ?', whereArgs: [userId]);

      debugPrint('Successfully cleared all data for user: $userId');
    } catch (e) {
      debugPrint('Error clearing user data: $e');
      rethrow;
    }
  }

  Future<void> clearAllLocalData() async {
    try {
      final db = await database;

      debugPrint('Clearing ALL local data...');

      await db.delete('odometer_history');
      await db.delete('components');
      await db.delete('motor_photos');
      await db.delete('motor_initialization');
      await db.delete('motors');
      await db.delete('feedback_entries');
      await db.delete('user_profile');

      debugPrint('Successfully cleared all local data');
    } catch (e) {
      debugPrint('Error clearing all local data: $e');
      rethrow;
    }
  }

  Future<List<String>> getAllUserIds() async {
    try {
      final db = await database;

      final userIds = <String>{};

      final motors = await db.query('motors', columns: ['user_id']);
      userIds.addAll(motors.map((e) => e['user_id'] as String));

      final profiles = await db.query('user_profile', columns: ['user_id']);
      userIds.addAll(profiles.map((e) => e['user_id'] as String));

      return userIds.toList();
    } catch (e) {
      debugPrint('Error getting all user IDs: $e');
      return [];
    }
  }

  /// Cleanup data dari user lain saat login
  Future<void> cleanupOtherUsersData() async {
    try {
      final currentUserId = _currentUserId();
      final allUserIds = await getAllUserIds();

      debugPrint('Current user: $currentUserId');
      debugPrint('All users in DB: $allUserIds');

      for (final userId in allUserIds) {
        if (userId != currentUserId && userId != 'local') {
          debugPrint('Cleaning up data for other user: $userId');
          await clearUserData(userId);
        }
      }

      debugPrint('Cleanup complete');
    } catch (e) {
      debugPrint('Error cleaning up other users data: $e');
    }
  }
}


extension _CurrentUser on DatabaseHelper {
  String _currentUserId() {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      return user?.id ?? 'local';
    } catch (_) {
      return 'local';
    }
  }
}

String getComponentTypeFromId(String componentId) {
  if (componentId.contains('_')) {
    final parts = componentId.split('_');
    if (parts.length > 1) {
      return parts.sublist(1).join('_');
    }
  }
  return componentId;
}

String makeComponentId(String motorId, String componentType) {
  return '${motorId}_$componentType';
}
