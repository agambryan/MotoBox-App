import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static SupabaseService? _instance;
  StreamSubscription<AuthState>? _authSubscription;
  Timer? _refreshTimer;

  SupabaseService._();

  factory SupabaseService() {
    _instance ??= SupabaseService._();
    return _instance!;
  }

  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (e) {
      debugPrint('Supabase not initialized: $e');
      return null;
    }
  }

  bool get isInitialized {
    try {
      Supabase.instance.client;
      return true;
    } catch (e) {
      return false;
    }
  }

  User? get currentUser {
    final client = _supabase;
    if (client == null) return null;
    try {
      return client.auth.currentUser;
    } catch (e) {
      debugPrint('Error getting current user: $e');
      return null;
    }
  }

  Future<Session?> getCurrentSession() async {
    try {
      final client = _supabase;
      if (client == null) return null;
      return client.auth.currentSession;
    } catch (e) {
      debugPrint('Error getting session: $e');
      return null;
    }
  }

  bool get isLoggedIn => currentUser != null;

  String? get userId => currentUser?.id;

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final client = _supabase;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }

      final response = await client.auth.signUp(
        email: email,
        password: password,
        data: {'username': username},
      );

      if (response.user != null) {
        try {
          await Future.delayed(const Duration(milliseconds: 500));

          final client = _supabase;
          if (client != null) {
            await client.from('profiles').upsert({
              'id': response.user!.id,
              'username': username,
              'email': email,
            }, onConflict: 'id');
          }
        } catch (profileError) {
          debugPrint('Error creating profile: $profileError');
        }
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<AuthResponse> signIn({
    required String emailOrUsername,
    required String password,
  }) async {
    try {
      final client = _supabase;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }

      String email = emailOrUsername;

      // Cek apakah input adalah email atau username
      if (!emailOrUsername.contains('@')) {
        // Input adalah username, cari email dari database
        try {
          final profileResponse = await client
              .from('profiles')
              .select('email')
              .eq('username', emailOrUsername)
              .maybeSingle();

          if (profileResponse == null) {
            throw AuthException('Username tidak ditemukan');
          }

          email = profileResponse['email'] as String;
        } catch (e) {
          throw AuthException('Username tidak ditemukan atau terjadi kesalahan');
        }
      }

      final response = await client.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (response.session != null) {
        _startAutoRefresh();
        _startSessionMonitoring();
      }

      return response;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    try {
      final client = _supabase;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }

      _stopAutoRefresh();
      _stopSessionMonitoring();

      await client.auth.signOut();
    } catch (e) {
      rethrow;
    }
  }

  /// Supabase SDK sudah menangani auto refresh, ini sebagai backup
  void _startAutoRefresh() {
    _stopAutoRefresh();

    _refreshTimer = Timer.periodic(const Duration(minutes: 50), (_) async {
      try {
        final client = _supabase;
        if (client == null) return;

        final session = client.auth.currentSession;
        if (session != null) {
          debugPrint('Auto refreshing session token...');
          await client.auth.refreshSession();
          debugPrint('Session token refreshed successfully');
        }
      } catch (e) {
        debugPrint('Error auto refreshing token: $e');
      }
    });

    debugPrint('Auto refresh token started');
  }

  void _stopAutoRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  void _startSessionMonitoring() {
    _stopSessionMonitoring();

    _authSubscription = _supabase?.auth.onAuthStateChange.listen(
      (AuthState data) {
        final event = data.event;
        final session = data.session;

        debugPrint('Auth state changed: $event');

        if (event == AuthChangeEvent.signedOut) {
          debugPrint('User signed out');
          _stopAutoRefresh();
        } else if (event == AuthChangeEvent.tokenRefreshed) {
          debugPrint('Token refreshed');
        } else if (event == AuthChangeEvent.signedIn) {
          debugPrint('User signed in');
          _startAutoRefresh();
        } else if (event == AuthChangeEvent.userUpdated) {
          debugPrint('User updated');
        }

        if (session == null && event != AuthChangeEvent.signedOut) {
          debugPrint('Session expired!');
          _handleSessionExpired();
        }
      },
      onError: (error) {
        debugPrint('Auth state error: $error');
      },
    );

    debugPrint('Session monitoring started');
  }

  void _stopSessionMonitoring() {
    _authSubscription?.cancel();
    _authSubscription = null;
  }

  void _handleSessionExpired() {
    debugPrint('Handling session expired...');
  }

  Future<bool> isSessionValid() async {
    try {
      final session = await getCurrentSession();
      if (session == null) return false;

      final expiresAt = session.expiresAt;
      if (expiresAt == null) return false;

      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      return expiresAt > now;
    } catch (e) {
      debugPrint('Error checking session validity: $e');
      return false;
    }
  }

  Future<void> refreshSession() async {
    try {
      final client = _supabase;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }

      debugPrint('Manually refreshing session...');
      final response = await client.auth.refreshSession();

      if (response.session != null) {
        debugPrint('Session refreshed successfully');
      } else {
        throw Exception('Failed to refresh session');
      }
    } catch (e) {
      debugPrint('Error refreshing session: $e');
      rethrow;
    }
  }

  void dispose() {
    _stopAutoRefresh();
    _stopSessionMonitoring();
  }

  Future<Map<String, dynamic>?> getUserProfile() async {
    try {
      final client = _supabase;
      if (client == null || userId == null) return null;

      final response = await client
          .from('profiles')
          .select()
          .eq('id', userId!)
          .single();

      return response;
    } catch (e) {
      debugPrint('Error getting user profile: $e');
      return null;
    }
  }

  Future<void> updateProfile({String? username}) async {
    try {
      final client = _supabase;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }
      if (userId == null) throw Exception('User not logged in');

      await client
          .from('profiles')
          .update({if (username != null) 'username': username})
          .eq('id', userId!);
    } catch (e) {
      rethrow;
    }
  }

  Future<void> resetPassword(String email) async {
    try {
      final client = _supabase;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }
      await client.auth.resetPasswordForEmail(email);
    } catch (e) {
      rethrow;
    }
  }

  Stream<AuthState> get authStateChanges {
    final client = _supabase;
    if (client == null) {
      return const Stream.empty();
    }
    return client.auth.onAuthStateChange;
  }

  Future<void> saveMotorToCloud(Map<String, dynamic> motor) async {
    try {
      final client = _supabase;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }
      if (userId == null) throw Exception('User not logged in');

      await client.from('motors').upsert({
        ...motor,
        'user_id': userId,
      }, onConflict: 'id');
    } catch (e) {
      debugPrint('Error saving motor to cloud: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMotorsFromCloud() async {
    try {
      final client = _supabase;
      if (client == null) {
        debugPrint('Supabase not initialized');
        return [];
      }
      if (userId == null) throw Exception('User not logged in');

      final response = await client
          .from('motors')
          .select()
          .eq('user_id', userId!)
          .order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting motors from cloud: $e');
      return [];
    }
  }

  Future<void> updateMotorInCloud(Map<String, dynamic> motor) async {
    try {
      final client = _supabase;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }
      if (userId == null) throw Exception('User not logged in');

      await client
          .from('motors')
          .update(motor)
          .eq('id', motor['id'])
          .eq('user_id', userId!);
    } catch (e) {
      debugPrint('Error updating motor in cloud: $e');
      rethrow;
    }
  }

  Future<void> deleteMotorFromCloud(String motorId) async {
    try {
      final client = _supabase;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }
      if (userId == null) throw Exception('User not logged in');

      await client
          .from('motors')
          .delete()
          .eq('id', motorId)
          .eq('user_id', userId!);
    } catch (e) {
      debugPrint('Error deleting motor from cloud: $e');
      rethrow;
    }
  }

  Future<void> saveComponentsToCloud(List<Map<String, dynamic>> components) async {
    try {
      final client = _supabase;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }
      if (userId == null) throw Exception('User not logged in');

      if (components.isEmpty) return;

      final componentsWithUserId = components.map((c) => {
        ...c,
        'user_id': userId,
      }).toList();

      await client.from('components').upsert(componentsWithUserId, onConflict: 'id');
    } catch (e) {
      debugPrint('Error saving components to cloud: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getComponentsFromCloud(String motorId) async {
    try {
      final client = _supabase;
      if (client == null) {
        debugPrint('Supabase not initialized');
        return [];
      }
      if (userId == null) throw Exception('User not logged in');

      final response = await client
          .from('components')
          .select()
          .eq('motor_id', motorId)
          .eq('user_id', userId!);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting components from cloud: $e');
      return [];
    }
  }

  Future<void> saveMotorPhotoToCloud(Map<String, dynamic> photo) async {
    try {
      final client = _supabase;
      if (client == null) {
        throw Exception('Supabase not initialized');
      }
      if (userId == null) throw Exception('User not logged in');

      await client.from('motor_photos').upsert({
        ...photo,
        'user_id': userId,
      });
    } catch (e) {
      debugPrint('Error saving motor photo to cloud: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> getMotorPhotosFromCloud(String motorId) async {
    try {
      final client = _supabase;
      if (client == null) {
        debugPrint('Supabase not initialized');
        return [];
      }
      if (userId == null) throw Exception('User not logged in');

      final response = await client
          .from('motor_photos')
          .select()
          .eq('motor_id', motorId)
          .eq('user_id', userId!)
          .order('is_primary', ascending: false);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Error getting motor photos from cloud: $e');
      return [];
    }
  }
}
