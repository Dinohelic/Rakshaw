import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../constants/app_constants.dart';

final secureStorageServiceProvider = Provider((ref) => SecureStorageService());

class SecureStorageService {
  final FlutterSecureStorage _storage;
  final Map<String, String> _memoryFallback = {};

  SecureStorageService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<void> saveToken(String token) async {
    try {
      await _storage.write(key: AppConstants.tokenKey, value: token);
    } catch (_) {
      _memoryFallback[AppConstants.tokenKey] = token;
    }
  }

  Future<String?> getToken() async {
    try {
      return await _storage.read(key: AppConstants.tokenKey);
    } catch (_) {
      return _memoryFallback[AppConstants.tokenKey];
    }
  }

  Future<void> clearToken() async {
    try {
      await _storage.delete(key: AppConstants.tokenKey);
    } catch (_) {
      _memoryFallback.remove(AppConstants.tokenKey);
    }
  }

  /// Sets location sharing consent decision for an authenticated student.
  Future<void> setLocationSharingConsent(String studentId, bool enabled) async {
    final key = 'location_sharing_consent_$studentId';
    try {
      await _storage.write(key: key, value: enabled ? 'true' : 'false');
    } catch (_) {
      _memoryFallback[key] = enabled ? 'true' : 'false';
    }
  }

  /// Returns whether the student has previously granted location sharing consent.
  Future<bool> getLocationSharingConsent(String studentId) async {
    final state = await getLocationSharingConsentState(studentId);
    return state == true;
  }

  /// Returns tri-state location consent:
  /// - `null`: Student has never been prompted / no decision on record (first login).
  /// - `true`: Student explicitly authorized location tracking.
  /// - `false`: Student opted out or withdrew consent.
  Future<bool?> getLocationSharingConsentState(String studentId) async {
    final key = 'location_sharing_consent_$studentId';
    String? val;
    try {
      val = await _storage.read(key: key);
    } catch (_) {
      val = _memoryFallback[key];
    }
    if (val == null) return null;
    return val == 'true';
  }

  /// Clears location sharing consent for a student (e.g. for testing reset).
  Future<void> clearLocationSharingConsent(String studentId) async {
    final key = 'location_sharing_consent_$studentId';
    try {
      await _storage.delete(key: key);
    } catch (_) {
      _memoryFallback.remove(key);
    }
  }

  static const String _rememberMeKey = 'raksha_remember_me_preference';

  /// Saves student's Remember Me preference.
  Future<void> setRememberMe(bool enabled) async {
    try {
      await _storage.write(key: _rememberMeKey, value: enabled ? 'true' : 'false');
    } catch (_) {
      _memoryFallback[_rememberMeKey] = enabled ? 'true' : 'false';
    }
  }

  /// Gets student's Remember Me preference (defaults to true if unset).
  Future<bool> getRememberMe() async {
    String? val;
    try {
      val = await _storage.read(key: _rememberMeKey);
    } catch (_) {
      val = _memoryFallback[_rememberMeKey];
    }
    if (val == null) return true; // Default to persistent
    return val == 'true';
  }

  /// Clears Remember Me preference.
  Future<void> clearRememberMe() async {
    try {
      await _storage.delete(key: _rememberMeKey);
    } catch (_) {
      _memoryFallback.remove(_rememberMeKey);
    }
  }
}
