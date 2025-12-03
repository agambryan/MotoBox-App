import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'connectivity_service.dart';

/// Service untuk mengelola sync queue offline-first
/// Menyimpan operasi yang gagal dan retry saat online
class SyncQueueService {
  static SyncQueueService? _instance;
  static const String _queueKey = 'sync_queue';
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  final List<SyncOperation> _queue = [];
  Timer? _syncTimer;
  bool _isSyncing = false;

  // Private constructor
  SyncQueueService._();

  // Singleton instance
  static Future<SyncQueueService> getInstance() async {
    if (_instance == null) {
      _instance = SyncQueueService._();
      await _instance!._loadQueue();
      _instance!._startAutoSync();
    }
    return _instance!;
  }

  /// Get Supabase client safely
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('Supabase not initialized: $e');
      return null;
    }
  }

  /// Load queue from SharedPreferences
  Future<void> _loadQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = prefs.getString(_queueKey);

      if (queueJson != null && queueJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(queueJson);
        _queue.clear();
        _queue.addAll(decoded.map((e) => SyncOperation.fromJson(e)));
        debugPrint('Loaded ${_queue.length} operations from sync queue');
      }
    } catch (e) {
      debugPrint('Error loading sync queue: $e');
    }
  }

  /// Save queue to SharedPreferences
  Future<void> _saveQueue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final queueJson = jsonEncode(_queue.map((e) => e.toJson()).toList());
      await prefs.setString(_queueKey, queueJson);
    } catch (e) {
      debugPrint('Error saving sync queue: $e');
    }
  }

  /// Add operation to queue
  Future<void> addToQueue(SyncOperation operation) async {
    _queue.add(operation);
    await _saveQueue();
    debugPrint('Added operation to sync queue: ${operation.type} - ${operation.table}');

    // Try to sync immediately if online
    if (ConnectivityService.instance.isOnline && !_isSyncing) {
      _processQueue();
    }
  }

  /// Start auto sync timer
  void _startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (ConnectivityService.instance.isOnline && !_isSyncing) {
        _processQueue();
      }
    });
  }

  /// Process sync queue
  Future<void> _processQueue() async {
    if (_isSyncing || _queue.isEmpty) return;
    if (!ConnectivityService.instance.isOnline) {
      debugPrint('Cannot sync: device is offline');
      return;
    }

    _isSyncing = true;
    debugPrint('Processing sync queue: ${_queue.length} operations');

    final operationsToProcess = List<SyncOperation>.from(_queue);

    for (final operation in operationsToProcess) {
      try {
        final success = await _syncOperation(operation);

        if (success) {
          _queue.remove(operation);
          debugPrint('Synced operation: ${operation.type} - ${operation.table}');
        } else {
          operation.retryCount++;

          if (operation.retryCount >= _maxRetries) {
            debugPrint('Max retries reached for operation: ${operation.id}');
            _queue.remove(operation);
          } else {
            debugPrint(
              'Retry ${operation.retryCount}/$_maxRetries for operation: ${operation.id}',
            );
            await Future.delayed(_retryDelay);
          }
        }
      } catch (e) {
        debugPrint('Error syncing operation: $e');
        operation.retryCount++;

        if (operation.retryCount >= _maxRetries) {
          _queue.remove(operation);
        }
      }
    }

    await _saveQueue();
    _isSyncing = false;

    debugPrint('Sync queue processed. Remaining: ${_queue.length}');
  }

  /// Sync single operation
  Future<bool> _syncOperation(SyncOperation operation) async {
    try {
      final client = _supabase;
      if (client == null) {
        debugPrint('Supabase not initialized, skipping sync');
        return false;
      }

      switch (operation.type) {
        case SyncOperationType.insert:
        case SyncOperationType.update:
          await client
              .from(operation.table)
              .upsert(operation.data, onConflict: 'id');
          return true;

        case SyncOperationType.delete:
          await client
              .from(operation.table)
              .delete()
              .eq('id', operation.data['id']);
          return true;
      }
    } catch (e) {
      debugPrint('Error in _syncOperation: $e');
      return false;
    }
  }

  /// Force sync now
  Future<void> forceSyncNow() async {
    if (!ConnectivityService.instance.isOnline) {
      throw Exception('Cannot sync: device is offline');
    }
    await _processQueue();
  }

  /// Get pending operations count
  int get pendingCount => _queue.length;

  /// Clear all queue
  Future<void> clearQueue() async {
    _queue.clear();
    await _saveQueue();
  }

  /// Dispose resources
  void dispose() {
    _syncTimer?.cancel();
  }
}

/// Sync operation model
class SyncOperation {
  final String id;
  final SyncOperationType type;
  final String table;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  int retryCount;

  SyncOperation({
    required this.id,
    required this.type,
    required this.table,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
  });

  factory SyncOperation.fromJson(Map<String, dynamic> json) {
    return SyncOperation(
      id: json['id'] as String,
      type: SyncOperationType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => SyncOperationType.insert,
      ),
      table: json['table'] as String,
      data: Map<String, dynamic>.from(json['data'] as Map),
      createdAt: DateTime.parse(json['createdAt'] as String),
      retryCount: json['retryCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'table': table,
      'data': data,
      'createdAt': createdAt.toIso8601String(),
      'retryCount': retryCount,
    };
  }
}

/// Sync operation type
enum SyncOperationType {
  insert,
  update,
  delete,
}
