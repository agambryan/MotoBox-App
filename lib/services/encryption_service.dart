import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

/// Service untuk enkripsi dan dekripsi data sensitif
class EncryptionService {
  static EncryptionService? _instance;

  EncryptionService._();

  static EncryptionService get instance {
    _instance ??= EncryptionService._();
    return _instance!;
  }

  /// Generate database password from user ID
  /// PENTING: Untuk production, sebaiknya gunakan user input password atau device-specific key
  String generateDbPassword(String userId) {
    const appSalt = 'MotoBox_2024_Secret';
    final combined = '$userId-$appSalt';

    final bytes = utf8.encode(combined);
    final digest = sha256.convert(bytes);

    return digest.toString();
  }

  String hashData(String data) {
    final bytes = utf8.encode(data);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  String? validatePhotoPath(String? path) {
    if (path == null || path.isEmpty) {
      return null;
    }

    try {
      if (path.contains('..') || path.contains('~')) {
        debugPrint('Invalid photo path: contains directory traversal');
        return null;
      }

      if (path.contains('\x00')) {
        debugPrint('Invalid photo path: contains null bytes');
        return null;
      }

      const allowedExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
      final lowerPath = path.toLowerCase();

      if (!allowedExtensions.any((ext) => lowerPath.endsWith(ext))) {
        debugPrint('Invalid photo path: unsupported extension');
        return null;
      }

      if (path.length > 500) {
        debugPrint('Invalid photo path: too long');
        return null;
      }

      final normalized = path.replaceAll(RegExp(r'[/\\]+'), '/');

      return normalized;
    } catch (e) {
      debugPrint('Error validating photo path: $e');
      return null;
    }
  }

  String sanitizeFileName(String fileName) {
    var sanitized = fileName.replaceAll(RegExp(r'[^\w\s\-\.]'), '');
    sanitized = sanitized.replaceAll(RegExp(r'\s+'), '_');

    final parts = sanitized.split('.');
    if (parts.length > 2) {
      final name = parts.sublist(0, parts.length - 1).join('_');
      final ext = parts.last;
      sanitized = '$name.$ext';
    }

    if (sanitized.length > 100) {
      final ext = sanitized.split('.').last;
      final name = sanitized.substring(0, 95 - ext.length);
      sanitized = '$name.$ext';
    }

    return sanitized.toLowerCase();
  }

  String generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = Random.secure();
    return List.generate(length, (index) => chars[random.nextInt(chars.length)]).join();
  }

  String generateSecureFileName(String originalName) {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = generateRandomString(8);
    final extension = originalName.split('.').last.toLowerCase();

    return '${timestamp}_$random.$extension';
  }

  String sanitizeInput(String input) {
    var sanitized = input.replaceAll(RegExp(r'[\x00-\x1F\x7F]'), '');
    sanitized = sanitized.trim();

    if (sanitized.length > 1000) {
      sanitized = sanitized.substring(0, 1000);
    }

    return sanitized;
  }

  bool containsSqlInjection(String input) {
    final dangerousPatterns = [
      RegExp(r"';", caseSensitive: false),
      RegExp(r'--', caseSensitive: false),
      RegExp(r'/\*', caseSensitive: false),
      RegExp(r'\*/', caseSensitive: false),
      RegExp(r'xp_', caseSensitive: false),
      RegExp(r'sp_', caseSensitive: false),
      RegExp(r'exec\s', caseSensitive: false),
      RegExp(r'execute\s', caseSensitive: false),
      RegExp(r'union\s', caseSensitive: false),
      RegExp(r'select\s.*from', caseSensitive: false),
      RegExp(r'insert\s.*into', caseSensitive: false),
      RegExp(r'delete\s.*from', caseSensitive: false),
      RegExp(r'update\s.*set', caseSensitive: false),
      RegExp(r'drop\s.*table', caseSensitive: false),
    ];

    return dangerousPatterns.any((pattern) => pattern.hasMatch(input));
  }

  bool containsXss(String input) {
    final dangerousPatterns = [
      RegExp(r'<script', caseSensitive: false),
      RegExp(r'javascript:', caseSensitive: false),
      RegExp(r'onerror\s*=', caseSensitive: false),
      RegExp(r'onload\s*=', caseSensitive: false),
      RegExp(r'onclick\s*=', caseSensitive: false),
      RegExp(r'<iframe', caseSensitive: false),
      RegExp(r'<embed', caseSensitive: false),
      RegExp(r'<object', caseSensitive: false),
    ];

    return dangerousPatterns.any((pattern) => pattern.hasMatch(input));
  }
}
